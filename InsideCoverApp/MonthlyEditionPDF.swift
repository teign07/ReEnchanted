import Foundation
import UIKit
import PDFKit
import Photos
#if canImport(Vision)
import Vision
import ImageIO
#endif

#if canImport(Vision)
private final class PublicationCoverVisionCollector: @unchecked Sendable {
    var faces: [CGRect] = []
    var people: [CGRect] = []
    var salient: [CGRect] = []
}
#endif

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
        // The First Door is the one volume every reader can compare. Give it a
        // house identity instead of letting the arrival month randomly turn
        // the threshold into waves, leaves, or a lamp.
        if edition.isFirstDoorEdition {
            return EditionStyle(
                palette: palettes[0],
                coverMotif: .keyAndDoor,
                ornament: .stars
            )
        }
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

    /// A full-page illuminated plate, already rendered.
    ///
    /// The plates arrive pre-rendered on purpose. `IlluminatedQuoteCard` is a
    /// SwiftUI view and `ImageRenderer` is `@MainActor`, so composing them here
    /// would drag main-thread work into the middle of PDF generation, and the
    /// sewing animation that covers a binding would stutter on the very frames
    /// meant to hide the wait. The caller composes them first, with the cache
    /// doing the real work on every bind after the first.
    struct IlluminatedPlate {
        let image: UIImage
        let caption: String
    }

    /// A selected cover image with the editorial title-safe region authored for
    /// that image. Reader photographs deliberately use the footer treatment;
    /// commissioned Bindery plates keep their own quiet clearing.
    struct VolumeCoverArtwork {
        let image: UIImage
        let titleLayout: PublicationCoverTitleLayout
        let id: String
        /// Normalised top-left source coordinates. Nil keeps the traditional
        /// centred crop used by authored plates.
        let focusPoint: CGPoint?

        init(
            image: UIImage,
            titleLayout: PublicationCoverTitleLayout,
            id: String,
            focusPoint: CGPoint? = nil
        ) {
            self.image = image
            self.titleLayout = titleLayout
            self.id = id
            self.focusPoint = focusPoint
        }
    }

    struct VolumeCoverCopy {
        var readerName: String
        var coverLine: String
        var coverSubline: String
        var dayCount: Int
        var pageCount: Int

        init(annual: AnnualEdition) {
            readerName = annual.readerRole?.fullName ?? annual.readerName
            coverLine = annual.resolvedCoverLine()
            coverSubline = annual.resolvedCoverSubline()
            dayCount = annual.dayCount
            pageCount = annual.pageCount
        }

        init(readerName: String, coverLine: String, coverSubline: String, dayCount: Int = 0, pageCount: Int = 0) {
            self.readerName = readerName
            self.coverLine = coverLine
            self.coverSubline = coverSubline
            self.dayCount = dayCount
            self.pageCount = pageCount
        }
    }

    static func volumeCoverCopy(for edition: MonthlyEdition) -> VolumeCoverCopy {
        if edition.publicationKind == .weekly {
            return VolumeCoverCopy(
                readerName: edition.readerRole?.fullName ?? edition.readerName,
                coverLine: "Issue No. \(edition.chapterNumber)",
                coverSubline: edition.subtitle,
                dayCount: edition.dayCount,
                pageCount: edition.pageCount
            )
        }
        if edition.isFirstDoorEdition {
            return VolumeCoverCopy(
                readerName: edition.readerRole?.fullName ?? edition.readerName,
                coverLine: "The First Door",
                coverSubline: edition.subtitle,
                dayCount: edition.dayCount,
                pageCount: edition.pageCount
            )
        }
        return VolumeCoverCopy(
            readerName: edition.readerRole?.fullName ?? edition.readerName,
            coverLine: edition.monthName,
            coverSubline: ["Chapter \(edition.chapterNumber)", edition.theme?.name]
                .compactMap { $0 }.joined(separator: " · "),
            dayCount: edition.dayCount,
            pageCount: edition.pageCount
        )
    }

    /// Finds the part of a reader photograph that an aspect-fill crop should
    /// protect. Faces outrank bodies, and bodies outrank general saliency. The
    /// result is frozen into the edition; later proof and press renders do not
    /// rerun Vision and cannot drift apart.
    static func readerPhotoFocus(for source: UIImage) -> PublicationCoverFocus? {
        #if canImport(Vision)
        let image = coverFocusWorkingImage(source, maxSide: 768)
        guard let cgImage = image.cgImage else { return nil }
        let collector = PublicationCoverVisionCollector()

        let faceRequest = VNDetectFaceRectanglesRequest { request, _ in
            collector.faces = ((request.results as? [VNFaceObservation]) ?? []).map(\.boundingBox)
        }
        let humanRequest = VNDetectHumanRectanglesRequest { request, _ in
            collector.people = ((request.results as? [VNHumanObservation]) ?? []).map(\.boundingBox)
        }
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest { request, _ in
            collector.salient = ((request.results as? [VNSaliencyImageObservation]) ?? [])
                .flatMap { $0.salientObjects ?? [] }
                .sorted { $0.confidence > $1.confidence }
                .prefix(3)
                .map(\.boundingBox)
        }
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: coverFocusVisionOrientation(for: image.imageOrientation)
        )
        try? handler.perform([faceRequest, humanRequest, saliencyRequest])

        let protected = !collector.faces.isEmpty
            ? collector.faces
            : (!collector.people.isEmpty ? collector.people : collector.salient)
        guard var union = protected.first else { return nil }
        for rect in protected.dropFirst() {
            union = union.union(rect)
        }
        return PublicationCoverFocus(
            x: min(0.92, max(0.08, union.midX)),
            y: min(0.92, max(0.08, 1 - union.midY))
        )
        #else
        return nil
        #endif
    }

    #if canImport(Vision)
    private static func coverFocusVisionOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private static func coverFocusWorkingImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxSide else { return image }
        let ratio = maxSide / longestSide
        let target = CGSize(
            width: max(1, image.size.width * ratio),
            height: max(1, image.size.height * ratio)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
    #endif

    static func write(
        _ edition: MonthlyEdition,
        plates: [IlluminatedPlate] = [],
        to url: URL
    ) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let style = EditionStyle.style(for: edition)
        let margins = UIEdgeInsets(top: 60, left: 120, bottom: 64, right: 58)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: url) { context in
            renderInterior(
                edition,
                plates: plates,
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
        plates: [IlluminatedPlate] = [],
        into context: UIGraphicsPDFRendererContext,
        style: EditionStyle,
        pageBounds: CGRect,
        margins: UIEdgeInsets,
        designSize: CGSize
    ) {
        var cursor = PDFCursor(bounds: pageBounds, margins: margins)
        cursor.seed = "\(BookThemeEngine.monthKey(for: edition.startDate))-\(edition.theme?.name ?? "untitled")"
        var marginaliaIndex = 0
        let marginalia = marginNotes(for: edition)
        let designRect = CGRect(origin: .zero, size: designSize)

        if edition.isFirstDoorEdition, let matter = edition.firstDoorPublication {
            renderFirstDoorInterior(
                edition,
                matter: matter,
                plates: plates,
                into: context,
                style: style,
                cursor: &cursor,
                designSize: designSize
            )
            return
        }

        context.beginPage()
        withDesignSpace(designSize: designSize, pageBounds: pageBounds) {
            drawCover(edition, style: style, bounds: designRect)
        }

        drawPatronFrontispiece(edition, style: style, context: context, cursor: &cursor)
        drawDedication(edition.dedication, style: style, context: context, cursor: &cursor)

        if !edition.foreword.isEmpty {
            beginComposedPage(context, style: style, cursor: &cursor)
            drawForeword(edition, style: style, context: context, cursor: &cursor)
        }

        if let bindingStory = edition.bindingStory?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            beginComposedPage(context, style: style, cursor: &cursor)
            drawBindingStory(bindingStory, edition: edition, style: style, context: context, cursor: &cursor)
        }

        // The plate signature. Real books gather their plates together because
        // of how signatures are printed, so this reads as bookmaking rather
        // than as decoration, and it lands where it belongs: the binding story
        // is the braids' overture, and these are the month's own strongest
        // lines, illuminated, right behind it.
        drawIlluminatedPlates(plates, style: style, context: context, cursor: &cursor)

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

        if let matter = edition.publicationMatter {
            if !matter.almanacItems.isEmpty {
                drawVolumeCabinet(
                    title: "The Month's Little Almanac",
                    note: "Outer weather, ink-time, and private charts only where you opened that drawer. Missing days remain missing.",
                    items: matter.almanacItems,
                    style: style,
                    context: context,
                    cursor: &cursor
                )
            }
            if !matter.crossingItems.isEmpty {
                drawVolumeCabinet(
                    title: "Things That Crossed the Hedge",
                    note: "Real choices that left a consequence in the Labyrinth. The ordinary world did this first.",
                    items: matter.crossingItems,
                    style: style,
                    context: context,
                    cursor: &cursor
                )
            }
        }
        if let conversation = edition.castConversation, !conversation.isEmpty {
            drawVolumeCastConversation(
                conversation,
                seed: "month-\(BookThemeEngine.monthKey(for: edition.startDate))",
                style: style,
                context: context,
                cursor: &cursor
            )
        }

        for section in edition.sections where section.id != "the-months-theme" {
            if section.id == "what-the-cast-did" {
                drawCastDivider(edition.castLead, style: style, context: context, cursor: &cursor)
            }
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

    /// The First Door is a commissioned threshold book, not a one-day monthly
    /// report. Its sequence performs the threshold before it explains it:
    /// ownership, a private note, the visible thread, story, handmade leaf,
    /// argument, cast dispute, supporting evidence, and only then proof.
    private static func renderFirstDoorInterior(
        _ edition: MonthlyEdition,
        matter: FirstDoorPublicationMatter,
        plates: [IlluminatedPlate],
        into context: UIGraphicsPDFRendererContext,
        style: EditionStyle,
        cursor: inout PDFCursor,
        designSize: CGSize
    ) {
        let designRect = CGRect(origin: .zero, size: designSize)
        var marginaliaIndex = 0
        let marginalia = marginNotes(for: edition)

        context.beginPage()
        withDesignSpace(designSize: designSize, pageBounds: cursor.bounds) {
            drawFirstDoorCover(edition, matter: matter, style: style, bounds: designRect)
        }

        drawFirstDoorOwnership(edition, matter: matter, style: style, context: context, cursor: &cursor)
        drawFirstDoorBookNote(edition, matter: matter, style: style, context: context, cursor: &cursor)
        drawPatronFrontispiece(edition, style: style, context: context, cursor: &cursor)
        drawFirstDoorThread(edition, matter: matter, style: style, context: context, cursor: &cursor)

        if let opening = edition.sections.first {
            drawSection(
                opening,
                style: style,
                marginalia: marginalia,
                marginaliaIndex: &marginaliaIndex,
                context: context,
                cursor: &cursor
            )
        }

        if let leaf = matter.pagewrightLeaf {
            drawFirstDoorPagewrightLeaf(
                edition,
                leaf: leaf,
                style: style,
                context: context,
                cursor: &cursor
            )
        }

        drawIlluminatedPlates(plates, style: style, context: context, cursor: &cursor)
        drawFirstDoorArgument(edition, matter: matter, style: style, context: context, cursor: &cursor)
        if let conversation = matter.bindingConversation, !conversation.isEmpty {
            drawVolumeCastConversation(
                conversation,
                seed: "first-door-\(matter.arrivalLine)",
                style: style,
                context: context,
                cursor: &cursor
            )
        }

        for section in edition.sections.dropFirst() {
            drawSection(
                section,
                style: style,
                marginalia: marginalia,
                marginaliaIndex: &marginaliaIndex,
                context: context,
                cursor: &cursor
            )
        }

        drawFirstDoorProof(edition, matter: matter, style: style, context: context, cursor: &cursor)
        drawClosing(matter.closing, edition: edition, style: style, context: context, cursor: &cursor)
        drawFirstDoorColophon(edition, matter: matter, style: style, context: context, cursor: &cursor)
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
        if edition.publicationKind == .weekly {
            guard spec.coverTreatment == .saddleStitch,
                  let matter = edition.weeklyPublication else {
                throw NSError(
                    domain: "Bindery",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "This weekly issue has not been prepared for the saddle-stitch press."]
                )
            }
            return try WeeklyIssuePDFWriter.writePrintInterior(
                matter,
                dedication: edition.dedication,
                spec: spec,
                to: url
            )
        }

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
        guard target <= spec.maximumPages else {
            let message = spec.coverTreatment == .saddleStitch
                ? "This weekly issue grew past 48 pages. Bind it as a softcover instead."
                : "This volume grew beyond the Bindery's 800-page limit. Divide it into smaller volumes before printing."
            throw NSError(
                domain: "Bindery",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
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
    /// front panel, sized from the final page count. A faithful draft: the
    /// authoritative dimensions come from the print partner's template for this
    /// exact page count at order time.
    static func writeCoverWrap(
        _ edition: MonthlyEdition,
        spec: PrintSpec = .hardcover6x9,
        pageCount: Int,
        coverPhoto: UIImage? = nil,
        exactDimensions: PhysicalBookCoverDimensions? = nil,
        to url: URL
    ) throws {
        let wrap = PrintGeometry.coverWrapSizeInches(pageCount: pageCount, spec: spec)
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: exactDimensions?.widthPoints ?? wrap.width * PrintSpec.pointsPerInch,
            height: exactDimensions?.heightPoints ?? wrap.height * PrintSpec.pointsPerInch
        )
        guard pageBounds.width > spec.trimWidthPoints * 2,
              pageBounds.height >= spec.trimHeightPoints else {
            throw NSError(domain: "Bindery", code: 15, userInfo: [NSLocalizedDescriptionKey: "Lulu returned a cover canvas too small for this edition."])
        }
        let style = EditionStyle.style(for: edition)
        let geometry = volumeCoverGeometry(pageBounds: pageBounds, pageCount: pageCount, spec: spec)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            guard let cg = UIGraphicsGetCurrentContext() else { return }
            drawVerticalWash(in: pageBounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)

            drawPhysicalCoverPanels(
                edition,
                spec: spec,
                style: style,
                coverPhoto: coverPhoto,
                backRect: geometry.back,
                spineRect: geometry.spine,
                frontRect: geometry.front,
                frontArtworkRect: geometry.frontArtwork
            )
        }
    }

    /// Small raster preview of the physical cover treatment: back, spine, front.
    /// This deliberately uses the same panel drawing as the PDF cover wrap.
    static func physicalCoverPreviewImage(
        _ edition: MonthlyEdition,
        spec: PrintSpec,
        pageCount: Int,
        coverPhoto: UIImage? = nil,
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
            drawPhysicalCoverPanels(
                edition,
                spec: spec,
                style: style,
                coverPhoto: coverPhoto,
                backRect: backRect,
                spineRect: spineRect,
                frontRect: frontRect
            )
            cg.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor.black.withAlphaComponent(0.22).setStroke()
            UIBezierPath(rect: CGRect(x: backRect.minX, y: backRect.minY, width: totalWidth, height: panelHeight)).stroke()
        }
    }

    private static func drawPhysicalCoverPanels(
        _ edition: MonthlyEdition,
        spec: PrintSpec,
        style: EditionStyle,
        coverPhoto: UIImage? = nil,
        backRect: CGRect,
        spineRect: CGRect,
        frontRect: CGRect,
        frontArtworkRect: CGRect? = nil
    ) {
        // Every supplied image, commissioned or personal, goes through the
        // same title-safe compositor used by the front proof. Reader photos
        // own an upper image field and a separate deep-ink title board; authored
        // plates retain their commissioned clearing.
        if let coverPhoto {
            let plate = PublicationCoverCatalogue.plate(id: edition.publicationCoverPlateID)
            let storedFocus = edition.publicationCoverFocus
            let artwork = VolumeCoverArtwork(
                image: coverPhoto,
                titleLayout: plate?.titleLayout ?? .photographFooter,
                id: plate?.id ?? "reader-photo",
                focusPoint: plate == nil
                    ? storedFocus.map { CGPoint(x: $0.x, y: $0.y) }
                    : nil
            )
            let copy = volumeCoverCopy(for: edition)
            let artworkRect = frontArtworkRect ?? frontRect
            drawCoverWrapField(for: artwork.titleLayout, in: artworkRect)
            drawVolumeFrontArtwork(artwork, artworkRect: artworkRect, visibleRect: frontRect)
            drawVolumeCoverType(copy, artwork: artwork, rect: frontRect)
            if edition.publicationKind == .weekly, let matter = edition.weeklyPublication {
                drawWeeklyIssueBackCover(matter, style: style, rect: backRect)
            } else {
                drawCoverBackPanel(edition, style: style, rect: backRect)
            }
            if spineRect.width >= 10 {
                drawSpineTitle(edition, style: style, rect: spineRect)
            }
            return
        }
        if edition.publicationKind == .weekly, let matter = edition.weeklyPublication {
            drawWeeklyIssueCover(matter, style: style, frontRect: frontRect, backRect: backRect)
            return
        }
        switch spec.coverTreatment {
        // A printed paperback cover is the same artwork problem as a case wrap:
        // front panel, back panel, and a spine title once the block is thick
        // enough to carry one. The spine check below handles thin seasons on
        // its own, which is why perfect binding needs no branch of its own.
        case .caseWrap, .perfectBound, .saddleStitch:
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

    /// A weekly cover is a magazine cover, not Chapter N squeezed onto a
    /// spine-less monthly jacket. The cover lines are editorial promises the
    /// issue can actually keep; the back is its contents page in miniature.
    private static func drawWeeklyIssueCover(
        _ matter: WeeklyPublicationMatter,
        style: EditionStyle,
        frontRect: CGRect,
        backRect: CGRect
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        drawVerticalWash(in: frontRect, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)
        drawVerticalWash(in: backRect, top: style.palette.paperBottom, bottom: style.palette.paperTop, cg: cg)
        WeeklyIssueShareCardRenderer.drawStarField(in: frontRect, color: style.palette.gold)

        let ink = style.palette.ink
        let accent = style.palette.accent
        drawCentered(
            "T H E   B O O K   O F   Y O U",
            font: .systemFont(ofSize: max(8, frontRect.height * 0.025), weight: .black),
            color: ink.withAlphaComponent(0.74),
            y: frontRect.minY + frontRect.height * 0.09,
            in: frontRect
        )
        drawCentered(
            "WEEKLY",
            font: .systemFont(ofSize: max(7, frontRect.height * 0.018), weight: .bold),
            color: accent,
            y: frontRect.minY + frontRect.height * 0.15,
            in: frontRect
        )
        drawCentered(
            "Issue No. \(matter.issue.number)",
            font: .serifFont(ofSize: max(25, frontRect.height * 0.080), weight: .bold),
            color: ink,
            y: frontRect.minY + frontRect.height * 0.28,
            in: frontRect
        )
        drawCentered(
            matter.issue.dateRange.uppercased(),
            font: .systemFont(ofSize: max(7, frontRect.height * 0.019), weight: .heavy),
            color: accent,
            y: frontRect.minY + frontRect.height * 0.39,
            in: frontRect
        )

        let coverStory = WeeklyIssue.taleLine(for: matter.issue)
            ?? matter.issue.highlights.first.map { "“\($0)”" }
            ?? matter.card.subtitle
        drawCenteredWrapped(
            coverStory,
            font: .serifItalicFont(ofSize: max(11, frontRect.height * 0.037)),
            color: ink.withAlphaComponent(0.90),
            rect: CGRect(
                x: frontRect.minX + frontRect.width * 0.12,
                y: frontRect.minY + frontRect.height * 0.51,
                width: frontRect.width * 0.76,
                height: frontRect.height * 0.22
            )
        )
        drawCentered(
            matter.issue.readerRole?.fullName ?? matter.readerName,
            font: .serifFont(ofSize: max(8, frontRect.height * 0.022), weight: .semibold),
            color: ink.withAlphaComponent(0.66),
            y: frontRect.minY + frontRect.height * 0.83,
            in: frontRect
        )
        drawCentered(
            "SEVEN DAYS · ONE SMALL PRESS",
            font: .systemFont(ofSize: max(6.5, frontRect.height * 0.015), weight: .bold),
            color: accent.withAlphaComponent(0.86),
            y: frontRect.minY + frontRect.height * 0.90,
            in: frontRect
        )
        drawWeeklyIssueBackCover(matter, style: style, rect: backRect)
    }

    private static func drawWeeklyIssueBackCover(
        _ matter: WeeklyPublicationMatter,
        style: EditionStyle,
        rect: CGRect
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        drawVerticalWash(in: rect, top: style.palette.paperBottom, bottom: style.palette.paperTop, cg: cg)
        let ink = style.palette.ink
        let accent = style.palette.accent
        drawCentered(
            "IN THIS ISSUE",
            font: .systemFont(ofSize: max(8, rect.height * 0.021), weight: .black),
            color: accent,
            y: rect.minY + rect.height * 0.13,
            in: rect
        )
        let lines = [
            matter.issue.bindingStory?.nonEmpty == nil ? nil : "The week, bound",
            matter.issue.castConversation?.isEmpty == false ? "An argument at the issue desk" : nil,
            "Seven days, set in full",
            matter.issue.revelations.isEmpty ? nil : "What the Book noticed",
            matter.issue.scrapbookCount == 0 ? nil : "Scrapbook plates",
            "The wrapped week"
        ].compactMap { $0 }
        var y = rect.minY + rect.height * 0.23
        for (index, line) in lines.enumerated() {
            drawCentered(
                "\(index + 1).  \(line)",
                font: .serifFont(ofSize: max(8, rect.height * 0.025), weight: .semibold),
                color: ink.withAlphaComponent(0.82),
                y: y,
                in: rect.insetBy(dx: rect.width * 0.09, dy: 0)
            )
            y += rect.height * 0.064
        }
        drawCenteredWrapped(
            matter.card.nextIssueTease,
            font: .serifItalicFont(ofSize: max(9, rect.height * 0.027)),
            color: ink.withAlphaComponent(0.72),
            rect: CGRect(
                x: rect.minX + rect.width * 0.12,
                y: rect.minY + rect.height * 0.70,
                width: rect.width * 0.76,
                height: rect.height * 0.13
            )
        )
        drawCentered(
            "6 × 9 · SADDLE STITCHED · MADE TO ORDER",
            font: .systemFont(ofSize: max(6, rect.height * 0.014), weight: .semibold),
            color: ink.withAlphaComponent(0.46),
            y: rect.minY + rect.height * 0.90,
            in: rect
        )
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

    static func writeAnnual(
        _ annual: AnnualEdition,
        plates: [IlluminatedPlate] = [],
        to url: URL
    ) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margins = UIEdgeInsets(top: 60, left: 120, bottom: 64, right: 58)
        let annualStyle = annualStyle(for: annual)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: url) { context in
            renderAnnualInterior(
                annual,
                plates: plates,
                into: context,
                style: annualStyle,
                pageBounds: pageBounds,
                margins: margins,
                designSize: pageBounds.size
            )
        }
    }

    /// The Bound Year press path. Unlike the old adapter, this keeps the volume
    /// as a volume all the way to the PDF: chapter dividers, front-of-volume
    /// almanac, Cast conversation, annual back matter, and distinct cover copy.
    @discardableResult
    static func writeVolumePrintInterior(
        _ annual: AnnualEdition,
        plates: [IlluminatedPlate] = [],
        spec: PrintSpec,
        to url: URL
    ) throws -> Int {
        let fullBleed = PrintGeometry.fullBleedTrimInches(spec: spec)
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: fullBleed.width * PrintSpec.pointsPerInch,
            height: fullBleed.height * PrintSpec.pointsPerInch
        )
        let style = annualStyle(for: annual)
        func renderedData(margins: UIEdgeInsets) -> Data {
            UIGraphicsPDFRenderer(bounds: pageBounds).pdfData { context in
                renderAnnualInterior(
                    annual,
                    plates: plates,
                    into: context,
                    style: style,
                    pageBounds: pageBounds,
                    margins: margins,
                    designSize: CGSize(width: 612, height: 792)
                )
            }
        }
        // Lulu's recommended gutter grows sharply after 150 pages. Render once,
        // let the actual flow reveal its bracket, then reflow with equal inner
        // and outer safety so both recto and verso pages clear the binding.
        var margins = volumeInteriorMargins(spec: spec, pageCount: 200)
        var document: PDFDocument?
        for _ in 0..<3 {
            document = PDFDocument(data: renderedData(margins: margins))
            guard let count = document?.pageCount else { break }
            let adjusted = volumeInteriorMargins(spec: spec, pageCount: count)
            if abs(adjusted.left - margins.left) < 0.5 { break }
            margins = adjusted
        }
        guard let document else {
            throw NSError(domain: "Bindery", code: 11, userInfo: [NSLocalizedDescriptionKey: "The chaptered interior would not render."])
        }
        let rawCount = document.pageCount
        let target = PrintGeometry.boundPageCount(rawPages: rawCount, spec: spec)
        guard target <= spec.maximumPages else {
            throw NSError(
                domain: "Bindery",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: "This volume grew beyond the Bindery's \(spec.maximumPages)-page limit. It needs another spine."]
            )
        }
        if target > rawCount {
            for _ in 0..<(target - rawCount) {
                if let blank = blankEndpaper(size: pageBounds.size, style: style) {
                    document.insert(blank, at: document.pageCount)
                }
            }
        }
        guard document.write(to: url) else {
            throw NSError(domain: "Bindery", code: 13, userInfo: [NSLocalizedDescriptionKey: "The chaptered interior would not save."])
        }
        return target
    }

    private static func volumeInteriorMargins(spec: PrintSpec, pageCount: Int) -> UIEdgeInsets {
        let trimSide: Double
        switch pageCount {
        case ..<61: trimSide = 0.5
        case 61...150: trimSide = 0.625
        case 151...400: trimSide = 1.0
        case 401...600: trimSide = 1.125
        default: trimSide = 1.25
        }
        let side = (spec.bleedInches + trimSide) * PrintSpec.pointsPerInch
        let vertical = (spec.bleedInches + spec.safeMarginInches) * PrintSpec.pointsPerInch
        return UIEdgeInsets(top: vertical, left: side, bottom: vertical, right: side)
    }

    static func writeVolumeCoverWrap(
        _ annual: AnnualEdition,
        spec: PrintSpec,
        pageCount: Int,
        artwork: VolumeCoverArtwork? = nil,
        exactDimensions: PhysicalBookCoverDimensions? = nil,
        to url: URL
    ) throws {
        let fallback = PrintGeometry.coverWrapSizeInches(pageCount: pageCount, spec: spec)
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: exactDimensions?.widthPoints ?? fallback.width * PrintSpec.pointsPerInch,
            height: exactDimensions?.heightPoints ?? fallback.height * PrintSpec.pointsPerInch
        )
        guard pageBounds.width > spec.trimWidthPoints * 2,
              pageBounds.height >= spec.trimHeightPoints else {
            throw NSError(domain: "Bindery", code: 14, userInfo: [NSLocalizedDescriptionKey: "Lulu returned a cover canvas too small for this book."])
        }
        let geometry = volumeCoverGeometry(pageBounds: pageBounds, pageCount: pageCount, spec: spec)
        let style = annualStyle(for: annual)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            guard let cg = UIGraphicsGetCurrentContext() else { return }
            drawVerticalWash(in: pageBounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)
            drawVolumeCoverPanels(
                annual,
                spec: spec,
                style: style,
                artwork: artwork,
                geometry: geometry
            )
        }
    }

    /// A front-cover proof made by the same UIKit compositor that writes the
    /// press PDF. The Bindery screen does not approximate the title with a
    /// landscape thumbnail; it shows the actual image crop, line breaks, ink,
    /// and title-safe region.
    static func volumeCoverFrontProof(
        copy: VolumeCoverCopy,
        artwork: VolumeCoverArtwork,
        size: CGSize = CGSize(width: 600, height: 900)
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            drawVolumeFrontArtwork(artwork, artworkRect: rect, visibleRect: rect)
            drawVolumeCoverType(copy, artwork: artwork, rect: rect)
        }
    }

    private struct VolumeCoverGeometry {
        var document: CGRect
        var back: CGRect
        var spine: CGRect
        var front: CGRect
        var leftFlap: CGRect?
        var rightFlap: CGRect?
        var frontArtwork: CGRect
    }

    private static func volumeCoverGeometry(
        pageBounds: CGRect,
        pageCount: Int,
        spec: PrintSpec
    ) -> VolumeCoverGeometry {
        let localSpineWidth = CGFloat(
            PrintGeometry.spineWidthInches(pageCount: pageCount, spec: spec) * PrintSpec.pointsPerInch
        )
        let exactDerivedSpine = pageBounds.width
            - CGFloat(spec.trimWidthPoints * 2)
            - CGFloat(spec.coverWrapMarginInches * PrintSpec.pointsPerInch * 2)
        // Paperback and casewrap canvases have known outside allowances, so
        // Lulu's total width reveals the exact spine. A dust jacket spends the
        // remainder on two flaps as well, so its centred local estimate is used
        // only to divide front/back; critical jacket type stays far from both
        // folds and cloth foil is supplied separately to Lulu.
        let spineWidth: CGFloat
        if spec.coverTreatment == .linenWrap {
            spineWidth = localSpineWidth
        } else if exactDerivedSpine > 0 {
            spineWidth = exactDerivedSpine
        } else {
            spineWidth = localSpineWidth
        }
        let center = pageBounds.midX
        let panelTop = max(0, (pageBounds.height - spec.trimHeightPoints) / 2)
        let back = CGRect(
            x: center - spineWidth / 2 - spec.trimWidthPoints,
            y: panelTop,
            width: spec.trimWidthPoints,
            height: spec.trimHeightPoints
        )
        let spine = CGRect(
            x: center - spineWidth / 2,
            y: panelTop,
            width: spineWidth,
            height: spec.trimHeightPoints
        )
        let front = CGRect(
            x: center + spineWidth / 2,
            y: panelTop,
            width: spec.trimWidthPoints,
            height: spec.trimHeightPoints
        )
        let leftRemainder = max(0, back.minX - pageBounds.minX)
        let rightRemainder = max(0, pageBounds.maxX - front.maxX)
        let isJacket = spec.coverTreatment == .linenWrap
        let leftFlap = isJacket && leftRemainder > 4
            ? CGRect(x: pageBounds.minX, y: panelTop, width: leftRemainder, height: spec.trimHeightPoints)
            : nil
        let rightFlap = isJacket && rightRemainder > 4
            ? CGRect(x: front.maxX, y: panelTop, width: rightRemainder, height: spec.trimHeightPoints)
            : nil

        // Map the commissioned 6.25 × 9.25 plate to the visible 6 × 9 front
        // plus its real 0.125-inch bleed. A complementary wash already fills
        // the deeper casewrap turn-in, so the illustration does not have to be
        // stretched until its authored title clearing wanders off the board.
        let frontArtwork = front
            .insetBy(dx: -spec.bleedPoints, dy: -spec.bleedPoints)
            .intersection(pageBounds)
        return VolumeCoverGeometry(
            document: pageBounds,
            back: back,
            spine: spine,
            front: front,
            leftFlap: leftFlap,
            rightFlap: rightFlap,
            frontArtwork: frontArtwork
        )
    }

    private static func drawVolumeCoverPanels(
        _ annual: AnnualEdition,
        spec: PrintSpec,
        style: EditionStyle,
        artwork: VolumeCoverArtwork?,
        geometry: VolumeCoverGeometry
    ) {
        let copy = VolumeCoverCopy(annual: annual)
        if let artwork {
            drawCoverWrapField(for: artwork.titleLayout, in: geometry.document)
            drawVolumeFrontArtwork(
                artwork,
                artworkRect: geometry.frontArtwork,
                visibleRect: geometry.front
            )
            drawVolumeCoverType(copy, artwork: artwork, rect: geometry.front)
        } else {
            withDesignSpaceMapped(designSize: CGSize(width: 612, height: 792), into: geometry.front) {
                drawAnnualCover(annual, style: style, bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
            }
        }
        drawVolumeBackPanel(annual, style: style, rect: geometry.back, darkField: artwork != nil)
        if geometry.spine.width >= 10 {
            drawVolumeSpineTitle(annual, style: style, rect: geometry.spine)
        }
        if spec.coverTreatment == .linenWrap {
            if let left = geometry.leftFlap {
                drawVolumeJacketFlap(annual, side: .left, style: style, rect: left, darkField: artwork != nil)
            }
            if let right = geometry.rightFlap {
                drawVolumeJacketFlap(annual, side: .right, style: style, rect: right, darkField: artwork != nil)
            }
        }
    }

    private static func drawCoverWrapField(for layout: PublicationCoverTitleLayout, in rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let colors: (UIColor, UIColor)
        switch layout {
        case .hedgeDoor:
            colors = (UIColor(red: 0.045, green: 0.075, blue: 0.050, alpha: 1), UIColor(red: 0.14, green: 0.10, blue: 0.055, alpha: 1))
        case .weatherCabinet:
            colors = (UIColor(red: 0.045, green: 0.075, blue: 0.11, alpha: 1), UIColor(red: 0.16, green: 0.105, blue: 0.055, alpha: 1))
        case .livingStacks, .centeredNight:
            colors = (UIColor(red: 0.025, green: 0.045, blue: 0.075, alpha: 1), UIColor(red: 0.105, green: 0.065, blue: 0.035, alpha: 1))
        case .photographFooter:
            colors = (UIColor(white: 0.055, alpha: 1), UIColor(white: 0.16, alpha: 1))
        }
        drawVerticalWash(in: rect, top: colors.0, bottom: colors.1, cg: cg)
    }

    private static func drawAspectFill(
        _ image: UIImage,
        in rect: CGRect,
        focusPoint: CGPoint? = nil
    ) {
        guard rect.width > 0, rect.height > 0, image.size.width > 0, image.size.height > 0,
              let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        cg.addRect(rect)
        cg.clip()
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let filled = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin: CGPoint
        if let focusPoint {
            let focus = CGPoint(
                x: min(1, max(0, focusPoint.x)),
                y: min(1, max(0, focusPoint.y))
            )
            // Put the detected subject above the photograph footer. Clamp to
            // the legal aspect-fill range so no uncovered edge can appear.
            let desired = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.36)
            let proposedX = desired.x - filled.width * focus.x
            let proposedY = desired.y - filled.height * focus.y
            origin = CGPoint(
                x: min(rect.minX, max(rect.maxX - filled.width, proposedX)),
                y: min(rect.minY, max(rect.maxY - filled.height, proposedY))
            )
        } else {
            origin = CGPoint(
                x: rect.midX - filled.width / 2,
                y: rect.midY - filled.height / 2
            )
        }
        image.draw(in: CGRect(
            x: origin.x,
            y: origin.y,
            width: filled.width,
            height: filled.height
        ))
        cg.restoreGState()
    }

    /// Reader photography is a composed cover, not arbitrary live type laid
    /// over arbitrary pixels. Its image owns the upper field and its title
    /// owns a separate lower field, so neither faces nor legibility depend on
    /// Vision finding the subject correctly. Authored plates remain full bleed.
    private static func drawVolumeFrontArtwork(
        _ artwork: VolumeCoverArtwork,
        artworkRect: CGRect,
        visibleRect: CGRect
    ) {
        guard artwork.titleLayout == .photographFooter else {
            drawAspectFill(
                artwork.image,
                in: artworkRect,
                focusPoint: artwork.focusPoint
            )
            return
        }

        drawCoverWrapField(for: .photographFooter, in: artworkRect)
        let photographBottom = visibleRect.minY + visibleRect.height * 0.61
        let photographRect = CGRect(
            x: artworkRect.minX,
            y: artworkRect.minY,
            width: artworkRect.width,
            height: max(1, photographBottom - artworkRect.minY)
        )
        drawAspectFill(
            artwork.image,
            in: photographRect,
            focusPoint: artwork.focusPoint
        )
    }

    private static func drawVolumeCoverType(
        _ copy: VolumeCoverCopy,
        artwork: VolumeCoverArtwork,
        rect: CGRect
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let normalised = artwork.titleLayout.titleRect
        let titleRect = CGRect(
            x: rect.minX + rect.width * normalised.x,
            y: rect.minY + rect.height * normalised.y,
            width: rect.width * normalised.width,
            height: rect.height * normalised.height
        )
        let darkInk = UIColor(red: 0.13, green: 0.105, blue: 0.075, alpha: 1)
        let lightInk = UIColor(white: 0.98, alpha: 1)
        let ink = artwork.titleLayout.usesDarkInk ? darkInk : lightInk
        let gold = artwork.titleLayout.usesDarkInk
            ? UIColor(red: 0.43, green: 0.29, blue: 0.12, alpha: 1)
            : UIColor(red: 0.91, green: 0.76, blue: 0.43, alpha: 1)

        if artwork.titleLayout == .photographFooter {
            // A photograph has no authored quiet area. Give the live type a
            // deep ink footer whose 92% field keeps white and gold readable
            // even over white sky, snow, or a high-frequency background.
            let field = CGRect(
                x: rect.minX,
                y: max(rect.minY, titleRect.minY - rect.height * 0.035),
                width: rect.width,
                height: rect.maxY - max(rect.minY, titleRect.minY - rect.height * 0.035)
            )
            UIColor(red: 0.025, green: 0.035, blue: 0.055, alpha: CGFloat(artwork.titleLayout.readabilityFieldOpacity)).setFill()
            UIBezierPath(rect: field).fill()
            gold.withAlphaComponent(0.64).setStroke()
            let seam = UIBezierPath()
            seam.move(to: CGPoint(x: field.minX + rect.width * 0.06, y: field.minY))
            seam.addLine(to: CGPoint(x: field.maxX - rect.width * 0.06, y: field.minY))
            seam.lineWidth = max(0.7, rect.width * 0.002)
            seam.stroke()
        } else if artwork.titleLayout.needsReadabilityVeil {
            cg.saveGState()
            let veil = titleRect.insetBy(dx: -rect.width * 0.025, dy: -rect.height * 0.018)
            UIColor.black.withAlphaComponent(CGFloat(artwork.titleLayout.readabilityFieldOpacity)).setFill()
            UIBezierPath(roundedRect: veil, cornerRadius: rect.width * 0.025).fill()
            cg.restoreGState()
        } else {
            UIColor(
                red: 0.96,
                green: 0.91,
                blue: 0.78,
                alpha: CGFloat(artwork.titleLayout.readabilityFieldOpacity)
            ).setFill()
            UIBezierPath(roundedRect: titleRect.insetBy(dx: -8, dy: -6), cornerRadius: 8).fill()
        }

        let unit = min(rect.width / 432, rect.height / 648)
        let brandRect = CGRect(x: titleRect.minX, y: titleRect.minY, width: titleRect.width, height: titleRect.height * 0.13)
        let nameRect = CGRect(x: titleRect.minX, y: titleRect.minY + titleRect.height * 0.15, width: titleRect.width, height: titleRect.height * 0.16)
        let lineRect = CGRect(x: titleRect.minX, y: titleRect.minY + titleRect.height * 0.32, width: titleRect.width, height: titleRect.height * 0.42)
        let sublineRect = CGRect(x: titleRect.minX, y: titleRect.minY + titleRect.height * 0.77, width: titleRect.width, height: titleRect.height * 0.19)

        drawFittedCentered(
            "T H E   B O O K   O F   Y O U",
            color: ink.withAlphaComponent(0.84),
            rect: brandRect,
            maximumSize: 10.5 * unit,
            minimumSize: 5.5 * unit,
            maximumLines: 1,
            font: { .systemFont(ofSize: $0, weight: .semibold) }
        )
        drawFittedCentered(
            copy.readerName.uppercased(),
            color: ink.withAlphaComponent(0.88),
            rect: nameRect,
            maximumSize: 15 * unit,
            minimumSize: 7 * unit,
            maximumLines: 2,
            font: { .serifFont(ofSize: $0, weight: .regular) }
        )
        drawFittedCentered(
            copy.coverLine,
            color: ink,
            rect: lineRect,
            maximumSize: 34 * unit,
            minimumSize: 13 * unit,
            maximumLines: 3,
            font: { .serifFont(ofSize: $0, weight: .bold) }
        )
        drawFittedCentered(
            copy.coverSubline,
            color: gold,
            rect: sublineRect,
            maximumSize: 13.5 * unit,
            minimumSize: 7 * unit,
            maximumLines: 2,
            font: { .serifItalicFont(ofSize: $0) }
        )
    }

    private static func drawFittedCentered(
        _ text: String,
        color: UIColor,
        rect: CGRect,
        maximumSize: CGFloat,
        minimumSize: CGFloat,
        maximumLines: Int,
        font: (CGFloat) -> UIFont
    ) {
        guard rect.width > 0, rect.height > 0 else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        func fits(_ candidate: String, at size: CGFloat) -> Bool {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font(size),
                .paragraphStyle: paragraph
            ]
            let measured = (candidate as NSString).boundingRect(
                with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let lineHeight = max(1, font(size).lineHeight)
            return measured.height <= rect.height
                && Int(ceil(measured.height / lineHeight)) <= maximumLines
        }

        var renderedText = text
        var chosen = minimumSize
        var size = maximumSize
        var foundFit = false
        while size >= minimumSize {
            if fits(text, at: size) {
                chosen = size
                foundFit = true
                break
            }
            size -= max(0.5, maximumSize * 0.025)
        }

        if !foundFit {
            // A cover must never draw outside its authored title clearing.
            // Find the longest grapheme-safe prefix that fits at minimum size,
            // then make the omission visible instead of clipping it silently.
            let characters = Array(text)
            var lower = 0
            var upper = characters.count
            while lower < upper {
                let midpoint = (lower + upper + 1) / 2
                let candidate = String(characters.prefix(midpoint))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    + (midpoint < characters.count ? "…" : "")
                if fits(candidate, at: minimumSize) {
                    lower = midpoint
                } else {
                    upper = midpoint - 1
                }
            }
            if lower < characters.count {
                renderedText = String(characters.prefix(lower))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    + "…"
            }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(chosen),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let measured = (renderedText as NSString).boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let drawRect = CGRect(x: rect.minX, y: rect.midY - min(rect.height, measured.height) / 2, width: rect.width, height: rect.height)
        (renderedText as NSString).draw(in: drawRect, withAttributes: attributes)
    }

    private enum JacketFlapSide { case left, right }

    private static func drawVolumeJacketFlap(
        _ annual: AnnualEdition,
        side: JacketFlapSide,
        style: EditionStyle,
        rect: CGRect,
        darkField: Bool
    ) {
        guard rect.width >= 90 else { return }
        let safety = min(36, rect.width * 0.14)
        let textRect = rect.insetBy(dx: safety, dy: 54)
        let title = side == .left ? "THIS BOOK WAS ALIVE FIRST" : "WHAT IT KEPT"
        let body: String
        if side == .left {
            body = "A season of ordinary life crossed the hedge and came back as an object: weather, arguments, meals, remembered details, and the marks they left in another world."
        } else {
            body = "\(annual.dayCount) days bound. \(annual.pageCount) kept Pages. \(annual.chapters.count) \(annual.chapters.count == 1 ? "chapter" : "chapters"). Nothing added merely to make the shelf look busier."
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineSpacing = 2.5
        let bodyInk = darkField ? UIColor.white.withAlphaComponent(0.82) : style.palette.coverText.withAlphaComponent(0.82)
        (title as NSString).draw(in: CGRect(x: textRect.minX, y: textRect.minY, width: textRect.width, height: 44), withAttributes: [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .bold),
            .foregroundColor: style.palette.gold,
            .kern: 0.8
        ])
        (body as NSString).draw(in: CGRect(x: textRect.minX, y: textRect.minY + 52, width: textRect.width, height: textRect.height - 52), withAttributes: [
            .font: UIFont.serifFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: bodyInk,
            .paragraphStyle: paragraph
        ])
    }

    private static func drawVolumeBackPanel(
        _ annual: AnnualEdition,
        style: EditionStyle,
        rect: CGRect,
        darkField: Bool = false
    ) {
        let text = darkField ? UIColor.white : style.palette.coverText
        drawCentered("T H E   B O O K   O F   Y O U", font: .systemFont(ofSize: 11, weight: .semibold), color: text.withAlphaComponent(0.8), y: rect.minY + rect.height * 0.34, in: rect)
        drawFittedCentered(
            annual.readerRole?.fullName ?? annual.readerName,
            color: text,
            rect: CGRect(x: rect.minX + 40, y: rect.minY + rect.height * 0.385, width: rect.width - 80, height: rect.height * 0.08),
            maximumSize: 16,
            minimumSize: 8,
            maximumLines: 2,
            font: { .serifFont(ofSize: $0, weight: .regular) }
        )
        drawFittedCentered(
            annual.resolvedCoverLine(),
            color: style.palette.gold,
            rect: CGRect(x: rect.minX + 40, y: rect.minY + rect.height * 0.46, width: rect.width - 80, height: rect.height * 0.12),
            maximumSize: 14,
            minimumSize: 8,
            maximumLines: 2,
            font: { .serifItalicFont(ofSize: $0) }
        )
        drawCentered("\(annual.dayCount) days bound \u{00B7} \(annual.pageCount) kept pages", font: .systemFont(ofSize: 9, weight: .medium), color: text.withAlphaComponent(0.6), y: rect.minY + rect.height * 0.62, in: rect)
    }

    /// Lulu's linen spine stamp allows at most 42 characters. The same concise
    /// shelf title also survives a thin perfect-bound spine.
    private static func drawVolumeSpineTitle(_ annual: AnnualEdition, style: EditionStyle, rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let shelfTitle = String("BOOK OF YOU \u{00B7} \(annual.resolvedCoverLine())".prefix(42))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.serifFont(ofSize: min(rect.width * 0.42, 13), weight: .semibold),
            .foregroundColor: style.palette.gold,
            .kern: 1.2
        ]
        let attributed = NSAttributedString(string: shelfTitle, attributes: attributes)
        let size = attributed.size()
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: .pi / 2)
        attributed.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        cg.restoreGState()
    }

    private static func renderAnnualInterior(
        _ annual: AnnualEdition,
        plates: [IlluminatedPlate],
        into context: UIGraphicsPDFRendererContext,
        style annualStyle: EditionStyle,
        pageBounds: CGRect,
        margins: UIEdgeInsets,
        designSize: CGSize
    ) {
        var cursor = PDFCursor(bounds: pageBounds, margins: margins)
        cursor.seed = "volume-\(annual.startDate.timeIntervalSinceReferenceDate)-\(annual.endDate.timeIntervalSinceReferenceDate)"
        let designRect = CGRect(origin: .zero, size: designSize)

        context.beginPage()
        withDesignSpace(designSize: designSize, pageBounds: pageBounds) {
            drawAnnualCover(annual, style: annualStyle, bounds: designRect)
        }

        if var patronEdition = annual.chapters.first {
            patronEdition.readerRole = annual.readerRole
            drawPatronFrontispiece(patronEdition, style: annualStyle, context: context, cursor: &cursor)
        }
        drawDedication(annual.dedication, style: annualStyle, context: context, cursor: &cursor)

        if !annual.foreword.isEmpty {
            beginComposedPage(context, style: annualStyle, cursor: &cursor)
            drawAnnualForeword(annual, style: annualStyle, context: context, cursor: &cursor)
        }

        drawIlluminatedPlates(plates, style: annualStyle, context: context, cursor: &cursor)

        beginComposedPage(context, style: annualStyle, cursor: &cursor)
        drawAnnualContents(annual, style: annualStyle, cursor: &cursor)

        if let matter = annual.publicationMatter {
            if !matter.almanacItems.isEmpty {
                drawVolumeCabinet(
                    title: "The Lived Almanac",
                    note: "Outer weather, ink-time, and the private charts you explicitly allowed into these covers.",
                    items: matter.almanacItems,
                    style: annualStyle,
                    context: context,
                    cursor: &cursor
                )
            }
            if !matter.crossingItems.isEmpty {
                drawVolumeCabinet(
                    title: "What Crossed the Hedge",
                    note: "Real choices that left receipts in the Labyrinth. Not metaphor: consequence.",
                    items: matter.crossingItems,
                    style: annualStyle,
                    context: context,
                    cursor: &cursor
                )
            }
        }

        if let conversation = annual.castConversation, !conversation.isEmpty {
            drawVolumeCastConversation(
                conversation,
                seed: "volume-\(annual.year)-\(annual.publicationKind?.rawValue ?? "annual")",
                style: annualStyle,
                context: context,
                cursor: &cursor
            )
        }

        for chapter in annual.chapters {
            let chapterStyle = EditionStyle.style(for: chapter)
            let marginalia = marginNotes(for: chapter)
            var marginaliaIndex = 0
            cursor.seed = "annual-\(annual.year)-\(chapter.monthName)"

            context.beginPage()
            withDesignSpace(designSize: designSize, pageBounds: pageBounds) {
                drawChapterDivider(chapter, style: chapterStyle, bounds: designRect)
            }

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
                withDesignSpace(designSize: designSize, pageBounds: pageBounds) {
                    drawStarChart(alive, edition: chapter, style: chapterStyle, bounds: designRect)
                }
            }

            for section in chapter.sections where section.id != "the-months-theme" {
                if section.id == "what-the-cast-did" {
                    drawCastDivider(chapter.castLead, style: chapterStyle, context: context, cursor: &cursor)
                }
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

        let named = annual.namedConstellations
        if !named.isEmpty {
            context.beginPage()
            withDesignSpace(designSize: designSize, pageBounds: pageBounds) {
                drawAnnualStarChart(named, annual: annual, style: annualStyle, bounds: designRect)
            }
        }

        if let memorySpine = annual.memorySpine, !memorySpine.isEmpty {
            drawAnnualMemorySpine(memorySpine, annual: annual, style: annualStyle, context: context, cursor: &cursor)
        }

        drawAnnualColophon(annual, style: annualStyle, context: context, cursor: &cursor)
    }

    private static func drawVolumeCabinet(
        title: String,
        note: String,
        items: [MonthlyEditionItem],
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        drawText(title, font: .serifFont(ofSize: 25, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 4)
        drawText(note, font: .serifItalicFont(ofSize: 10.5), color: style.palette.ink.withAlphaComponent(0.64), cursor: &cursor, spacingAfter: 10)
        drawAccentRule(style, cursor: &cursor)

        for (index, item) in items.enumerated() {
            let bodyHeight = measuredTextHeight(
                item.body,
                font: .serifFont(ofSize: 10.8, weight: .regular),
                width: cursor.contentWidth - 26
            )
            let needed = min(cursor.bottom - cursor.margins.top, bodyHeight + 74)
            ensureSpace(needed, style: style, context: context, cursor: &cursor)
            let card = CGRect(
                x: cursor.left - 9,
                y: cursor.y - 7,
                width: cursor.contentWidth + 18,
                height: bodyHeight + 61
            )
            drawTornScrap(
                in: card,
                rotation: (frac("\(cursor.pageSeed)-cabinet-\(index)") - 0.5) * 0.018,
                fill: blend(parchment(for: style).top, style.palette.accent, index.isMultiple(of: 2) ? 0.08 : 0.12),
                seed: "\(cursor.pageSeed)-cabinet-\(index)"
            )
            drawTapeStrip(
                center: CGPoint(x: card.minX + 30, y: card.minY + 2),
                length: 48,
                angle: -0.45,
                tint: style.palette.gold
            )
            drawText(item.title, font: .systemFont(ofSize: 11.5, weight: .bold), color: style.palette.accent, cursor: &cursor, spacingAfter: 5)
            drawText(item.body, font: .serifFont(ofSize: 10.8, weight: .regular), color: style.palette.ink.withAlphaComponent(0.91), cursor: &cursor, spacingAfter: 22)
        }
        drawOrnamentRow(style, centerY: cursor.y + 10, in: cursor.bounds, color: style.palette.gold)
        cursor.y += 30
    }

    private static func drawVolumeCastConversation(
        _ conversation: BoundVolumeCastConversation,
        seed: String,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        drawText(conversation.title, font: .serifFont(ofSize: 25, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 4)
        drawText(conversation.setting, font: .serifItalicFont(ofSize: 10.5), color: style.palette.ink.withAlphaComponent(0.64), cursor: &cursor, spacingAfter: 10)
        drawAccentRule(style, cursor: &cursor)

        for (index, line) in conversation.lines.enumerated() {
            let voice = KeepMarginalia.voice(forSlug: line.speakerID)
            let ink = voice.map { castInk($0.accentHex) } ?? style.palette.accent
            let bodyHeight = measuredTextHeight(
                line.words,
                font: .serifFont(ofSize: 11.3, weight: .regular),
                width: cursor.contentWidth - 34
            )
            ensureSpace(bodyHeight + 64, style: style, context: context, cursor: &cursor)
            let scrap = CGRect(
                x: cursor.left + (index.isMultiple(of: 2) ? -8 : 16),
                y: cursor.y - 7,
                width: cursor.contentWidth - 8,
                height: bodyHeight + 52
            )
            drawTornScrap(
                in: scrap,
                rotation: (index.isMultiple(of: 2) ? -0.012 : 0.014),
                fill: blend(parchment(for: style).top, ink, 0.07),
                seed: "volume-conversation-\(seed)-\(index)"
            )
            let glyph = line.glyph?.nonEmpty ?? voice?.glyph ?? ""
            drawText(
                [glyph, line.speakerName].filter { !$0.isEmpty }.joined(separator: "  "),
                font: .systemFont(ofSize: 10.5, weight: .bold),
                color: ink,
                cursor: &cursor,
                spacingAfter: 5,
                leftInset: index.isMultiple(of: 2) ? 2 : 24
            )
            drawText(
                line.words,
                font: .serifFont(ofSize: 11.3, weight: .regular),
                color: style.palette.ink.withAlphaComponent(0.92),
                cursor: &cursor,
                spacingAfter: 21,
                leftInset: index.isMultiple(of: 2) ? 2 : 24
            )
        }
        drawText(
            "They were told to discuss the book in front of them. They were not allowed to invent a life behind it.",
            font: .serifItalicFont(ofSize: 9),
            color: style.palette.ink.withAlphaComponent(0.50),
            cursor: &cursor,
            spacingAfter: 12
        )
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
        drawCentered(annual.resolvedCoverLine(), font: .serifFont(ofSize: 40, weight: .bold), color: text, y: 416, in: bounds)
        drawCentered(annual.resolvedCoverSubline(), font: .serifItalicFont(ofSize: 18), color: style.palette.gold, y: 474, in: bounds)

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
        let head = "THE BOOK OF YOU \u{00B7} \(annual.readerName) \u{00B7} \(annual.resolvedCoverLine().uppercased())"
        let headAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: style.palette.ink.withAlphaComponent(0.45)
        ]
        (head as NSString).draw(at: CGPoint(x: cursor.left, y: 30), withAttributes: headAttributes)

        let noun = annual.publicationKind == .seasonal ? "Season" : "Year"
        drawText("Foreword to the \(noun)", font: .serifFont(ofSize: 24, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 10)
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
        let noun = annual.publicationKind == .seasonal ? "Season" : "Year"
        drawText("The \(noun) in \(annual.chapters.count == 1 ? "One Chapter" : "\(spelledOut(annual.chapters.count)) Chapters")",
                 font: .serifFont(ofSize: 22, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 6)
        drawAccentRule(style, cursor: &cursor)
        if !(annual.publicationMatter?.almanacItems.isEmpty ?? true) {
            drawText("The Lived Almanac", font: .systemFont(ofSize: 13, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 2)
            drawText("Weather, ink-time, and allowed private chart patterns.", font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.6), cursor: &cursor, spacingAfter: 10)
        }
        if !(annual.publicationMatter?.crossingItems.isEmpty ?? true) {
            drawText("What Crossed the Hedge", font: .systemFont(ofSize: 13, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 2)
            drawText("The real choices that changed something in the Labyrinth.", font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.6), cursor: &cursor, spacingAfter: 10)
        }
        if let conversation = annual.castConversation, !conversation.isEmpty {
            drawText(conversation.title, font: .systemFont(ofSize: 13, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 2)
            drawText("The Cast argues with the object in front of them.", font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.6), cursor: &cursor, spacingAfter: 10)
        }
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

        let annualCopy = annual.publicationKind != .seasonal
        drawCentered(annualCopy ? "The Year's Constellations" : "The Season's Constellations", font: .serifFont(ofSize: 26, weight: .bold), color: style.palette.coverText, y: 64, in: bounds)
        drawCentered(annualCopy ? "Threads the Book named across the membership year." : "Threads the Book named across these months.", font: .serifItalicFont(ofSize: 12), color: style.palette.coverText.withAlphaComponent(0.75), y: 98, in: bounds)

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
        let head = "THE BOOK OF YOU \u{00B7} \(annual.readerName) \u{00B7} \(annual.resolvedCoverLine().uppercased())"
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
        drawCentered("The Book of You \u{00B7} \(annual.readerName) \u{00B7} \(annual.resolvedCoverLine())", font: .serifItalicFont(ofSize: 12), color: style.palette.ink.withAlphaComponent(0.8), y: cursor.y, in: cursor.bounds)
        cursor.y += 22
        drawCentered("Bound by the Book itself, which read every page twice, and the year once more.", font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.55), y: cursor.y, in: cursor.bounds)
        cursor.y += 20
        drawCentered("Made with ReEnchanted \u{00B7} reenchanted.app", font: .systemFont(ofSize: 8.5, weight: .semibold), color: style.palette.ink.withAlphaComponent(0.48), y: cursor.y, in: cursor.bounds)
    }

    private static func spelledOut(_ n: Int) -> String {
        let words = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]
        return (0...12).contains(n) ? words[n] : "\(n)"
    }

    // MARK: First Door

    private static func drawFirstDoorCover(
        _ edition: MonthlyEdition,
        matter: FirstDoorPublicationMatter,
        style: EditionStyle,
        bounds: CGRect
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }

        let selectedArtwork: VolumeCoverArtwork? = {
            if let readerCover = matter.readerCoverArtwork,
               let image = UIImage(contentsOfFile: readerCover.imagePath),
               image.size.width > 0,
               image.size.height > 0 {
                return VolumeCoverArtwork(
                    image: image,
                    titleLayout: readerCover.titleLayout,
                    id: "first-door-reader-photo",
                    focusPoint: {
                        guard let x = readerCover.focusX,
                              let y = readerCover.focusY,
                              (0...1).contains(x),
                              (0...1).contains(y) else { return nil }
                        return CGPoint(x: CGFloat(x), y: CGFloat(y))
                    }()
                )
            }
            if let plate = PublicationCoverCatalogue.plate(id: edition.publicationCoverPlateID),
               let image = UIImage(named: plate.assetName) {
                return VolumeCoverArtwork(
                    image: image,
                    titleLayout: plate.titleLayout,
                    id: plate.id
                )
            }
            return nil
        }()

        if let artwork = selectedArtwork {
            // The authored plate is a 2:3 front board. Preserve that geometry
            // inside the Letter reading PDF instead of stretching its quiet
            // title clearing to the wider page ratio. Reader photographs use
            // the same board geometry and their dedicated footer clearing.
            drawVerticalWash(in: bounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)
            let coverWidth = min(bounds.width, bounds.height * 2 / 3)
            let coverRect = CGRect(
                x: bounds.midX - coverWidth / 2,
                y: bounds.minY,
                width: coverWidth,
                height: bounds.height
            )
            let copy = VolumeCoverCopy(
                readerName: edition.readerName,
                coverLine: "THE FIRST DOOR",
                coverSubline: edition.readerRole?.markedName ?? "ONE TRUE THING CARRIED THROUGH"
            )
            cg.saveGState()
            cg.setShadow(
                offset: CGSize(width: 0, height: 3),
                blur: 12,
                color: UIColor.black.withAlphaComponent(0.28).cgColor
            )
            drawVolumeFrontArtwork(artwork, artworkRect: coverRect, visibleRect: coverRect)
            cg.restoreGState()
            drawVolumeCoverType(copy, artwork: artwork, rect: coverRect)
            style.palette.gold.withAlphaComponent(0.34).setStroke()
            let frame = UIBezierPath(rect: coverRect.insetBy(dx: 0.5, dy: 0.5))
            frame.lineWidth = 1
            frame.stroke()
            return
        }

        drawVerticalWash(in: bounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)

        let illustrationFrame = CGRect(x: bounds.midX - 112, y: 70, width: 224, height: 176)
        drawFirstDoorThresholdSigil(in: illustrationFrame, matter: matter, style: style)
        drawOrnamentRow(style, centerY: 276, in: bounds, color: style.palette.gold)

        let text = style.palette.coverText
        drawCentered(
            "T H E   B O O K   O F   Y O U",
            font: .systemFont(ofSize: 12.5, weight: .semibold),
            color: text.withAlphaComponent(0.82),
            y: 302,
            in: bounds
        )
        drawCenteredWrapped(
            edition.readerName,
            font: .serifFont(ofSize: 25, weight: .regular),
            color: text,
            rect: CGRect(x: 84, y: 330, width: bounds.width - 168, height: 48)
        )
        drawCentered(
            "THE FIRST DOOR",
            font: .serifFont(ofSize: 36, weight: .bold),
            color: text,
            y: 390,
            in: bounds
        )

        if let role = edition.readerRole {
            drawCenteredWrapped(
                role.markedName,
                font: .serifItalicFont(ofSize: 16),
                color: style.palette.gold,
                rect: CGRect(x: 86, y: 445, width: bounds.width - 172, height: 50),
                lineSpacing: 4
            )
        }

        drawOrnamentRow(style, centerY: 520, in: bounds, color: style.palette.gold)
        drawCentered(
            "ONE TRUE THING CARRIED THROUGH",
            font: .systemFont(ofSize: 10.5, weight: .bold),
            color: text.withAlphaComponent(0.72),
            y: 548,
            in: bounds
        )
        drawCenteredWrapped(
            matter.arrivalLine,
            font: .serifItalicFont(ofSize: 10.5),
            color: text.withAlphaComponent(0.62),
            rect: CGRect(x: 110, y: 686, width: bounds.width - 220, height: 34)
        )
        drawCentered(
            "A PRIVATE FIRST EDITION",
            font: .systemFont(ofSize: 8.5, weight: .semibold),
            color: text.withAlphaComponent(0.44),
            y: 738,
            in: bounds
        )
    }

    private static func drawFirstDoorThresholdSigil(
        in frame: CGRect,
        matter: FirstDoorPublicationMatter,
        style: EditionStyle
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()

        let door = CGRect(
            x: frame.midX - 45,
            y: frame.minY + 14,
            width: 90,
            height: frame.height - 28
        )
        style.palette.coverText.withAlphaComponent(0.07).setFill()
        let outer = UIBezierPath(roundedRect: door, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 42, height: 42))
        outer.fill()
        style.palette.gold.withAlphaComponent(0.86).setStroke()
        outer.lineWidth = 1.7
        outer.stroke()

        let opened = CGRect(x: door.minX + 13, y: door.minY + 17, width: door.width - 25, height: door.height - 17)
        let panel = UIBezierPath(roundedRect: opened, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 30, height: 30))
        blend(style.palette.paperBottom, style.palette.accent, 0.16).setFill()
        panel.fill()
        style.palette.coverText.withAlphaComponent(0.34).setStroke()
        panel.lineWidth = 0.8
        panel.stroke()

        let keyhole = UIBezierPath(ovalIn: CGRect(x: opened.midX - 4, y: opened.midY - 2, width: 8, height: 8))
        keyhole.append(UIBezierPath(rect: CGRect(x: opened.midX - 2, y: opened.midY + 4, width: 4, height: 12)))
        style.palette.gold.withAlphaComponent(0.88).setFill()
        keyhole.fill()

        let threadPoints = [
            CGPoint(x: frame.minX + 14, y: frame.maxY - 22),
            CGPoint(x: door.minX - 12, y: door.midY + 30),
            CGPoint(x: opened.midX, y: opened.midY + 28),
            CGPoint(x: door.maxX + 10, y: door.midY - 22),
            CGPoint(x: frame.maxX - 14, y: frame.minY + 28)
        ]
        let thread = UIBezierPath()
        thread.move(to: threadPoints[0])
        for index in 1..<threadPoints.count {
            let prior = threadPoints[index - 1]
            let point = threadPoints[index]
            thread.addCurve(
                to: point,
                controlPoint1: CGPoint(x: (prior.x + point.x) / 2, y: prior.y),
                controlPoint2: CGPoint(x: (prior.x + point.x) / 2, y: point.y)
            )
        }
        style.palette.gold.setStroke()
        thread.lineWidth = 1.6
        thread.stroke()

        let activeCount = min(5, max(1, matter.thresholdThread?.count ?? matter.signatures.count))
        for (index, point) in threadPoints.enumerated() {
            let dot = UIBezierPath(ovalIn: CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9))
            (index < activeCount ? style.palette.gold : style.palette.coverText.withAlphaComponent(0.24)).setFill()
            dot.fill()
            style.palette.coverText.withAlphaComponent(0.58).setStroke()
            dot.lineWidth = 0.7
            dot.stroke()
        }

        cg.restoreGState()
    }

    private static func drawFirstDoorOwnership(
        _ edition: MonthlyEdition,
        matter: FirstDoorPublicationMatter,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        let bounds = cursor.bounds
        cursor.y = 126

        drawCentered(
            "THIS COPY BELONGS TO",
            font: .systemFont(ofSize: 10.5, weight: .bold),
            color: style.palette.accent,
            y: cursor.y,
            in: bounds
        )
        cursor.y += 38
        drawCenteredWrapped(
            edition.readerName,
            font: .serifFont(ofSize: 34, weight: .bold),
            color: style.palette.ink,
            rect: CGRect(x: 88, y: cursor.y, width: bounds.width - 176, height: 94),
            lineSpacing: 5
        )
        cursor.y += 108
        drawOrnamentRow(style, centerY: cursor.y, in: bounds, color: style.palette.gold)
        cursor.y += 34

        if let role = edition.readerRole {
            drawCenteredWrapped(
                role.markedName,
                font: .serifFont(ofSize: 20, weight: .semibold),
                color: style.palette.ink,
                rect: CGRect(x: 92, y: cursor.y, width: bounds.width - 184, height: 64),
                lineSpacing: 4
            )
            cursor.y += 72
            drawCenteredWrapped(
                role.gloss,
                font: .serifItalicFont(ofSize: 12),
                color: style.palette.ink.withAlphaComponent(0.72),
                rect: CGRect(x: 120, y: cursor.y, width: bounds.width - 240, height: 70),
                lineSpacing: 5
            )
            cursor.y += 86
            if let markEvidence = role.markEvidence {
                drawCenteredWrapped(
                    "The mark was earned here: \(markEvidence)",
                    font: .serifItalicFont(ofSize: 9.5),
                    color: style.palette.accent.withAlphaComponent(0.82),
                    rect: CGRect(x: 116, y: cursor.y, width: bounds.width - 232, height: 64),
                    lineSpacing: 3
                )
                cursor.y += 72
            }
        }

        drawCenteredWrapped(
            matter.arrivalLine,
            font: .serifItalicFont(ofSize: 10.5),
            color: style.palette.ink.withAlphaComponent(0.56),
            rect: CGRect(x: 118, y: max(cursor.y, 610), width: bounds.width - 236, height: 44),
            lineSpacing: 3
        )
    }

    private static func drawFirstDoorBookNote(
        _ edition: MonthlyEdition,
        matter: FirstDoorPublicationMatter,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard let note = matter.bookNote?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty else { return }

        beginComposedPage(context, style: style, cursor: &cursor)
        drawRunningHead(edition, style: style, cursor: cursor)

        let bodyFont = UIFont.serifFont(ofSize: 12.2, weight: .regular)
        let bodyHeight = measuredTextHeight(note, font: bodyFont, width: cursor.contentWidth - 64)
        let cardHeight = min(cursor.bottom - cursor.y - 30, max(390, bodyHeight + 118))
        let card = CGRect(
            x: cursor.left - 8,
            y: cursor.y + 30,
            width: cursor.contentWidth + 16,
            height: cardHeight
        )
        drawTornScrap(
            in: card,
            rotation: -0.009,
            fill: blend(parchment(for: style).top, style.palette.gold, 0.07),
            seed: "first-door-book-note-\(matter.arrivalLine)"
        )
        drawTapeStrip(
            center: CGPoint(x: card.midX + 74, y: card.minY + 3),
            length: 68,
            angle: 0.08,
            tint: style.palette.gold
        )

        cursor.y = card.minY + 38
        drawText(
            "A NOTE FOUND UNDER THE COVER",
            font: .systemFont(ofSize: 9.8, weight: .bold),
            color: style.palette.accent,
            cursor: &cursor,
            spacingAfter: 20,
            leftInset: 32
        )
        drawText(
            note,
            font: bodyFont,
            color: style.palette.ink.withAlphaComponent(0.94),
            cursor: &cursor,
            spacingAfter: 10,
            leftInset: 32
        )
    }

    private static func drawFirstDoorProof(
        _ edition: MonthlyEdition,
        matter: FirstDoorPublicationMatter,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let signatures = Array(matter.signatures.prefix(4))
        guard !signatures.isEmpty else { return }
        let numerals = ["I", "II", "III", "IV"]
        for pageStart in stride(from: 0, to: signatures.count, by: 2) {
            beginComposedPage(context, style: style, cursor: &cursor)
            drawRunningHead(edition, style: style, cursor: cursor)
            drawText(
                pageStart == 0 ? "What I Can Prove" : "What I Can Prove, continued",
                font: .serifFont(ofSize: 26, weight: .bold),
                color: style.palette.ink,
                cursor: &cursor,
                spacingAfter: 5
            )
            drawText(
                pageStart == 0
                    ? "The receipts come last. First the little book had to do what it claimed."
                    : "Two more marks from the same crossing.",
                font: .serifItalicFont(ofSize: 10.5),
                color: style.palette.ink.withAlphaComponent(0.62),
                cursor: &cursor,
                spacingAfter: 10
            )
            drawAccentRule(style, cursor: &cursor)

            for index in pageStart..<min(pageStart + 2, signatures.count) {
                let signature = signatures[index]
                let textWidth = cursor.contentWidth - 48
                let evidenceHeight = measuredTextHeight(
                    signature.evidence,
                    font: .serifFont(ofSize: 11.3, weight: .regular),
                    width: textWidth
                )
                let meaningHeight = measuredTextHeight(
                    signature.meaning,
                    font: .serifItalicFont(ofSize: 9.8),
                    width: textWidth
                )
                let cardHeight = max(158, evidenceHeight + meaningHeight + 98)
                ensureSpace(cardHeight + 24, style: style, context: context, cursor: &cursor)
                let card = CGRect(
                    x: cursor.left - (index.isMultiple(of: 2) ? 5 : -9),
                    y: cursor.y - 5,
                    width: cursor.contentWidth - 4,
                    height: cardHeight
                )
                drawTornScrap(
                    in: card,
                    rotation: index.isMultiple(of: 2) ? -0.009 : 0.011,
                    fill: blend(parchment(for: style).top, style.palette.accent, index.isMultiple(of: 2) ? 0.06 : 0.10),
                    seed: "first-door-proof-\(signature.id)"
                )
                drawTapeStrip(
                    center: CGPoint(x: card.minX + 44, y: card.minY + 3),
                    length: 58,
                    angle: -0.34,
                    tint: style.palette.gold
                )
                drawText(
                    "\(numerals[index])  \(signature.title.uppercased())",
                    font: .systemFont(ofSize: 10.5, weight: .bold),
                    color: style.palette.accent,
                    cursor: &cursor,
                    spacingAfter: 9,
                    leftInset: 24
                )
                drawText(
                    signature.evidence,
                    font: .serifFont(ofSize: 11.3, weight: .regular),
                    color: style.palette.ink,
                    cursor: &cursor,
                    spacingAfter: 8,
                    leftInset: 24
                )
                drawText(
                    signature.meaning,
                    font: .serifItalicFont(ofSize: 9.8),
                    color: style.palette.ink.withAlphaComponent(0.66),
                    cursor: &cursor,
                    spacingAfter: 26,
                    leftInset: 24
                )
                cursor.y = max(cursor.y, card.maxY + 20)
            }
        }
    }

    private static func drawFirstDoorThread(
        _ edition: MonthlyEdition,
        matter: FirstDoorPublicationMatter,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        drawRunningHead(edition, style: style, cursor: cursor)
        drawText("The Thread That Came Through", font: .serifFont(ofSize: 24, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 4)
        drawText(
            "Not a table of contents. The route one real thing took through the First Door.",
            font: .serifItalicFont(ofSize: 10.2),
            color: style.palette.ink.withAlphaComponent(0.62),
            cursor: &cursor,
            spacingAfter: 9
        )
        drawAccentRule(style, cursor: &cursor)

        let legacyBeats = matter.signatures.prefix(4).map {
            FirstDoorPublicationMatter.ThresholdBeat(id: $0.id, stage: $0.title.uppercased(), detail: $0.evidence)
        }
        let beats = (matter.thresholdThread?.isEmpty == false)
            ? matter.thresholdThread ?? []
            : legacyBeats
        let threadX = cursor.left + 18

        for (index, beat) in beats.enumerated() {
            let detailHeight = measuredTextHeight(
                beat.detail,
                font: .serifFont(ofSize: 10.7, weight: .regular),
                width: cursor.contentWidth - 58
            )
            let beatHeight = max(78, detailHeight + 48)
            ensureSpace(beatHeight + 8, style: style, context: context, cursor: &cursor)

            if index < beats.count - 1 {
                style.palette.gold.withAlphaComponent(0.56).setStroke()
                let thread = UIBezierPath()
                thread.move(to: CGPoint(x: threadX, y: cursor.y + 28))
                thread.addCurve(
                    to: CGPoint(x: threadX + (index.isMultiple(of: 2) ? 3 : -2), y: cursor.y + beatHeight + 11),
                    controlPoint1: CGPoint(x: threadX - 5, y: cursor.y + beatHeight * 0.42),
                    controlPoint2: CGPoint(x: threadX + 6, y: cursor.y + beatHeight * 0.72)
                )
                thread.lineWidth = 1.4
                thread.stroke()
            }

            style.palette.accentSoft.setFill()
            let seal = UIBezierPath(ovalIn: CGRect(x: threadX - 12, y: cursor.y + 4, width: 25, height: 25))
            seal.fill()
            style.palette.accent.setStroke()
            seal.lineWidth = 1
            seal.stroke()
            drawCentered(
                "\(index + 1)",
                font: .systemFont(ofSize: 8.5, weight: .bold),
                color: style.palette.accent,
                y: cursor.y + 10,
                in: CGRect(x: threadX - 12, y: 0, width: 25, height: cursor.bounds.height)
            )

            drawText(
                beat.stage,
                font: .systemFont(ofSize: 9.8, weight: .bold),
                color: style.palette.accent,
                cursor: &cursor,
                spacingAfter: 4,
                leftInset: 52
            )
            drawText(
                beat.detail,
                font: .serifFont(ofSize: 10.7, weight: .regular),
                color: style.palette.ink.withAlphaComponent(0.91),
                cursor: &cursor,
                spacingAfter: 18,
                leftInset: 52
            )
            cursor.y += max(0, beatHeight - detailHeight - 46)
        }

        drawText(
            "There. I did not make the ordinary thing less real. I gave it somewhere strange to go.",
            font: .serifItalicFont(ofSize: 10),
            color: style.palette.accent.withAlphaComponent(0.78),
            cursor: &cursor,
            spacingAfter: 8
        )
    }

    private static func drawFirstDoorPagewrightLeaf(
        _ edition: MonthlyEdition,
        leaf: FirstDoorPublicationMatter.PagewrightLeaf,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard let image = UIImage(contentsOfFile: leaf.imagePath),
              image.size.width > 0,
              image.size.height > 0 else { return }

        beginComposedPage(context, style: style, cursor: &cursor)
        drawRunningHead(edition, style: style, cursor: cursor)
        drawText("The Page You Made", font: .serifFont(ofSize: 24, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 3)
        drawText(
            leaf.title,
            font: .serifItalicFont(ofSize: 10.5),
            color: style.palette.ink.withAlphaComponent(0.62),
            cursor: &cursor,
            spacingAfter: 10
        )
        drawAccentRule(style, cursor: &cursor)

        let available = CGRect(
            x: cursor.left,
            y: cursor.y + 8,
            width: cursor.contentWidth,
            height: max(120, cursor.bottom - cursor.y - 36)
        )
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = CGRect(
            x: available.midX - size.width / 2,
            y: available.minY,
            width: size.width,
            height: size.height
        )
        style.palette.accentSoft.setFill()
        UIBezierPath(rect: rect.insetBy(dx: -8, dy: -8)).fill()
        image.draw(in: rect)
        style.palette.accent.withAlphaComponent(0.72).setStroke()
        let frame = UIBezierPath(rect: rect.insetBy(dx: -8, dy: -8))
        frame.lineWidth = 1
        frame.stroke()

        drawCenteredWrapped(
            "Composed at the First Door from nothing the reader had not already given the Book.",
            font: .serifItalicFont(ofSize: 9),
            color: style.palette.ink.withAlphaComponent(0.56),
            rect: CGRect(x: 90, y: min(cursor.bounds.height - 62, rect.maxY + 16), width: cursor.bounds.width - 180, height: 42),
            lineSpacing: 3
        )
    }

    private static func drawFirstDoorArgument(
        _ edition: MonthlyEdition,
        matter: FirstDoorPublicationMatter,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        let bounds = cursor.bounds
        drawRunningHead(edition, style: style, cursor: cursor)

        drawCentered(
            "THE FIRST ARGUMENT",
            font: .systemFont(ofSize: 10.5, weight: .bold),
            color: style.palette.accent,
            y: 82,
            in: bounds
        )
        drawCenteredWrapped(
            matter.firstArgumentTitle,
            font: .serifFont(ofSize: 27, weight: .bold),
            color: style.palette.ink,
            rect: CGRect(x: 88, y: 112, width: bounds.width - 176, height: 72),
            lineSpacing: 4
        )

        let chartFrame = CGRect(x: 104, y: 202, width: bounds.width - 208, height: 210)
        style.palette.ink.withAlphaComponent(0.12).setStroke()
        let border = UIBezierPath(roundedRect: chartFrame, cornerRadius: 10)
        border.lineWidth = 0.8
        border.stroke()
        drawConstellationMotif(
            in: chartFrame.insetBy(dx: 20, dy: 20),
            constellations: edition.constellations.filter(\.isAlive),
            seed: BookThemeEngine.monthKey(for: edition.startDate),
            stroke: style.palette.gold,
            glow: style.palette.accent,
            labeled: true
        )

        cursor.y = 446
        drawText(
            matter.firstArgumentBody,
            font: .serifFont(ofSize: 11.5, weight: .regular),
            color: style.palette.ink,
            cursor: &cursor,
            spacingAfter: 12
        )
        drawText(
            "The shelves keep the argument open. A first reading is a beginning, not a verdict.",
            font: .serifItalicFont(ofSize: 10),
            color: style.palette.accent.withAlphaComponent(0.78),
            cursor: &cursor,
            spacingAfter: 8
        )
    }

    private static func drawFirstDoorColophon(
        _ edition: MonthlyEdition,
        matter: FirstDoorPublicationMatter,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        let bounds = cursor.bounds
        cursor.y = bounds.midY - 110
        drawOrnamentRow(style, centerY: cursor.y, in: bounds, color: style.palette.accent)
        cursor.y += 30
        drawCentered(
            "FIRST DOOR EDITION",
            font: .systemFont(ofSize: 9.5, weight: .bold),
            color: style.palette.accent,
            y: cursor.y,
            in: bounds
        )
        cursor.y += 24
        drawCenteredWrapped(
            edition.chapterHeading,
            font: .serifItalicFont(ofSize: 12),
            color: style.palette.ink.withAlphaComponent(0.82),
            rect: CGRect(x: 92, y: cursor.y, width: bounds.width - 184, height: 46),
            lineSpacing: 3
        )
        cursor.y += 54
        if let role = edition.readerRole {
            drawCenteredWrapped(
                role.signature,
                font: .serifFont(ofSize: 10.5, weight: .semibold),
                color: style.palette.ink.withAlphaComponent(0.70),
                rect: CGRect(x: 92, y: cursor.y, width: bounds.width - 184, height: 50),
                lineSpacing: 3
            )
            cursor.y += 58
        }
        drawCenteredWrapped(
            "Composed from the answers, choices, and consequences witnessed at the threshold. \(matter.arrivalLine)",
            font: .serifItalicFont(ofSize: 9.5),
            color: style.palette.ink.withAlphaComponent(0.54),
            rect: CGRect(x: 112, y: cursor.y, width: bounds.width - 224, height: 58),
            lineSpacing: 3
        )
        cursor.y += 70
        drawCentered(
            "Made with ReEnchanted \u{00B7} reenchanted.app",
            font: .systemFont(ofSize: 8.5, weight: .semibold),
            color: style.palette.ink.withAlphaComponent(0.42),
            y: cursor.y,
            in: bounds
        )
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
            "Constellations I keep about you, as they stood this month.",
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
        marginalia: [BoundMarginNote],
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
        marginalia: [BoundMarginNote],
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
        if let contextNote = item.contextNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            drawText(
                contextNote,
                font: .serifItalicFont(ofSize: 8.8),
                color: style.palette.accent.withAlphaComponent(0.78),
                cursor: &cursor,
                spacingAfter: 7
            )
        }

        // Marginalia. When the Cast acted this month they annotate the reader's
        // own pages in their own ink and sign with their own glyph: Pippa's
        // interrobang, Mook's section sign. The Book still speaks in the
        // margins it is left; those notes simply go unsigned.
        if showMarginNote, !marginalia.isEmpty {
            let note = marginalia[marginaliaIndex % marginalia.count]
            let noteSeed = "\(cursor.pageSeed)-margin\(marginaliaIndex)"
            marginaliaIndex += 1

            let speakerInk = note.accentHex.map { castInk($0) }
            let bodyColor = speakerInk?.withAlphaComponent(0.88)
                ?? style.palette.ink.withAlphaComponent(0.82)

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 1
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.serifItalicFont(ofSize: 8),
                .foregroundColor: bodyColor,
                .paragraphStyle: paragraph
            ]
            let textRect = CGRect(x: 30, y: itemTop + 20, width: 72, height: 120)
            let measured = (note.text as NSString).boundingRect(
                with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], attributes: attributes, context: nil
            )

            // A signed note needs room underneath for the signature.
            let signature = note.isSpoken
                ? [note.glyph, note.speakerName].compactMap { $0 }.joined(separator: " ")
                : nil
            let signatureHeight: CGFloat = signature == nil ? 0 : 12

            // A torn scrap of note paper, taped into the gutter at a slight tilt.
            let scrap = CGRect(
                x: 22,
                y: itemTop + 12,
                width: 88,
                height: min(132, measured.height + 18 + signatureHeight)
            )
            drawTornScrap(
                in: scrap,
                rotation: (frac("\(noteSeed)-rot") - 0.5) * 0.18,
                fill: blend(parchment(for: style).top, style.palette.gold, 0.12),
                seed: noteSeed
            )
            drawTapeStrip(center: CGPoint(x: scrap.midX, y: scrap.minY + 2), length: 40, angle: (frac("\(noteSeed)-tape") - 0.5) * 0.5, tint: style.palette.gold)
            (note.text as NSString).draw(in: textRect, withAttributes: attributes)

            if let signature {
                let signatureParagraph = NSMutableParagraphStyle()
                signatureParagraph.alignment = .right
                let signatureRect = CGRect(
                    x: textRect.minX,
                    y: textRect.minY + min(measured.height, 104) + 2,
                    width: textRect.width,
                    height: 11
                )
                (signature as NSString).draw(in: signatureRect, withAttributes: [
                    .font: UIFont.serifFont(ofSize: 7.2, weight: .semibold),
                    .foregroundColor: (speakerInk ?? style.palette.accent).withAlphaComponent(0.95),
                    .paragraphStyle: signatureParagraph
                ])
            }
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
        if let contextNote = item.contextNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            height += measuredTextHeight(
                contextNote,
                font: .serifItalicFont(ofSize: 8.8),
                width: cursor.contentWidth
            ) + 7
        }
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
                let body = paragraph.replacingOccurrences(of: ": The Book", with: "")
                drawText(body, font: .serifFont(ofSize: 12, weight: .regular), color: style.palette.ink, cursor: &cursor, spacingAfter: 18)
                drawText("The Book", font: .serifItalicFont(ofSize: 13), color: style.palette.accent, cursor: &cursor, spacingAfter: 8)
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
        // The full three-part reading: role, epithet and hands: appears once
        // per volume, here. The chapter heading above carries the short name;
        // the colophon is where the Book signs off on who it decided you are.
        if let role = edition.readerRole {
            drawCentered(
                role.signature,
                font: .serifFont(ofSize: 11, weight: .semibold),
                color: style.palette.ink.withAlphaComponent(0.72),
                y: cursor.y,
                in: cursor.bounds
            )
            cursor.y += 18
            if let markName = role.markName {
                drawCentered(
                    "Marked \u{201C}\(markName)\u{201D} by the Book, on evidence.",
                    font: .serifItalicFont(ofSize: 9.5),
                    color: style.palette.ink.withAlphaComponent(0.55),
                    y: cursor.y,
                    in: cursor.bounds
                )
                cursor.y += 16
            }
            drawCentered(
                role.compassLine,
                font: .serifItalicFont(ofSize: 9.5),
                color: style.palette.accent.withAlphaComponent(0.75),
                y: cursor.y,
                in: cursor.bounds
            )
            cursor.y += 20
        }
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

    /// The divider facing the Cast's own movement: a plate of whoever was most
    /// present this month.
    ///
    /// Earned rather than decorative: it is the character who actually turned
    /// up in the ledger, so the same volume never shows the same face twice
    /// running unless they really did dominate two months.
    private static func drawCastDivider(
        _ lead: BoundCastLead?,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard let lead,
              let assetName = lead.plateAssetName,
              let plate = UIImage(named: assetName) else { return }

        beginComposedPage(context, style: style, cursor: &cursor)
        let bounds = cursor.bounds
        let available = CGRect(
            x: bounds.minX + 78,
            y: bounds.minY + 110,
            width: bounds.width - 156,
            height: bounds.height - 280
        )
        let scale = min(available.width / plate.size.width, available.height / plate.size.height)
        let drawn = CGSize(width: plate.size.width * scale, height: plate.size.height * scale)
        let origin = CGPoint(x: available.midX - drawn.width / 2, y: available.midY - drawn.height / 2)
        plate.draw(in: CGRect(origin: origin, size: drawn))

        var y = origin.y + drawn.height + 26
        drawOrnamentRow(style, centerY: y, in: bounds, color: style.palette.accent)
        y += 26
        drawCentered(
            lead.name,
            font: .serifFont(ofSize: 14, weight: .semibold),
            color: style.palette.ink.withAlphaComponent(0.88),
            y: y,
            in: bounds
        )
        y += 21
        drawCentered(
            "was in it most, this month",
            font: .serifItalicFont(ofSize: 10.5),
            color: style.palette.ink.withAlphaComponent(0.6),
            y: y,
            in: bounds
        )
    }

    /// The plate signature: each illuminated quote card given a whole page,
    /// aspect-fitted with a caption naming where the line came from.
    private static func drawIlluminatedPlates(
        _ plates: [IlluminatedPlate],
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !plates.isEmpty else { return }
        for plate in plates {
            beginComposedPage(context, style: style, cursor: &cursor)
            let bounds = cursor.bounds
            let available = CGRect(
                x: bounds.minX + 56,
                y: bounds.minY + 72,
                width: bounds.width - 112,
                height: bounds.height - 190
            )
            let scale = min(
                available.width / plate.image.size.width,
                available.height / plate.image.size.height
            )
            let drawn = CGSize(
                width: plate.image.size.width * scale,
                height: plate.image.size.height * scale
            )
            let origin = CGPoint(
                x: available.midX - drawn.width / 2,
                y: available.midY - drawn.height / 2
            )
            plate.image.draw(in: CGRect(origin: origin, size: drawn))

            let caption = plate.caption.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !caption.isEmpty else { continue }
            drawCentered(
                caption,
                font: .serifItalicFont(ofSize: 9.5),
                color: style.palette.ink.withAlphaComponent(0.6),
                y: origin.y + drawn.height + 22,
                in: bounds
            )
        }
    }

    /// The dedication page.
    ///
    /// Set high on an otherwise empty leaf, italic, centred, no heading: the
    /// convention is centuries old because it works. A short line surrounded by
    /// white space is louder than anything decorated, and this is the one page
    /// the Book had no hand in, so it does not get the Book's ornament either.
    fileprivate static func drawDedication(
        _ dedication: BoundDedication?,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard let dedication else { return }
        beginComposedPage(context, style: style, cursor: &cursor)
        let bounds = cursor.bounds

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 6
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.serifItalicFont(ofSize: 14),
            .foregroundColor: style.palette.ink.withAlphaComponent(0.86),
            .paragraphStyle: paragraph
        ]
        // Sits in the upper third, where a dedication belongs. Centring it
        // vertically would make it look like a pull quote.
        let column = CGRect(
            x: bounds.minX + bounds.width * 0.18,
            y: bounds.minY + bounds.height * 0.26,
            width: bounds.width * 0.64,
            height: bounds.height * 0.5
        )
        (dedication.text as NSString).draw(in: column, withAttributes: attributes)
    }

    /// The frontispiece: a full-page plate of the cast member who patrons the
    /// reader's role, facing the foreword.
    ///
    /// This is the oldest move in bookmaking: a portrait plate opposite the
    /// title, and here it is personal: the character standing at the front of
    /// the volume is the one who stands for *this* reader. Drawn only when the
    /// role has a patron and the plate art actually exists, so a cast member
    /// added without art degrades to no frontispiece rather than a blank page.
    private static func drawPatronFrontispiece(
        _ edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard let role = edition.readerRole,
              let assetName = role.patronPlateAssetName,
              let plate = UIImage(named: assetName) else { return }

        beginComposedPage(context, style: style, cursor: &cursor)
        let bounds = cursor.bounds

        // Aspect-fit inside the text block, leaving room for the caption.
        let available = CGRect(
            x: bounds.minX + 64,
            y: bounds.minY + 96,
            width: bounds.width - 128,
            height: bounds.height - 260
        )
        let scale = min(available.width / plate.size.width, available.height / plate.size.height)
        let drawn = CGSize(width: plate.size.width * scale, height: plate.size.height * scale)
        let origin = CGPoint(
            x: available.midX - drawn.width / 2,
            y: available.midY - drawn.height / 2
        )
        plate.draw(in: CGRect(origin: origin, size: drawn))

        var captionY = origin.y + drawn.height + 26
        drawOrnamentRow(style, centerY: captionY, in: bounds, color: style.palette.accent)
        captionY += 24

        if let patronName = role.patronName {
            drawCentered(
                patronName,
                font: .serifFont(ofSize: 13, weight: .semibold),
                color: style.palette.ink.withAlphaComponent(0.86),
                y: captionY,
                in: bounds
            )
            captionY += 20
        }
        drawCentered(
            "who stands for \(role.fullName)",
            font: .serifItalicFont(ofSize: 10.5),
            color: style.palette.ink.withAlphaComponent(0.62),
            y: captionY,
            in: bounds
        )
    }

    /// "RRGGBB" → UIColor. The cast accent hexes live in Shared as plain
    /// strings because InsideCoverCore imports neither SwiftUI nor UIKit; the
    /// SwiftUI twin of this lives on `Color` in BookStatusCards.
    fileprivate static func castInk(_ hex: String) -> UIColor {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Who annotates this volume.
    ///
    /// The Cast speaks where they acted: those are real quotes from the act
    /// ledger, not lines written for the occasion, and the Book fills the rest
    /// with its own observations. The two are interleaved rather than stacked,
    /// so a character turns up periodically through the volume instead of
    /// crowding the opening chapters and then falling silent.
    private static func marginNotes(for edition: MonthlyEdition) -> [BoundMarginNote] {
        let spoken = edition.marginalia ?? []
        let unspoken = CastMarginalia.unspokenNotes(marginaliaLines(for: edition))
        guard !spoken.isEmpty else { return unspoken }
        guard !unspoken.isEmpty else { return spoken }

        var interleaved: [BoundMarginNote] = []
        var voices = spoken.makeIterator()
        var book = unspoken.makeIterator()
        var next: BoundMarginNote?
        repeat {
            next = voices.next()
            if let next { interleaved.append(next) }
            if let bookNote = book.next() { interleaved.append(bookNote) }
        } while next != nil
        while let remaining = book.next() { interleaved.append(remaining) }
        return interleaved
    }

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

    static func drawVerticalWash(in bounds: CGRect, top: UIColor, bottom: UIColor, cg: CGContext) {
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

    static func drawCentered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, in bounds: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }

    /// Centred display type that still behaves when a reader earns a long role
    /// name or writes a long personal name. The one-line cover helper above is
    /// intentionally kept for short furniture; identity must never run off the
    /// edge of its own book.
    private static func drawCenteredWrapped(
        _ text: String,
        font: UIFont,
        color: UIColor,
        rect: CGRect,
        lineSpacing: CGFloat = 2
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = lineSpacing
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
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

    static func drawCentered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, in bounds: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }

    static func drawVerticalWash(in bounds: CGRect, top: UIColor, bottom: UIColor, cg: CGContext) {
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

/// Renders the reader's role as something they can send to somebody. Shares the
/// Weekly Issue card's plate treatment on purpose: the two cards should read as
/// pages from the same book, not two apps.
enum ReaderRoleShareCardRenderer {
    static let defaultSize = CGSize(width: 1080, height: 1350)

    static func write(_ card: ReaderRoleShareCard, to url: URL, size: CGSize = defaultSize) throws {
        guard let data = image(for: card, size: size).pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }

    static func image(for card: ReaderRoleShareCard, size: CGSize = defaultSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(card, in: CGRect(origin: .zero, size: size), cg: context.cgContext)
        }
    }

    private static func draw(_ card: ReaderRoleShareCard, in bounds: CGRect, cg: CGContext) {
        let ink = UIColor(red: 0.12, green: 0.09, blue: 0.07, alpha: 1)
        let paperTop = UIColor(red: 0.98, green: 0.92, blue: 0.76, alpha: 1)
        let paperBottom = UIColor(red: 0.72, green: 0.58, blue: 0.39, alpha: 1)
        let teal = UIColor(red: 0.05, green: 0.42, blue: 0.45, alpha: 1)
        let gold = UIColor(red: 0.78, green: 0.52, blue: 0.18, alpha: 1)
        let red = UIColor(red: 0.54, green: 0.12, blue: 0.13, alpha: 1)

        WeeklyIssueShareCardRenderer.drawVerticalWash(in: bounds, top: paperTop, bottom: paperBottom, cg: cg)
        WeeklyIssueShareCardRenderer.drawStarField(in: bounds, color: gold)

        let cardRect = bounds.insetBy(dx: 72, dy: 78)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 42)
        UIColor.white.withAlphaComponent(0.28).setFill()
        cardPath.fill()
        gold.withAlphaComponent(0.46).setStroke()
        cardPath.lineWidth = 3
        cardPath.stroke()
        WeeklyIssueShareCardRenderer.drawCornerMarks(in: cardRect, color: red.withAlphaComponent(0.72))

        WeeklyIssueShareCardRenderer.drawCentered(
            "THE BOOK OF YOU", font: .systemFont(ofSize: 28, weight: .bold),
            color: ink.withAlphaComponent(0.58), y: cardRect.minY + 58, in: bounds
        )
        WeeklyIssueShareCardRenderer.drawCentered(
            "WHAT IT DECIDED I AM", font: .systemFont(ofSize: 23, weight: .semibold),
            color: teal.withAlphaComponent(0.82), y: cardRect.minY + 96, in: bounds
        )

        let nameRect = CGRect(x: cardRect.minX + 76, y: cardRect.minY + 210, width: cardRect.width - 152, height: 300)
        WeeklyIssueShareCardRenderer.drawWrappedCentered(
            card.fullName, font: .serifFont(ofSize: 92, weight: .bold), color: ink, rect: nameRect
        )

        if let hands = card.handsName {
            WeeklyIssueShareCardRenderer.drawCentered(
                hands.uppercased(), font: .systemFont(ofSize: 27, weight: .heavy),
                color: red, y: nameRect.maxY + 6, in: bounds
            )
        }

        let glossRect = CGRect(x: cardRect.minX + 104, y: nameRect.maxY + 74, width: cardRect.width - 208, height: 210)
        WeeklyIssueShareCardRenderer.drawWrappedCentered(
            card.gloss, font: .serifItalicFont(ofSize: 40), color: ink.withAlphaComponent(0.82), rect: glossRect
        )

        if let cost = card.epithetCost {
            let costRect = CGRect(x: cardRect.minX + 120, y: glossRect.maxY + 26, width: cardRect.width - 240, height: 140)
            WeeklyIssueShareCardRenderer.drawWrappedCentered(
                cost, font: .systemFont(ofSize: 28, weight: .semibold),
                color: ink.withAlphaComponent(0.58), rect: costRect
            )
        }

        WeeklyIssueShareCardRenderer.drawCentered(
            card.patronLine, font: .systemFont(ofSize: 27, weight: .bold),
            color: teal.withAlphaComponent(0.92), y: cardRect.maxY - 268, in: bounds
        )
        let closeRect = CGRect(x: cardRect.minX + 120, y: cardRect.maxY - 214, width: cardRect.width - 240, height: 92)
        WeeklyIssueShareCardRenderer.drawWrappedCentered(
            card.closingLine, font: .serifItalicFont(ofSize: 36), color: red.withAlphaComponent(0.90), rect: closeRect
        )
        WeeklyIssueShareCardRenderer.drawCentered(
            "Made with ReEnchanted", font: .systemFont(ofSize: 24, weight: .bold),
            color: ink.withAlphaComponent(0.62), y: cardRect.maxY - 78, in: bounds
        )
        WeeklyIssueShareCardRenderer.drawCentered(
            "reenchanted.app", font: .systemFont(ofSize: 21, weight: .semibold),
            color: ink.withAlphaComponent(0.46), y: cardRect.maxY - 43, in: bounds
        )
    }
}

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

        // The deluxe cut earns its extra ink: the reader's role banners the
        // week, every stat gets a pill instead of the three that fit the plain
        // plate, and the back-page tease comes to the front.
        var statY = cardRect.minY + 730
        if card.isDeluxe, let banner = card.roleBanner {
            drawCentered(
                banner.uppercased(), font: .systemFont(ofSize: 26, weight: .heavy),
                color: gold, y: cardRect.minY + 700, in: bounds
            )
            statY = cardRect.minY + 752
        }
        let pills = card.isDeluxe && !card.fullStats.isEmpty ? card.fullStats : card.stats
        drawStatPills(pills, y: statY, in: cardRect, ink: ink, fill: teal, accent: gold, limit: card.isDeluxe ? 5 : 3)

        let motifRect = CGRect(x: cardRect.minX + 86, y: statY + 160, width: cardRect.width - 172, height: 128)
        drawWrappedCentered(card.motifLine, font: .systemFont(ofSize: 32, weight: .semibold), color: ink.withAlphaComponent(0.82), rect: motifRect)

        if card.isDeluxe, !card.nextIssueTease.isEmpty {
            let teaseRect = CGRect(x: cardRect.minX + 110, y: cardRect.maxY - 330, width: cardRect.width - 220, height: 96)
            drawWrappedCentered(
                card.nextIssueTease, font: .systemFont(ofSize: 27, weight: .semibold),
                color: teal.withAlphaComponent(0.86), rect: teaseRect
            )
        }
        let closeRect = CGRect(x: cardRect.minX + 120, y: cardRect.maxY - 230, width: cardRect.width - 240, height: 92)
        drawWrappedCentered(card.closingLine, font: .serifItalicFont(ofSize: 36), color: red.withAlphaComponent(0.90), rect: closeRect)
        drawCentered("Made with ReEnchanted", font: .systemFont(ofSize: 24, weight: .bold), color: ink.withAlphaComponent(0.62), y: cardRect.maxY - 78, in: bounds)
        drawCentered("reenchanted.app", font: .systemFont(ofSize: 21, weight: .semibold), color: ink.withAlphaComponent(0.46), y: cardRect.maxY - 43, in: bounds)
    }

    private static func drawStatPills(_ stats: [String], y: CGFloat, in cardRect: CGRect, ink: UIColor, fill: UIColor, accent: UIColor, limit: Int = 3) {
        let shown = Array(stats.prefix(limit))
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

    static func drawStarField(in bounds: CGRect, color: UIColor) {
        color.withAlphaComponent(0.16).setFill()
        for index in 0..<72 {
            let x = CGFloat((index * 139) % 1013) + 28
            let y = CGFloat((index * 197) % 1279) + 31
            let radius = CGFloat((index % 4) + 2)
            UIBezierPath(ovalIn: CGRect(x: x, y: y, width: radius, height: radius)).fill()
        }
    }

    static func drawVerticalWash(in bounds: CGRect, top: UIColor, bottom: UIColor, cg: CGContext) {
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

    static func drawCornerMarks(in rect: CGRect, color: UIColor) {
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

    static func drawCentered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, in bounds: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }

    static func drawWrappedCentered(_ text: String, font: UIFont, color: UIColor, rect: CGRect) {
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

    /// Each issue gets its own deterministic binding: palette and ornament
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
        // The single strongest page of the week: the issue's centerfold.
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

            /// A torn label taped across the leaf: the issue's section headers.
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
            func drawMarginNote(_ note: BoundMarginNote, top: CGFloat, cursor: PDFCursor) {
                guard top + 140 < pageBounds.height - 60 else { return }
                let speakerInk = note.accentHex.map { Monthly.castInk($0) }
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 1.5
                let attributed = NSAttributedString(string: note.text, attributes: [
                    .font: UIFont.serifItalicFont(ofSize: 8),
                    .foregroundColor: speakerInk?.withAlphaComponent(0.86) ?? ink.withAlphaComponent(0.62),
                    .paragraphStyle: paragraph
                ])
                let measured = attributed.boundingRect(
                    with: CGSize(width: 70, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let signature = note.isSpoken
                    ? [note.glyph, note.speakerName].compactMap { $0 }.joined(separator: " ")
                    : nil
                let signatureHeight: CGFloat = signature == nil ? 0 : 11
                let seed = "\(cursor.pageSeed)-margin-\(note.text.prefix(12))"
                let scrap = CGRect(
                    x: 16,
                    y: top + 8,
                    width: 86,
                    height: min(128, measured.height + 18 + signatureHeight)
                )
                Monthly.drawTornScrap(
                    in: scrap,
                    rotation: (Monthly.frac("\(seed)-rot") - 0.5) * 0.14,
                    fill: Monthly.blend(Monthly.parchment(for: style).top, style.palette.gold, 0.12),
                    seed: seed
                )
                attributed.draw(in: CGRect(x: scrap.minX + 8, y: scrap.minY + 9, width: 70, height: measured.height))
                if let signature {
                    let signatureStyle = NSMutableParagraphStyle()
                    signatureStyle.alignment = .right
                    (signature as NSString).draw(
                        in: CGRect(
                            x: scrap.minX + 8,
                            y: scrap.minY + 9 + measured.height + 1,
                            width: 70,
                            height: 10
                        ),
                        withAttributes: [
                            .font: UIFont.serifFont(ofSize: 6.8, weight: .semibold),
                            .foregroundColor: (speakerInk ?? accent).withAlphaComponent(0.95),
                            .paragraphStyle: signatureStyle
                        ]
                    )
                }
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
            drawCentered(issue.readerRole?.fullName ?? readerName, font: .serifItalicFont(ofSize: 15), color: ink.withAlphaComponent(0.70), y: cursor.y, in: pageBounds)
            cursor.y += 26
            drawCentered(issue.dateRange.uppercased(), font: .systemFont(ofSize: 10, weight: .semibold), color: accent, y: cursor.y, in: pageBounds)
            cursor.y += 28
            thickRule(accent.withAlphaComponent(0.48), cursor: &cursor)
            cursor.y += 16

            if issue.dedication != nil {
                // Let the masthead stand as the cover, then give the reader's
                // words a whole quiet leaf before the Book begins speaking.
                Monthly.drawDedication(
                    issue.dedication,
                    style: style,
                    context: context,
                    cursor: &cursor
                )
                cursor = beginPage(margins: frontMargins)
            }

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
            if issue.castConversation?.isEmpty == false {
                contents.append(("At the Issue Desk", "the Cast gets hold of the proof"))
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

            // ---- At the Issue Desk: the Cast reacts to this exact proof ----

            if let conversation = issue.castConversation, !conversation.isEmpty {
                cursor = beginPage(margins: readingMargins)
                drawTornLabel(conversation.title, cursor: &cursor)
                Monthly.drawText(
                    conversation.setting,
                    font: .serifItalicFont(ofSize: 10.5),
                    color: ink.withAlphaComponent(0.60),
                    cursor: &cursor,
                    spacingAfter: 16
                )
                for line in conversation.lines {
                    ensureSpace(76, cursor: &cursor, margins: readingMargins)
                    let voice = KeepMarginalia.voice(forSlug: line.speakerID)
                    let speakerInk = voice.map { Monthly.castInk($0.accentHex) } ?? accent
                    Monthly.drawText(
                        [line.glyph ?? voice?.glyph ?? "", line.speakerName].filter { !$0.isEmpty }.joined(separator: "  "),
                        font: .systemFont(ofSize: 9.5, weight: .bold),
                        color: speakerInk,
                        cursor: &cursor,
                        spacingAfter: 4
                    )
                    Monthly.drawText(
                        line.words,
                        font: .serifFont(ofSize: 11.5, weight: .regular),
                        color: ink.withAlphaComponent(0.90),
                        cursor: &cursor,
                        spacingAfter: 15,
                        leftInset: 12
                    )
                }
            }

            // ---- The Seven Days: the week, day by day, in the reader's ink ----

            cursor = beginPage(margins: readingMargins)
            drawTornLabel("The Seven Days", cursor: &cursor)

            let weekStart = calendar.startOfDay(for: issue.startDate)
            let pagesByDay = Dictionary(grouping: prosePages) { calendar.startOfDay(for: $0.createdAt) }
            let marginalia = marginNotes(issue: issue, card: card)
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

    /// Sets a closed week as a 6 x 9 saddle-stitched publication. The digital
    /// reading copy above flows like an article; this one turns every day into
    /// a spread, then gives photographs, findings, and the wrapped week their
    /// own leaves. Quiet weeks stay honestly slim. Ordinary weeks aim for 32
    /// pages, with Lulu's 48-page ceiling retained as an exceptional limit.
    @discardableResult
    static func writePrintInterior(
        _ matter: WeeklyPublicationMatter,
        dedication: BoundDedication?,
        spec: PrintSpec,
        to url: URL
    ) throws -> Int {
        guard spec.coverTreatment == .saddleStitch else {
            throw NSError(
                domain: "Bindery",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "A weekly issue needs the saddle-stitch press."]
            )
        }

        var issue = matter.issue
        issue.dedication = dedication
        let card = matter.card
        let style = style(for: issue)
        let ink = style.palette.ink
        let accent = style.palette.accent
        let fullBleed = PrintGeometry.fullBleedTrimInches(spec: spec)
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: fullBleed.width * PrintSpec.pointsPerInch,
            height: fullBleed.height * PrintSpec.pointsPerInch
        )
        let edge = spec.interiorMarginsPoints
        let margins = UIEdgeInsets(
            top: edge.top,
            left: edge.left,
            bottom: edge.bottom,
            right: edge.right
        )
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let calendar = Calendar.current
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = calendar
        weekdayFormatter.dateFormat = "EEEE"
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.dateFormat = "MMM d"
        let prosePages = issue.pages.filter { !EditionCurator.isScrapbookPage($0) }
        let pagesByDay = Dictionary(grouping: prosePages) { calendar.startOfDay(for: $0.createdAt) }
        let plates: [(page: BookPage, image: UIImage)] = issue.pages
            .filter(EditionCurator.isScrapbookPage)
            .compactMap { page in Monthly.firstImage(from: page.mediaAssets).map { (page, $0) } }
            .prefix(4)
            .map(\.self)

        let data = renderer.pdfData { context in
            var pageNumber = 0

            func beginPage(section: String? = nil) -> PDFCursor {
                context.beginPage()
                pageNumber += 1
                Monthly.drawComposedBackground(
                    style: style,
                    seed: "weekly-print-\(issue.number)-\(pageNumber)",
                    in: pageBounds
                )
                if let section {
                    drawCentered(
                        section.uppercased(),
                        font: .systemFont(ofSize: 7.5, weight: .heavy),
                        color: accent.withAlphaComponent(0.74),
                        y: 23,
                        in: pageBounds
                    )
                }
                drawCentered(
                    "THE BOOK OF YOU · ISSUE \(issue.number)",
                    font: .systemFont(ofSize: 6.8, weight: .semibold),
                    color: ink.withAlphaComponent(0.40),
                    y: pageBounds.height - 27,
                    in: pageBounds
                )
                var cursor = PDFCursor(bounds: pageBounds, margins: margins)
                cursor.seed = "weekly-print-\(issue.number)"
                cursor.pageIndex = pageNumber - 1
                return cursor
            }

            func heading(_ text: String, cursor: inout PDFCursor, size: CGFloat = 24) {
                Monthly.drawText(
                    text,
                    font: .serifFont(ofSize: size, weight: .bold),
                    color: ink,
                    cursor: &cursor,
                    spacingAfter: 13
                )
                Monthly.drawOrnamentRow(style, centerY: cursor.y, in: pageBounds, color: accent)
                cursor.y += 20
            }

            func body(_ text: String, cursor: inout PDFCursor, limit: Int = 1_250, size: CGFloat = 11.5) {
                Monthly.drawText(
                    clamp(text, limit: limit),
                    font: .serifFont(ofSize: size, weight: .regular),
                    color: ink.withAlphaComponent(0.88),
                    cursor: &cursor,
                    spacingAfter: 12
                )
            }

            // Masthead: the physical cover is separate, so this is the first
            // right-hand interior page rather than a second cover pretending.
            var cursor = beginPage()
            cursor.y += 26
            drawCentered(
                "T H E   B O O K   O F   Y O U",
                font: .systemFont(ofSize: 8.5, weight: .black),
                color: ink.withAlphaComponent(0.62),
                y: cursor.y,
                in: pageBounds
            )
            cursor.y += 42
            drawCentered(
                "Issue No. \(issue.number)",
                font: .serifFont(ofSize: 35, weight: .bold),
                color: ink,
                y: cursor.y,
                in: pageBounds
            )
            cursor.y += 50
            drawCentered(
                matter.readerName,
                font: .serifItalicFont(ofSize: 13),
                color: ink.withAlphaComponent(0.70),
                y: cursor.y,
                in: pageBounds
            )
            cursor.y += 28
            drawCentered(
                issue.dateRange.uppercased(),
                font: .systemFont(ofSize: 9, weight: .bold),
                color: accent,
                y: cursor.y,
                in: pageBounds
            )
            if let taleLine = WeeklyIssue.taleLine(for: issue) {
                cursor.y += 58
                body(taleLine, cursor: &cursor, limit: 420, size: 13)
            } else if let highlight = issue.highlights.first {
                cursor.y += 58
                body("“\(highlight)”", cursor: &cursor, limit: 420, size: 13)
            }

            if let dedication = issue.dedication {
                cursor = beginPage(section: "Dedication")
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                paragraph.lineSpacing = 6
                (dedication.text as NSString).draw(
                    in: CGRect(
                        x: pageBounds.width * 0.16,
                        y: pageBounds.height * 0.27,
                        width: pageBounds.width * 0.68,
                        height: pageBounds.height * 0.46
                    ),
                    withAttributes: [
                        .font: UIFont.serifItalicFont(ofSize: 14),
                        .foregroundColor: ink.withAlphaComponent(0.88),
                        .paragraphStyle: paragraph
                    ]
                )
            }

            // Editor's note and the map of the issue share one leaf.
            cursor = beginPage(section: "From the Bindery")
            heading("This week, bound", cursor: &cursor)
            let editorial = matter.editorialNote?.nonEmpty
                ?? (issue.isFirstIssue
                    ? "Your first week closed and left enough ink to hold."
                    : "Another seven days closed. These are the pieces that held.")
            body(editorial, cursor: &cursor, limit: 760)
            cursor.y += 8
            let contents = [
                "The week, bound",
                issue.castConversation?.isEmpty == false ? "At the issue desk" : nil,
                "Seven days · two leaves each",
                issue.revelations.isEmpty ? nil : "What the Book noticed",
                plates.isEmpty ? nil : "Plates from the week",
                "The wrapped week"
            ].compactMap { $0 }
            for (index, line) in contents.enumerated() {
                Monthly.drawText(
                    "\(index + 1).  \(line)",
                    font: .serifFont(ofSize: 11, weight: .semibold),
                    color: ink.withAlphaComponent(0.76),
                    cursor: &cursor,
                    spacingAfter: 7
                )
            }

            // The binding story gets up to three leaves. The local writer is
            // capped before this point, and this second bound keeps a malformed
            // archive from swallowing the whole booklet.
            let bindingText = issue.bindingStory?.nonEmpty
                ?? issue.highlights.joined(separator: "\n\n")
            let bindingChunks = physicalTextChunks(bindingText, characterLimit: 1_350, maximumChunks: 3)
            for (index, chunk) in bindingChunks.enumerated() {
                cursor = beginPage(section: "The Week, Bound")
                heading(index == 0 ? "The week, bound" : "The week, still binding", cursor: &cursor)
                body(chunk, cursor: &cursor, limit: 1_400, size: 12)
            }

            if let conversation = issue.castConversation, !conversation.isEmpty {
                cursor = beginPage(section: "At the Issue Desk")
                heading(conversation.title, cursor: &cursor, size: 22)
                body(conversation.setting, cursor: &cursor, limit: 320, size: 10.5)
                cursor.y += 4
                for line in conversation.lines {
                    Monthly.drawText(
                        [line.glyph ?? "", line.speakerName].filter { !$0.isEmpty }.joined(separator: "  "),
                        font: .systemFont(ofSize: 8.5, weight: .bold),
                        color: accent,
                        cursor: &cursor,
                        spacingAfter: 3
                    )
                    body(line.words, cursor: &cursor, limit: 360, size: 10.7)
                }
            }

            // Seven two-page movements. The first leaf records the day's
            // contents; the facing leaf sets its strongest page at reading size.
            let weekStart = calendar.startOfDay(for: issue.startDate)
            for offset in 0..<WeeklyIssue.weekDays {
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
                let dayPages = (pagesByDay[date] ?? []).sorted { $0.createdAt < $1.createdAt }
                let weekday = weekdayFormatter.string(from: date)
                let dateLine = dayFormatter.string(from: date)

                cursor = beginPage(section: "The Seven Days")
                heading(weekday, cursor: &cursor, size: 28)
                Monthly.drawText(
                    dateLine.uppercased(),
                    font: .systemFont(ofSize: 8.5, weight: .heavy),
                    color: accent,
                    cursor: &cursor,
                    spacingAfter: 18
                )
                if dayPages.isEmpty {
                    let quiet = quietLines[ConstellationKeeper.stableIndex(
                        for: "weekly-print-\(issue.number)-quiet-\(offset)",
                        count: quietLines.count
                    )]
                    body("\(weekday) \(quiet)", cursor: &cursor, limit: 500, size: 13)
                } else {
                    for page in dayPages.prefix(2) {
                        Monthly.drawText(
                            page.type.title.uppercased(),
                            font: .systemFont(ofSize: 7.5, weight: .heavy),
                            color: accent.withAlphaComponent(0.86),
                            cursor: &cursor,
                            spacingAfter: 5
                        )
                        body(page.userInput.nonEmpty ?? page.promptText, cursor: &cursor, limit: 360, size: 10.7)
                    }
                    if dayPages.count > 2 {
                        body("And \(dayPages.count - 2) more kept that day.", cursor: &cursor, limit: 120, size: 9.5)
                    }
                }

                cursor = beginPage(section: "\(weekday) · Set Full")
                if let strongest = dayPages.max(by: {
                    StorySpark.score($0.userInput.nonEmpty ?? $0.promptText)
                        < StorySpark.score($1.userInput.nonEmpty ?? $1.promptText)
                }) {
                    heading(strongest.type.title, cursor: &cursor, size: 21)
                    body(strongest.userInput.nonEmpty ?? strongest.promptText, cursor: &cursor, limit: 1_200, size: 11.8)
                    if let image = Monthly.firstImage(from: strongest.mediaAssets), cursor.bottom - cursor.y > 150 {
                        Monthly.drawFramedImage(image, style: style, context: context, cursor: &cursor)
                    }
                } else {
                    cursor.y += 74
                    Monthly.drawOrnamentRow(style, centerY: cursor.y, in: pageBounds, color: accent)
                    cursor.y += 34
                    let line = issue.highlights.isEmpty
                        ? "Nothing asked to be made into evidence. The day is still allowed to have happened."
                        : issue.highlights[offset % issue.highlights.count]
                    body(line, cursor: &cursor, limit: 520, size: 13)
                }
            }

            for revelation in issue.revelations.prefix(2) {
                cursor = beginPage(section: "What the Book Noticed")
                heading(revelation.title, cursor: &cursor, size: 22)
                body(revelation.body, cursor: &cursor, limit: 1_050, size: 12)
                for evidence in revelation.evidence.prefix(2) {
                    cursor.y += 9
                    body("“\(evidence.excerpt)”", cursor: &cursor, limit: 320, size: 10.5)
                }
            }

            for (index, plate) in plates.enumerated() {
                cursor = beginPage(section: "Plate \(index + 1)")
                let title = plate.page.promptText.nonEmpty ?? "A page the week made by hand"
                heading(title, cursor: &cursor, size: 20)
                let available = CGRect(
                    x: margins.left,
                    y: cursor.y,
                    width: pageBounds.width - margins.left - margins.right,
                    height: cursor.bottom - cursor.y - 24
                )
                let scale = min(available.width / plate.image.size.width, available.height / plate.image.size.height)
                let size = CGSize(width: plate.image.size.width * scale, height: plate.image.size.height * scale)
                let rect = CGRect(
                    x: available.midX - size.width / 2,
                    y: available.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                plate.image.draw(in: rect)
                accent.withAlphaComponent(0.54).setStroke()
                let frame = UIBezierPath(rect: rect.insetBy(dx: -5, dy: -5))
                frame.lineWidth = 1
                frame.stroke()
            }

            cursor = beginPage(section: "The Wrapped Week")
            heading(card.title, cursor: &cursor, size: 27)
            body(card.subtitle, cursor: &cursor, limit: 520, size: 12)
            drawStatGrid(card.stats, cursor: &cursor, bounds: pageBounds, ink: ink, accent: accent)
            cursor.y += 8
            drawWrappedPanel(
                title: "The week's refrain",
                body: card.motifLine,
                color: accent,
                ink: ink,
                cursor: &cursor,
                bounds: pageBounds
            )

            cursor = beginPage(section: "The Week Closes")
            cursor.y += 54
            Monthly.drawOrnamentRow(style, centerY: cursor.y, in: pageBounds, color: accent)
            cursor.y += 36
            body(
                matter.closingNote?.nonEmpty
                    ?? "The month and the year are still gathering. This week is already whole.",
                cursor: &cursor,
                limit: 760,
                size: 13
            )
            cursor.y += 42
            body(
                card.nextIssueTease.nonEmpty
                    ?? "Issue No. \(issue.number + 1) is already gathering.",
                cursor: &cursor,
                limit: 420,
                size: 11
            )

            cursor = beginPage(section: "Colophon")
            cursor.y += 72
            drawCentered(
                "ISSUE NO. \(issue.number)",
                font: .systemFont(ofSize: 8, weight: .heavy),
                color: accent,
                y: cursor.y,
                in: pageBounds
            )
            cursor.y += 36
            drawCentered(
                "Set privately from pages kept in ReEnchanted",
                font: .serifItalicFont(ofSize: 11),
                color: ink.withAlphaComponent(0.72),
                y: cursor.y,
                in: pageBounds
            )
            cursor.y += 28
            drawCentered(
                "6 × 9 · saddle stitched · made to order",
                font: .systemFont(ofSize: 7.5, weight: .semibold),
                color: ink.withAlphaComponent(0.48),
                y: cursor.y,
                in: pageBounds
            )
        }

        guard let document = PDFDocument(data: data) else {
            throw NSError(domain: "Bindery", code: 6, userInfo: [NSLocalizedDescriptionKey: "The weekly interior would not render."])
        }
        let preferred = matter.preferredPhysicalPageCount
        let target = PrintGeometry.boundPageCount(
            rawPages: max(document.pageCount, preferred),
            spec: spec
        )
        guard target <= WeeklyPrintEditorialPolicy.technicalMaximumPages else {
            throw NSError(
                domain: "Bindery",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "This week grew past 48 pages. It needs a tighter edit or a softcover expanded issue."]
            )
        }

        while document.pageCount < target {
            let paddingData = renderer.pdfData { context in
                context.beginPage()
                Monthly.drawComposedBackground(
                    style: style,
                    seed: "weekly-print-\(issue.number)-quiet-endpaper-\(document.pageCount)",
                    in: pageBounds
                )
                Monthly.drawOrnamentRow(
                    style,
                    centerY: pageBounds.midY,
                    in: pageBounds,
                    color: accent.withAlphaComponent(0.42)
                )
            }
            guard let paddingPage = PDFDocument(data: paddingData)?.page(at: 0) else { break }
            // Keep the colophon as the final printed leaf; quiet endpapers sit
            // immediately before it instead of trailing after the book ends.
            document.insert(paddingPage, at: max(0, document.pageCount - 1))
        }

        guard document.write(to: url) else {
            throw NSError(domain: "Bindery", code: 8, userInfo: [NSLocalizedDescriptionKey: "The weekly interior would not save."])
        }
        return document.pageCount
    }

    // MARK: - Issue material

    /// What the gutter whispers on the Seven Days pages: the week's refrain
    /// first, then the Book's own small asides.
    /// The issue's margins. The Cast speaks where they acted inside the week -
    /// quoted, signed and in their own ink, exactly as in the monthly volume -
    /// and the Book's own observations fill what is left, interleaved so a
    /// voice is not spent on the first leaf.
    private static func marginNotes(issue: WeeklyIssue, card: WeeklyIssueShareCard) -> [BoundMarginNote] {
        let spoken = issue.marginalia ?? []
        let unspoken = CastMarginalia.unspokenNotes(marginaliaLines(issue: issue, card: card))
        guard !spoken.isEmpty else { return unspoken }
        guard !unspoken.isEmpty else { return spoken }

        var interleaved: [BoundMarginNote] = []
        var voices = spoken.makeIterator()
        var book = unspoken.makeIterator()
        var next: BoundMarginNote?
        repeat {
            next = voices.next()
            if let next { interleaved.append(next) }
            if let bookNote = book.next() { interleaved.append(bookNote) }
        } while next != nil
        while let remaining = book.next() { interleaved.append(remaining) }
        return interleaved
    }

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

    /// How a day with no kept pages is set: honest, never scolding.
    /// Completed with the weekday name: "Tuesday kept its own counsel."
    private static let quietLines = [
        "kept its own counsel.",
        "passed without ink, not every day asks to be written down.",
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

    private static func physicalTextChunks(
        _ text: String,
        characterLimit: Int,
        maximumChunks: Int
    ) -> [String] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        var chunks: [String] = []
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if candidate.count > characterLimit, !current.isEmpty {
                chunks.append(current)
                if chunks.count == maximumChunks { break }
                current = word
            } else {
                current = candidate
            }
        }
        if chunks.count < maximumChunks, !current.isEmpty { chunks.append(current) }
        return chunks
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

    static func drawCentered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, in bounds: CGRect) {
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
