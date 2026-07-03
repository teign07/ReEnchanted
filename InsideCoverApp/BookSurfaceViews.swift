import SwiftUI
import OSLog
import Darwin.Mach
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(Vision)
import Vision
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLLM)
import MLXLLM
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXVLM)
import MLXVLM
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMCommon)
import MLXLMCommon
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMTokenizers)
import MLXLMTokenizers
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMHFAPI)
import MLXLMHFAPI
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLX)
import MLX
#endif

struct IlluminatedArtifactPreview: View {
    let draft: IlluminatedPhotoDraft
    var sourceImage: UIImage? = nil
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private var plan: IlluminatedCompositionPlan {
        draft.compositionPlan
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / plan.canvasSize.width,
                proxy.size.height / plan.canvasSize.height
            )
            let xOffset = (proxy.size.width - plan.canvasSize.width * scale) / 2
            let yOffset = (proxy.size.height - plan.canvasSize.height * scale) / 2

            ZStack {
                Image(plan.backgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: plan.canvasSize.width * scale, height: plan.canvasSize.height * scale)
                    .clipped()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                textureOverlays(scale: scale, proxySize: proxy.size)

                illuminatedPhoto(scale: scale, xOffset: xOffset, yOffset: yOffset)

                ForEach(plan.decorations) { decoration in
                    illuminatedDecoration(decoration, scale: scale, xOffset: xOffset, yOffset: yOffset)
                }

                ForEach(plan.textSlots) { slot in
                    illuminatedTextSlot(slot, scale: scale, xOffset: xOffset, yOffset: yOffset)
                }

                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, BookPalette.ink.opacity(0.22)],
                            center: .center,
                            startRadius: 80 * scale,
                            endRadius: 840 * scale
                        )
                    )
                    .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(BookPalette.nightPanel)
        }
    }

    private func illuminatedPhoto(scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> some View {
        let frame = plan.photoFrame
        let variation = OrganicPlacementVariation(seed: plan.randomSeed, key: "photo-frame")
        return photoImage
            .saturation(saturation(for: plan.photoTreatment))
            .contrast(contrast(for: plan.photoTreatment))
            .brightness(brightness(for: plan.photoTreatment))
            .frame(width: frame.size.width * scale, height: frame.size.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: frame.cornerRadius * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: frame.cornerRadius * scale, style: .continuous)
                    .stroke(BookPalette.paper.opacity(0.82), lineWidth: max(2, 8 * scale))
            }
            .shadow(color: .black.opacity(0.28), radius: 18 * scale, x: 0, y: 10 * scale)
            .rotationEffect(.degrees(frame.rotationDegrees + variation.rotationDegrees))
            .position(
                x: xOffset + (frame.position.x + frame.size.width / 2 + variation.xOffset) * scale,
                y: yOffset + (frame.position.y + frame.size.height / 2 + variation.yOffset) * scale
            )
    }

    @ViewBuilder
    private var photoImage: some View {
        if let sourceImage {
            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFill()
        } else {
            Image(draft.sourceAssetName)
                .resizable()
                .scaledToFill()
        }
    }

    private func illuminatedTextSlot(_ slot: IlluminatedTextSlot, scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> some View {
        let variation = OrganicPlacementVariation(seed: plan.randomSeed, key: "text-\(slot.slotId)", maxOffset: 5, maxRotation: 2.2)
        return ZStack(alignment: .topLeading) {
            illuminatedPaperScrap(slot, scale: scale)

            VStack(alignment: .leading, spacing: 5 * scale) {
                if let title = slot.title, !title.isEmpty {
                    Text(title.uppercased())
                        .font(.system(size: max(7, 30 * scale), weight: .bold, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .lineLimit(1)
                }
                Text(slot.body)
                    .font(font(for: slot.fontStyle, scale: scale))
                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                    .lineSpacing(4 * scale)
                    .minimumScaleFactor(0.55)
                    .lineLimit(7)
            }
            .padding(EdgeInsets(top: 24 * scale, leading: 26 * scale, bottom: 18 * scale, trailing: 22 * scale))
        }
        .frame(width: slot.size.width * scale, height: slot.size.height * scale)
        .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10 * scale, x: 0, y: 6 * scale)
        .rotationEffect(.degrees(slot.rotationDegrees + variation.rotationDegrees))
        .position(
            x: xOffset + (slot.position.x + slot.size.width / 2 + variation.xOffset) * scale,
            y: yOffset + (slot.position.y + slot.size.height / 2 + variation.yOffset) * scale
        )
    }

    private func illuminatedPaperScrap(_ slot: IlluminatedTextSlot, scale: CGFloat) -> some View {
        let material = OrganicPlacementVariation(seed: plan.randomSeed, key: "paper-\(slot.slotId)", maxOffset: 1, maxRotation: 0.4)
        return ZStack {
            Image(slot.paperAssetName)
                .resizable()
                .scaledToFill()
                .opacity(slot.paperAssetName == "MarginaliaSeal" ? 0.18 + material.opacityLift * 0.06 : 0.80 + material.opacityLift * 0.12)
                .frame(width: slot.size.width * scale, height: slot.size.height * scale)
                .clipped()

            LinearGradient(
                colors: [
                    BookPalette.page.opacity(0.92),
                    BookPalette.paper.opacity(0.80),
                    BookPalette.gold.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 9 * scale, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.18), lineWidth: max(1, 2 * scale))

            VStack {
                HStack {
                    tapeStrip(scale: scale)
                        .rotationEffect(.degrees(-7))
                    Spacer()
                    if slot.slotId != "observation-list" {
                        tapeStrip(scale: scale)
                            .rotationEffect(.degrees(8))
                    }
                }
                Spacer()
            }
            .padding(EdgeInsets(top: -8 * scale, leading: 18 * scale, bottom: 0, trailing: 18 * scale))

            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(BookPalette.ink.opacity(0.08))
                    .frame(width: max(1.5, CGFloat(3 + index % 3) * scale), height: max(1.5, CGFloat(3 + index % 3) * scale))
                    .position(
                        x: CGFloat((index * 67 + abs(slot.slotId.stableHash % 43)) % max(1, Int(slot.size.width))) * scale,
                        y: CGFloat((index * 41 + abs(slot.slotId.stableHash % 71)) % max(1, Int(slot.size.height))) * scale
                    )
            }
        }
        .frame(width: slot.size.width * scale, height: slot.size.height * scale)
    }

    @ViewBuilder
    private func illuminatedDecoration(_ decoration: DecorationPlacement, scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> some View {
        let variation = OrganicPlacementVariation(seed: plan.randomSeed, key: "decoration-\(decoration.assetName)-\(decoration.position.x)-\(decoration.position.y)", maxOffset: 7, maxRotation: 3)
        let opacity = decoration.kind == .stamp
            ? max(0.12, min(0.62, decoration.opacity + variation.opacityLift * 0.16 - 0.08))
            : max(0.16, min(0.86, decoration.opacity + variation.opacityLift * 0.10 - 0.04))
        Group {
            if decoration.kind == .stamp,
               let stamp = distressedStampImage(assetName: decoration.assetName, variation: variation) {
                Image(uiImage: stamp)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(decoration.assetName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .opacity(opacity)
        .blendMode(decoration.kind == .stamp ? .multiply : .normal)
        .frame(width: decoration.size.width * scale, height: decoration.size.height * scale)
        .rotationEffect(.degrees(decoration.rotationDegrees + variation.rotationDegrees))
        .position(
            x: xOffset + (decoration.position.x + decoration.size.width / 2 + variation.xOffset) * scale,
            y: yOffset + (decoration.position.y + decoration.size.height / 2 + variation.yOffset) * scale
        )
    }

    @ViewBuilder
    private func textureOverlays(scale: CGFloat, proxySize: CGSize) -> some View {
        ForEach(Array(plan.textureOverlayNames.enumerated()), id: \.offset) { index, name in
            let variation = OrganicPlacementVariation(seed: plan.randomSeed, key: "texture-\(name)-\(index)", maxOffset: 10, maxRotation: 1.5)
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: plan.canvasSize.width * scale, height: plan.canvasSize.height * scale)
                .clipped()
                .opacity(0.035 + variation.opacityLift * 0.045)
                .blendMode(index.isMultiple(of: 2) ? .multiply : .overlay)
                .rotationEffect(.degrees(variation.rotationDegrees))
                .position(
                    x: proxySize.width / 2 + variation.xOffset * scale,
                    y: proxySize.height / 2 + variation.yOffset * scale
                )
                .allowsHitTesting(false)
        }
    }

    private func distressedStampImage(assetName: String, variation: OrganicPlacementVariation) -> UIImage? {
        guard let image = UIImage(named: assetName),
              let input = CIImage(image: image) else {
            return nil
        }
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.saturation = 0.72 + Float(variation.opacityLift) * 0.18
        controls.contrast = 0.88 + Float(variation.distress) * 0.46
        controls.brightness = -0.04 - Float(variation.distress) * 0.08

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = controls.outputImage
        blur.radius = Float(variation.distress * 0.45)

        guard let output = blur.outputImage?.cropped(to: input.extent),
              let cgImage = Self.ciContext.createCGImage(output, from: input.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func tapeStrip(scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2 * scale, style: .continuous)
            .fill(BookPalette.paper.opacity(0.58))
            .overlay {
                RoundedRectangle(cornerRadius: 2 * scale, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.08), lineWidth: max(0.5, scale))
            }
            .frame(width: 66 * scale, height: 22 * scale)
            .shadow(color: .black.opacity(0.08), radius: 3 * scale, x: 0, y: 2 * scale)
    }

    private func font(for style: IlluminatedFontStyle, scale: CGFloat) -> Font {
        let size = max(8, 34 * scale)
        switch style {
        case .serifTitle:
            return .system(size: size * 1.12, weight: .semibold, design: .serif)
        case .serifBody:
            return .system(size: size, weight: .regular, design: .serif)
        case .handwritten:
            return .system(size: size, weight: .regular, design: .serif)
        case .stamp:
            return .system(size: size * 0.9, weight: .bold, design: .serif)
        }
    }

    private func saturation(for treatment: PhotoTreatment) -> Double {
        switch treatment {
        case .naturalKept:
            return 1.04
        case .softArchive:
            return 0.88
        case .sepiaFieldNote:
            return 0.78
        case .hearthGlow:
            return 0.96
        case .quietMatte:
            return 0.72
        }
    }

    private func contrast(for treatment: PhotoTreatment) -> Double {
        switch treatment {
        case .naturalKept:
            return 1.04
        case .softArchive:
            return 0.96
        case .sepiaFieldNote:
            return 0.92
        case .hearthGlow:
            return 1.02
        case .quietMatte:
            return 0.9
        }
    }

    private func brightness(for treatment: PhotoTreatment) -> Double {
        switch treatment {
        case .naturalKept, .softArchive:
            return 0.01
        case .sepiaFieldNote:
            return 0.015
        case .hearthGlow:
            return 0.025
        case .quietMatte:
            return 0.0
        }
    }
}

struct BookConnectionsSheet: View {
    enum Section: String, CaseIterable, Identifiable {
        case clusters = "Clusters"
        case constellations = "Stars"
        case themes = "Themes"

        var id: String { rawValue }
    }

    let days: [BookDay]
    let inputs: BookSourceInputs
    var onOpenPage: (BookPage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: Section = .clusters

    private var clusters: [BookMotifCluster] {
        let derived = inputs.clusters.isEmpty
            ? BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: inputs.constellations, themes: inputs.themes)
            : inputs.clusters
        return derived.sorted { left, right in
            if left.strength == right.strength {
                return left.name < right.name
            }
            return left.strength > right.strength
        }
    }

    private var constellations: [Constellation] {
        inputs.constellations.sorted { left, right in
            if left.phase == right.phase {
                return left.strengthPeak > right.strengthPeak
            }
            return left.phase.title < right.phase.title
        }
    }

    private var themes: [BookTheme] {
        inputs.themes.sorted { $0.monthKey > $1.monthKey }
    }

    private var pageByID: [String: BookPage] {
        Dictionary(uniqueKeysWithValues: days.flatMap(\.pages).map { ($0.id, $0) })
    }

    private var evidencePages: [BookPage] {
        let ids = Set(
            clusters.flatMap(\.evidencePageIDs)
                + constellations.flatMap(\.evidencePageIDs)
                + themes.flatMap(\.evidencePageIDs)
        )
        return days
            .flatMap(\.pages)
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    BookConnectionsMapView(
                        clusters: clusters,
                        constellations: constellations,
                        themes: themes
                    )
                    .frame(height: 230)
                    .accessibilityLabel("A symbolic map of the Book's clusters, constellations, and themes")

                    Picker("Connections section", selection: $selectedSection) {
                        ForEach(Section.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    selectedSectionView
                    evidenceShelf
                }
                .padding(18)
            }
            .background(BookBackground().ignoresSafeArea())
            .navigationTitle("Book Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The Book's private map", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)
            Text("Connections")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(BookPalette.lampGold)
            Text(summaryLine)
                .font(.callout)
                .foregroundStyle(BookPalette.nightText.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(BookPalette.nightPanel.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
        )
    }

    private var summaryLine: String {
        let clusterCount = clusters.count
        let namedCount = constellations.filter(\.isNamed).count
        let themeCount = themes.count
        if clusterCount + namedCount + themeCount == 0 {
            return "The Book needs a little more kept material before it can draw a trustworthy map."
        }
        return "I can currently see \(clusterCount) cluster\(clusterCount == 1 ? "" : "s"), \(namedCount) named constellation\(namedCount == 1 ? "" : "s"), and \(themeCount) remembered theme\(themeCount == 1 ? "" : "s")."
    }

    @ViewBuilder
    private var selectedSectionView: some View {
        switch selectedSection {
        case .clusters:
            if clusters.isEmpty {
                EmptyBookCard(title: "No clusters yet", message: "Keep a few more pages. The Book is looking for places where several motifs begin to share gravity.")
            } else {
                VStack(spacing: 12) {
                    ForEach(clusters) { cluster in
                        BookClusterCard(cluster: cluster, evidencePages: pages(for: cluster.evidencePageIDs), onOpenPage: onOpenPage)
                    }
                }
            }
        case .constellations:
            if constellations.isEmpty {
                EmptyBookCard(title: "No constellations yet", message: "A thread needs to return before it earns a place in the sky.")
            } else {
                VStack(spacing: 12) {
                    ForEach(constellations) { constellation in
                        BookConstellationCard(constellation: constellation, evidencePages: pages(for: constellation.evidencePageIDs), onOpenPage: onOpenPage)
                    }
                }
            }
        case .themes:
            if themes.isEmpty {
                EmptyBookCard(title: "No themes remembered yet", message: "A month needs enough pages before it can take a title in the margins.")
            } else {
                VStack(spacing: 12) {
                    ForEach(themes) { theme in
                        BookThemeConnectionCard(theme: theme, evidencePages: pages(for: theme.evidencePageIDs), onOpenPage: onOpenPage)
                    }
                }
            }
        }
    }

    private var evidenceShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evidence Pages")
                .sectionRuneLabel()
            if evidencePages.isEmpty {
                Text("When a connection points to kept pages, they will collect here.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.nightText.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(evidencePages.prefix(12)) { page in
                            Button {
                                BookFeedback.play(.openPage)
                                onOpenPage(page)
                            } label: {
                                BookEvidenceMiniCard(page: page)
                            }
                            .buttonStyle(.bookPress())
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
        }
        .padding(14)
        .background(BookPalette.nightPanel.opacity(0.30), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func pages(for ids: [String]) -> [BookPage] {
        ids.compactMap { pageByID[$0] }.sorted { $0.createdAt > $1.createdAt }
    }
}

private struct BookConnectionsMapView: View {
    let clusters: [BookMotifCluster]
    let constellations: [Constellation]
    let themes: [BookTheme]

    private var nodes: [ConnectionMapNode] {
        let clusterNodes = clusters.prefix(5).map {
            ConnectionMapNode(id: $0.id, strength: $0.strength, kind: .cluster)
        }
        let constellationNodes = constellations.filter(\.isAlive).prefix(6).map {
            ConnectionMapNode(id: $0.id, strength: $0.strengthPeak, kind: .constellation)
        }
        let themeNodes = themes.prefix(4).map {
            ConnectionMapNode(id: $0.id, strength: $0.strength, kind: .theme)
        }
        return Array(clusterNodes + constellationNodes + themeNodes)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let radius = max(58, min(size.width, size.height) * 0.34)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(BookPalette.nightPanel.opacity(0.44))
                ForEach(0..<4, id: \.self) { ring in
                    Circle()
                        .stroke(BookPalette.gold.opacity(0.08 + Double(ring) * 0.025), lineWidth: 1)
                        .frame(width: radius * CGFloat(ring + 2) * 0.62, height: radius * CGFloat(ring + 2) * 0.62)
                        .position(center)
                }
                if nodes.isEmpty {
                    Text("The map is still dark.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.62))
                } else {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                        let point = point(for: index, count: nodes.count, center: center, radius: radius, strength: node.strength)
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: point)
                        }
                        .stroke(node.color.opacity(0.28), lineWidth: 1)
                        Circle()
                            .fill(node.color.opacity(0.22))
                            .frame(width: node.diameter + 14, height: node.diameter + 14)
                            .position(point)
                        Circle()
                            .fill(node.color)
                            .frame(width: node.diameter, height: node.diameter)
                            .shadow(color: node.color.opacity(0.35), radius: 8, x: 0, y: 0)
                            .position(point)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.18), lineWidth: 1)
        )
    }

    private func point(for index: Int, count: Int, center: CGPoint, radius: CGFloat, strength: Int) -> CGPoint {
        let angle = (Double(index) / Double(max(1, count))) * Double.pi * 2 - Double.pi / 2
        let pull = CGFloat(0.72 + Double(min(96, max(40, strength)) - 40) / 180)
        return CGPoint(
            x: center.x + cos(angle) * radius * pull,
            y: center.y + sin(angle) * radius * pull
        )
    }
}

private struct ConnectionMapNode {
    enum Kind {
        case cluster
        case constellation
        case theme
    }

    var id: String
    var strength: Int
    var kind: Kind

    var color: Color {
        switch kind {
        case .cluster: return BookPalette.teal
        case .constellation: return BookPalette.lampGold
        case .theme: return BookPalette.violet
        }
    }

    var diameter: CGFloat {
        CGFloat(8 + min(18, max(4, strength / 5)))
    }
}

private struct BookClusterCard: View {
    let cluster: BookMotifCluster
    let evidencePages: [BookPage]
    var onOpenPage: (BookPage) -> Void

    var body: some View {
        BookConnectionCardShell(accent: BookPalette.teal) {
            VStack(alignment: .leading, spacing: 10) {
                connectionHeader(title: cluster.name, subtitle: "\(cluster.strength)% glow · \(cluster.motifs.count) motifs", symbol: "sparkles.rectangle.stack", accent: BookPalette.teal)
                Text(cluster.line)
                    .font(.callout)
                    .foregroundStyle(BookPalette.nightText.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                motifCloud(cluster.motifs, accent: BookPalette.teal)
                evidenceButtons(evidencePages, accent: BookPalette.teal, onOpenPage: onOpenPage)
            }
        }
    }
}

private struct BookConstellationCard: View {
    let constellation: Constellation
    let evidencePages: [BookPage]
    var onOpenPage: (BookPage) -> Void

    var body: some View {
        BookConnectionCardShell(accent: BookPalette.lampGold) {
            VStack(alignment: .leading, spacing: 10) {
                connectionHeader(
                    title: constellation.displayName,
                    subtitle: "\(constellation.phase.title) · \(constellation.sightingCount) sightings · peak \(constellation.strengthPeak)",
                    symbol: constellation.isNamed ? "star.fill" : "star",
                    accent: BookPalette.lampGold
                )
                Text(constellation.latestLine)
                    .font(.callout)
                    .foregroundStyle(BookPalette.nightText.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                if !constellation.tags.isEmpty {
                    motifCloud(Array(constellation.tags.prefix(8)), accent: BookPalette.lampGold)
                }
                evidenceButtons(evidencePages, accent: BookPalette.lampGold, onOpenPage: onOpenPage)
            }
        }
    }
}

private struct BookThemeConnectionCard: View {
    let theme: BookTheme
    let evidencePages: [BookPage]
    var onOpenPage: (BookPage) -> Void

    var body: some View {
        BookConnectionCardShell(accent: BookPalette.violet) {
            VStack(alignment: .leading, spacing: 10) {
                connectionHeader(title: theme.name, subtitle: "\(theme.monthKey) · \(theme.strength)% strength", symbol: "moon.stars", accent: BookPalette.violet)
                Text(theme.line)
                    .font(.callout)
                    .foregroundStyle(BookPalette.nightText.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                motifCloud(theme.motifs, accent: BookPalette.violet)
                if !theme.excerptLines.isEmpty {
                    Text(theme.excerptLines.prefix(2).joined(separator: "\n"))
                        .font(.caption)
                        .foregroundStyle(BookPalette.nightText.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                evidenceButtons(evidencePages, accent: BookPalette.violet, onOpenPage: onOpenPage)
            }
        }
    }
}

private struct BookConnectionCardShell<Content: View>: View {
    let accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.nightPanel.opacity(0.44), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            )
    }
}

private func connectionHeader(title: String, subtitle: String, symbol: String, accent: Color) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: symbol)
            .font(.headline.weight(.bold))
            .foregroundStyle(accent)
            .frame(width: 26, height: 26)
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.nightText)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent.opacity(0.82))
        }
        Spacer()
    }
}

private func motifCloud(_ motifs: [String], accent: Color) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
            ForEach(motifs.prefix(10), id: \.self) { motif in
                Text(motif)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent.opacity(0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.10), in: Capsule())
            }
        }
    }
}

private func evidenceButtons(_ pages: [BookPage], accent: Color, onOpenPage: @escaping (BookPage) -> Void) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        if !pages.isEmpty {
            Text("Evidence")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.54))
            ForEach(pages.prefix(3)) { page in
                Button {
                    BookFeedback.play(.openPage)
                    onOpenPage(page)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(accent)
                        Text(page.userInput.nonEmpty ?? page.promptText)
                            .font(.caption)
                            .foregroundStyle(BookPalette.nightText.opacity(0.76))
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(8)
                    .background(BookPalette.ink.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.bookPress())
            }
        }
    }
}

private struct BookEvidenceMiniCard: View {
    let page: BookPage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(page.type.shortTitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal)
            Text(page.userInput.nonEmpty ?? page.promptText)
                .font(.caption)
                .foregroundStyle(BookPalette.nightText.opacity(0.82))
                .lineLimit(4)
                .frame(width: 156, alignment: .leading)
        }
        .padding(10)
        .frame(width: 180, alignment: .topLeading)
        .frame(minHeight: 104, alignment: .topLeading)
        .background(BookPalette.nightPanel.opacity(0.46), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct OrganicPlacementVariation {
    let xOffset: Double
    let yOffset: Double
    let rotationDegrees: Double
    let opacityLift: Double
    let distress: Double

    init(seed: Int, key: String, maxOffset: Double = 6, maxRotation: Double = 3) {
        xOffset = Self.signed(seed: seed, key: "\(key)-x", range: maxOffset)
        yOffset = Self.signed(seed: seed, key: "\(key)-y", range: maxOffset)
        rotationDegrees = Self.signed(seed: seed, key: "\(key)-r", range: maxRotation)
        opacityLift = Self.unit(seed: seed, key: "\(key)-o")
        distress = Self.unit(seed: seed, key: "\(key)-d")
    }

    private static func signed(seed: Int, key: String, range: Double) -> Double {
        (unit(seed: seed, key: key) * 2 - 1) * range
    }

    private static func unit(seed: Int, key: String) -> Double {
        var hash = UInt64(bitPattern: Int64(seed)) ^ 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 10_000) / 10_000
    }
}

@MainActor
enum IlluminatedPageRenderer {
    static func renderPreview(draft: IlluminatedPhotoDraft, sourceImage: UIImage?) -> URL? {
        AppMemoryLedger.record("illumination-render-enter")
        let plan = draft.compositionPlan
        let content = IlluminatedArtifactPreview(draft: draft, sourceImage: sourceImage)
            .frame(width: plan.canvasSize.width, height: plan.canvasSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        guard let image = renderer.uiImage,
              let data = image.jpegData(compressionQuality: 0.9) else {
            return nil
        }

        do {
            let directory = try renderedDirectory()
            let filename = "illuminated-\(draft.id.uuidString).jpg"
            let url = directory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            AppMemoryLedger.record("illumination-render-exit")
            return url
        } catch {
            appLog.error("Illuminated render failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func renderedDirectory() throws -> URL {
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("IlluminatedPages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

struct IlluminatedQuoteCard: View {
    let quote: String
    let sourceTitle: String
    let weatherLine: String
    let dateLine: String
    let style: PageVisualStyle
    let seed: Int

    /// The card is rendered at this fixed size; the content column is inset from
    /// the edges so the quote always wraps inside the gilded border instead of
    /// drifting past it.
    static let renderSize = CGSize(width: 1080, height: 1350)
    static let horizontalInset: CGFloat = 88
    static var contentWidth: CGFloat { renderSize.width - horizontalInset * 2 }

    /// A fully deterministic, per-card layout derived from the seed — palette,
    /// vertical balance, border, label ornament, divider, fonts, stains, and
    /// marginalia all vary, so no two souvenir cards look alike while the same
    /// card always re-renders identically.
    private var composition: QuoteCardComposition {
        QuoteCardComposition(seed: seed, baseFontSize: quoteFontSize)
    }

    private var quoteFontSize: CGFloat {
        let count = quote.count
        if count > 260 { return 42 }
        if count > 180 { return 48 }
        if count > 110 { return 56 }
        return 64
    }

    var body: some View {
        let c = composition
        ZStack {
            LinearGradient(
                colors: [c.ink.paperTop, c.ink.paperMid, c.ink.paperBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("ParchmentTexture")
                .resizable()
                .scaledToFill()
                .frame(width: Self.renderSize.width, height: Self.renderSize.height)
                .clipped()
                .opacity(0.26)
                .blendMode(.multiply)

            Image("ParchmentFiber")
                .resizable()
                .scaledToFill()
                .frame(width: Self.renderSize.width, height: Self.renderSize.height)
                .clipped()
                .opacity(c.fiberOpacity)
                .blendMode(.overlay)

            stainsLayer(c)
            marginaliaLayer(c)

            contentColumn(c)
                .frame(width: Self.contentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: c.verticalOffset)
                .rotationEffect(.degrees(c.contentRotation))
        }
        .frame(width: Self.renderSize.width, height: Self.renderSize.height)
        .overlay { borderLayer(c) }
        .clipShape(RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous))
        .background(BookPalette.paper)
    }

    @ViewBuilder
    private func contentColumn(_ c: QuoteCardComposition) -> some View {
        VStack(spacing: 30) {
            HStack(spacing: 12) {
                Image(systemName: c.labelSymbol)
                Text(sourceTitle.uppercased())
                Image(systemName: c.labelSymbol)
            }
            .font(.system(size: 20, weight: .bold, design: .serif))
            .foregroundStyle(c.ink.accent.opacity(0.86))
            .tracking(1.8)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: Self.contentWidth)

            // A hard width frame (not maxWidth) forces the quote to wrap at the
            // content width regardless of the size ImageRenderer proposes;
            // maxWidth + minimumScaleFactor let the text lay out against an
            // unbounded width and clip past the gilded border.
            Text("“\(quote)”")
                .font(.system(size: c.quoteFontSize, weight: c.quoteWeight, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .tracking(c.quoteTracking)
                .lineLimit(nil)
                .frame(width: Self.contentWidth)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ZStack {
                    Rectangle()
                        .fill(c.ink.accent.opacity(0.45))
                        .frame(width: c.dividerWidth, height: 1.6)
                    if c.dividerMedallion {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(c.ink.accent.opacity(0.72))
                            .padding(.horizontal, 7)
                            .background(c.ink.paperMid)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: c.weatherSymbol)
                    Text(weatherLine)
                }
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: Self.contentWidth)

                Text(dateLine)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(c.ink.accent.opacity(0.86))
                    .tracking(1.2)

                Text("ReEnchanted")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
            }
        }
    }

    private func stainsLayer(_ c: QuoteCardComposition) -> some View {
        ZStack {
            ForEach(c.stains) { stain in
                Circle()
                    .fill(c.ink.accent.opacity(stain.opacity))
                    .frame(width: stain.size.width, height: stain.size.height)
                    .blur(radius: 16)
                    .position(stain.center)
            }
        }
    }

    private func marginaliaLayer(_ c: QuoteCardComposition) -> some View {
        ZStack {
            marginaliaImage(c.watermark)
            ForEach(c.edgeMarginalia) { mark in
                marginaliaImage(mark)
            }
        }
    }

    private func marginaliaImage(_ mark: QuoteCardComposition.MarginaliaPlacement) -> some View {
        Image(mark.asset)
            .resizable()
            .scaledToFit()
            .frame(width: mark.width)
            .opacity(mark.opacity)
            .rotationEffect(.degrees(mark.rotation))
            .position(mark.center)
    }

    @ViewBuilder
    private func borderLayer(_ c: QuoteCardComposition) -> some View {
        switch c.border {
        case .doubleGild:
            ZStack {
                RoundedRectangle(cornerRadius: max(8, c.cornerRadius - 6), style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [c.ink.gild.opacity(0.92), c.ink.accent.opacity(0.5), c.ink.gild.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 14
                    )
                    .padding(c.borderInset)
                RoundedRectangle(cornerRadius: max(6, c.cornerRadius - 14), style: .continuous)
                    .stroke(BookPalette.parchmentEdge.opacity(0.35), lineWidth: 2)
                    .padding(c.borderInset + 22)
            }
        case .singleHairline:
            RoundedRectangle(cornerRadius: max(6, c.cornerRadius - 8), style: .continuous)
                .stroke(c.ink.accent.opacity(0.6), lineWidth: 3)
                .padding(c.borderInset + 8)
        case .ribbon:
            ZStack {
                RoundedRectangle(cornerRadius: max(8, c.cornerRadius - 6), style: .continuous)
                    .stroke(c.ink.accent.opacity(0.55), lineWidth: 12)
                    .padding(c.borderInset)
                RoundedRectangle(cornerRadius: max(8, c.cornerRadius - 6), style: .continuous)
                    .stroke(c.ink.gild.opacity(0.85), lineWidth: 2)
                    .padding(c.borderInset)
            }
        case .brackets:
            ZStack {
                RoundedRectangle(cornerRadius: max(4, c.cornerRadius - 10), style: .continuous)
                    .stroke(c.ink.accent.opacity(0.25), lineWidth: 1.5)
                    .padding(c.borderInset + 6)
                QuoteCardCornerBrackets(inset: c.borderInset, arm: 120)
                    .stroke(c.ink.gild.opacity(0.9), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
    }
}

/// Four illuminated corner L-brackets, one of the quote card's border treatments.
private struct QuoteCardCornerBrackets: Shape {
    var inset: CGFloat
    var arm: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + arm))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + arm, y: r.minY))

        p.move(to: CGPoint(x: r.maxX - arm, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + arm))

        p.move(to: CGPoint(x: r.maxX, y: r.maxY - arm))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - arm, y: r.maxY))

        p.move(to: CGPoint(x: r.minX + arm, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - arm))
        return p
    }
}

/// Deterministic, seed-driven layout plan for one souvenir card — the quote-card
/// analogue of the illuminated-photo composition engine. Every visual knob is
/// derived from the seed so the same card always re-renders identically while
/// different cards each get their own palette, balance, and ornament.
private struct QuoteCardComposition {
    struct Ink {
        let accent: Color
        let gild: Color
        let paperTop: Color
        let paperMid: Color
        let paperBottom: Color
    }

    struct MarginaliaPlacement: Identifiable {
        let id: Int
        let asset: String
        let center: CGPoint
        let width: CGFloat
        let rotation: Double
        let opacity: Double
    }

    struct StainSpec: Identifiable {
        let id: Int
        let center: CGPoint
        let size: CGSize
        let opacity: Double
    }

    enum Border {
        case doubleGild
        case singleHairline
        case ribbon
        case brackets
    }

    let ink: Ink
    let verticalOffset: CGFloat
    let contentRotation: Double
    let labelSymbol: String
    let weatherSymbol: String
    let quoteWeight: Font.Weight
    let quoteTracking: CGFloat
    let quoteFontSize: CGFloat
    let dividerWidth: CGFloat
    let dividerMedallion: Bool
    let border: Border
    let cornerRadius: CGFloat
    let borderInset: CGFloat
    let fiberOpacity: Double
    let stains: [StainSpec]
    let watermark: MarginaliaPlacement
    let edgeMarginalia: [MarginaliaPlacement]

    private static let inks: [Ink] = [
        Ink(accent: Color(red: 0.45, green: 0.13, blue: 0.18), gild: Color(red: 0.86, green: 0.62, blue: 0.34),
            paperTop: Color(red: 0.96, green: 0.90, blue: 0.78), paperMid: Color(red: 0.89, green: 0.79, blue: 0.64), paperBottom: Color(red: 0.74, green: 0.58, blue: 0.42)),
        Ink(accent: Color(red: 0.08, green: 0.42, blue: 0.45), gild: BookPalette.lampGold,
            paperTop: Color(red: 0.94, green: 0.92, blue: 0.82), paperMid: Color(red: 0.83, green: 0.82, blue: 0.69), paperBottom: Color(red: 0.62, green: 0.64, blue: 0.55)),
        Ink(accent: Color(red: 0.20, green: 0.22, blue: 0.46), gild: Color(red: 0.90, green: 0.74, blue: 0.44),
            paperTop: Color(red: 0.93, green: 0.91, blue: 0.83), paperMid: Color(red: 0.82, green: 0.80, blue: 0.72), paperBottom: Color(red: 0.60, green: 0.59, blue: 0.58)),
        Ink(accent: Color(red: 0.16, green: 0.34, blue: 0.22), gild: Color(red: 0.85, green: 0.69, blue: 0.38),
            paperTop: Color(red: 0.94, green: 0.92, blue: 0.80), paperMid: Color(red: 0.83, green: 0.81, blue: 0.66), paperBottom: Color(red: 0.61, green: 0.62, blue: 0.50)),
        Ink(accent: Color(red: 0.36, green: 0.19, blue: 0.30), gild: Color(red: 0.88, green: 0.70, blue: 0.46),
            paperTop: Color(red: 0.95, green: 0.90, blue: 0.82), paperMid: Color(red: 0.86, green: 0.78, blue: 0.70), paperBottom: Color(red: 0.68, green: 0.58, blue: 0.56)),
        Ink(accent: Color(red: 0.55, green: 0.34, blue: 0.10), gild: BookPalette.lampGold,
            paperTop: Color(red: 0.96, green: 0.91, blue: 0.77), paperMid: Color(red: 0.88, green: 0.79, blue: 0.61), paperBottom: Color(red: 0.72, green: 0.59, blue: 0.39)),
        Ink(accent: Color(red: 0.20, green: 0.33, blue: 0.44), gild: Color(red: 0.87, green: 0.72, blue: 0.45),
            paperTop: Color(red: 0.93, green: 0.92, blue: 0.84), paperMid: Color(red: 0.81, green: 0.81, blue: 0.72), paperBottom: Color(red: 0.59, green: 0.62, blue: 0.58)),
        Ink(accent: Color(red: 0.60, green: 0.28, blue: 0.13), gild: Color(red: 0.90, green: 0.71, blue: 0.42),
            paperTop: Color(red: 0.96, green: 0.90, blue: 0.76), paperMid: Color(red: 0.89, green: 0.77, blue: 0.60), paperBottom: Color(red: 0.74, green: 0.56, blue: 0.40))
    ]

    private static let labelSymbols = [
        "sparkles", "sparkle", "star.fill", "seal.fill", "leaf.fill", "sun.max.fill", "moon.stars.fill", "laurel.leading"
    ]

    private static let weatherSymbols = [
        "cloud.sun.fill", "sun.max.fill", "cloud.fill", "cloud.moon.fill", "sparkles"
    ]

    private static let marginaliaPool: [String] = {
        let assets = CoreMarginsPack.pack.doodles + CoreMarginsPack.pack.stamps
        let names = Set(assets.map(\.assetName))
        return names.isEmpty ? ["MarginaliaFeather", "MarginaliaStar", "MarginaliaCompass"] : names.sorted()
    }()

    private static let weights: [Font.Weight] = [.medium, .semibold, .bold]

    init(seed: Int, baseFontSize: CGFloat) {
        func u(_ key: String) -> Double { Self.unit(seed: seed, key: key) }
        func d(_ lo: Double, _ hi: Double, _ key: String) -> CGFloat { CGFloat(lo + (hi - lo) * u(key)) }
        func index(_ count: Int, _ key: String) -> Int { min(count - 1, Int(u(key) * Double(count))) }

        let canvas = IlluminatedQuoteCard.renderSize

        ink = Self.inks[index(Self.inks.count, "ink")]
        verticalOffset = d(-80, 80, "voff")
        contentRotation = Double(d(-1.4, 1.4, "crot"))
        labelSymbol = Self.labelSymbols[index(Self.labelSymbols.count, "label")]
        weatherSymbol = Self.weatherSymbols[index(Self.weatherSymbols.count, "weather")]
        quoteWeight = Self.weights[index(Self.weights.count, "weight")]
        quoteTracking = d(0, 1.1, "track")
        quoteFontSize = baseFontSize * d(0.95, 1.06, "fscale")
        dividerWidth = d(180, 320, "divw")
        dividerMedallion = u("divm") > 0.5
        border = [Border.doubleGild, .singleHairline, .ribbon, .brackets][index(4, "border")]
        cornerRadius = d(14, 46, "corner")
        borderInset = d(26, 40, "binset")
        fiberOpacity = Double(d(0.12, 0.22, "fiber"))

        let stainCount = 3 + Int(u("stainN") * 4) // 3...6
        stains = (0..<stainCount).map { i in
            StainSpec(
                id: i,
                center: CGPoint(x: d(90, canvas.width - 90, "sx\(i)"), y: d(120, canvas.height - 120, "sy\(i)")),
                size: CGSize(width: d(150, 280, "sw\(i)"), height: d(120, 240, "sh\(i)")),
                opacity: Double(d(0.04, 0.075, "so\(i)"))
            )
        }

        let pool = Self.marginaliaPool
        watermark = MarginaliaPlacement(
            id: -1,
            asset: pool[index(pool.count, "wm")],
            center: CGPoint(x: d(420, 660, "wmx"), y: d(260, 460, "wmy")),
            width: d(360, 460, "wmw"),
            rotation: Double(d(-12, 12, "wmr")),
            opacity: Double(d(0.08, 0.14, "wmo"))
        )

        // Marginalia live in the margin zones so they frame the text without
        // ever sitting on top of it.
        let zones: [CGPoint] = [
            CGPoint(x: 0.15, y: 0.13), CGPoint(x: 0.85, y: 0.14),
            CGPoint(x: 0.11, y: 0.49), CGPoint(x: 0.89, y: 0.51),
            CGPoint(x: 0.17, y: 0.87), CGPoint(x: 0.83, y: 0.86)
        ]
        let zoneOrder = Array(0..<zones.count).sorted { u("zone\($0)") < u("zone\($1)") }
        let edgeCount = 3 + Int(u("edgeN") * 2) // 3...4
        edgeMarginalia = (0..<min(edgeCount, zones.count)).map { i in
            let zone = zones[zoneOrder[i]]
            let asset = pool[(index(pool.count, "ea\(i)") + i * 7) % pool.count]
            return MarginaliaPlacement(
                id: i,
                asset: asset,
                center: CGPoint(
                    x: zone.x * canvas.width + d(-18, 18, "ejx\(i)"),
                    y: zone.y * canvas.height + d(-22, 22, "ejy\(i)")
                ),
                width: d(95, 165, "ew\(i)"),
                rotation: Double(d(-18, 18, "er\(i)")),
                opacity: Double(d(0.18, 0.34, "eo\(i)"))
            )
        }
    }

    /// FNV-1a over the seed + a per-knob key, mapped to a stable 0...1 value —
    /// matching the hashing used by the photo engine's placement variation.
    private static func unit(seed: Int, key: String) -> Double {
        var hash = UInt64(bitPattern: Int64(seed)) ^ 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 10_000) / 10_000
    }
}

@MainActor
enum IlluminatedQuoteCardRenderer {
    static func render(
        quote: String,
        sourceTitle: String,
        weatherLine: String,
        dateLine: String,
        style: PageVisualStyle,
        seed: Int
    ) -> URL? {
        let content = IlluminatedQuoteCard(
            quote: quote,
            sourceTitle: sourceTitle,
            weatherLine: weatherLine,
            dateLine: dateLine,
            style: style,
            seed: seed
        )
        .frame(width: IlluminatedQuoteCard.renderSize.width, height: IlluminatedQuoteCard.renderSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            return nil
        }

        do {
            let directory = try renderedDirectory()
            let filename = "illuminated-quote-\(seed.magnitude)-\(quote.stableHash.magnitude).png"
            let url = directory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            appLog.error("Illuminated quote render failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func renderedDirectory() throws -> URL {
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("IlluminatedQuoteCards", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

struct SurfaceCard: View {
    let surface: SurfacePage
    let isBusy: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasSurfaced = false
    @State private var idle = false

    private var visualStyle: PageVisualStyle {
        if surface.type == .festival {
            return PageVisualStyle.festivalStyle(accent: surface.payload.metadata["accent"] ?? "")
        }
        return PageVisualStyle.style(for: surface.type)
    }

    private var privacyNote: String? {
        guard let value = surface.payload.metadata["privacy"], !value.isEmpty else {
            return nil
        }
        return value.capitalized
    }

    private var symbolName: String {
        surface.payload.metadata["symbol"] ?? surface.type.symbolName
    }

    private var illustrationAssetName: String? {
        guard surface.type == .illustration else { return nil }
        let value = surface.payload.metadata["assetName"] ?? ""
        return value.isEmpty ? nil : value
    }

    private var illuminatedDraft: IlluminatedPhotoDraft? {
        guard surface.type == .illuminatedPhoto,
              let sourceAssetName = surface.payload.metadata["sourceAssetName"] else {
            return nil
        }
        let fallback = FakePhotoIlluminationAnalyzer.analyze(assetName: sourceAssetName)
        let analysis = PhotoAnalysis.fromSurfaceMetadata(surface.payload.metadata, fallback: fallback)
        let seed = abs(surface.id.stableHash)
        return IlluminatedPageComposer.compose(
            analysis: analysis,
            sourceAssetName: sourceAssetName,
            seed: seed,
            assetLocalIdentifier: surface.payload.metadata["assetLocalIdentifier"]
        )
    }

    private var marginaliaName: String {
        visualStyle.cornerMarginalia
    }

    private var sideMarginaliaName: String {
        visualStyle.sideMarginalia
    }

    private var isReadingCard: Bool {
        surface.type == .wonderCompass
            || surface.type == .patreon
            || surface.type == .illustration
            || surface.type == .illuminatedPhoto
            || surface.type == .quip
            || surface.type == .narrativeOS
            || surface.type == .marginsAtlas
            || surface.type == .bookConnections
            || surface.type == .bookRemembered
            || surface.type == .bookNotices
            || surface.type == .theBleed
            || surface.type == .radio
            || surface.type == .facultyResearch
            || surface.type == .supportGuild
            || surface.renderStyle == .quoteCard
    }

    private var previewText: String? {
        guard isReadingCard else { return nil }
        let body = surface.payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        if surface.type == .wonderCompass || surface.type == .narrativeOS || surface.type == .marginsAtlas || surface.type == .bookConnections || surface.type == .bookRemembered || surface.type == .bookNotices || surface.type == .theBleed || surface.type == .radio || surface.type == .gossip || surface.type == .facultyResearch || surface.type == .supportGuild || surface.payload.metadata["illustrationKind"] == "cast" {
            return body.bookPreviewSentenceLimit(2)
        }
        return body
    }

    private var surfaceLabel: String {
        surface.payload.metadata["surfaceLabel"]?.nonEmpty ?? surface.type.shortTitle
    }

    /// True when the shelf card is a Shadow Wonder variant of an ordinary page
    /// type — surfaced once the Dusk Thorn is invested in and the world turns
    /// toward the worn edge. Mirrors the open-page badge in CapturePageSheet.
    private var isShadowWonderVariant: Bool {
        surface.payload.metadata["variant"] == "shadow-wonder"
    }

    /// A compact goblin-core chip so a Shadow Wonder card reads as distinct on the
    /// shelf, not just once opened.
    private var shadowWonderChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 9, weight: .bold))
            Text("SHADOW WONDER")
                .font(.system(size: 9, weight: .black))
                .tracking(0.8)
        }
        .foregroundStyle(BookPalette.violet)
        .padding(.vertical, 3)
        .padding(.horizontal, 7)
        .background(BookPalette.violet.opacity(0.13), in: Capsule())
        .overlay { Capsule().stroke(BookPalette.violet.opacity(0.30), lineWidth: 1) }
        .accessibilityLabel("Shadow Wonder variant")
    }

    private var previewLineLimit: Int {
        switch surface.type {
        case .wonderCompass:
            return 3
        case .narrativeOS, .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .theBleed, .radio:
            return 4
        case .gossip:
            return 4
        case .facultyResearch:
            return 4
        case .supportGuild:
            return 4
        case .illustration, .illuminatedPhoto:
            return 4
        default:
            return 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(visualStyle.symbolColor)
                    .frame(width: 28, alignment: .leading)

                Text(surfaceLabel.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(visualStyle.accent.opacity(0.82))
                    .padding(.top, 3)

                if isShadowWonderVariant {
                    shadowWonderChip
                }

                Spacer()
            }
            .padding(.trailing, 38)

            Text(surface.prompt)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 26)

            Text(surface.detail)
                .font(.footnote)
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            if let illustrationAssetName {
                Image(illustrationAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }

            if let illuminatedDraft {
                illuminatedCardPreview(draft: illuminatedDraft)
            }

            if let previewText {
                Text(previewText)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                    .lineSpacing(3)
                    .lineLimit(previewLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            Text(surface.reason)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.6))
                .lineLimit(isReadingCard ? 1 : 2)
                .fixedSize(horizontal: false, vertical: true)

            if let privacyNote {
                Label(privacyNote, systemImage: "lock.shield")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(visualStyle.accent.opacity(0.86))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack {
                Text(isBusy ? "Taking ink..." : "Open the page")
                    .font(.caption.weight(.bold))
                Spacer()
                Image(systemName: isBusy ? "circle.dotted" : "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .offset(
                        x: (reduceMotion || isBusy || !idle) ? 0 : 3,
                        y: (reduceMotion || isBusy || !idle) ? 0 : -3
                    )
            }
            .foregroundStyle(visualStyle.accent)
        }
        .textSelection(.enabled)
        .padding(16)
        .frame(minHeight: isReadingCard ? 330 : 212, alignment: .topLeading)
        .parchmentSurface(style: visualStyle, isActive: true)
        // A soft "breathing" accent edge so the live card reads as awake. Kept
        // strictly inside the card's bounds (a contained inset stroke, not a
        // drop shadow) so it can never bloom into a grey halo behind the stack.
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(visualStyle.accent.opacity(reduceMotion ? 0 : (idle ? 0.34 : 0.0)), lineWidth: 1.5)
                .padding(1.5)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            PageCurl()
                .fill(visualStyle.accent.opacity(0.16))
                .frame(width: 34, height: 34)
                .opacity(0.72)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            CardScrapMark(seed: surface.id, style: visualStyle)
                .offset(x: 10, y: 8)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            MarginaliaImage(name: sideMarginaliaName, width: visualStyle.sideMarginaliaWidth, opacity: visualStyle.sideMarginaliaOpacity)
                .rotationEffect(.degrees(surface.id.stableHash.isMultiple(of: 2) ? -9 : 8))
                .offset(x: -10, y: isReadingCard ? 74 : 34)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            MarginaliaImage(name: marginaliaName, width: isReadingCard ? visualStyle.cornerMarginaliaWidth + 12 : visualStyle.cornerMarginaliaWidth, opacity: visualStyle.cornerMarginaliaOpacity)
                .rotationEffect(.degrees(surface.id.stableHash.isMultiple(of: 2) ? 7 : -8))
                .offset(x: 12, y: 10)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            MarginaliaImage(name: visualStyle.smallMarginalia, width: 38, opacity: 0.30)
                .rotationEffect(.degrees(surface.id.stableHash.isMultiple(of: 3) ? 12 : -10))
                .offset(x: 14, y: -8)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .center) {
            MarginaliaImage(name: visualStyle.watermarkMarginalia, width: isReadingCard ? 150 : 118, opacity: visualStyle.watermarkOpacity)
                .rotationEffect(.degrees(surface.id.stableHash.isMultiple(of: 2) ? -13 : 11))
                .offset(x: isReadingCard ? 108 : 92, y: isReadingCard ? -34 : -16)
                .allowsHitTesting(false)
        }
        .rotationEffect(.degrees(surface.id.stableHash.isMultiple(of: 2) ? -0.6 : 0.5))
        .opacity(hasSurfaced ? 1 : 0)
        .offset(y: hasSurfaced ? 0 : (reduceMotion ? 0 : -18))
        .onAppear {
            guard !hasSurfaced else { return }
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.72, dampingFraction: 0.84)) {
                hasSurfaced = true
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                idle = true
            }
        }
    }

    @ViewBuilder
    private func illuminatedCardPreview(draft: IlluminatedPhotoDraft) -> some View {
        if let renderedPath = surface.payload.metadata["renderedPreviewPath"],
           let image = UIImage(contentsOfFile: renderedPath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }
                .accessibilityLabel("Proposed illuminated photo page")
                .imagePreviewOnTap { surface.payload.metadata["renderedPreviewPath"].flatMap { ImagePreview.url(forFilePath: $0) } }
        } else {
            IlluminatedArtifactPreview(draft: draft)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }
                .accessibilityLabel("Proposed illuminated photo page")
        }
    }
}

struct SwipeDismissSurfaceCard: View {
    let surface: SurfacePage
    let isBusy: Bool
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var isTucking = false

    private let dismissThreshold: CGFloat = 96
    private let horizontalDragRatio: CGFloat = 1.6

    /// Deep oxblood wax, so the reveal reads as the Book's margin rather than
    /// a system delete action.
    private let waxDeep = Color(red: 0.24, green: 0.06, blue: 0.08)
    private let waxRed = Color(red: 0.42, green: 0.13, blue: 0.13)

    /// How far into the dismissal the drag has travelled, 0…1.
    private var dragProgress: CGFloat {
        min(1, abs(min(0, dragOffset)) / dismissThreshold)
    }

    /// A page peeling toward the gutter tips a little; the tuck deepens the tip.
    private var tiltDegrees: Double {
        guard !reduceMotion else { return 0 }
        let base = Double(dragProgress) * 3.0
        return isTucking ? base + 6 : base
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            marginReveal

            Button {
                onOpen()
            } label: {
                SurfaceCard(surface: surface, isBusy: isBusy)
            }
            .buttonStyle(.bookPress())
            .scaleEffect(reduceMotion ? 1 : (isTucking ? 0.9 : 1 - dragProgress * 0.03), anchor: .bottomLeading)
            .rotationEffect(.degrees(-tiltDegrees), anchor: .bottomLeading)
            .offset(x: dragOffset)
            .overlay(alignment: .topTrailing) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(BookPalette.ink.opacity(0.42))
                        .padding(12)
                }
                .buttonStyle(.bookPress())
                .accessibilityLabel("Let \(surface.payload.metadata["surfaceLabel"]?.nonEmpty ?? surface.type.title) pass for now")
            }
            .overlay(alignment: .trailing) {
                SwipeDismissHandle()
                    .padding(.trailing, 2)
                    .gesture(
                        DragGesture(minimumDistance: 26)
                            .onChanged(handleDragChanged)
                            .onEnded(handleDragEnded)
                    )
            }
        }
        .accessibilityHint("Tap to open. Use the small right-edge tab or close button to let this page pass.")
    }

    /// The oxblood margin that the page slips into — with a wax seal that
    /// firms up as the drag crosses the dismiss threshold.
    private var marginReveal: some View {
        let sealed = dragProgress > 0.75 || isTucking
        return HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: sealed ? "seal.fill" : "seal")
                    .font(.title3.weight(.bold))
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragProgress) * -12))
                Text("Let it pass")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(BookPalette.page.opacity(0.9))
            .scaleEffect(reduceMotion ? 1 : 0.84 + dragProgress * 0.2)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            .padding(.trailing, 26)
        }
        .frame(maxWidth: .infinity, minHeight: 176)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [waxDeep, waxRed],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22 + dragProgress * 0.3), lineWidth: 1)
        }
        .opacity(reduceMotion ? 1 : 0.3 + dragProgress * 0.7)
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        guard isDeliberateHorizontalDismiss(value) else {
            dragOffset = 0
            return
        }
        dragOffset = min(0, value.translation.width)
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        guard isDeliberateHorizontalDismiss(value) else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                dragOffset = 0
            }
            return
        }

        let shouldDismiss = value.translation.width < -dismissThreshold || value.predictedEndTranslation.width < -dismissThreshold * 1.4
        if shouldDismiss {
            BookFeedback.play(.dismissPage)
            withAnimation(.easeIn(duration: 0.26)) {
                dragOffset = -520
                isTucking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                onDismiss()
                dragOffset = 0
                isTucking = false
            }
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                dragOffset = 0
            }
        }
    }

    private func isDeliberateHorizontalDismiss(_ value: DragGesture.Value) -> Bool {
        let horizontal = abs(value.translation.width)
        let vertical = abs(value.translation.height)
        return value.translation.width < 0 && horizontal > vertical * horizontalDragRatio
    }
}

private struct SwipeDismissHandle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hinting = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.caption2.weight(.black))
            Image(systemName: "xmark")
                .font(.caption2.weight(.black))
        }
        .foregroundStyle(BookPalette.ink.opacity(reduceMotion ? 0.32 : (hinting ? 0.5 : 0.28)))
        .frame(width: 34, height: 82)
        .background(
            Capsule(style: .continuous)
                .fill(BookPalette.paper.opacity(0.18))
        )
        .offset(x: (reduceMotion || !hinting) ? 0 : -3)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                hinting = true
            }
        }
    }
}

struct PageSourceCard: View {
    let source: BookPageSource
    let isEnabled: Bool

    private var visualStyle: PageVisualStyle {
        PageVisualStyle.style(for: source.type)
    }

    private var isOpen: Bool {
        source.isActive && isEnabled
    }

    private var borderColor: Color {
        isOpen ? visualStyle.accent.opacity(0.36) : BookPalette.ink.opacity(0.12)
    }

    private var statusText: String {
        if !source.isActive {
            return "not yet"
        }
        return isEnabled ? "awake" : "quiet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: source.symbolName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isOpen ? visualStyle.symbolColor : BookPalette.ink.opacity(0.46))
                    .frame(width: 30, height: 30)
                    .background(
                        (isOpen ? visualStyle.accent : BookPalette.ink)
                            .opacity(0.10),
                        in: Circle()
                    )

                Spacer(minLength: 8)

                Text(statusText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isOpen ? visualStyle.accent : BookPalette.ink.opacity(0.46))
            }

            Text(source.shortTitle)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(BookPalette.ink.opacity(source.isActive ? 1 : 0.62))
                .lineLimit(1)

            Text(source.note)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(source.cadence)
                Spacer(minLength: 8)
                Image(systemName: source.privacy == .localSensitive ? "lock.shield" : "lock")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(BookPalette.ink.opacity(0.50))
        }
        .padding(14)
        .frame(width: 158, height: 168, alignment: .topLeading)
        .parchmentSurface(style: visualStyle, isActive: isOpen)
        .overlay(alignment: .bottomTrailing) {
            MarginaliaImage(name: visualStyle.smallMarginalia, width: 38, opacity: isOpen ? 0.28 : 0.14)
                .rotationEffect(.degrees(8))
                .offset(x: 8, y: 8)
                .allowsHitTesting(false)
        }
    }
}

struct BraidingTableSheet: View {
    let fragmentCount: Int
    let braidCount: Int
    let onBraidNew: () -> Void
    let onReBraidLast: () -> Void
    let onOpenLatest: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var canBraid: Bool { fragmentCount > 0 }

    private var statusLine: String {
        let fragments = "\(fragmentCount) fragment\(fragmentCount == 1 ? "" : "s") today"
        let braids = braidCount == 0
            ? "no braid kept yet"
            : "\(braidCount) braid\(braidCount == 1 ? "" : "s") kept"
        return "\(fragments) · \(braids)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(statusLine)
                            .font(.system(.subheadline, design: .serif).weight(.semibold))
                            .foregroundStyle(BookPalette.ink.opacity(0.7))

                        if !canBraid {
                            Text("The Book needs one true fragment kept today before it can braid.")
                                .font(.system(.footnote, design: .serif))
                                .foregroundStyle(BookPalette.ink.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if braidCount == 0 {
                            actionCard(
                                title: "Braid today",
                                subtitle: "Draw today's fragments into one page worth keeping.",
                                systemImage: "link",
                                enabled: canBraid
                            ) { dismiss(); onBraidNew() }
                        } else {
                            actionCard(
                                title: "Re-braid the last",
                                subtitle: "Unravel the most recent braid and weave today's fragments again.",
                                systemImage: "arrow.triangle.2.circlepath",
                                enabled: canBraid
                            ) { dismiss(); onReBraidLast() }

                            actionCard(
                                title: "Braid a new one too",
                                subtitle: "Keep the last braid and weave another beside it.",
                                systemImage: "plus.rectangle.on.rectangle",
                                enabled: canBraid
                            ) { dismiss(); onBraidNew() }

                            actionCard(
                                title: "Open today's braid",
                                subtitle: "Read the most recent Book of You page.",
                                systemImage: "book",
                                enabled: true
                            ) { dismiss(); onOpenLatest() }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("The Braiding Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        BookFeedback.play(.tap)
                        dismiss()
                    }
                }
            }
        }
    }

    private func actionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            BookFeedback.play(.openPage)
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BookPalette.gold)
                    .frame(width: 36, height: 36)
                    .background(BookPalette.lampGold.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(BookPalette.ink)
                    Text(subtitle)
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.page.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BookPalette.parchmentEdge.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

struct SourceSettingsSheet: View {
    let sources: [BookPageSource]
    let onSet: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var preferences: [String: Bool]

    init(
        sources: [BookPageSource],
        preferences: [String: Bool],
        onSet: @escaping (String, Bool) -> Void
    ) {
        self.sources = sources
        self.onSet = onSet
        _preferences = State(initialValue: preferences)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sources) { source in
                            SourceToggleRow(
                                source: source,
                                isEnabled: preferences[source.id] ?? source.isActive,
                                isEditable: source.isActive
                            ) { isEnabled in
                                BookFeedback.play(isEnabled ? .undo : .dismissPage)
                                preferences[source.id] = isEnabled
                                onSet(source.id, isEnabled)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Doorways")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close")
                    {
                        BookFeedback.play(.tap)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SourceToggleRow: View {
    let source: BookPageSource
    let isEnabled: Bool
    let isEditable: Bool
    let onChange: (Bool) -> Void

    private var statusText: String {
        if !source.isActive {
            return "not yet"
        }
        return isEnabled ? "awake" : "quiet"
    }

    private var visualStyle: PageVisualStyle {
        PageVisualStyle.style(for: source.type)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: source.symbolName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isEnabled && source.isActive ? visualStyle.symbolColor : BookPalette.ink.opacity(0.46))
                .frame(width: 34, height: 34)
                .background(
                    (isEnabled && source.isActive ? visualStyle.accent : BookPalette.ink).opacity(0.10),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(source.title)
                        .font(.headline)
                        .foregroundStyle(BookPalette.ink)
                    Text(statusText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isEnabled && source.isActive ? visualStyle.accent : BookPalette.ink.opacity(0.48))
                }

                Text(source.note)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Toggle(
                "",
                isOn: Binding(
                    get: { isEnabled },
                    set: { onChange($0) }
                )
            )
            .labelsHidden()
            .disabled(!isEditable)
            .tint(visualStyle.accent)
        }
        .padding(14)
        .parchmentSurface(style: visualStyle, isActive: isEnabled && source.isActive)
    }
}

struct FragmentRow: View {
    let page: BookPage
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var dragOffset: CGFloat = 0

    private let dismissThreshold: CGFloat = 82
    private let horizontalDragRatio: CGFloat = 1.6

    private var visualStyle: PageVisualStyle {
        PageVisualStyle.style(for: page.type)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()
                Label("Remove", systemImage: "xmark.circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.54))
                    .padding(.trailing, 18)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(
                BookPalette.paper.opacity(0.42),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(visualStyle.accent.opacity(0.18), lineWidth: 1)
            }

            HStack(alignment: .top, spacing: 12) {
                if let mediaAsset = page.mediaAssets.first {
                    BookOfYouMediaThumbnail(asset: mediaAsset, width: 56, height: 48)
                } else {
                    Image(systemName: page.type.symbolName)
                        .foregroundStyle(visualStyle.symbolColor)
                        .frame(width: 28, height: 28)
                        .background(visualStyle.accent.opacity(0.12), in: Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(page.type.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(fragmentText)
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .lineLimit(3)
                }
                .padding(.trailing, 30)

                Spacer(minLength: 0)
            }
            .padding(14)
            .parchmentSurface(style: visualStyle, isActive: false)
            .offset(x: dragOffset)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                onOpen()
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(BookPalette.ink.opacity(0.42))
                        .padding(10)
                }
                .buttonStyle(.bookPress())
                .accessibilityLabel("Remove \(page.type.title) from Today's Margins")
            }
            .overlay(alignment: .trailing) {
                SwipeDismissHandle()
                    .padding(.trailing, 2)
                    .gesture(
                        DragGesture(minimumDistance: 26)
                            .onChanged(handleDragChanged)
                            .onEnded(handleDragEnded)
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                MarginaliaImage(name: visualStyle.cornerMarginalia, width: 46, opacity: 0.20)
                    .offset(x: 8, y: 8)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens this kept page. Use the close button or small right-edge tab to remove it.")
    }

    private var fragmentText: String {
        let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? page.promptText : text
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        guard isDeliberateHorizontalDismiss(value) else {
            dragOffset = 0
            return
        }
        dragOffset = min(0, value.translation.width)
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        guard isDeliberateHorizontalDismiss(value) else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                dragOffset = 0
            }
            return
        }

        let shouldDismiss = value.translation.width < -dismissThreshold || value.predictedEndTranslation.width < -dismissThreshold * 1.4
        if shouldDismiss {
            withAnimation(.easeInOut(duration: 0.2)) {
                dragOffset = -500
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onRemove()
                dragOffset = 0
            }
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                dragOffset = 0
            }
        }
    }

    private func isDeliberateHorizontalDismiss(_ value: DragGesture.Value) -> Bool {
        let horizontal = abs(value.translation.width)
        let vertical = abs(value.translation.height)
        return value.translation.width < 0 && horizontal > vertical * horizontalDragRatio
    }
}

struct ResurfacedPageRow: View {
    let page: BookPage
    let onOpen: () -> Void

    private var visualStyle: PageVisualStyle {
        PageVisualStyle.style(for: page.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(page.type.title, systemImage: "sparkle.magnifyingglass")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(visualStyle.accent)

                Spacer(minLength: 8)

                Text(page.createdAt, style: .date)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.48))
            }

            Text(page.userInput)
                .font(.system(.callout, design: .serif, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(BookPalette.ink.opacity(0.78))
                .lineLimit(4)

            Text("The Book brought this back because old wonder sometimes knows the way.")
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.56))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .parchmentSurface(style: visualStyle, isActive: false)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            onOpen()
        }
        .overlay(alignment: .topTrailing) {
            MarginaliaImage(name: visualStyle.sideMarginalia, width: 62, opacity: 0.24)
                .rotationEffect(.degrees(4))
                .offset(x: 12, y: -10)
                .allowsHitTesting(false)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens this returned page.")
    }
}

private struct CardScrapMark: View {
    let seed: String
    var style: PageVisualStyle = .default

    private var angle: Angle {
        .degrees(seed.stableHash.isMultiple(of: 2) ? -4 : 5)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.scrapColor.opacity(0.50))
                .frame(width: style.scrapWidth, height: style.scrapHeight)
                .overlay {
                    Image("ParchmentFiber")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.34)
                        .blendMode(.multiply)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(style.accent.opacity(0.24), lineWidth: 1)
                }
                .rotationEffect(angle)

            Rectangle()
                .fill(style.accent.opacity(0.23))
                .frame(width: 36, height: 9)
                .rotationEffect(.degrees(seed.stableHash.isMultiple(of: 3) ? 12 : -10))
                .offset(x: 34, y: -4)
                .blendMode(.multiply)

            Rectangle()
                .fill(BookPalette.ink.opacity(0.26))
                .frame(width: style.scrapWidth * 0.42, height: 1)
                .offset(x: 10, y: 10)

            Rectangle()
                .fill(BookPalette.ink.opacity(0.20))
                .frame(width: style.scrapWidth * 0.62, height: 1)
                .offset(x: 10, y: 18)
        }
        .opacity(0.94)
    }
}

struct BookOfYouCard: View {
    let page: BookPage
    let onOpen: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inkVisible = false

    private let visualStyle = PageVisualStyle.style(for: .bookOfYou)
    private var details: BraidPageDetails { BraidPageDetails.details(for: page) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Book of You", systemImage: "book.closed")
                .font(.caption.weight(.bold))
                .foregroundStyle(visualStyle.accent)

            Text(details.title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !page.mediaAssets.isEmpty {
                BookOfYouMediaStrip(assets: page.mediaAssets)
            }

            Text(details.body)
                .font(.system(.body, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(inkVisible ? 1 : 0.16)
                .blur(radius: inkVisible ? 0 : 2.5)
                .shadow(color: BookPalette.lampGold.opacity(inkVisible ? 0.12 : 0.36), radius: inkVisible ? 2 : 10)
        }
        .padding(18)
        .parchmentSurface(style: visualStyle, isActive: true)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            onOpen()
        }
        .overlay(alignment: .topTrailing) {
            Text("kept")
                .font(.caption2.weight(.bold))
                .foregroundStyle(visualStyle.accent)
                .padding(12)
        }
        .overlay(alignment: .leading) {
            MarginaliaImage(name: visualStyle.sideMarginalia, width: 72, opacity: 0.34)
                .rotationEffect(.degrees(-9))
                .offset(x: -14, y: 26)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            MarginaliaImage(name: visualStyle.cornerMarginalia, width: 76, opacity: 0.28)
                .rotationEffect(.degrees(-8))
                .offset(x: 12, y: 12)
                .allowsHitTesting(false)
        }
        .onAppear {
            inkVisible = false
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 1.45).delay(0.16)) {
                inkVisible = true
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens today's Book of You page.")
    }
}

private struct BookOfYouMediaStrip: View {
    let assets: [BookPageMediaAsset]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(assets.prefix(6)) { asset in
                    BookOfYouMediaThumbnail(asset: asset)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct BookOfYouMediaThumbnail: View {
    let asset: BookPageMediaAsset
    var width: CGFloat = 104
    var height: CGFloat = 82

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    BookPalette.page.opacity(0.72)
                    Image(systemName: "photo")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.42))
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
        .accessibilityLabel(accessibilityLabel)
        .imagePreviewOnTap { previewURL }
    }

    private var previewURL: URL? {
        switch asset.kind {
        case .bundledImage: return ImagePreview.url(forAsset: asset.reference)
        case .renderedImageFile: return ImagePreview.url(forFilePath: asset.reference)
        case .photoLibraryAsset, .audioFile: return nil
        }
    }

    private var image: Image? {
        switch asset.kind {
        case .bundledImage:
            return Image(asset.reference)
        case .renderedImageFile:
            #if canImport(UIKit)
            if let uiImage = UIImage(contentsOfFile: asset.reference) {
                return Image(uiImage: uiImage)
            }
            #endif
            return nil
        case .photoLibraryAsset, .audioFile:
            return nil
        }
    }

    private var accessibilityLabel: String {
        let caption = asset.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return caption.isEmpty ? "Kept visual fragment" : caption
    }
}

struct ArchiveCard: View {
    let page: BookPage
    let onOpen: () -> Void
    private var details: BraidPageDetails { BraidPageDetails.details(for: page) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(page.createdAt, style: .date)
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)
            Text(details.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .lineLimit(2)
            Text(details.body)
                .font(.footnote)
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .lineLimit(5)
        }
        .padding(14)
        .frame(width: 240, height: 170, alignment: .topLeading)
        .parchmentSurface(accent: BookPalette.gold, isActive: false)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            onOpen()
        }
        .overlay(alignment: .bottomTrailing) {
            MarginaliaImage(name: "MarginaliaShell", width: 42, opacity: 0.16)
                .offset(x: 6, y: 8)
                .allowsHitTesting(false)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens this Book of You page.")
    }
}

struct EmptyBookCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
            Text(message)
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.66))
        }
        .foregroundStyle(BookPalette.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentSurface(accent: BookPalette.gold.opacity(0.7), isActive: false)
    }
}

struct MarginaliaImage: View {
    let name: String
    let width: CGFloat
    var opacity: Double = 0.28

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .opacity(opacity)
            .saturation(0.95)
            .shadow(color: .black.opacity(0.16), radius: 3, x: 0, y: 2)
    }
}

struct LivingMarginaliaImage: View {
    let name: String
    let width: CGFloat
    var opacity: Double = 0.28
    var glow = false
    var isPaused = false
    /// Degrees of gentle side-to-side sway riding the breath cycle.
    var sway: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breath = false

    private var isAnimating: Bool {
        !reduceMotion && !isPaused
    }

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .opacity(opacity)
            .scaleEffect(breath && isAnimating ? 1.025 : 0.995)
            .rotationEffect(.degrees(breath && isAnimating ? sway : -sway))
            .shadow(color: BookPalette.lampGold.opacity(glow ? (breath && isAnimating ? 0.45 : 0.22) : 0.12), radius: glow ? (breath && isAnimating ? 16 : 8) : 3)
            .onAppear {
                guard isAnimating else { return }
                withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                    breath = true
                }
            }
            .onChange(of: isPaused) { _, paused in
                if paused {
                    breath = false
                } else if !reduceMotion {
                    withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                        breath = true
                    }
                }
            }
    }
}

/// A whisper of Ken Burns: endless slow scale-and-drift breathing for
/// `scaledToFill` imagery. The minimum scale keeps a few points of overflow
/// in reserve so the image never pulls away from its clip edges.
struct AmbientKenBurnsModifier: ViewModifier {
    var minScale: CGFloat = 1.03
    var maxScale: CGFloat = 1.06
    var drift: CGSize = CGSize(width: 4, height: 2)
    var period: Double = 18
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    private var isAnimating: Bool {
        !reduceMotion && !isPaused
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? (phase ? maxScale : minScale) : 1.0)
            .offset(
                x: isAnimating ? (phase ? drift.width : -drift.width) : 0,
                y: isAnimating ? (phase ? drift.height : -drift.height) : 0
            )
            .onAppear {
                guard isAnimating else { return }
                withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
            .onChange(of: isPaused) { _, paused in
                if paused {
                    phase = false
                } else if !reduceMotion {
                    withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) {
                        phase = true
                    }
                }
            }
    }
}

/// Slow opacity breathing for small "the Book is alive" accents.
struct AmbientPulseModifier: ViewModifier {
    var dimmed: Double = 0.55
    var bright: Double = 1.0
    var period: Double = 3.4
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    private var isAnimating: Bool {
        !reduceMotion && !isPaused
    }

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? (lit ? bright : dimmed) : bright)
            .onAppear {
                guard isAnimating else { return }
                withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) {
                    lit = true
                }
            }
            .onChange(of: isPaused) { _, paused in
                if paused {
                    lit = false
                } else if !reduceMotion {
                    withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) {
                        lit = true
                    }
                }
            }
    }
}

extension View {
    func ambientKenBurns(
        minScale: CGFloat = 1.03,
        maxScale: CGFloat = 1.06,
        drift: CGSize = CGSize(width: 4, height: 2),
        period: Double = 18,
        isPaused: Bool = false
    ) -> some View {
        modifier(AmbientKenBurnsModifier(minScale: minScale, maxScale: maxScale, drift: drift, period: period, isPaused: isPaused))
    }

    func ambientPulse(dimmed: Double = 0.55, bright: Double = 1.0, period: Double = 3.4, isPaused: Bool = false) -> some View {
        modifier(AmbientPulseModifier(dimmed: dimmed, bright: bright, period: period, isPaused: isPaused))
    }
}

private func openingProgress(_ value: Double, from start: Double, to end: Double) -> Double {
    guard end > start else { return value >= end ? 1 : 0 }
    return smoothstep(min(max((value - start) / (end - start), 0), 1))
}

private func smoothstep(_ value: Double) -> Double {
    value * value * (3 - 2 * value)
}

/// Accumulates animation time from clamped per-frame deltas instead of wall
/// clock, so a main-thread stall (launch work, first-frame layout) pauses the
/// opening movie instead of making it skip ahead.
private final class StallTolerantClock {
    private var lastTick: Date?
    private(set) var elapsed: TimeInterval = 0

    func tick(_ now: Date, maxDelta: TimeInterval) -> TimeInterval {
        defer { lastTick = now }
        guard let lastTick else { return elapsed }
        let delta = now.timeIntervalSince(lastTick)
        guard delta > 0 else { return elapsed }
        elapsed += min(delta, maxDelta)
        return elapsed
    }
}

struct OpeningMovieView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = StallTolerantClock()
    @State private var didFinish = false

    private var duration: TimeInterval {
        reduceMotion ? 2.2 : 6.2
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 12 : 1 / 24)) { timeline in
            let elapsed = clock.tick(timeline.date, maxDelta: 1 / 8)
            let progress = min(max(elapsed / duration, 0), 1)

            GeometryReader { proxy in
                let size = proxy.size
                let fairy = fairyPosition(progress: progress, size: size)
                let wipe = openingProgress(progress, from: 0.82, to: 1.0)

                ZStack {
                    BookBackground()
                        .overlay {
                            Rectangle()
                                .fill(BookPalette.nightPanel.opacity(0.34))
                        }

                    VStack(spacing: 18) {
                        Spacer(minLength: size.height * 0.20)

                        WrittenGoldText(
                            "Real Life...",
                            font: .system(size: min(size.width * 0.12, 48), weight: .medium, design: .serif),
                            progress: openingProgress(progress, from: 0.08, to: reduceMotion ? 0.18 : 0.34)
                        )
                        .frame(maxWidth: .infinity, alignment: .center)

                        WrittenGoldText(
                            "ReEnchanted",
                            font: .system(size: min(size.width * 0.132, 54), weight: .semibold, design: .serif),
                            progress: openingProgress(progress, from: reduceMotion ? 0.20 : 0.32, to: reduceMotion ? 0.42 : 0.60)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: max(1, size.width - 54), alignment: .center)
                        .shadow(color: BookPalette.lampGold.opacity(0.22), radius: 18, x: 0, y: 6)

                        WrittenGoldText(
                            "By The Doobaleedoos",
                            font: .system(size: min(size.width * 0.060, 24), weight: .semibold, design: .serif),
                            progress: openingProgress(progress, from: reduceMotion ? 0.42 : 0.58, to: reduceMotion ? 0.58 : 0.74)
                        )
                        .kerning(1.2)
                        .textCase(.uppercase)

                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, max(28, proxy.safeAreaInsets.bottom + 20))
                    .opacity(1 - wipe * 0.75)

                    FairyScribe()
                        .frame(width: 38, height: 38)
                        .position(fairy)
                        .opacity(progress < 0.95 ? 1 : 1 - openingProgress(progress, from: 0.95, to: 1.0))
                        .accessibilityHidden(true)

                    SparkleTrail(progress: progress, fairyPosition: fairy)
                        .allowsHitTesting(false)

                    PageTurnWipe(progress: wipe)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    finish()
                }
                .onChange(of: progress) { _, newValue in
                    guard newValue >= 1 else { return }
                    finish()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            BookFeedback.play(.openPage)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Opening animation. Real Life, ReEnchanted. By The Doobaleedoos.")
        .accessibilityAddTraits(.isButton)
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        BookFeedback.play(.braidComplete)
        onFinished()
    }

    private func fairyPosition(progress: Double, size: CGSize) -> CGPoint {
        let settled = CGPoint(x: size.width * 0.74, y: size.height * 0.38)
        if reduceMotion {
            return settled
        }

        let points = [
            CGPoint(x: size.width * 0.18, y: size.height * 0.30),
            CGPoint(x: size.width * 0.76, y: size.height * 0.30),
            CGPoint(x: size.width * 0.18, y: size.height * 0.43),
            CGPoint(x: size.width * 0.80, y: size.height * 0.43),
            CGPoint(x: size.width * 0.30, y: size.height * 0.51),
            CGPoint(x: size.width * 0.70, y: size.height * 0.51),
            settled
        ]

        let routeProgress = openingProgress(progress, from: 0.04, to: 0.80)
        let scaled = routeProgress * Double(points.count - 1)
        let index = min(Int(scaled), points.count - 2)
        let local = scaled - Double(index)
        let eased = smoothstep(local)
        let start = points[index]
        let end = points[index + 1]
        let bob = CGFloat(sin(progress * .pi * 18) * 4)

        return CGPoint(
            x: start.x + (end.x - start.x) * eased,
            y: start.y + (end.y - start.y) * eased + bob
        )
    }
}

struct WrittenGoldText: View {
    let text: String
    let font: Font
    let progress: Double

    init(_ text: String, font: Font, progress: Double) {
        self.text = text
        self.font = font
        self.progress = progress
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: [BookPalette.nightText, BookPalette.lampGold, BookPalette.gold],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: BookPalette.lampGold.opacity(0.30), radius: 10, x: 0, y: 4)
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .frame(width: max(1, proxy.size.width * progress))
                }
            }
            .overlay(alignment: .trailing) {
                if progress > 0 && progress < 1 {
                    Circle()
                        .fill(BookPalette.lampGold.opacity(0.46))
                        .frame(width: 9, height: 9)
                        .blur(radius: 3)
                        .offset(x: 8)
                }
            }
    }
}

struct FairyScribe: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            wing(rotation: -28)
                .offset(x: -16, y: -4)
            wing(rotation: 28)
                .offset(x: 16, y: -4)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white,
                            BookPalette.lampGold,
                            BookPalette.gold.opacity(0.82),
                            BookPalette.lampGold.opacity(0.30),
                            .clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 24
                    )
                )
                .frame(width: 34, height: 34)
                .shadow(color: BookPalette.lampGold.opacity(pulse ? 0.82 : 0.42), radius: pulse ? 24 : 12)

            Circle()
                .fill(.white.opacity(0.88))
                .frame(width: 7, height: 7)
                .blur(radius: 1)
        }
        .scaleEffect(pulse && !reduceMotion ? 1.08 : 0.96)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.82).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func wing(rotation: Double) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        BookPalette.nightText.opacity(0.84),
                        BookPalette.lampGold.opacity(0.54),
                        BookPalette.gold.opacity(0.26)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 11, height: 25)
            .rotationEffect(.degrees(rotation))
            .shadow(color: BookPalette.lampGold.opacity(0.45), radius: 8)
    }
}

struct SparkleTrail: View {
    let progress: Double
    let fairyPosition: CGPoint

    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                let age = Double(index) / 24
                let opacity = max(0, 0.68 - age * 0.58) * (1 - openingProgress(progress, from: 0.82, to: 0.98))
                let angle = Double(index) * 1.37 + progress * 10
                let radius = CGFloat(6 + index * 2)

                Image(systemName: index % 3 == 0 ? "sparkle" : "plus")
                    .font(.system(size: index % 3 == 0 ? 9 : 5, weight: .bold))
                    .foregroundStyle((index % 4 == 0 ? BookPalette.nightText : BookPalette.lampGold).opacity(opacity))
                    .position(
                        x: fairyPosition.x - CGFloat(cos(angle)) * radius - CGFloat(index),
                        y: fairyPosition.y - CGFloat(sin(angle)) * radius + CGFloat(index) * 0.7
                    )
            }
        }
    }
}

struct PageTurnWipe: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let height = max(1, proxy.size.height)
            let x = width * (1.12 - progress * 1.42)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(BookPalette.page.opacity(progress))
                    .frame(width: width * 1.4, height: height * 1.2)
                    .offset(x: x)
                    .shadow(color: .black.opacity(0.30 * progress), radius: 24, x: -16, y: 0)

                Path { path in
                    path.move(to: CGPoint(x: x, y: -20))
                    path.addCurve(
                        to: CGPoint(x: x + width * 0.10, y: height + 20),
                        control1: CGPoint(x: x + width * 0.16, y: height * 0.22),
                        control2: CGPoint(x: x - width * 0.08, y: height * 0.74)
                    )
                    path.addLine(to: CGPoint(x: x + width * 0.20, y: height + 20))
                    path.addLine(to: CGPoint(x: x + width * 0.20, y: -20))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            BookPalette.nightText.opacity(0.35 * progress),
                            BookPalette.parchmentEdge.opacity(0.72 * progress),
                            .black.opacity(0.16 * progress)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 0.6)
            }
        }
        .opacity(progress)
    }
}

struct BookBackground: View {
    var isQuiet = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var driftsAmbiently: Bool {
        !reduceMotion && !isQuiet
    }

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.025, green: 0.027, blue: 0.060),
                Color(red: 0.060, green: 0.055, blue: 0.105),
                Color(red: 0.115, green: 0.074, blue: 0.088)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            LinearGradient(
                colors: [.clear, BookPalette.nightPanel.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay {
            // A plain `Date()` here only advances when something else
            // re-renders the view, which froze the drift in practice —
            // the TimelineView keeps it actually moving while unquiet.
            if driftsAmbiently {
                TimelineView(.animation(minimumInterval: 1 / 12)) { timeline in
                    driftingBackdrop(at: timeline.date)
                }
            } else {
                driftingBackdrop(at: Date(timeIntervalSinceReferenceDate: 0))
            }
        }
        .overlay {
            AmbientLetterField(isPaused: isQuiet)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            MarginaliaImage(name: "MarginaliaLavender", width: 130, opacity: 0.11)
                .rotationEffect(.degrees(-8))
                .offset(x: -20, y: 32)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            MarginaliaImage(name: "MarginaliaStar", width: 150, opacity: 0.08)
                .rotationEffect(.degrees(11))
                .offset(x: 36, y: 24)
                .allowsHitTesting(false)
        }
        .overlay {
            Rectangle()
                .fill(.black.opacity(0.18))
                .blendMode(.multiply)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func driftingBackdrop(at date: Date) -> some View {
        ZStack {
            LabyrinthBackdrop()
                .stroke(BookPalette.lampGold.opacity(0.10), lineWidth: 1)
                .frame(width: 380, height: 380)
                .offset(x: 120 + ambientDrift(date, scale: 8), y: -260 + ambientDrift(date, scale: 5, phase: 1.8))
                .blendMode(.plusLighter)

            StarSpeckle()
                .fill(BookPalette.lampGold.opacity(0.14 + ambientOpacity(date) * 0.05))
                .offset(x: ambientDrift(date, scale: 5, phase: 0.8), y: ambientDrift(date, scale: 7, phase: 2.2))
                .blendMode(.plusLighter)
        }
    }

    private func ambientDrift(_ date: Date, scale: Double, phase: Double = 0) -> CGFloat {
        guard !reduceMotion, !isQuiet else { return 0 }
        return CGFloat(sin(date.timeIntervalSinceReferenceDate / 18 + phase) * scale)
    }

    private func ambientOpacity(_ date: Date) -> Double {
        guard !reduceMotion, !isQuiet else { return 0.2 }
        return (sin(date.timeIntervalSinceReferenceDate / 12) + 1) / 2
    }
}

enum BookPalette {
    static let ink = Color(red: 0.18, green: 0.14, blue: 0.10)
    static let page = Color(red: 0.97, green: 0.91, blue: 0.78)
    static let paper = Color(red: 0.91, green: 0.82, blue: 0.64)
    static let teal = Color(red: 0.08, green: 0.42, blue: 0.45)
    static let gold = Color(red: 0.72, green: 0.43, blue: 0.16)
    static let lampGold = Color(red: 0.95, green: 0.73, blue: 0.43)
    static let nightText = Color(red: 0.94, green: 0.86, blue: 0.72)
    static let nightPanel = Color(red: 0.055, green: 0.063, blue: 0.120)
    static let parchmentEdge = Color(red: 0.50, green: 0.31, blue: 0.14)
    static let violet = Color(red: 0.36, green: 0.19, blue: 0.30)
}

struct PageVisualStyle {
    var accent: Color
    var symbolColor: Color
    var paperTop: Color
    var paperMiddle: Color
    var paperBottom: Color
    var scrapColor: Color
    var sideMarginalia: String
    var cornerMarginalia: String
    var smallMarginalia: String
    var watermarkMarginalia: String
    var sideMarginaliaWidth: CGFloat = 56
    var cornerMarginaliaWidth: CGFloat = 70
    var sideMarginaliaOpacity: Double = 0.38
    var cornerMarginaliaOpacity: Double = 0.34
    var watermarkOpacity: Double = 0.10
    var fiberOpacity: Double = 0.24
    var grainOpacity: Double = 0.09
    var scrapWidth: CGFloat = 74
    var scrapHeight: CGFloat = 30
    var moonwriteGlow: Bool = false

    static let `default` = PageVisualStyle(
        accent: BookPalette.gold,
        symbolColor: BookPalette.gold,
        paperTop: BookPalette.page,
        paperMiddle: BookPalette.paper,
        paperBottom: Color(red: 0.80, green: 0.64, blue: 0.42),
        scrapColor: BookPalette.paper,
        sideMarginalia: "IlluminationScrapS01_15",
        cornerMarginalia: "IlluminationScrapS02_05",
        smallMarginalia: "IlluminationScrapS03_10",
        watermarkMarginalia: "IlluminationScrapS02_13"
    )

    static func style(for type: BookPageType) -> PageVisualStyle {
        switch type {
        case .inventory, .bindery:
            return PageVisualStyle(
                accent: Color(red: 0.18, green: 0.43, blue: 0.40),
                symbolColor: Color(red: 0.18, green: 0.43, blue: 0.40),
                paperTop: Color(red: 0.93, green: 0.88, blue: 0.73),
                paperMiddle: Color(red: 0.82, green: 0.74, blue: 0.59),
                paperBottom: Color(red: 0.57, green: 0.49, blue: 0.39),
                scrapColor: Color(red: 0.86, green: 0.79, blue: 0.65),
                sideMarginalia: "IlluminationScrapS02_19",
                cornerMarginalia: "IlluminationScrapS03_11",
                smallMarginalia: "MarginaliaStamp",
                watermarkMarginalia: "MarginaliaCompass",
                watermarkOpacity: 0.09
            )
        case .calendar:
            return PageVisualStyle(
                accent: Color(red: 0.30, green: 0.34, blue: 0.58),
                symbolColor: Color(red: 0.30, green: 0.34, blue: 0.58),
                paperTop: Color(red: 0.94, green: 0.92, blue: 0.82),
                paperMiddle: Color(red: 0.84, green: 0.82, blue: 0.72),
                paperBottom: Color(red: 0.66, green: 0.65, blue: 0.58),
                scrapColor: Color(red: 0.86, green: 0.85, blue: 0.76),
                sideMarginalia: "IlluminationScrapS02_08",
                cornerMarginalia: "IlluminationScrapS03_24",
                smallMarginalia: "MarginaliaStamp",
                watermarkMarginalia: "MarginaliaCompass",
                watermarkOpacity: 0.10
            )
        case .packPage, .wordNegotiation:
            return PageVisualStyle(
                accent: Color(red: 0.33, green: 0.36, blue: 0.52),
                symbolColor: Color(red: 0.33, green: 0.36, blue: 0.52),
                paperTop: Color(red: 0.94, green: 0.91, blue: 0.81),
                paperMiddle: Color(red: 0.84, green: 0.80, blue: 0.71),
                paperBottom: Color(red: 0.66, green: 0.62, blue: 0.56),
                scrapColor: Color(red: 0.87, green: 0.84, blue: 0.76),
                sideMarginalia: "IlluminationScrapS03_11",
                cornerMarginalia: "IlluminationScrapS02_19",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaStar",
                watermarkOpacity: 0.10
            )
        case .gamePage:
            return PageVisualStyle(
                accent: Color(red: 0.14, green: 0.42, blue: 0.43),
                symbolColor: Color(red: 0.14, green: 0.42, blue: 0.43),
                paperTop: Color(red: 0.93, green: 0.91, blue: 0.78),
                paperMiddle: Color(red: 0.82, green: 0.80, blue: 0.67),
                paperBottom: Color(red: 0.61, green: 0.58, blue: 0.49),
                scrapColor: Color(red: 0.87, green: 0.84, blue: 0.70),
                sideMarginalia: "MarginaliaCompass",
                cornerMarginalia: "IlluminationScrapS03_24",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaCompass",
                watermarkOpacity: 0.11
            )
        case .glowInvitation:
            return PageVisualStyle(
                accent: BookPalette.lampGold,
                symbolColor: BookPalette.lampGold,
                paperTop: Color(red: 0.98, green: 0.92, blue: 0.73),
                paperMiddle: Color(red: 0.88, green: 0.78, blue: 0.58),
                paperBottom: Color(red: 0.66, green: 0.54, blue: 0.40),
                scrapColor: Color(red: 0.94, green: 0.83, blue: 0.62),
                sideMarginalia: "MarginaliaStar",
                cornerMarginalia: "MarginaliaCompass",
                smallMarginalia: "MarginaliaStamp",
                watermarkMarginalia: "MarginaliaStar",
                sideMarginaliaWidth: 70,
                cornerMarginaliaWidth: 84,
                sideMarginaliaOpacity: 0.42,
                cornerMarginaliaOpacity: 0.34,
                watermarkOpacity: 0.12,
                scrapWidth: 92,
                scrapHeight: 34
            )
        case .helpTips:
            return PageVisualStyle(
                accent: Color(red: 0.20, green: 0.43, blue: 0.50),
                symbolColor: Color(red: 0.20, green: 0.43, blue: 0.50),
                paperTop: Color(red: 0.95, green: 0.91, blue: 0.78),
                paperMiddle: Color(red: 0.84, green: 0.80, blue: 0.66),
                paperBottom: Color(red: 0.66, green: 0.62, blue: 0.52),
                scrapColor: Color(red: 0.86, green: 0.83, blue: 0.70),
                sideMarginalia: "IlluminationScrapS01_08",
                cornerMarginalia: "IlluminationScrapS03_10",
                smallMarginalia: "MarginaliaCompass",
                watermarkMarginalia: "MarginaliaStamp",
                sideMarginaliaWidth: 62,
                cornerMarginaliaWidth: 78,
                sideMarginaliaOpacity: 0.38,
                cornerMarginaliaOpacity: 0.34,
                watermarkOpacity: 0.10,
                scrapWidth: 88,
                scrapHeight: 32
            )
        case .welcome:
            return PageVisualStyle(
                accent: Color(red: 0.40, green: 0.32, blue: 0.58),
                symbolColor: Color(red: 0.40, green: 0.32, blue: 0.58),
                paperTop: Color(red: 0.96, green: 0.91, blue: 0.76),
                paperMiddle: Color(red: 0.86, green: 0.78, blue: 0.64),
                paperBottom: Color(red: 0.66, green: 0.56, blue: 0.50),
                scrapColor: Color(red: 0.90, green: 0.82, blue: 0.68),
                sideMarginalia: "MarginaliaCompass",
                cornerMarginalia: "MarginaliaSeal",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 70,
                cornerMarginaliaWidth: 84,
                sideMarginaliaOpacity: 0.40,
                cornerMarginaliaOpacity: 0.36,
                watermarkOpacity: 0.13,
                scrapWidth: 94,
                scrapHeight: 34
            )
        case .radio:
            return PageVisualStyle(
                accent: Color(red: 0.17, green: 0.38, blue: 0.44),
                symbolColor: Color(red: 0.17, green: 0.38, blue: 0.44),
                paperTop: Color(red: 0.94, green: 0.89, blue: 0.73),
                paperMiddle: Color(red: 0.82, green: 0.76, blue: 0.62),
                paperBottom: Color(red: 0.56, green: 0.54, blue: 0.48),
                scrapColor: Color(red: 0.87, green: 0.80, blue: 0.63),
                sideMarginalia: "MarginaliaCompass",
                cornerMarginalia: "MarginaliaStar",
                smallMarginalia: "MarginaliaStamp",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 72,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.38,
                cornerMarginaliaOpacity: 0.34,
                watermarkOpacity: 0.12,
                scrapWidth: 92,
                scrapHeight: 34
            )
        case .bookJump:
            return PageVisualStyle(
                accent: Color(red: 0.28, green: 0.22, blue: 0.48),
                symbolColor: Color(red: 0.28, green: 0.22, blue: 0.48),
                paperTop: Color(red: 0.95, green: 0.89, blue: 0.76),
                paperMiddle: Color(red: 0.84, green: 0.76, blue: 0.64),
                paperBottom: Color(red: 0.60, green: 0.52, blue: 0.52),
                scrapColor: Color(red: 0.90, green: 0.80, blue: 0.66),
                sideMarginalia: "MarginaliaCompass",
                cornerMarginalia: "MarginaliaSeal",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 72,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.42,
                cornerMarginaliaOpacity: 0.36,
                watermarkOpacity: 0.12,
                scrapWidth: 92,
                scrapHeight: 34
            )
        case .bookFae:
            return PageVisualStyle(
                accent: Color(red: 0.22, green: 0.42, blue: 0.32),
                symbolColor: Color(red: 0.22, green: 0.42, blue: 0.32),
                paperTop: Color(red: 0.94, green: 0.90, blue: 0.72),
                paperMiddle: Color(red: 0.82, green: 0.78, blue: 0.60),
                paperBottom: Color(red: 0.54, green: 0.55, blue: 0.40),
                scrapColor: Color(red: 0.86, green: 0.80, blue: 0.62),
                sideMarginalia: "MarginaliaFeather",
                cornerMarginalia: "MarginaliaSeal",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "IlluminationScrapS02_13",
                sideMarginaliaWidth: 74,
                cornerMarginaliaWidth: 84,
                sideMarginaliaOpacity: 0.44,
                cornerMarginaliaOpacity: 0.36,
                watermarkOpacity: 0.12,
                scrapWidth: 90,
                scrapHeight: 34
            )
        case .elective:
            // Folded-note warmth: wine accent, feather marginalia, the feel
            // of a favor tucked into the binding.
            return PageVisualStyle(
                accent: Color(red: 0.52, green: 0.26, blue: 0.30),
                symbolColor: Color(red: 0.52, green: 0.26, blue: 0.30),
                paperTop: Color(red: 0.97, green: 0.91, blue: 0.78),
                paperMiddle: Color(red: 0.89, green: 0.79, blue: 0.64),
                paperBottom: Color(red: 0.72, green: 0.58, blue: 0.46),
                scrapColor: Color(red: 0.94, green: 0.84, blue: 0.68),
                sideMarginalia: "MarginaliaFeather",
                cornerMarginalia: "IlluminationScrapS03_12",
                smallMarginalia: "MarginaliaStamp",
                watermarkMarginalia: "MarginaliaSeal",
                watermarkOpacity: 0.12
            )
        case .academyClass:
            // Chalk-and-lamplight: slate-toned paper, gold accents, compass
            // watermark — the feel of a lesson under way.
            return PageVisualStyle(
                accent: Color(red: 0.27, green: 0.40, blue: 0.46),
                symbolColor: Color(red: 0.27, green: 0.40, blue: 0.46),
                paperTop: Color(red: 0.93, green: 0.90, blue: 0.79),
                paperMiddle: Color(red: 0.82, green: 0.80, blue: 0.70),
                paperBottom: Color(red: 0.62, green: 0.63, blue: 0.57),
                scrapColor: Color(red: 0.83, green: 0.84, blue: 0.74),
                sideMarginalia: "IlluminationScrapS02_08",
                cornerMarginalia: "IlluminationScrapS01_14",
                smallMarginalia: "IlluminationScrapS03_10",
                watermarkMarginalia: "MarginaliaCompass",
                watermarkOpacity: 0.11
            )
        case .mood:
            return PageVisualStyle(
                accent: Color(red: 0.36, green: 0.39, blue: 0.70),
                symbolColor: Color(red: 0.36, green: 0.39, blue: 0.70),
                paperTop: Color(red: 0.93, green: 0.90, blue: 0.77),
                paperMiddle: Color(red: 0.78, green: 0.80, blue: 0.68),
                paperBottom: Color(red: 0.65, green: 0.66, blue: 0.56),
                scrapColor: Color(red: 0.79, green: 0.82, blue: 0.72),
                sideMarginalia: "IlluminationScrapS03_11",
                cornerMarginalia: "IlluminationScrapS02_04",
                smallMarginalia: "IlluminationScrapS03_10",
                watermarkMarginalia: "MarginaliaCompass",
                watermarkOpacity: 0.13
            )
        case .diary:
            return PageVisualStyle(
                accent: Color(red: 0.42, green: 0.31, blue: 0.54),
                symbolColor: Color(red: 0.42, green: 0.31, blue: 0.54),
                paperTop: Color(red: 0.96, green: 0.91, blue: 0.78),
                paperMiddle: Color(red: 0.88, green: 0.80, blue: 0.66),
                paperBottom: Color(red: 0.70, green: 0.60, blue: 0.49),
                scrapColor: Color(red: 0.95, green: 0.86, blue: 0.70),
                sideMarginalia: "IlluminationScrapS02_08",
                cornerMarginalia: "IlluminationScrapS03_12",
                smallMarginalia: "IlluminationScrapS01_08",
                watermarkMarginalia: "IlluminationScrapS02_13",
                watermarkOpacity: 0.11
            )
        case .souvenir:
            var style = PageVisualStyle(
                accent: BookPalette.gold,
                symbolColor: BookPalette.gold,
                paperTop: Color(red: 0.98, green: 0.90, blue: 0.71),
                paperMiddle: Color(red: 0.92, green: 0.76, blue: 0.52),
                paperBottom: Color(red: 0.76, green: 0.56, blue: 0.35),
                scrapColor: Color(red: 0.98, green: 0.86, blue: 0.62),
                sideMarginalia: "IlluminationScrapS01_20",
                cornerMarginalia: "IlluminationScrapS03_24",
                smallMarginalia: "IlluminationScrapS01_21",
                watermarkMarginalia: "MarginaliaShell",
                sideMarginaliaWidth: 58,
                cornerMarginaliaWidth: 76,
                watermarkOpacity: 0.12
            )
            if Almanac.isMoonwriteActive() {
                style.accent = Color(red: 0.83, green: 0.76, blue: 1.0)
                style.symbolColor = Color(red: 0.93, green: 0.90, blue: 1.0)
                style.paperTop = Color(red: 0.96, green: 0.94, blue: 0.86)
                style.paperMiddle = Color(red: 0.86, green: 0.82, blue: 0.72)
                style.paperBottom = Color(red: 0.62, green: 0.60, blue: 0.66)
                style.scrapColor = Color(red: 0.95, green: 0.91, blue: 0.78)
                style.watermarkMarginalia = "MarginaliaStar"
                style.watermarkOpacity = 0.20
                style.fiberOpacity = 0.14
                style.grainOpacity = 0.034
                style.moonwriteGlow = true
            }
            return style
        case .rest:
            return PageVisualStyle(
                accent: Color(red: 0.45, green: 0.36, blue: 0.58),
                symbolColor: Color(red: 0.45, green: 0.36, blue: 0.58),
                paperTop: Color(red: 0.92, green: 0.88, blue: 0.78),
                paperMiddle: Color(red: 0.81, green: 0.77, blue: 0.69),
                paperBottom: Color(red: 0.64, green: 0.58, blue: 0.53),
                scrapColor: Color(red: 0.84, green: 0.79, blue: 0.74),
                sideMarginalia: "IlluminationScrapS02_18",
                cornerMarginalia: "IlluminationScrapS02_19",
                smallMarginalia: "MarginaliaLavender",
                watermarkMarginalia: "MarginaliaLavender",
                sideMarginaliaWidth: 64,
                sideMarginaliaOpacity: 0.46,
                cornerMarginaliaOpacity: 0.28,
                watermarkOpacity: 0.09
            )
        case .body:
            return PageVisualStyle(
                accent: Color(red: 0.22, green: 0.48, blue: 0.38),
                symbolColor: Color(red: 0.22, green: 0.48, blue: 0.38),
                paperTop: Color(red: 0.91, green: 0.88, blue: 0.72),
                paperMiddle: Color(red: 0.78, green: 0.77, blue: 0.61),
                paperBottom: Color(red: 0.63, green: 0.62, blue: 0.50),
                scrapColor: Color(red: 0.77, green: 0.82, blue: 0.66),
                sideMarginalia: "IlluminationScrapS02_26",
                cornerMarginalia: "IlluminationScrapS01_14",
                smallMarginalia: "IlluminationScrapS03_25",
                watermarkMarginalia: "MarginaliaLavender",
                watermarkOpacity: 0.10
            )
        case .fuel:
            return PageVisualStyle(
                accent: Color(red: 0.42, green: 0.48, blue: 0.22),
                symbolColor: Color(red: 0.42, green: 0.48, blue: 0.22),
                paperTop: Color(red: 0.95, green: 0.89, blue: 0.70),
                paperMiddle: Color(red: 0.82, green: 0.78, blue: 0.57),
                paperBottom: Color(red: 0.66, green: 0.61, blue: 0.43),
                scrapColor: Color(red: 0.86, green: 0.80, blue: 0.58),
                sideMarginalia: "IlluminationScrapS01_14",
                cornerMarginalia: "IlluminationScrapS02_26",
                smallMarginalia: "IlluminationScrapS03_25",
                watermarkMarginalia: "MarginaliaShell",
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.11
            )
        case .supportGuild:
            return PageVisualStyle(
                accent: Color(red: 0.36, green: 0.48, blue: 0.50),
                symbolColor: Color(red: 0.36, green: 0.48, blue: 0.50),
                paperTop: Color(red: 0.94, green: 0.88, blue: 0.74),
                paperMiddle: Color(red: 0.79, green: 0.74, blue: 0.62),
                paperBottom: Color(red: 0.61, green: 0.56, blue: 0.50),
                scrapColor: Color(red: 0.82, green: 0.78, blue: 0.66),
                sideMarginalia: "IlluminationScrapS02_26",
                cornerMarginalia: "IlluminationScrapS02_12",
                smallMarginalia: "MarginaliaSeal",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 70,
                cornerMarginaliaWidth: 84,
                sideMarginaliaOpacity: 0.42,
                watermarkOpacity: 0.12,
                scrapWidth: 92
            )
        case .facultyResearch:
            return PageVisualStyle(
                accent: Color(red: 0.43, green: 0.34, blue: 0.58),
                symbolColor: Color(red: 0.43, green: 0.34, blue: 0.58),
                paperTop: Color(red: 0.93, green: 0.86, blue: 0.75),
                paperMiddle: Color(red: 0.78, green: 0.70, blue: 0.66),
                paperBottom: Color(red: 0.58, green: 0.50, blue: 0.54),
                scrapColor: Color(red: 0.82, green: 0.72, blue: 0.70),
                sideMarginalia: "IlluminationScrapS03_24",
                cornerMarginalia: "IlluminationScrapS02_13",
                smallMarginalia: "MarginaliaFeather",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 66,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.42,
                watermarkOpacity: 0.12,
                scrapWidth: 92
            )
        case .letter:
            return PageVisualStyle(
                accent: Color(red: 0.48, green: 0.30, blue: 0.36),
                symbolColor: Color(red: 0.48, green: 0.30, blue: 0.36),
                paperTop: Color(red: 0.96, green: 0.89, blue: 0.76),
                paperMiddle: Color(red: 0.86, green: 0.76, blue: 0.64),
                paperBottom: Color(red: 0.68, green: 0.55, blue: 0.48),
                scrapColor: Color(red: 0.92, green: 0.80, blue: 0.66),
                sideMarginalia: "MarginaliaFeather",
                cornerMarginalia: "MarginaliaSeal",
                smallMarginalia: "IlluminationScrapS02_13",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 58,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.42,
                watermarkOpacity: 0.11,
                scrapWidth: 88
            )
        case .weather, .location:
            return PageVisualStyle(
                accent: Color(red: 0.12, green: 0.45, blue: 0.54),
                symbolColor: Color(red: 0.12, green: 0.45, blue: 0.54),
                paperTop: Color(red: 0.88, green: 0.87, blue: 0.74),
                paperMiddle: Color(red: 0.70, green: 0.77, blue: 0.70),
                paperBottom: Color(red: 0.50, green: 0.61, blue: 0.58),
                scrapColor: Color(red: 0.77, green: 0.85, blue: 0.78),
                sideMarginalia: "IlluminationScrapS01_08",
                cornerMarginalia: "IlluminationScrapS01_09",
                smallMarginalia: "MarginaliaShell",
                watermarkMarginalia: "MarginaliaShell",
                sideMarginaliaWidth: 62,
                cornerMarginaliaWidth: 78,
                sideMarginaliaOpacity: 0.42,
                cornerMarginaliaOpacity: 0.34,
                watermarkOpacity: 0.13
            )
        case .quip:
            return PageVisualStyle(
                accent: Color(red: 0.70, green: 0.33, blue: 0.18),
                symbolColor: Color(red: 0.70, green: 0.33, blue: 0.18),
                paperTop: Color(red: 0.99, green: 0.87, blue: 0.62),
                paperMiddle: Color(red: 0.92, green: 0.70, blue: 0.44),
                paperBottom: Color(red: 0.72, green: 0.48, blue: 0.30),
                scrapColor: Color(red: 0.97, green: 0.78, blue: 0.50),
                sideMarginalia: "IlluminationScrapS03_10",
                cornerMarginalia: "IlluminationScrapS03_11",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaStar",
                sideMarginaliaWidth: 54,
                watermarkOpacity: 0.16
            )
        case .aboutYou:
            return PageVisualStyle(
                accent: Color(red: 0.55, green: 0.28, blue: 0.39),
                symbolColor: Color(red: 0.55, green: 0.28, blue: 0.39),
                paperTop: Color(red: 0.96, green: 0.86, blue: 0.76),
                paperMiddle: Color(red: 0.88, green: 0.70, blue: 0.66),
                paperBottom: Color(red: 0.68, green: 0.50, blue: 0.52),
                scrapColor: Color(red: 0.92, green: 0.74, blue: 0.68),
                sideMarginalia: "IlluminationScrapS02_12",
                cornerMarginalia: "IlluminationScrapS02_13",
                smallMarginalia: "MarginaliaFeather",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.11
            )
        case .wonderCompass:
            return PageVisualStyle(
                accent: BookPalette.gold,
                symbolColor: BookPalette.gold,
                paperTop: Color(red: 0.99, green: 0.89, blue: 0.66),
                paperMiddle: Color(red: 0.91, green: 0.72, blue: 0.44),
                paperBottom: Color(red: 0.69, green: 0.46, blue: 0.24),
                scrapColor: Color(red: 0.98, green: 0.82, blue: 0.52),
                sideMarginalia: "IlluminationScrapS01_02",
                cornerMarginalia: "IlluminationScrapS01_03",
                smallMarginalia: "MarginaliaCompass",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 68,
                cornerMarginaliaWidth: 84,
                sideMarginaliaOpacity: 0.42,
                cornerMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.15,
                scrapWidth: 86
            )
        case .lore, .narrativeOS, .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .theBleed:
            return PageVisualStyle(
                accent: BookPalette.violet,
                symbolColor: BookPalette.violet,
                paperTop: Color(red: 0.92, green: 0.82, blue: 0.70),
                paperMiddle: Color(red: 0.76, green: 0.66, blue: 0.63),
                paperBottom: Color(red: 0.54, green: 0.44, blue: 0.48),
                scrapColor: Color(red: 0.80, green: 0.70, blue: 0.70),
                sideMarginalia: "IlluminationScrapS03_24",
                cornerMarginalia: "IlluminationScrapS03_25",
                smallMarginalia: "IlluminationScrapS03_10",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 66,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.44,
                cornerMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.14,
                scrapWidth: 92,
                scrapHeight: 34
            )
        case .gossip:
            return PageVisualStyle(
                accent: Color(red: 0.78, green: 0.50, blue: 0.26),
                symbolColor: Color(red: 0.78, green: 0.50, blue: 0.26),
                paperTop: Color(red: 0.95, green: 0.84, blue: 0.67),
                paperMiddle: Color(red: 0.82, green: 0.66, blue: 0.54),
                paperBottom: Color(red: 0.58, green: 0.43, blue: 0.42),
                scrapColor: Color(red: 0.88, green: 0.72, blue: 0.57),
                sideMarginalia: "IlluminationScrapS02_21",
                cornerMarginalia: "IlluminationScrapS03_16",
                smallMarginalia: "IlluminationScrapS03_08",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 72,
                cornerMarginaliaWidth: 86,
                sideMarginaliaOpacity: 0.48,
                cornerMarginaliaOpacity: 0.42,
                watermarkOpacity: 0.16,
                scrapWidth: 92,
                scrapHeight: 34
            )
        case .patreon:
            return PageVisualStyle(
                accent: Color(red: 0.60, green: 0.26, blue: 0.22),
                symbolColor: Color(red: 0.60, green: 0.26, blue: 0.22),
                paperTop: Color(red: 0.96, green: 0.83, blue: 0.67),
                paperMiddle: Color(red: 0.86, green: 0.62, blue: 0.50),
                paperBottom: Color(red: 0.62, green: 0.38, blue: 0.34),
                scrapColor: Color(red: 0.87, green: 0.62, blue: 0.55),
                sideMarginalia: "IlluminationScrapS02_05",
                cornerMarginalia: "IlluminationScrapS02_04",
                smallMarginalia: "IlluminationScrapS01_21",
                watermarkMarginalia: "MarginaliaSeal",
                cornerMarginaliaWidth: 86,
                cornerMarginaliaOpacity: 0.42,
                watermarkOpacity: 0.14
            )
        case .illustration:
            return PageVisualStyle(
                accent: Color(red: 0.30, green: 0.44, blue: 0.54),
                symbolColor: Color(red: 0.30, green: 0.44, blue: 0.54),
                paperTop: Color(red: 0.92, green: 0.84, blue: 0.70),
                paperMiddle: Color(red: 0.75, green: 0.68, blue: 0.58),
                paperBottom: Color(red: 0.52, green: 0.48, blue: 0.44),
                scrapColor: Color(red: 0.80, green: 0.74, blue: 0.64),
                sideMarginalia: "IlluminationScrapS03_24",
                cornerMarginalia: "IlluminationScrapS01_15",
                smallMarginalia: "IlluminationScrapS03_11",
                watermarkMarginalia: "MarginaliaStamp",
                sideMarginaliaWidth: 68,
                watermarkOpacity: 0.13
            )
        case .illuminatedPhoto:
            return PageVisualStyle(
                accent: Color(red: 0.58, green: 0.31, blue: 0.17),
                symbolColor: Color(red: 0.58, green: 0.31, blue: 0.17),
                paperTop: Color(red: 0.96, green: 0.84, blue: 0.66),
                paperMiddle: Color(red: 0.82, green: 0.63, blue: 0.46),
                paperBottom: Color(red: 0.56, green: 0.39, blue: 0.30),
                scrapColor: Color(red: 0.91, green: 0.72, blue: 0.54),
                sideMarginalia: "IlluminationScrapS01_14",
                cornerMarginalia: "IlluminationScrapS02_27",
                smallMarginalia: "IlluminationScrapS03_25",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 76,
                cornerMarginaliaWidth: 90,
                sideMarginaliaOpacity: 0.46,
                cornerMarginaliaOpacity: 0.44,
                watermarkOpacity: 0.15,
                scrapWidth: 96,
                scrapHeight: 34
            )
        case .enchantment:
            return PageVisualStyle(
                accent: BookPalette.teal,
                symbolColor: BookPalette.lampGold,
                paperTop: Color(red: 0.96, green: 0.84, blue: 0.66),
                paperMiddle: Color(red: 0.82, green: 0.66, blue: 0.48),
                paperBottom: Color(red: 0.56, green: 0.42, blue: 0.31),
                scrapColor: Color(red: 0.91, green: 0.74, blue: 0.55),
                sideMarginalia: "IlluminationScrapS01_14",
                cornerMarginalia: "IlluminationScrapS02_27",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 76,
                cornerMarginaliaWidth: 90,
                sideMarginaliaOpacity: 0.46,
                cornerMarginaliaOpacity: 0.44,
                watermarkOpacity: 0.15,
                scrapWidth: 96,
                scrapHeight: 34
            )
        case .anchor:
            return PageVisualStyle(
                accent: Color(red: 0.18, green: 0.45, blue: 0.42),
                symbolColor: Color(red: 0.18, green: 0.45, blue: 0.42),
                paperTop: Color(red: 0.93, green: 0.86, blue: 0.67),
                paperMiddle: Color(red: 0.76, green: 0.70, blue: 0.53),
                paperBottom: Color(red: 0.48, green: 0.48, blue: 0.40),
                scrapColor: Color(red: 0.80, green: 0.75, blue: 0.57),
                sideMarginalia: "MarginaliaCompass",
                cornerMarginalia: "IlluminationScrapS02_13",
                smallMarginalia: "MarginaliaSeal",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 72,
                cornerMarginaliaWidth: 86,
                sideMarginaliaOpacity: 0.40,
                cornerMarginaliaOpacity: 0.36,
                watermarkOpacity: 0.14,
                scrapWidth: 92,
                scrapHeight: 34
            )
        case .bookOfYou:
            return PageVisualStyle(
                accent: BookPalette.teal,
                symbolColor: BookPalette.teal,
                paperTop: Color(red: 0.97, green: 0.91, blue: 0.76),
                paperMiddle: Color(red: 0.87, green: 0.75, blue: 0.56),
                paperBottom: Color(red: 0.66, green: 0.52, blue: 0.39),
                scrapColor: Color(red: 0.88, green: 0.78, blue: 0.60),
                sideMarginalia: "IlluminationScrapS01_20",
                cornerMarginalia: "IlluminationScrapS01_03",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaStamp",
                sideMarginaliaWidth: 70,
                cornerMarginaliaWidth: 84,
                sideMarginaliaOpacity: 0.42,
                watermarkOpacity: 0.13
            )
        case .askTheBook:
            return PageVisualStyle(
                accent: Color(red: 0.18, green: 0.50, blue: 0.55),
                symbolColor: Color(red: 0.18, green: 0.50, blue: 0.55),
                paperTop: Color(red: 0.95, green: 0.88, blue: 0.72),
                paperMiddle: Color(red: 0.78, green: 0.75, blue: 0.62),
                paperBottom: Color(red: 0.55, green: 0.55, blue: 0.50),
                scrapColor: Color(red: 0.82, green: 0.79, blue: 0.66),
                sideMarginalia: "IlluminationScrapS03_10",
                cornerMarginalia: "IlluminationScrapS01_20",
                smallMarginalia: "MarginaliaCompass",
                watermarkMarginalia: "MarginaliaStamp",
                sideMarginaliaWidth: 66,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.12,
                scrapWidth: 90
            )
        case .inkrestOfficeHours:
            return PageVisualStyle(
                accent: Color(red: 0.46, green: 0.36, blue: 0.56),
                symbolColor: Color(red: 0.46, green: 0.36, blue: 0.56),
                paperTop: Color(red: 0.95, green: 0.89, blue: 0.74),
                paperMiddle: Color(red: 0.80, green: 0.74, blue: 0.62),
                paperBottom: Color(red: 0.58, green: 0.53, blue: 0.52),
                scrapColor: Color(red: 0.83, green: 0.78, blue: 0.68),
                sideMarginalia: "IlluminationScrapS02_26",
                cornerMarginalia: "IlluminationScrapS01_20",
                smallMarginalia: "MarginaliaSeal",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 68,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.12,
                scrapWidth: 90
            )
        case .faeBargain:
            return PageVisualStyle(
                accent: Color(red: 0.24, green: 0.46, blue: 0.42),
                symbolColor: Color(red: 0.24, green: 0.46, blue: 0.42),
                paperTop: Color(red: 0.93, green: 0.90, blue: 0.78),
                paperMiddle: Color(red: 0.78, green: 0.76, blue: 0.64),
                paperBottom: Color(red: 0.56, green: 0.56, blue: 0.50),
                scrapColor: Color(red: 0.81, green: 0.80, blue: 0.68),
                sideMarginalia: "IlluminationScrapS03_11",
                cornerMarginalia: "IlluminationScrapS02_19",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 66,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.12,
                scrapWidth: 90
            )
        case .pactDispatch:
            return PageVisualStyle(
                accent: Color(red: 0.52, green: 0.30, blue: 0.30),
                symbolColor: Color(red: 0.52, green: 0.30, blue: 0.30),
                paperTop: Color(red: 0.94, green: 0.89, blue: 0.77),
                paperMiddle: Color(red: 0.80, green: 0.73, blue: 0.62),
                paperBottom: Color(red: 0.58, green: 0.52, blue: 0.49),
                scrapColor: Color(red: 0.82, green: 0.77, blue: 0.66),
                sideMarginalia: "IlluminationScrapS02_19",
                cornerMarginalia: "IlluminationScrapS02_12",
                smallMarginalia: "MarginaliaSeal",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 66,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.12,
                scrapWidth: 90
            )
        case .pactVerdict:
            return PageVisualStyle(
                accent: Color(red: 0.34, green: 0.30, blue: 0.52),
                symbolColor: Color(red: 0.34, green: 0.30, blue: 0.52),
                paperTop: Color(red: 0.94, green: 0.90, blue: 0.78),
                paperMiddle: Color(red: 0.80, green: 0.74, blue: 0.63),
                paperBottom: Color(red: 0.57, green: 0.53, blue: 0.52),
                scrapColor: Color(red: 0.82, green: 0.78, blue: 0.67),
                sideMarginalia: "IlluminationScrapS02_19",
                cornerMarginalia: "IlluminationScrapS02_26",
                smallMarginalia: "MarginaliaSeal",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 66,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.12,
                scrapWidth: 90
            )
        case .pactErrand:
            return PageVisualStyle(
                accent: Color(red: 0.46, green: 0.36, blue: 0.26),
                symbolColor: Color(red: 0.46, green: 0.36, blue: 0.26),
                paperTop: Color(red: 0.95, green: 0.91, blue: 0.78),
                paperMiddle: Color(red: 0.81, green: 0.74, blue: 0.61),
                paperBottom: Color(red: 0.58, green: 0.52, blue: 0.47),
                scrapColor: Color(red: 0.83, green: 0.78, blue: 0.65),
                sideMarginalia: "IlluminationScrapS03_11",
                cornerMarginalia: "IlluminationScrapS02_12",
                smallMarginalia: "MarginaliaCompass",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 66,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.12,
                scrapWidth: 90
            )
        case .festival:
            return PageVisualStyle(
                accent: Color(red: 0.44, green: 0.33, blue: 0.60),
                symbolColor: Color(red: 0.62, green: 0.46, blue: 0.24),
                paperTop: Color(red: 0.96, green: 0.90, blue: 0.74),
                paperMiddle: Color(red: 0.82, green: 0.74, blue: 0.58),
                paperBottom: Color(red: 0.42, green: 0.38, blue: 0.46),
                scrapColor: Color(red: 0.85, green: 0.79, blue: 0.64),
                sideMarginalia: "IlluminationScrapS02_08",
                cornerMarginalia: "IlluminationScrapS03_24",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 70,
                cornerMarginaliaWidth: 86,
                sideMarginaliaOpacity: 0.42,
                watermarkOpacity: 0.14,
                scrapWidth: 92
            )
        case .twoReadings:
            return PageVisualStyle(
                accent: Color(red: 0.30, green: 0.34, blue: 0.50),
                symbolColor: Color(red: 0.30, green: 0.34, blue: 0.50),
                paperTop: Color(red: 0.95, green: 0.90, blue: 0.77),
                paperMiddle: Color(red: 0.80, green: 0.75, blue: 0.63),
                paperBottom: Color(red: 0.57, green: 0.55, blue: 0.52),
                scrapColor: Color(red: 0.83, green: 0.79, blue: 0.67),
                sideMarginalia: "IlluminationScrapS01_20",
                cornerMarginalia: "IlluminationScrapS02_26",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 68,
                cornerMarginaliaWidth: 82,
                sideMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.12,
                scrapWidth: 90
            )
        case .castBond:
            return PageVisualStyle(
                accent: Color(red: 0.58, green: 0.34, blue: 0.42),
                symbolColor: Color(red: 0.58, green: 0.34, blue: 0.42),
                paperTop: Color(red: 0.95, green: 0.88, blue: 0.74),
                paperMiddle: Color(red: 0.81, green: 0.72, blue: 0.62),
                paperBottom: Color(red: 0.58, green: 0.48, blue: 0.50),
                scrapColor: Color(red: 0.86, green: 0.76, blue: 0.66),
                sideMarginalia: "IlluminationScrapS02_21",
                cornerMarginalia: "IlluminationScrapS03_16",
                smallMarginalia: "MarginaliaFeather",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 72,
                cornerMarginaliaWidth: 86,
                sideMarginaliaOpacity: 0.44,
                cornerMarginaliaOpacity: 0.40,
                watermarkOpacity: 0.14,
                scrapWidth: 92,
                scrapHeight: 34
            )
        case .todaysSky:
            return PageVisualStyle(
                accent: Color(red: 0.40, green: 0.44, blue: 0.66),
                symbolColor: Color(red: 0.62, green: 0.58, blue: 0.34),
                paperTop: Color(red: 0.93, green: 0.91, blue: 0.80),
                paperMiddle: Color(red: 0.74, green: 0.74, blue: 0.70),
                paperBottom: Color(red: 0.34, green: 0.36, blue: 0.50),
                scrapColor: Color(red: 0.80, green: 0.79, blue: 0.70),
                sideMarginalia: "IlluminationScrapS02_08",
                cornerMarginalia: "IlluminationScrapS03_24",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaCompass",
                sideMarginaliaWidth: 70,
                cornerMarginaliaWidth: 86,
                sideMarginaliaOpacity: 0.42,
                watermarkOpacity: 0.14,
                scrapWidth: 92
            )
        }
    }
}

private struct ParchmentSurface: ViewModifier {
    let accent: Color
    var style: PageVisualStyle?
    let isActive: Bool

    private var resolved: PageVisualStyle {
        style ?? {
            var fallback = PageVisualStyle.default
            fallback.accent = accent
            fallback.symbolColor = accent
            return fallback
        }()
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                resolved.paperTop,
                                resolved.paperMiddle,
                                resolved.paperBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
            }
            .overlay {
                Image("ParchmentFiber")
                    .resizable()
                    .scaledToFill()
                    .opacity(isActive ? resolved.fiberOpacity : max(0.10, resolved.fiberOpacity * 0.62))
                    .blendMode(.multiply)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .overlay {
                ParchmentGrain()
                    .fill(BookPalette.ink.opacity(resolved.grainOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.parchmentEdge.opacity(0.38), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(resolved.accent.opacity(isActive ? 0.48 : 0.22), lineWidth: 1)
                    .padding(2)
            }
            .overlay {
                if resolved.moonwriteGlow {
                    MoonwriteParchmentGlow(accent: resolved.accent, isActive: isActive)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: resolved.moonwriteGlow
                    ? resolved.accent.opacity(isActive ? 0.46 : 0.26)
                    : .clear,
                radius: resolved.moonwriteGlow ? (isActive ? 22 : 12) : 0,
                x: 0,
                y: 0
            )
    }
}

extension View {
    func storyFieldSmallText() -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(BookPalette.ink.opacity(0.62))
            .fixedSize(horizontal: false, vertical: true)
    }

    func parchmentSurface(accent: Color = BookPalette.gold, isActive: Bool = false) -> some View {
        modifier(ParchmentSurface(accent: accent, style: nil, isActive: isActive))
    }

    func parchmentSurface(style: PageVisualStyle, isActive: Bool = false) -> some View {
        modifier(ParchmentSurface(accent: style.accent, style: style, isActive: isActive))
    }

    func sectionRuneLabel() -> some View {
        self
            .font(.system(.caption, design: .serif, weight: .semibold))
            .textCase(.uppercase)
            .kerning(2)
            .foregroundStyle(BookPalette.lampGold)
    }
}

private struct MoonwriteParchmentGlow: View {
    let accent: Color
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(isActive ? 0.18 : 0.10),
                    accent.opacity(isActive ? 0.18 : 0.10),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color.white.opacity(isActive ? 0.30 : 0.18),
                    accent.opacity(isActive ? 0.20 : 0.12),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 8,
                endRadius: isActive ? 260 : 180
            )
            .opacity(reduceMotion ? 0.86 : (pulse ? 1.0 : 0.66))
            .blendMode(.screen)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isActive ? 0.70 : 0.40),
                            accent.opacity(isActive ? 0.72 : 0.44),
                            Color.white.opacity(isActive ? 0.28 : 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isActive ? 1.8 : 1.2
                )
                .padding(3)

            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(isActive ? 0.46 : 0.28))
                    .frame(width: CGFloat(2 + index % 3), height: CGFloat(2 + index % 3))
                    .position(
                        x: CGFloat(28 + (index * 47) % 250),
                        y: CGFloat(20 + (index * 71) % 190)
                    )
                    .opacity(reduceMotion ? 0.42 : (pulse ? 0.72 : 0.26))
                    .blendMode(.screen)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// A blobby, hand-pressed wax seal edge: a circle with small cosine wobbles so
/// no two seals (and no two presses) read as the same machine-cut disc.
struct WaxSealShape: Shape {
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        var path = Path()
        let lobes = 9 + (abs(seed) % 3)
        let phase = Double(abs(seed) % 17) / 17 * 2 * .pi
        let secondPhase = Double(abs(seed) % 7) / 7 * 2 * .pi
        let steps = 96
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let wobble = 1
                + 0.045 * cos(Double(lobes) * angle + phase)
                + 0.022 * cos(Double(lobes * 2 + 1) * angle + secondPhase)
            let radius = baseRadius * wobble
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// One of the three marginalia seals pressed into the page top: Body, Weather,
/// Location. Wax-toned, embossed, with a per-seal tilt and a breathing shimmer
/// while its doorway is working.
struct MarginaliaSealButton: View {
    let title: String
    let systemImage: String
    let wax: Color
    let seed: Int
    let isBusy: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    private var tilt: Double {
        Double((abs(seed) % 7)) - 3
    }

    var body: some View {
        Button {
            guard !isBusy else { return }
            action()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    WaxSealShape(seed: seed)
                        .fill(
                            RadialGradient(
                                colors: [
                                    wax.opacity(0.98),
                                    wax.opacity(0.86),
                                    wax.opacity(0.62)
                                ],
                                center: .init(x: 0.38, y: 0.34),
                                startRadius: 2,
                                endRadius: 46
                            )
                        )
                        .overlay {
                            WaxSealShape(seed: seed)
                                .stroke(.black.opacity(0.22), lineWidth: 1)
                        }
                        .overlay {
                            WaxSealShape(seed: seed &+ 31)
                                .stroke(.white.opacity(0.30), lineWidth: 1.1)
                                .padding(7)
                        }
                        .shadow(color: .black.opacity(0.34), radius: 6, x: 0, y: 4)

                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black.opacity(0.32))
                        .offset(x: 0.8, y: 1.2)
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .shadow(color: wax.opacity(0.8), radius: 5)

                    if isBusy {
                        WaxSealShape(seed: seed)
                            .fill(.white.opacity(0.14))
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                            .offset(y: 22)
                    }
                }
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(reduceMotion ? 0 : tilt))
                .scaleEffect(isPressed && !reduceMotion ? 0.92 : 1)

                Text(title)
                    .font(.system(.caption2, design: .serif, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(1.1)
                    .foregroundStyle(BookPalette.nightText.opacity(0.82))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityLabel("\(title) seal")
        .accessibilityHint(isBusy ? "Working" : "Press to open")
    }
}

private struct ParchmentGrain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (0.08, 0.14, 1.4), (0.18, 0.72, 1.0), (0.31, 0.24, 0.8),
            (0.46, 0.82, 1.2), (0.58, 0.38, 0.9), (0.72, 0.18, 1.1),
            (0.82, 0.64, 1.5), (0.92, 0.30, 0.7), (0.38, 0.55, 1.0)
        ]
        for point in points {
            let center = CGPoint(x: rect.minX + rect.width * point.0, y: rect.minY + rect.height * point.1)
            path.addEllipse(in: CGRect(x: center.x, y: center.y, width: point.2, height: point.2))
        }
        return path
    }
}

private struct PageCurl: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.maxX * 0.74, y: rect.maxY * 0.18)
        )
        path.closeSubpath()
        return path
    }
}

private struct StarSpeckle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<72 {
            let x = rect.minX + rect.width * CGFloat((index * 37) % 100) / 100
            let y = rect.minY + rect.height * CGFloat((index * 61) % 100) / 100
            let size = CGFloat((index % 3) + 1)
            path.addEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }
        return path
    }
}

private struct AmbientLetterField: View {
    let isPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion || isPaused {
            Canvas { context, size in
                AmbientLetterFieldRenderer.draw(in: context, size: size, time: 0, reduceMotion: true)
            }
            .opacity(isPaused ? 0.24 : 0.36)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
                Canvas { context, size in
                    AmbientLetterFieldRenderer.draw(
                        in: context,
                        size: size,
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        reduceMotion: false
                    )
                }
            }
            .opacity(0.78)
        }
    }
}

private enum AmbientLetterFieldRenderer {
    private struct Letter {
        var glyph: Character
        var position: CGPoint
        var size: CGFloat
        var depth: CGFloat
        var angle: Double
        var color: Color
        var alpha: Double
        var flash: Double
    }

    private static let glyphs = Array("REENCHANTEDBOOKOFYOUPAGESKEPTSTORY")
    private static let colors = [
        BookPalette.lampGold,
        Color(red: 1.0, green: 0.86, blue: 0.56),
        // Brighter than BookPalette.teal so the cool letters read as colour
        // rather than grey at these low alphas.
        Color(red: 0.36, green: 0.80, blue: 0.80),
        Color(red: 0.70, green: 0.58, blue: 0.98)
    ]
    private static let pixieColor = Color(red: 1.0, green: 0.90, blue: 0.68)

    static func draw(in context: GraphicsContext, size: CGSize, time: TimeInterval, reduceMotion: Bool) {
        guard size.width > 4, size.height > 4 else { return }

        let clock = reduceMotion ? 0 : time
        let count = letterCount(for: size)
        let gather = reduceMotion ? 0 : gatherStrength(at: clock)
        let targetIndex = count == 0 ? 0 : Int(floor(clock / 16).truncatingRemainder(dividingBy: Double(count)))
        let pixie = pixiePosition(size: size, time: clock, targetIndex: targetIndex, gather: gather)
        let letters = (0..<count).map {
            letter(at: $0, count: count, size: size, time: clock, pixie: pixie, gather: gather)
        }

        drawLetters(letters, in: context)
        if !reduceMotion {
            drawCollisionSparks(letters, in: context, time: clock)
            drawPixie(at: pixie, in: context, size: size, time: clock, targetIndex: targetIndex, gather: gather)
        }
    }

    private static func letterCount(for size: CGSize) -> Int {
        let area = size.width * size.height
        return min(30, max(16, Int(area / 26_000)))
    }

    private static func letter(
        at index: Int,
        count: Int,
        size: CGSize,
        time: TimeInterval,
        pixie: CGPoint,
        gather: Double
    ) -> Letter {
        let seed = Double(index + 1)
        let depth = CGFloat(0.44 + random(seed, 0) * 0.72)
        let base = CGPoint(
            x: size.width * CGFloat(0.06 + random(seed, 1) * 0.88),
            y: size.height * CGFloat(0.06 + random(seed, 2) * 0.88)
        )
        let driftScale = 13 + 24 * depth
        let drift = CGPoint(
            x: CGFloat(sin(time * (0.058 + random(seed, 3) * 0.044) + seed * 1.7)) * driftScale
                + CGFloat(cos(time * 0.032 + seed)) * driftScale * 0.50,
            y: CGFloat(cos(time * (0.050 + random(seed, 4) * 0.036) + seed * 1.3)) * driftScale
                + CGFloat(sin(time * 0.034 + seed * 0.6)) * driftScale * 0.44
        )

        let wandering = wrapped(
            CGPoint(x: base.x + drift.x, y: base.y + drift.y),
            in: size,
            margin: 34
        )
        let dx = pixie.x - wandering.x
        let dy = pixie.y - wandering.y
        let distance = hypot(dx, dy)
        // Reach further and pull harder so the pixie truly scoops letters up
        // into a clustered swarm rather than nudging the nearest few.
        let radius = 150 + 96 * Double(depth)
        let localPull = gather * smoothstep(1, 0, distance / radius)
        // A wider swirl keeps the gathered letters orbiting the pixie — close
        // enough to keep clashing and sparking, loose enough to read as a swarm
        // instead of collapsing to a single point.
        let orbit = CGPoint(
            x: CGFloat(sin(time * 1.65 + seed)) * CGFloat(localPull) * 34,
            y: CGFloat(cos(time * 1.32 + seed * 0.8)) * CGFloat(localPull) * 29
        )
        let pulled = CGPoint(
            x: wandering.x + dx * CGFloat(localPull * 0.88) + orbit.x,
            y: wandering.y + dy * CGFloat(localPull * 0.88) + orbit.y
        )
        let baseSize = CGFloat(7.0 + random(seed, 5) * 9.0)
        let flash = min(1, localPull * 0.82)

        return Letter(
            glyph: glyphs[index % glyphs.count],
            position: wrapped(pulled, in: size, margin: 40),
            size: baseSize * (0.72 + depth * 0.62),
            depth: depth,
            angle: sin(time * (0.10 + random(seed, 6) * 0.10) + seed) * 0.30 + flash * 0.20,
            color: colors[index % colors.count],
            alpha: 0.13 + random(seed, 7) * 0.20 + flash * 0.34,
            flash: flash
        )
    }

    private static func drawLetters(_ letters: [Letter], in context: GraphicsContext) {
        for letter in letters {
            var letterContext = context
            letterContext.translateBy(x: letter.position.x, y: letter.position.y)
            letterContext.rotate(by: .radians(letter.angle))

            let text = Text(String(letter.glyph))
                .font(.system(size: letter.size * (1 + CGFloat(letter.flash) * 0.18), weight: .semibold, design: .serif))
                .foregroundStyle(letter.color.opacity(min(0.62, letter.alpha)))

            letterContext.addFilter(.shadow(
                color: letter.color.opacity(0.20 + letter.flash * 0.34),
                radius: 3 + letter.depth * 5 + CGFloat(letter.flash) * 7
            ))
            letterContext.draw(text, at: .zero, anchor: .center)
        }
    }

    private static func drawCollisionSparks(_ letters: [Letter], in context: GraphicsContext, time: TimeInterval) {
        guard letters.count > 1 else { return }

        for first in 0..<(letters.count - 1) {
            for second in (first + 1)..<letters.count {
                let a = letters[first]
                let b = letters[second]
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let distance = hypot(dx, dy)
                let threshold = (a.size + b.size) * 0.42 + 6
                guard distance < threshold else { continue }

                let pairSeed = Double(first * 31 + second * 17)
                let pulse = max(0, sin(time * 14.5 + pairSeed))
                let strength = min(1, Double(1 - distance / threshold) * (0.48 + pulse * 0.72))
                guard strength > 0.14 else { continue }

                let center = CGPoint(x: (a.position.x + b.position.x) * 0.5, y: (a.position.y + b.position.y) * 0.5)

                // A bright kiss of light right where the two glyphs meet.
                let flareRadius = CGFloat(1.8 + 3.4 * strength)
                var flareContext = context
                flareContext.addFilter(.shadow(color: Color.white.opacity(0.68 * strength), radius: 12))
                flareContext.fill(
                    Path(ellipseIn: CGRect(x: center.x - flareRadius, y: center.y - flareRadius, width: flareRadius * 2, height: flareRadius * 2)),
                    with: .color(Color.white.opacity(0.66 * strength))
                )

                for spark in 0..<6 {
                    let seed = pairSeed + Double(spark) * 2.7
                    let angle = seed + time * 1.75
                    let distance = CGFloat(3 + random(seed, 1) * 14) * CGFloat(strength)
                    let point = CGPoint(
                        x: center.x + cos(angle) * distance,
                        y: center.y + sin(angle) * distance
                    )
                    let radius = CGFloat(0.8 + random(seed, 2) * 1.7) * CGFloat(strength)
                    let color = spark.isMultiple(of: 2) ? a.color : b.color
                    var sparkContext = context
                    sparkContext.addFilter(.shadow(color: color.opacity(0.76 * strength), radius: 10))
                    sparkContext.fill(
                        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(color.opacity(0.88 * strength))
                    )
                }
            }
        }
    }

    private static func drawPixie(
        at point: CGPoint,
        in context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        targetIndex: Int,
        gather: Double
    ) {
        for index in (1...12).reversed() {
            let trailTime = time - Double(index) * 0.11
            let trailGather = gatherStrength(at: trailTime)
            let trailPoint = pixiePosition(size: size, time: trailTime, targetIndex: targetIndex, gather: trailGather)
            let opacity = Double(13 - index) / 12 * 0.18
            let radius = CGFloat(0.8 + Double(13 - index) / 12 * 1.5)
            context.fill(
                Path(ellipseIn: CGRect(x: trailPoint.x - radius, y: trailPoint.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(pixieColor.opacity(opacity))
            )
        }

        var pixieContext = context
        pixieContext.translateBy(x: point.x, y: point.y)
        pixieContext.rotate(by: .radians(heading(time: time) + .pi / 2))

        let flap = 0.82 + sin(time * 22) * 0.18
        for side in [-1.0, 1.0] {
            var wingContext = pixieContext
            wingContext.scaleBy(x: side * flap, y: 1)
            let wing = Path(ellipseIn: CGRect(x: 2.2, y: -2.5, width: 5.6, height: 3.1))
            wingContext.fill(wing, with: .color(pixieColor.opacity(0.13 + gather * 0.16)))
        }

        let halo = CGFloat(5.6 + gather * 7.0 + sin(time * 6) * 0.7)
        pixieContext.addFilter(.shadow(color: pixieColor.opacity(0.52 + gather * 0.30), radius: halo))
        pixieContext.fill(
            Path(ellipseIn: CGRect(x: -halo, y: -halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    pixieColor.opacity(0.56 + gather * 0.22),
                    pixieColor.opacity(0.12),
                    .clear
                ]),
                center: .zero,
                startRadius: 0,
                endRadius: halo
            )
        )
        pixieContext.fill(
            Path(ellipseIn: CGRect(x: -1.35, y: -1.35, width: 2.7, height: 2.7)),
            with: .color(Color.white.opacity(0.88))
        )
    }

    private static func pixiePosition(size: CGSize, time: TimeInterval, targetIndex: Int, gather: Double) -> CGPoint {
        let wander = CGPoint(
            x: size.width * CGFloat(0.50 + sin(time * 0.071) * 0.32 + cos(time * 0.029) * 0.08),
            y: size.height * CGFloat(0.46 + cos(time * 0.063 + 0.7) * 0.24 + sin(time * 0.041) * 0.08)
        )
        let targetSeed = Double(targetIndex + 1)
        let target = CGPoint(
            x: size.width * CGFloat(0.08 + random(targetSeed, 1) * 0.84),
            y: size.height * CGFloat(0.08 + random(targetSeed, 2) * 0.82)
        )
        let pull = gather * 0.86
        let point = CGPoint(
            x: wander.x + (target.x - wander.x) * CGFloat(pull),
            y: wander.y + (target.y - wander.y) * CGFloat(pull)
        )
        return wrapped(point, in: size, margin: 50)
    }

    private static func heading(time: TimeInterval) -> Double {
        let dx = cos(time * 0.071) * 0.32 - sin(time * 0.029) * 0.08
        let dy = -sin(time * 0.063 + 0.7) * 0.24 + cos(time * 0.041) * 0.08
        return atan2(dy, dx)
    }

    private static func gatherStrength(at time: TimeInterval) -> Double {
        let phase = (time.truncatingRemainder(dividingBy: 16) + 16).truncatingRemainder(dividingBy: 16) / 16
        // Gather quickly, hold the swarm together for a good stretch, then let
        // go — a longer plateau so the "gathered up for a little while" reads.
        let rise = smoothstep(0.12, 0.30, phase)
        let fall = 1 - smoothstep(0.70, 0.90, phase)
        return max(0, min(1, rise * fall))
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge0 != edge1 else { return x < edge0 ? 0 : 1 }
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private static func random(_ seed: Double, _ salt: Double) -> Double {
        let value = sin(seed * 12.9898 + salt * 78.233) * 43_758.5453
        return value - floor(value)
    }

    private static func wrapped(_ point: CGPoint, in size: CGSize, margin: CGFloat) -> CGPoint {
        let width = max(size.width + margin * 2, 1)
        let height = max(size.height + margin * 2, 1)
        return CGPoint(
            x: wrap(point.x + margin, width) - margin,
            y: wrap(point.y + margin, height) - margin
        )
    }

    private static func wrap(_ value: CGFloat, _ max: CGFloat) -> CGFloat {
        let remainder = value.truncatingRemainder(dividingBy: max)
        return remainder >= 0 ? remainder : remainder + max
    }
}

private struct LabyrinthBackdrop: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for index in 0..<7 {
            let inset = CGFloat(index) * rect.width * 0.065
            path.addArc(
                center: center,
                radius: rect.width * 0.46 - inset,
                startAngle: .degrees(Double(index) * 18 + 20),
                endAngle: .degrees(Double(index) * 18 + 300),
                clockwise: false
            )
        }
        return path
    }
}

/// First-run story onboarding, adapted from Enchantify's Academy tutorial:
/// the fall into the book, the guide, the snack question, the name, and the
/// core belief with its first planted investment.
struct OnboardingFlowView: View {
    private enum OnboardingRehearsalChoice {
        case keep
        case wait
    }

    private struct OnboardingChoice: Identifiable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
    }

    private struct WickerModeChoice: Identifiable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
        var difficulty: Int
        var successLine: String
        var failureLine: String
    }

    private struct WickerBeliefOutcome: Equatable {
        var choiceID: String
        var roll: Int
        var difficulty: Int
        var succeeded: Bool
    }

    private struct BenefitChecklistItem: Identifiable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
    }

    private struct ScienceCitationItem: Identifiable {
        var id: String
        var title: String
        var finding: String
        var source: String
        var symbol: String
    }

    struct Result {
        var snack: String
        var name: String
        var belief: String
        var investedBelief: Bool
        var firstSouvenir: String
        var sleeveWord: String
        var drawnChapterID: String
        var wickerMode: String
        var wickerRollSucceeded: Bool
        var tastePreference: String
        var comfortBoundary: String
        var whisperCadence: String
    }

    let onGlowUnlocked: () -> Void
    let onKeepIlluminatedPhoto: (IlluminatedPhotoDraft, URL?) -> Void
    let onFinished: (Result) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isOnboardingFieldFocused: Bool
    // Persisted so a player who closes mid-onboarding reopens on the same page
    // instead of restarting. Reset to 0 when onboarding finishes (see `advance`
    // / `finishWithDefaults`) so a future re-onboard starts clean.
    @AppStorage("onboardingStep") private var step = 0
    // Shown on relaunch when there is saved onboarding progress to resume.
    @State private var showResumePrompt = false
    @State private var snack = ""
    @State private var name = ""
    @State private var belief = ""
    @State private var investedBelief = false
    @State private var rehearsalChoice: OnboardingRehearsalChoice?
    @State private var firstSouvenir = ""
    @State private var shimmer = false
    @State private var rehearsalInkBurstTrigger = 0
    @State private var pageTilt = false
    @State private var didNotifyGlowUnlocked = false
    @State private var castPreviewURL: URL?
    @State private var didWakeFirstInk = false
    @State private var sleeveWord: String?
    @State private var didSteadyFirstPage = false
    @State private var unwrittenWordDrag: CGSize = .zero
    @State private var didTuckUnwrittenWord = false
    @State private var drawnChapterID = ""
    @State private var onboardingPhotoItem: PhotosPickerItem?
    @State private var onboardingPhotoImage: UIImage?
    @State private var onboardingPhotoDraft: IlluminatedPhotoDraft?
    @State private var onboardingPhotoPreviewURL: URL?
    @State private var onboardingPhotoMessage = "Choose or take one ordinary photo. The Book will illuminate it here without asking Gemma."
    @State private var isOnboardingPhotoLoading = false
    @State private var isOnboardingCameraPresented = false
    @State private var didKeepOnboardingPhoto = false
    @State private var isSavingOnboardingPhoto = false
    @State private var wickerOutcome: WickerBeliefOutcome?
    @State private var tastePreference = ""
    @State private var comfortBoundary = ""
    @State private var whisperCadence = ""
    @State private var benefitChecklistVisibleCount = 0

    private let stepCount = 15
    private let sleeveWords = ["GLINT", "MARGIN", "THRESHOLD"]
	    private let benefitChecklistItems = [
	        BenefitChecklistItem(
	            id: "autopilot",
	            title: "Notice one real thing",
	            detail: "The app gives you small prompts that pull attention back to the room, walk, weather, person, or object in front of you.",
	            symbol: "eye"
	        ),
	        BenefitChecklistItem(
	            id: "hooks",
	            title: "Save it before it disappears",
	            detail: "Keep one sentence or photo so the moment has a handle later. It does not have to be poetic. It just has to be true.",
	            symbol: "bookmark"
	        ),
	        BenefitChecklistItem(
	            id: "meaning",
	            title: "Make days feel less blank",
	            detail: "Your kept moments build a visible record, so a week has scenes you can remember instead of becoming one grey blur.",
	            symbol: "rectangle.stack"
	        ),
	        BenefitChecklistItem(
	            id: "return",
	            title: "Feel more connected",
	            detail: "The Book can bring back related memories, people, places, and seasons so your life starts feeling linked instead of scattered.",
	            symbol: "arrow.triangle.2.circlepath"
	        ),
	        BenefitChecklistItem(
	            id: "adventure",
	            title: "Add small adventures",
	            detail: "Compass prompts turn errands, walks, waiting rooms, and ordinary Tuesdays into low-pressure quests worth noticing.",
	            symbol: "safari"
	        )
	    ]
		    private let scienceCitationItems = [
		        ScienceCitationItem(
		            id: "mind-wandering",
		            title: "Autopilot is normal",
		            finding: "People reported mind-wandering during 46.9% of waking moments. Almost half the day can go by with attention somewhere else, and that drift tends to make people less happy.",
		            source: "Killingsworth & Gilbert, Science (2010)",
		            symbol: "brain.head.profile"
		        ),
	        ScienceCitationItem(
	            id: "awe-walks",
	            title: "Wonder can be trained",
	            finding: "People who practiced awe walks felt more positive emotion and more connection than people taking ordinary walks.",
	            source: "Sturm et al., Emotion (2020)",
	            symbol: "figure.walk"
	        ),
	        ScienceCitationItem(
	            id: "small-self",
	            title: "Awe gets you out of your head",
	            finding: "Awe research links wonder with feeling connected to something larger than your private worry loop.",
	            source: "Piff et al., JPSP (2015)",
	            symbol: "person.2.wave.2"
	        ),
	        ScienceCitationItem(
	            id: "habit-memory",
	            title: "Writing helps moments stick",
	            finding: "Details you generate yourself are easier to remember, and small repeated actions can become real habits.",
	            source: "Lally et al., EJSP (2010); Slamecka & Graf, JEP (1978)",
	            symbol: "bookmark"
	        )
	    ]
    private let tasteChoices = [
        OnboardingChoice(id: "letters", title: "Letters and voices", detail: "People inside the Book should look up sooner.", symbol: "envelope.open"),
        OnboardingChoice(id: "errands", title: "Strange errands", detail: "Small impossible invitations should find the desk.", symbol: "wand.and.stars"),
        OnboardingChoice(id: "cozy", title: "Cozy noticing", detail: "Warm, exact, ordinary magic should come first.", symbol: "mug"),
        OnboardingChoice(id: "weather-place", title: "Weather and place", detail: "Sky, ground, rooms, and thresholds should speak up.", symbol: "cloud.sun"),
        OnboardingChoice(id: "eerie", title: "Eerie story threads", detail: "Let the edges get a little haunted.", symbol: "moon.stars"),
        OnboardingChoice(id: "oddities", title: "Funny little oddities", detail: "Give the Book permission to be peculiar.", symbol: "sparkles")
    ]
    private let comfortChoices = [
        OnboardingChoice(id: "gentle", title: "Gentle", detail: "Keep the Grey quiet and the Book careful.", symbol: "leaf"),
        OnboardingChoice(id: "balanced", title: "Balanced", detail: "Let wonder and shadow both have edges.", symbol: "scalemass"),
        OnboardingChoice(id: "strange", title: "Let it get strange", detail: "Sharper doors, odder signs, more pressure from the margins.", symbol: "eye")
    ]
    private let whisperChoices = [
        OnboardingChoice(id: "morning", title: "Morning", detail: "The Book may tap the glass near the start of the day.", symbol: "sunrise"),
        OnboardingChoice(id: "evening", title: "Evening", detail: "The Book may call you back when the day is ready to braid.", symbol: "moon"),
        OnboardingChoice(id: "both", title: "Both", detail: "A morning nudge and an evening return.", symbol: "sunrise.fill"),
        OnboardingChoice(id: "inside", title: "Only inside the covers", detail: "No outside whispers. The Book waits until opened.", symbol: "bell.slash")
    ]
    private let wickerChoices = [
        WickerModeChoice(
            id: "slice-of-life",
            title: "Slice of Life",
            detail: "Answer him with one concrete ordinary detail.",
            symbol: "mug",
            difficulty: 42,
            successLine: "Wicker tries to sneer, but the ordinary detail lands too cleanly. Zara looks pleased despite herself.",
            failureLine: "The detail comes out smaller than you meant. Wicker smiles like he found a loose thread, but Zara steps beside you before he can pull it."
        ),
        WickerModeChoice(
            id: "arc",
            title: "Arc",
            detail: "Turn the interruption into a promise of motion.",
            symbol: "arrow.triangle.turn.up.right.diamond",
            difficulty: 56,
            successLine: "You name the direction before Wicker can name the flaw. The hall shifts half a degree toward your next door.",
            failureLine: "The promise wobbles. Wicker hears the wobble immediately, but the Book keeps the attempt as a beginning, not a verdict."
        ),
        WickerModeChoice(
            id: "surprise",
            title: "Surprise",
            detail: "Refuse the expected answer and let something odd through.",
            symbol: "sparkles",
            difficulty: 64,
            successLine: "The answer is so sideways that Wicker forgets to be superior for one entire second. A nearby shelf laughs in paper.",
            failureLine: "The surprise misfires and becomes awkward magic. Wicker enjoys that too much. Zara mutters, \"Useful data,\" which somehow helps."
        )
    ]
    private let firstSentenceStarters = [
        "The light in this room is doing something I almost missed.",
        "I can hear one small sound under everything else.",
        "Today I am carrying a feeling with no good name yet.",
        "The weather outside makes the room feel different.",
        "Something ordinary near me looks like a sign if I let it."
    ]

    init(
        onGlowUnlocked: @escaping () -> Void = {},
        onKeepIlluminatedPhoto: @escaping (IlluminatedPhotoDraft, URL?) -> Void = { _, _ in },
        onFinished: @escaping (Result) -> Void
    ) {
        self.onGlowUnlocked = onGlowUnlocked
        self.onKeepIlluminatedPhoto = onKeepIlluminatedPhoto
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            BookBackground()
                .overlay {
                    Rectangle()
                        .fill(BookPalette.nightPanel.opacity(0.4))
                }
                .ignoresSafeArea()
                .onTapGesture {
                    isOnboardingFieldFocused = false
                }

            onboardingAura
                .onTapGesture {
                    isOnboardingFieldFocused = false
                }

            GeometryReader { proxy in
                let isPortrait = proxy.size.height >= proxy.size.width
                let headerInset: CGFloat = 14
                // Let the reading card claim most of the height instead of a tight
                // fixed cap, and ride just below the top of the page. Reserves room
                // for the step dots and spacers; adapts to small devices.
                let scrollMaxHeight: CGFloat = isPortrait
                    ? min(640, max(420, proxy.size.height - 116))
                    : min(540, max(360, proxy.size.height - 120))

                VStack(spacing: 0) {
                    Spacer(minLength: isPortrait ? 12 : 18)

                    VStack(spacing: 0) {
                        onboardingHeader
                            .padding(.horizontal, headerInset)
                            .padding(.top, headerInset)
                            .padding(.bottom, 10)

                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 18) {
                                    Color.clear
                                        .frame(height: 0)
                                        .id("onboarding-page-top")

                                    stagePill
                                    stepContent
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                                            removal: .opacity.combined(with: .move(edge: .leading))
                                        ))
                                }
                                .padding(.horizontal, 22)
                                .padding(.bottom, 74)
                            }
                            .onChange(of: step) { _, _ in
                                DispatchQueue.main.async {
                                    withAnimation(reduceMotion ? .none : .easeOut(duration: 0.18)) {
                                        scrollProxy.scrollTo("onboarding-page-top", anchor: .top)
                                    }
                                }
                                notifyGlowUnlockedIfNeeded()
                            }
                            .onChange(of: belief) { _, _ in
                                notifyGlowUnlockedIfNeeded()
                            }
                            .scrollDismissesKeyboard(.interactively)
                        }
                    }
	                    .frame(maxHeight: scrollMaxHeight)
	                    .background {
	                        ZStack {
	                            Image("ParchmentTexture")
	                                .resizable()
	                                .scaledToFill()
	                                .opacity(0.9)
	                            BookPalette.page.opacity(0.6)
	                            LinearGradient(
	                                colors: [
	                                    BookPalette.lampGold.opacity(shimmer ? 0.16 : 0.05),
	                                    .clear,
	                                    BookPalette.teal.opacity(shimmer ? 0.08 : 0.03)
	                                ],
	                                startPoint: .topLeading,
	                                endPoint: .bottomTrailing
	                            )
	                        }
	                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(shimmer ? 0.62 : 0.34), lineWidth: 1)
                    }
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : (pageTilt ? 0.8 : -0.8)), axis: (x: 0, y: 1, z: 0))
                    .padding(.top, isPortrait ? 8 : 12)
                    .padding(.horizontal, 22)
                    .shadow(color: BookPalette.lampGold.opacity(shimmer ? 0.18 : 0.08), radius: 22, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.32), radius: 12, x: 0, y: 18)
                    .zIndex(0)

                    stepDots
                        .padding(.top, isPortrait ? 18 : 16)

                    Spacer(minLength: 30)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }

            if showResumePrompt {
                resumePrompt
            }
        }
        .transition(.opacity)
        #if canImport(QuickLook)
        .quickLookPreview($castPreviewURL)
        #endif
        #if canImport(PhotosUI)
        .onChange(of: onboardingPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task { await loadOnboardingPhoto(from: newValue) }
        }
        #endif
        #if canImport(UIKit) && canImport(PhotosUI)
        .fullScreenCover(isPresented: $isOnboardingCameraPresented) {
            BookCameraCaptureView { data in
                Task { await loadOnboardingPhoto(imageData: data) }
            }
            .ignoresSafeArea()
        }
        #endif
        .onAppear {
            // If the player closed the app partway through, offer to resume.
            if step > 0 { showResumePrompt = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                shimmer = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                pageTilt = true
            }
        }
    }

    private struct OnboardingCastMember: Identifiable {
        var id: String { image }
        let image: String
        let name: String
        let line: String
        let tint: Color
    }

    private func notifyGlowUnlockedIfNeeded() {
        guard !didNotifyGlowUnlocked else { return }
        guard step >= 4 else { return }
        guard !belief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        didNotifyGlowUnlocked = true
        onGlowUnlocked()
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index == step ? BookPalette.lampGold : BookPalette.nightText.opacity(0.3))
                    .frame(width: index == step ? 9 : 6, height: index == step ? 9 : 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var onboardingHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(BookPalette.lampGold.opacity(0.26), lineWidth: 1)
                    .frame(width: 54, height: 54)
                Circle()
                    .trim(from: 0.08, to: 0.88)
                    .stroke(BookPalette.lampGold.opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (shimmer ? 22 : -18)))
                Image(systemName: onboardingSymbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(BookPalette.lampGold)
                    .shadow(color: BookPalette.lampGold.opacity(0.5), radius: 8)
            }
            .accessibilityHidden(true)

	            VStack(alignment: .leading, spacing: 3) {
	                Text("THE FIRST DOOR")
	                    .font(.system(size: 12, weight: .black))
	                    .foregroundStyle(BookPalette.lampGold.opacity(0.82))
	                Text(onboardingHeaderLine)
	                    .font(.system(.body, design: .serif).weight(.semibold))
	                    .foregroundStyle(BookPalette.nightText)
	                    .lineLimit(2)
	                    .minimumScaleFactor(0.86)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.nightPanel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        }
    }

    private var onboardingAura: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<12, id: \.self) { index in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    let angle = Double(index) * 0.9 + (shimmer ? 0.8 : 0)
                    Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "plus")
                        .font(.system(size: index.isMultiple(of: 3) ? 10 : 6, weight: .bold))
                        .foregroundStyle(BookPalette.lampGold.opacity(0.10 + Double(index % 4) * 0.025))
                        .position(
                            x: width * (0.18 + 0.64 * CGFloat((sin(angle) + 1) / 2)),
                            y: height * (0.14 + 0.72 * CGFloat((cos(angle * 1.3) + 1) / 2))
                        )
                        .blur(radius: index.isMultiple(of: 3) ? 0 : 0.5)
                }
            }
            .opacity(reduceMotion ? 0.35 : 1)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var stagePill: some View {
        HStack(spacing: 8) {
	            Label("Step \(step + 1) of \(stepCount)", systemImage: onboardingSymbol)
	                .font(.subheadline.weight(.bold))
	                .foregroundStyle(BookPalette.teal)
	            Spacer(minLength: 0)
	            Text(onboardingStageName)
	                .font(.subheadline.weight(.bold))
	                .foregroundStyle(BookPalette.ink.opacity(0.58))

            if step < stepCount - 1 {
                Button {
                    finishWithDefaults()
	                } label: {
	                    Text("Skip Onboarding")
	                        .font(.subheadline.weight(.bold))
	                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.teal)
                .accessibilityLabel("Skip onboarding")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(BookPalette.paper.opacity(0.48), in: Capsule())
        .contentShape(Rectangle())
        .onTapGesture {
            isOnboardingFieldFocused = false
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
	        case 0:
	            onboardingSystemStrip([
	                ("book.closed", "The Labyrinth of Stories"),
	                ("building.columns", "An infinite Academy"),
	                ("door.left.hand.open", "An impossible arrival")
	            ])
	            onboardingTitle("The Cover Opens")
	            onboardingProse("""
	            You open the app.

	            The cover brightens with its true name: The Labyrinth of Stories.

	            The first word lifts from the screen and turns to look at you.
	            """)

            onboardingInkWakeAction()

            onboardingProse("""
            Then the sentence breaks its spine.

            Ink blooms under the glass, cold as rainwater and impossibly wet. It climbs through the light and over your fingers. The room tips. Your stomach remains briefly behind while the rest of you falls through the bright gutter between screen and story.

            Stories rush past in layers. A green sea slaps salt across your mouth. Someone's first kiss tastes of strawberries and panic. Dragonfire warms the soles of your feet. Snow catches in your hair, smelling faintly of peppermint and old wool. A city burns somewhere below, its smoke curling into commas. You hear swords, lullabies, train brakes, wolves, applause — a thousand endings all happening at once.

            There isn't any down. There are only chapters.

            Words flock around you, sorting themselves as you fall. HERO circles your wrist and thinks better of it. WITNESS keeps pace at your shoulder. LOST flashes across your ribs, crosses itself out, and becomes ARRIVING. Then a smaller word catches in your sleeve, too quick for the Book to read until you choose it.
            """)

            onboardingSleeveWordChoice()

            onboardingProse("""
            The screen widens until it has margins, then pages, then weather. White light brushes your cheeks like wings. For one breath you're sure you're about to be shelved.

            Stone meets you in a crumple.
            """)

            onboardingSteadyPageAction()

            onboardingProse("""
            You're sprawled beneath a sky made of vaulted glass, inside a library so large its far shelves have sun showers. Towers of books lean together like old scholars. Staircases climb into cloud. Enchantify Academy burns gold among the stacks, and every student on the nearest gallery is staring at you.

            Behind you, the app's screen goes black with the soft, final sound of a door deciding it was never there.

            A bell misses its own note.

            Someone whispers, with considerable academic alarm, "They came through the Unwritten."
            """)
            continueButton("Stand up", disabled: !didCompleteFirstDoorArrival)
        case 1:
            guidePortrait(mood: "Zara Finch looks relieved to see someone from the Unwritten.")
            onboardingTitle("What the Academy Fights")
            onboardingProse("""
            A girl with quick gray eyes reaches you first and offers a hand.

            "Up," she says. "The Book does its best work when people are standing."

            She hauls you out of the sentence-dust, then points to the pale bite marks spreading along the nearest shelf.

            "Zara Finch," she says. "And before anyone gives you a brochure, you should know what we fight here."

            "We call it the Nothing; yes, just like the Neverending Story. I've read it. In books, the Nothing eats pages blank. In your world, it wears better disguises: boredom, routine, burnout, loneliness, days that feel too long while the years go too fast. The terrible little feeling that your life's happening, but not quite to you."
            """)

            onboardingNotYourFaultCard
            onboardingScienceLedger
            onboardingBenefitChecklist

            onboardingProse("""
            Zara lets the proof sit there for a second.

            "You're not lazy. You're not boring. Your brain's doing what brains do: saving energy, predicting familiar days, and skipping details it thinks it already knows."

            "The Academy fights that here. You fight it there. ReEnchanted gives you small, repeatable ways to notice your life before the Nothing turns it into wallpaper."
            """)

            continueButton("See your chapter")
        case 2:
            onboardingTitle("The Chapter Without an Ending")
            onboardingProse("""
            Now that you're standing, Zara checks your sleeves for punctuation, then looks behind you for a door that isn't there anymore.

            "You're from the Great Unwritten," she says. Not a question. "Your ordinary world is a Chapter of this Book — supposedly the best one. No fixed plot. No narrator tidying things afterward. Everything you do can change what comes next."

            "Most people think they're forgetting their lives. Usually they never quite recorded them. The Book helps with that. It catches the small, stupid, shining details before the day sweeps them away."
            """)

            onboardingUnwrittenMarginDrag()

            onboardingProse("""
            She glances up at the watching students. "We can jump into almost any written book - Dracula, The Wizard of Oz, Pride and Prejudice. Walk its roads. Meet its people. Get chased out of its third act. But no one here can jump into yours. An unwritten next page can't hold a doorway."

            "You, however, came the other way. Almost nobody does that. So they're going to be fascinated by your groceries, your weather, your terrible signs, and anything else you thought was ordinary. Sorry in advance."
            """)
            continueButton("Meet your guide", disabled: !didTuckUnwrittenWord)
        case 3:
            guidePortrait(mood: "Zara's already decided your ordinary life is evidence.")
            onboardingTitle("The Guide")
            onboardingProse("""
            Zara brushes ink off your shoulder. A compass hangs on a cord around her neck.

            "You fell well — most people land in the cookery section."

            She points down the aisle. "Before the Book starts choosing pages for you, it needs a few human details. Nothing grand. The little things are usually where the magic gets specific."

            She studies you, then asks the most important question first:

            "What's your favorite snack to eat while reading? Mine's sharp green apples. They keep me awake when the footnotes get long."

            This isn't a test. It's the Book learning your texture.
            """)
            onboardingBenefitCard(
                symbol: "line.3.horizontal.decrease.circle",
                title: "What this does for you",
                body: "Tiny specifics keep future pages from feeling generic. The Book uses details like this to make questions, letters, and stories feel like they belong to your actual life."
            )
            onboardingField("Your answer...", text: $snack)
            if let answer = snack.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                onboardingPreviewCard(
                    symbol: "takeoutbag.and.cup.and.straw",
                    title: "A margin ration appears",
                    body: "The Book writes \(answer) beside your name in tiny, serious ink. Specificity is how doors learn handles."
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            continueButton("Tell her", disabled: snack.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case 4:
            onboardingPreviewCard(symbol: "book.closed", title: "The Book learns your name", body: "It's how characters, letters, and future pages can speak to you without sounding like a form.")
            onboardingTitle("The Name the Book Knows")
            onboardingProse("""
            Zara nods, satisfied, as if your answer told her more than it should have.

            "The Book wants to know what to call you. Not your full legal anything — just the name that feels like yours when someone says it kindly."

            She taps a blank line on the first page. "Write that name here. Later, when someone in the stacks writes to you, that's the name they'll use."
            """)
            onboardingField("What should the Book call you?", text: $name)
            if let answer = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                onboardingPreviewCard(
                    symbol: "signature",
                    title: "Hello, \(answer)",
                    body: "Zara says it once, carefully, and the Book darkens the letters so future pages can find you."
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            continueButton("Write it in", disabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case 5:
            onboardingPreviewCard(symbol: "leaf", title: "Beliefs become living ink", body: "A belief you name here can later glow, recur, gather pages, and pull story toward itself.")
            onboardingTitle("Belief and the Grey")
            onboardingProse("""
            Zara goes quiet for a moment. When she speaks again, her voice is lower.

            At the far end of the aisle, a grey absence worries at the corner of a page. A word vanishes. Then another.

            "The Nothing," Zara says. "It isn't a villain. It's what remains when Belief leaves: pages eaten blank here; burnout, routine, and a world reduced to wallpaper in the Unwritten."

            She raises her compass. The erased word returns in wet black ink. "Belief makes the magic happen. Not certainty. Attention. Care. The stubborn decision that something matters enough to become real again."

            "I believe every book's a door. That's mine. I'll trade it to you for yours."

            "What do you believe in?"

            It can be a person, a value, a promise, a place, a stubborn little light. Don't make it impressive. Make it true enough to follow.
            """)
            onboardingBenefitCard(
                symbol: "sparkle.magnifyingglass",
                title: "What this does for you",
                body: "Naming a belief tells the Book what you want to feel more alive around. Giving it Belief makes the app more likely to return to that value, person, place, or pattern."
            )
            onboardingField("I believe...", text: $belief)
            if let answer = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                onboardingProse("""
                "Good," Zara says. "Saying it out loud matters. But the Labyrinth remembers best when a belief has a little weight."

                "Belief's what you give. Glow's what the Book shows you afterward."

                "You can plant three points of Belief into what you just named. The Book will hold it. Things with more Belief become more real here: they Glow brighter, appear in more Pages, and find their way into stories more often. It won't give those points back. That's why planting means something."
                """)
                onboardingPreviewCard(
                    symbol: "sparkles",
                    title: "Your Glow wakes",
                    body: "The new pill at the top is yours. It shows the Book's attention around you, and later it opens the menu for giving Belief to pages, people, and patterns."
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))

                onboardingBeliefSigil(answer)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))

                VStack(spacing: 10) {
                    Button {
                        BookFeedback.play(.braidStart)
                        investedBelief = true
                        advance()
                    } label: {
                        Label("Plant 3 Belief", systemImage: "leaf")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)

                    Button {
                        BookFeedback.play(.select)
                        investedBelief = false
                        advance()
                    } label: {
                        Text("Keep it for now")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BookPalette.ink.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(BookPalette.ink.opacity(0.26), lineWidth: 1.2)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        case 6:
            onboardingTitle("The School's Argument")
            onboardingProse("""
            Zara leads you into a circular hall where five long banners hang above an empty marble floor. Each one leans forward on its pole, just a little, as if the cloth has weight and curiosity.

            "The Academy has five Chapters," she says. "Not teams. Not Houses in prettier robes. Arguments."

            The belief you gave the Book is still warm in the air between your hands.

            Nothing opens. No floor drops away. No music swells. The banners simply lean toward the newest person in the room.

            "They're trying to decide what kind of attention you have," Zara says. "Every Chapter thinks it knows how to fight the Nothing. Every Chapter is partly right, which is why the argument has lasted this long."

            Zara steadies your elbow. "You won't Bind today. The Chapters will watch what you keep, and later the Binding will recognize where your Belief has actually been living."

            She nods toward the leaning cloth. "Still. Which argument tugged first?"
            """)
            onboardingBenefitCard(
                symbol: "signpost.right",
                title: "What this does for you",
                body: "This is not a personality quiz. It tells the Book what kind of wonder to lead with first: action, listening, surprise, connection, or honest friction."
            )
            onboardingChapterAffinityPicker
            continueButton("Warm the talisman", disabled: drawnChapterID.isEmpty)
            if drawnChapterID.isEmpty {
                secondaryOnboardingButton("Let the Book choose", systemImage: "sparkles") {
                    drawnChapterID = AcademyChapterRegistry.publicChapters.first?.id ?? ""
                    advance()
                }
            }
        case 7:
            onboardingTitle("The First Page Rises")
            onboardingProse("""
            A small page slips from the stack and lands in front of you.

            Zara folds her arms. "This is the whole trick. The Book offers pages. Some ask a question. Some notice the weather. Some bring a character, a memory, or a small strange invitation."

            "You don't have to keep them all. If a page isn't for today, let it wait. On the home screen, you can also swipe a page left to clear it away. If it catches something true, keep it. Kept pages become the archive the Book uses to remember you."

            "Try it once, where it can't hurt anything."
            """)
            onboardingBenefitCard(
                symbol: "bookmark",
                title: "What this does for you",
                body: "A kept sentence is a memory hook. Writing the detail yourself uses the generation effect: one specific line can bring back the room, the mood, and the reason the moment mattered."
            )
            onboardingPracticePage
            continueButton(
                rehearsalChoice == .keep ? "Keep the sentence" : "Let the page drift",
                disabled: rehearsalChoice == nil || (rehearsalChoice == .keep && firstSouvenir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
            if rehearsalChoice == nil {
                secondaryOnboardingButton("Skip practice", systemImage: "clock") {
                    rehearsalChoice = .wait
                    advance()
                }
            }
        case 8:
            onboardingTitle("The Plate Illuminates")
            onboardingProse("""
            Penny Blackletter appears with a brass frame under one arm.

            "Photos are already little spells," Zara says. "A private square of evidence. The Book can gild one without explaining it to a machine first."

            Choose or take a photo if you want to see the trick now. This first plate uses local margins only: frame, texture, scraps, and the image you hand it. Later, the fuller Illuminated Photos page can read the subject more closely.
            """)
            onboardingBenefitCard(
                symbol: "photo.on.rectangle.angled",
                title: "What this does for you",
                body: "This trains the core habit: look again at your own evidence. A photo becomes a remembered page instead of another square lost in the camera roll."
            )
            onboardingIlluminatedPhotoDemo
            continueButton(onboardingPhotoDraft == nil ? "Skip the plate for now" : "Keep walking")
        case 9:
            onboardingTitle("The Cast Notices")
            onboardingProse("""
            Beyond Zara, the library-school is already full of people with opinions.

            "You'll meet them slowly," Zara says. "No one sensible introduces a whole academy at once. But they know you're here now — the person who jumped out of the Chapter none of us can enter."

            Some send letters across the binding. Some ask for evidence from your unreachable world. Some disagree about what your pages mean. They remember what you tell them, form opinions, and change their minds.

            Your real life matters here because it isn't flavor text. A true action in the Unwritten carries more weight than something merely narrated inside the Book. It's how you help the Academy resist the Nothing — and how the Academy helps you notice your world before it disappears into routine.
            """)
            onboardingBenefitCard(
                symbol: "person.2.wave.2",
                title: "What this does for you",
                body: "Characters give your real actions social gravity. They ask, disagree, remember, and make ordinary choices feel worth noticing."
            )
            onboardingCastGlimpse
            continueButton("Meet the morning")
        case 10:
            onboardingTitle("Wicker Interrupts")
            onboardingProse("""
            You and Zara are almost through the next arch when a boy in a green-black coat steps out from behind a shelf as if he has been waiting for the exact worst moment.

            "So this is the impossible reader," he says. "Tiny bit shorter than the rumors."

            Zara sighs. "Wicker."

            "What? I am being welcoming." He looks at you, bright-eyed and completely unconvinced. "Show me what kind of story the Unwritten sent us."

            The Book warms under your hand. Zara does not answer for you.
            """)
            onboardingBenefitCard(
                symbol: "theatermasks",
                title: "What this does for you",
                body: "This is a sample of story friction. ReEnchanted can turn your choices into consequences without punishing failure; both outcomes become material."
            )
            onboardingWickerChoice
            continueButton("Carry the result", disabled: wickerOutcome == nil)
            if wickerOutcome == nil {
                secondaryOnboardingButton("Let Zara answer", systemImage: "person.crop.circle") {
                    wickerOutcome = WickerBeliefOutcome(choiceID: "slice-of-life", roll: 50, difficulty: 42, succeeded: true)
                    advance()
                }
            }
        case 11:
            onboardingTitle("What Should Find You")
            onboardingProse("""
            Zara leads you past a catalog desk where blank cards are sorting themselves into piles.

            "The Book will learn from what you keep," she says. "But first taste matters. If you give it one direction now, it can stop knocking on completely wrong doors while it learns you."

            "Choose the kind of page you want to find you first. This is a bias, not a cage."
            """)
            onboardingBenefitCard(
                symbol: "rectangle.stack.badge.play",
                title: "What this does for you",
                body: "This helps today's pages become useful sooner. The Book will keep learning from what you keep, dismiss, write, photograph, and follow."
            )
            onboardingChoiceList(choices: tasteChoices, selection: $tastePreference)
            continueButton("Tune the shelf", disabled: tastePreference.isEmpty)
            if tastePreference.isEmpty {
                secondaryOnboardingButton("Decide later", systemImage: "clock") {
                    tastePreference = "cozy"
                    advance()
                }
            }
        case 12:
            onboardingTitle("How Sharp Should It Get")
            onboardingProse("""
            The grey bite at the page edge pauses, listening.

            "The Book can be soft," Zara says. "It can also be eerie, challenging, and a little too exact. Both can be useful. Neither should be forced."

            "Tell it how hard to press at first. You can change this later by what you keep and dismiss."
            """)
            onboardingBenefitCard(
                symbol: "hand.raised",
                title: "What this does for you",
                body: "This sets the first emotional edge. ReEnchanted should invite curiosity and adventure, not turn your life into homework or shove you into intensity."
            )
            onboardingChoiceList(choices: comfortChoices, selection: $comfortBoundary)
            continueButton("Set the edge", disabled: comfortBoundary.isEmpty)
            if comfortBoundary.isEmpty {
                secondaryOnboardingButton("Use balanced", systemImage: "scalemass") {
                    comfortBoundary = "balanced"
                    advance()
                }
            }
        case 13:
            onboardingTitle("When the Book Taps the Glass")
            onboardingProse("""
            A small brass bell rolls out of the binding and comes to rest by your hand.

            "Last question," Zara says. "Outside the covers, the Book should be polite. It can tap the glass in the morning, call you back in the evening, do both, or keep all its voice inside the app."

            "Choose the first rule."
            """)
            onboardingBenefitCard(
                symbol: "bell.badge",
                title: "What this does for you",
                body: "This decides how adventure reaches you outside the app: a morning nudge, an evening return, both, or silence until you choose to open the Book."
            )
            onboardingChoiceList(choices: whisperChoices, selection: $whisperCadence)
            continueButton("Choose the whisper", disabled: whisperCadence.isEmpty)
            if whisperCadence.isEmpty {
                secondaryOnboardingButton("Keep quiet for now", systemImage: "bell.slash") {
                    whisperCadence = "inside"
                    advance()
                }
            }
        default:
            onboardingSystemStrip([
                ("signature", name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"),
                ("sparkles", sleeveWord ?? "GLINT"),
                ("rectangle.stack", tasteTitle)
            ])
            onboardingTitle("The First Door Writes Back")
            onboardingProse(firstDoorMiniStory)
            onboardingBenefitCard(
                symbol: "rectangle.stack",
                title: "What you just built",
                body: "You gave the Book enough real material to begin: details, preference, belief, image, choice, and one memory hook. Next it starts paying that back as pages, returns, Compass prompts, and a Book of You."
            )
            continueButton("Step into your story")
        }
    }

    private var onboardingSymbol: String {
        switch step {
        case 0: return "book.closed"
        case 1: return "sparkle.magnifyingglass"
        case 2: return "door.left.hand.open"
        case 3: return "person.crop.circle"
        case 4: return "text.book.closed"
        case 5: return "leaf"
        case 6: return "flag.2.crossed"
        case 7: return "rectangle.stack"
        case 8: return "photo.artframe"
        case 9: return "person.2"
        case 10: return "theatermasks"
        case 11: return "slider.horizontal.3"
        case 12: return "scalemass"
        case 13: return "bell"
        default: return "sparkles"
        }
    }

    private var onboardingStageName: String {
        switch step {
        case 0: return "Arrival"
        case 1: return "The Nothing"
        case 2: return "The Unwritten"
        case 3: return "Guide"
        case 4: return "Name"
        case 5: return "Belief"
        case 6: return "Chapters"
        case 7: return "First Page"
        case 8: return "Illumination"
        case 9: return "Cast"
        case 10: return "Wicker"
        case 11: return "Taste"
        case 12: return "Edge"
        case 13: return "Whispers"
        default: return "Threshold"
        }
    }

    private var onboardingHeaderLine: String {
        switch step {
	        case 0: return "The Labyrinth of Stories is waking up."
        case 1: return "Zara names what the Academy fights."
        case 2: return "The Academy has never seen your door."
        case 3: return "Zara meets you at the stacks."
        case 4: return "The Book wants your name."
        case 5: return "A first belief asks for weight."
        case 6: return "Five old arguments notice you."
        case 7: return "Try keeping one true page."
        case 8: return "A photo becomes a plate."
        case 9: return "The world looks back."
        case 10: return "A first antagonist tests the page."
        case 11: return "The Book learns what to bring first."
        case 12: return "The Grey asks how sharp to be."
        case 13: return "The bell waits for permission."
        default: return "The daily magic begins."
        }
    }

    private var onboardingPracticePage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundStyle(BookPalette.lampGold)
	                Text("A Practice Page")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.lampGold)
	                Spacer()
	                Text("SAFE TO TRY")
	                    .font(.system(size: 11, weight: .black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.48))
            }

            Text("Something in this room wants to be noticed before you go.")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Look around for one real detail: a color, a sound, a shadow, the weight of your phone, the weather through the window. If it feels worth keeping, choose Keep and write one sentence. If not, choose Let it wait. Both are correct.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                rehearsalButton(.wait, title: "Let it wait", symbol: "clock")
                rehearsalButton(.keep, title: "Keep this page", symbol: "archivebox")
            }

            if rehearsalChoice == .keep {
                firstSentenceHelp
                onboardingField("One true sentence...", text: $firstSouvenir)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if rehearsalChoice == .wait {
	                Text("Good. Letting weak pages pass keeps the archive honest.")
	                    .font(.callout.weight(.semibold))
	                    .foregroundStyle(BookPalette.teal)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .background(BookPalette.page.opacity(0.66), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
    }

    private var onboardingIlluminatedPhotoDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "photo.artframe")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 30, height: 30)
                    .background(BookPalette.nightPanel.opacity(0.9), in: Circle())
	                Text("Illuminated Photo demo")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.76))
	                Spacer(minLength: 0)
	                Text("LOCAL")
	                    .font(.system(size: 11, weight: .black))
	                    .foregroundStyle(BookPalette.teal)
	            }

	            Text(onboardingPhotoMessage)
	                .font(.system(.callout, design: .serif))
	                .foregroundStyle(BookPalette.ink.opacity(0.64))
	                .fixedSize(horizontal: false, vertical: true)

            if let draft = onboardingPhotoDraft {
                onboardingIlluminatedPreview(draft)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: isOnboardingPhotoLoading ? "hourglass" : "photo.on.rectangle.angled")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(BookPalette.lampGold)
                    VStack(alignment: .leading, spacing: 4) {
	                        Text(isOnboardingPhotoLoading ? "The plate is drying." : "Hand the Book one picture.")
	                            .font(.subheadline.weight(.black))
	                            .foregroundStyle(BookPalette.ink.opacity(0.78))
	                        Text("A room corner, a coffee cup, a window, a face, a page, anything ordinary enough to be true.")
	                            .font(.system(.callout, design: .serif))
	                            .foregroundStyle(BookPalette.ink.opacity(0.6))
	                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(BookPalette.paper.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 10) {
                #if canImport(PhotosUI)
                PhotosPicker(selection: $onboardingPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label(isOnboardingPhotoLoading ? "Illuminating..." : (onboardingPhotoDraft == nil ? "Choose photo" : "Choose another"), systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isOnboardingPhotoLoading)
                #endif

                #if canImport(UIKit)
                if BookCameraCaptureView.isCameraAvailable {
                    Button {
                        BookFeedback.play(.openPage)
                        isOnboardingCameraPresented = true
                    } label: {
                        Label("Take photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isOnboardingPhotoLoading)
                }
                #endif
            }
	            .font(.subheadline.weight(.bold))
	            .tint(BookPalette.teal)

            if onboardingPhotoDraft != nil {
                HStack(spacing: 10) {
                    Button {
                        keepOnboardingIlluminatedPhoto()
                    } label: {
                        Label(didKeepOnboardingPhoto ? "Kept in Book" : "Keep in Book", systemImage: didKeepOnboardingPhoto ? "checkmark.circle.fill" : "book.closed")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(didKeepOnboardingPhoto)

                    Button {
                        Task { await saveOnboardingIlluminatedPhotoToPhotos() }
                    } label: {
                        Label(isSavingOnboardingPhoto ? "Saving..." : "Save", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSavingOnboardingPhoto || onboardingPhotoPreviewURL == nil)

                    if let url = onboardingPhotoPreviewURL {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
	                .font(.subheadline.weight(.bold))
	                .tint(BookPalette.teal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(BookPalette.page.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.24), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func onboardingIlluminatedPreview(_ draft: IlluminatedPhotoDraft) -> some View {
        #if canImport(UIKit)
        if let url = onboardingPhotoPreviewURL,
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }
                .imagePreviewOnTap { url }
        } else {
            IlluminatedArtifactPreview(draft: draft, sourceImage: onboardingPhotoImage)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }
        }
        #else
        IlluminatedArtifactPreview(draft: draft, sourceImage: nil)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
        #endif
    }

    private func onboardingChoiceList(choices: [OnboardingChoice], selection: Binding<String>) -> some View {
        VStack(spacing: 8) {
            ForEach(choices) { choice in
                let selected = selection.wrappedValue == choice.id
                Button {
                    isOnboardingFieldFocused = false
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selection.wrappedValue = choice.id
                    }
                    BookFeedback.play(.select)
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: selected ? "checkmark.circle.fill" : choice.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(selected ? BookPalette.teal : BookPalette.lampGold)
                            .frame(width: 30, height: 30)
                            .background((selected ? BookPalette.teal : BookPalette.lampGold).opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
	                            Text(choice.title)
	                                .font(.subheadline.weight(.black))
	                                .foregroundStyle(BookPalette.ink.opacity(0.82))
	                            Text(choice.detail)
	                                .font(.system(.callout, design: .serif))
	                                .foregroundStyle(BookPalette.ink.opacity(0.62))
	                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((selected ? BookPalette.teal.opacity(0.13) : BookPalette.page.opacity(0.58)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke((selected ? BookPalette.teal : BookPalette.lampGold).opacity(selected ? 0.48 : 0.18), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var onboardingWickerChoice: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
	                Image(systemName: "dice")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 28, height: 28)
                    .background(BookPalette.nightPanel.opacity(0.9), in: Circle())
	                Text("Choose the shape of the answer")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                Spacer(minLength: 0)
            }

	            Text("Each answer makes a Belief roll. Success is not winning the scene forever; failure is not losing it. It decides what kind of thread Wicker catches for the final braid.")
	                .font(.system(.callout, design: .serif))
	                .foregroundStyle(BookPalette.ink.opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(wickerChoices) { choice in
                    let selected = wickerOutcome?.choiceID == choice.id
                    Button {
                        resolveWicker(choice)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selected ? "checkmark.seal.fill" : choice.symbol)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(selected ? BookPalette.teal : BookPalette.lampGold)
                                .frame(width: 32, height: 32)
                                .background((selected ? BookPalette.teal : BookPalette.lampGold).opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
	                                    Text(choice.title)
	                                        .font(.subheadline.weight(.black))
	                                        .foregroundStyle(BookPalette.ink.opacity(0.82))
	                                    Text("DC \(choice.difficulty)")
	                                        .font(.system(size: 11, weight: .black))
	                                        .foregroundStyle(BookPalette.ink.opacity(0.46))
                                }
	                                Text(choice.detail)
	                                    .font(.system(.callout, design: .serif))
	                                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected ? BookPalette.teal.opacity(0.13) : BookPalette.page.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke((selected ? BookPalette.teal : BookPalette.lampGold).opacity(selected ? 0.48 : 0.18), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            if let outcome = wickerOutcome,
               let choice = wickerChoice(for: outcome.choiceID) {
                VStack(alignment: .leading, spacing: 8) {
	                    HStack(spacing: 8) {
	                        Image(systemName: outcome.succeeded ? "sparkles" : "exclamationmark.triangle")
	                            .font(.subheadline.weight(.black))
	                            .foregroundStyle(outcome.succeeded ? BookPalette.teal : BookPalette.lampGold)
	                        Text(outcome.succeeded ? "Belief holds" : "Belief wobbles")
	                            .font(.subheadline.weight(.black))
	                            .foregroundStyle(BookPalette.ink.opacity(0.76))
	                        Spacer(minLength: 0)
	                        Text("\(outcome.roll) / \(outcome.difficulty)")
	                            .font(.system(size: 12, weight: .black))
	                            .foregroundStyle(BookPalette.ink.opacity(0.54))
	                    }
	                    Text(outcome.succeeded ? choice.successLine : choice.failureLine)
	                        .font(.system(.callout, design: .serif))
	                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background((outcome.succeeded ? BookPalette.teal : BookPalette.lampGold).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke((outcome.succeeded ? BookPalette.teal : BookPalette.lampGold).opacity(0.28), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.2), lineWidth: 1)
        }
    }

    private func resolveWicker(_ choice: WickerModeChoice) {
        isOnboardingFieldFocused = false
        let roll = wickerRoll(for: choice)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
            wickerOutcome = WickerBeliefOutcome(
                choiceID: choice.id,
                roll: roll,
                difficulty: choice.difficulty,
                succeeded: roll >= choice.difficulty
            )
        }
        BookFeedback.play(roll >= choice.difficulty ? .braidComplete : .select)
    }

    private func wickerRoll(for choice: WickerModeChoice) -> Int {
        let seed = [
            name.trimmingCharacters(in: .whitespacesAndNewlines),
            belief.trimmingCharacters(in: .whitespacesAndNewlines),
            sleeveWord ?? "",
            drawnChapterID,
            choice.id
        ].joined(separator: "|")
        let base = abs(seed.stableHash) % 100
        let beliefBonus = investedBelief ? 12 : 4
        return min(100, base + beliefBonus)
    }

    private func wickerChoice(for id: String) -> WickerModeChoice? {
        wickerChoices.first { $0.id == id }
    }

    private var didCompleteFirstDoorArrival: Bool {
        didWakeFirstInk && sleeveWord != nil && didSteadyFirstPage
    }

    private func onboardingInkWakeAction() -> some View {
        Button {
            isOnboardingFieldFocused = false
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                didWakeFirstInk = true
            }
            BookFeedback.play(.openPage)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(BookPalette.ink.opacity(didWakeFirstInk ? 0.18 : 0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: didWakeFirstInk ? "drop.fill" : "drop")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(didWakeFirstInk ? BookPalette.teal : BookPalette.ink.opacity(0.72))
                        .shadow(color: BookPalette.teal.opacity(didWakeFirstInk ? 0.45 : 0), radius: 9)
                }
                VStack(alignment: .leading, spacing: 4) {
	                    Text(didWakeFirstInk ? "The ink notices you." : "Touch the first wet word.")
	                        .font(.subheadline.weight(.black))
	                        .foregroundStyle(BookPalette.ink.opacity(0.78))
	                    Text(didWakeFirstInk ? "It leaves a tiny black star on your fingertip." : "The word is looking back. It should not be able to do that.")
	                        .font(.system(.callout, design: .serif))
	                        .foregroundStyle(BookPalette.ink.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.page.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((didWakeFirstInk ? BookPalette.teal : BookPalette.lampGold).opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(didWakeFirstInk ? "The ink notices you" : "Touch the first wet word")
    }

    private func onboardingSleeveWordChoice() -> some View {
        VStack(alignment: .leading, spacing: 10) {
	            Text(sleeveWord.map { "\($0) catches and stays." } ?? "Which word catches on your sleeve?")
	                .font(.subheadline.weight(.black))
	                .foregroundStyle(BookPalette.ink.opacity(0.72))
            HStack(spacing: 8) {
                ForEach(sleeveWords, id: \.self) { word in
                    let selected = sleeveWord == word
                    Button {
                        isOnboardingFieldFocused = false
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            sleeveWord = word
                        }
                        BookFeedback.play(.select)
                    } label: {
	                        Text(word)
	                            .font(.system(size: 14, weight: .black, design: .serif))
	                            .tracking(0.6)
                            .foregroundStyle(selected ? BookPalette.nightText : BookPalette.ink.opacity(0.74))
                            .lineLimit(1)
	                            .minimumScaleFactor(0.88)
	                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(
                                selected ? BookPalette.teal.opacity(0.88) : BookPalette.paper.opacity(0.56),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke((selected ? BookPalette.teal : BookPalette.lampGold).opacity(0.32), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func onboardingSteadyPageAction() -> some View {
        Button {
            steadyFirstPage()
        } label: {
            HStack(spacing: 12) {
            Image(systemName: didSteadyFirstPage ? "hand.raised.fill" : "hand.raised")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(didSteadyFirstPage ? BookPalette.teal : BookPalette.ink.opacity(0.72))
                .frame(width: 42, height: 42)
                .background(BookPalette.paper.opacity(0.62), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
	                Text(didSteadyFirstPage ? "The page steadies." : "Hold still against the page.")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.78))
	                Text(didSteadyFirstPage ? "The stone floor decides to be under you." : "For one breath, press back. Let down become down again.")
	                    .font(.system(.callout, design: .serif))
	                    .foregroundStyle(BookPalette.ink.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(BookPalette.page.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((didSteadyFirstPage ? BookPalette.teal : BookPalette.lampGold).opacity(0.28), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(didSteadyFirstPage ? "The page steadies" : "Hold still against the page")
        .accessibilityHint("Tap to continue the arrival.")
        .accessibilityAction {
            steadyFirstPage()
        }
    }

    private func steadyFirstPage() {
        guard !didSteadyFirstPage else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            didSteadyFirstPage = true
        }
        BookFeedback.play(.braidComplete)
    }

    private func onboardingUnwrittenMarginDrag() -> some View {
        VStack(alignment: .leading, spacing: 10) {
	            Text(didTuckUnwrittenWord ? "The margin accepts the word." : "Move UNWRITTEN into the margin.")
	                .font(.subheadline.weight(.black))
	                .foregroundStyle(BookPalette.ink.opacity(0.72))

            HStack(spacing: 12) {
                Text("UNWRITTEN")
                    .font(.system(size: 12, weight: .black, design: .serif))
                    .tracking(1.2)
                    .foregroundStyle(didTuckUnwrittenWord ? BookPalette.nightText : BookPalette.ink.opacity(0.78))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        didTuckUnwrittenWord ? BookPalette.teal.opacity(0.88) : BookPalette.paper.opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(0.26), lineWidth: 1)
                    }
                    .offset(didTuckUnwrittenWord ? CGSize(width: 78, height: 0) : unwrittenWordDrag)
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { value in
                                guard !didTuckUnwrittenWord else { return }
                                unwrittenWordDrag = value.translation
                            }
                            .onEnded { value in
                                guard !didTuckUnwrittenWord else { return }
                                if value.translation.width > 70 {
                                    tuckUnwrittenWord()
                                } else {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
                                        unwrittenWordDrag = .zero
                                    }
                                }
                            }
                    )
                    .accessibilityAction {
                        tuckUnwrittenWord()
                    }

                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    Image(systemName: didTuckUnwrittenWord ? "checkmark.seal.fill" : "sidebar.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(didTuckUnwrittenWord ? BookPalette.teal : BookPalette.lampGold)
	                    Text("MARGIN")
	                        .font(.system(size: 11, weight: .black))
	                        .foregroundStyle(BookPalette.ink.opacity(0.52))
                }
                .frame(width: 72, height: 54)
                .background(BookPalette.paper.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(didTuckUnwrittenWord ? 0.42 : 0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }

            if !didTuckUnwrittenWord {
                secondaryOnboardingButton("Tuck into margin", systemImage: "sidebar.right") {
                    tuckUnwrittenWord()
                }
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.54), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func tuckUnwrittenWord() {
        guard !didTuckUnwrittenWord else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
            didTuckUnwrittenWord = true
            unwrittenWordDrag = .zero
        }
        BookFeedback.play(.select)
    }

    private func onboardingBeliefSigil(_ belief: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(BookPalette.lampGold.opacity(0.18))
                    .frame(width: 58, height: 58)
                Circle()
                    .stroke(BookPalette.lampGold.opacity(0.48), lineWidth: 1.4)
                    .frame(width: 58, height: 58)
                Image(systemName: "sparkles")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .shadow(color: BookPalette.lampGold.opacity(0.45), radius: 8)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
	                Text("A sigil takes shape")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.78))
	                Text("\"\(belief)\" now has an edge the Book can recognize. If you plant Belief here, it becomes a living motif in the Labyrinth.")
	                    .font(.system(.callout, design: .serif))
	                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.page.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.24), lineWidth: 1)
        }
    }

    private func rehearsalButton(_ choice: OnboardingRehearsalChoice, title: String, symbol: String) -> some View {
        let selected = rehearsalChoice == choice
        return Button {
            BookFeedback.play(choice == .keep ? .keepPage : .dismissPage)
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                rehearsalChoice = choice
            }
            if choice == .keep {
                rehearsalInkBurstTrigger += 1
            }
        } label: {
	            Label(title, systemImage: selected ? "checkmark.circle.fill" : symbol)
	                .font(.subheadline.weight(.black))
	                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background((selected ? BookPalette.teal : BookPalette.paper).opacity(selected ? 0.22 : 0.48),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke((selected ? BookPalette.teal : BookPalette.ink).opacity(selected ? 0.52 : 0.14), lineWidth: 1)
                }
        }
        .buttonStyle(.bookPress())
        .foregroundStyle(selected ? BookPalette.teal : BookPalette.ink.opacity(0.72))
        .overlay {
            if choice == .keep {
                LivingInkBurst(
                    trigger: rehearsalInkBurstTrigger,
                    text: firstSouvenir.nonEmpty ?? "KEEP",
                    mood: .kept,
                    intensity: 0.46
                )
                .padding(.horizontal, 16)
            }
        }
    }

    private var onboardingCastGlimpse: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                onboardingCastCard(OnboardingCastMember(
                    image: "LabyrinthCharacterZaraFinch",
                    name: "Zara",
                    line: "opens the door",
                    tint: BookPalette.teal
                ))
                onboardingCastCard(OnboardingCastMember(
                    image: "LabyrinthCharacterFinnBridges",
                    name: "Finn",
                    line: "finds the path",
                    tint: BookPalette.violet
                ))
            }
            HStack(spacing: 8) {
                onboardingCastCard(OnboardingCastMember(
                    image: "LabyrinthCharacterPennyBlackletter",
                    name: "Penny",
                    line: "spots the glint",
                    tint: BookPalette.gold
                ))
                onboardingCastCard(OnboardingCastMember(
                    image: "LabyrinthCharacterOrionBlackthorn",
                    name: "Orion",
                    line: "guards the threshold",
                    tint: BookPalette.lampGold
                ))
            }
        }
    }

    private var onboardingChapterAffinityPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
	                Image(systemName: "sparkles")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 26, height: 26)
                    .background(BookPalette.nightPanel.opacity(0.88), in: Circle())
	                Text("A first tug, not a Binding")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.74))
                Spacer(minLength: 0)
            }

	            Text("\"The talisman with the most Belief quietly influences everything,\" Zara says. \"What pages appear more often. Which invitations repeat. The atmosphere the Book reaches for first. Three points won't decide your fate, but it will teach the shelves what scent to try.\"")
	                .font(.system(.callout, design: .serif))
	                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(Array(AcademyChapterRegistry.publicChapters.enumerated()), id: \.element.id) { index, chapter in
                    let selected = drawnChapterID == chapter.id
                    Button {
                        isOnboardingFieldFocused = false
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                            drawnChapterID = chapter.id
                        }
                        BookFeedback.play(.select)
                    } label: {
                        HStack(alignment: .top, spacing: 13) {
                            chapterBannerIllustration(for: chapter, selected: selected)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 7) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(chapter.name)
                                        .font(.subheadline.weight(.black))
                                        .foregroundStyle(BookPalette.ink.opacity(0.84))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.84)
	                                    Text("3 Belief")
	                                        .font(.system(size: 12, weight: .black))
	                                        .foregroundStyle(selected ? BookPalette.nightText : BookPalette.teal)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background((selected ? BookPalette.teal : BookPalette.teal.opacity(0.12)), in: Capsule())
                                        .lineLimit(1)
                                }

                                Text(chapterSimpleMeaning(for: chapter))
                                    .font(.system(.callout, design: .serif))
                                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(chapterSurprise(for: chapter))
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("\(chapter.talismanName) warms. The Book tries this argument first.")
                                    .font(.footnote.weight(.black))
                                    .foregroundStyle(selected ? BookPalette.teal : BookPalette.ink.opacity(0.62))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected ? BookPalette.teal.opacity(0.13) : BookPalette.page.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke((selected ? BookPalette.teal : BookPalette.lampGold).opacity(selected ? 0.48 : 0.18), lineWidth: 1)
                        }
                        .rotation3DEffect(
                            .degrees(selected ? -2 : Double(index - 2) * 1.8),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.65
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.2), lineWidth: 1)
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private func chapterBannerIllustration(for chapter: AcademyChapter, selected: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: selected ? "checkmark.seal.fill" : chapter.symbolName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(selected ? BookPalette.teal : BookPalette.lampGold)
                .frame(width: 42, height: 42)
                .background((selected ? BookPalette.teal : BookPalette.lampGold).opacity(0.12), in: Circle())

            Text(chapterIllustrationLabel(for: chapter))
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(width: 64)
                .frame(minHeight: 24)
        }
        .frame(width: 70)
    }

    private func chapterIllustrationLabel(for chapter: AcademyChapter) -> String {
        switch chapter.id {
        case "emberheart": return "a match\nin a hand"
        case "mossbloom": return "roots under\na stone"
        case "tidecrest": return "a wave in\na teacup"
        case "riddlewind": return "two hands\non a map"
        case "duskthorn": return "a thorn by\na candle"
        default: return chapter.talismanName
        }
    }

    private func chapterSimpleMeaning(for chapter: AcademyChapter) -> String {
        switch chapter.id {
        case "emberheart":
            return "Zara says Emberheart believes wonder starts when you choose to move. It likes beginnings, dares, and doors you open yourself."
        case "mossbloom":
            return "Zara says Mossbloom believes the world is already talking. It teaches you to slow down until the ordinary thing becomes specific."
        case "tidecrest":
            return "Zara says Tidecrest believes a moment does not need to become a lesson. It wants you awake enough to be surprised."
        case "riddlewind":
            return "Zara says Riddlewind believes meaning gets stronger when it is shared. It looks for jokes, questions, and other people."
        case "duskthorn":
            return "Zara says Duskthorn believes a story needs an edge. It does not worship darkness; it refuses to lie about what is there."
        default:
            return chapter.philosophy
        }
    }

    private func chapterSurprise(for chapter: AcademyChapter) -> String {
        switch chapter.id {
        case "emberheart":
            return "\"Surprising thing,\" Zara says. \"The brave Chapter is mostly afraid of wasting its life.\""
        case "mossbloom":
            return "\"Surprising thing,\" Zara says. \"The quiet Chapter notices trouble first.\""
        case "tidecrest":
            return "\"Surprising thing,\" Zara says. \"The playful Chapter is serious about not making everything useful.\""
        case "riddlewind":
            return "\"Surprising thing,\" Zara says. \"The friendly Chapter wins more arguments than the clever one.\""
        case "duskthorn":
            return "\"Surprising thing,\" Zara says. \"The thorny Chapter is often the kindest, because it names the real wound.\""
        default:
            return "\(chapter.talismanName) changes what the Book reaches for first."
        }
    }

    private func onboardingCastCard(_ member: OnboardingCastMember) -> some View {
        Button {
            guard let url = ImagePreview.url(forAsset: member.image) else {
                BookFeedback.play(.error)
                return
            }
            BookFeedback.play(.openPage)
            castPreviewURL = url
        } label: {
            VStack(spacing: 8) {
                Image(member.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(member.tint.opacity(0.72), lineWidth: 1.4)
                    }
                    .shadow(color: member.tint.opacity(0.22), radius: 8)
                    .accessibilityHidden(true)
	                Text(member.name)
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink)
	                Text(member.line)
	                    .font(.system(size: 12, weight: .semibold))
	                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, minHeight: 126)
            .padding(10)
            .background(BookPalette.paper.opacity(0.46), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(member.tint.opacity(0.18), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
	                    Image(systemName: "arrow.up.left.and.arrow.down.right")
	                    .font(.system(size: 11, weight: .black))
	                    .foregroundStyle(member.tint.opacity(0.7))
                    .padding(6)
            }
        }
        .buttonStyle(.bookPress())
        .accessibilityLabel("Open full illustration of \(member.name)")
    }

    #if canImport(PhotosUI)
    @MainActor
    private func loadOnboardingPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            BookFeedback.play(.error)
            onboardingPhotoMessage = "That photo would not open. You can skip this plate and still continue."
            return
        }
        await loadOnboardingPhoto(imageData: data)
    }
    #endif

    @MainActor
    private func loadOnboardingPhoto(imageData data: Data) async {
        isOnboardingPhotoLoading = true
        onboardingPhotoMessage = "The Book is gilding the edges locally. No Gemma, no waiting for a reader in the wall."
        defer { isOnboardingPhotoLoading = false }

        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            BookFeedback.play(.error)
            onboardingPhotoMessage = "That photo would not open. You can skip this plate and still continue."
            return
        }
        let analysis = onboardingPhotoDemoAnalysis(for: image, byteCount: data.count)
        let draft = IlluminatedPageComposer.compose(
            analysis: analysis,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: data.count ^ Int(Date().timeIntervalSinceReferenceDate * 1000),
            assetLocalIdentifier: "onboarding-local:\(UUID().uuidString)"
        )
        let renderedURL = IlluminatedPageRenderer.renderPreview(draft: draft, sourceImage: image)
        onboardingPhotoImage = image
        onboardingPhotoDraft = draft
        onboardingPhotoPreviewURL = renderedURL
        didKeepOnboardingPhoto = false
        onboardingPhotoMessage = renderedURL == nil
            ? "The margins are ready. This first version uses a local fallback frame; the fuller photo page can read subjects later."
            : "The plate is ready. This first version illuminated your photo locally, without Gemma."
        BookFeedback.play(.braidComplete)
        #else
        BookFeedback.play(.error)
        onboardingPhotoMessage = "Photo illumination needs image support on this device."
        #endif
    }

    #if canImport(UIKit)
    private func onboardingPhotoDemoAnalysis(for image: UIImage, byteCount: Int) -> PhotoAnalysis {
        let size = image.size
        let orientation = size.width > size.height ? "landscape" : (size.height > size.width ? "portrait" : "square")
        let megapixels = max(0.1, (size.width * size.height) / 1_000_000)
        return PhotoAnalysisValidator.validate(PhotoAnalysis(
            scene: "A private \(orientation) photo chosen at the First Door.",
            motifs: ["photo", "first-door", "private", orientation],
            mood: "fresh evidence",
            suggestedTemplate: .academyFieldStudy,
            marginalia: PhotoMarginalia(
                fieldNote: "First Door plate. Chosen by hand, illuminated locally.",
                stampLabel: "PRIVATE PHOTO PLATE",
                observationList: [
                    "The Book received one \(orientation) photograph.",
                    "The image stayed in the room; no Gemma reading was requested.",
                    String(format: "The plate carries roughly %.1f megapixels of real light.", megapixels)
                ],
                closingLine: "The Book does not need a grand subject. It needs evidence."
            ),
            souvenirCandidates: [
                "A real photo became the first illuminated plate.",
                "The ordinary image accepted gold at the edges."
            ]
        ))
    }
    #endif

    @MainActor
    private func keepOnboardingIlluminatedPhoto() {
        guard let draft = onboardingPhotoDraft else { return }
        onKeepIlluminatedPhoto(draft, onboardingPhotoPreviewURL)
        didKeepOnboardingPhoto = true
        onboardingPhotoMessage = "Kept. The illuminated plate is tucked into Today's Margins."
        BookFeedback.play(.keepPage)
    }

    @MainActor
    private func saveOnboardingIlluminatedPhotoToPhotos() async {
        guard let artifactURL = onboardingPhotoPreviewURL else {
            BookFeedback.play(.error)
            onboardingPhotoMessage = "The plate is not ready to save yet."
            return
        }
        isSavingOnboardingPhoto = true
        defer { isSavingOnboardingPhoto = false }

        #if canImport(Photos)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: artifactURL)
            }
            onboardingPhotoMessage = "Saved. The illuminated plate is tucked into Photos."
            BookFeedback.play(.keepPage)
        } catch {
            onboardingPhotoMessage = "Photos would not take the plate yet. Check photo permissions, then try again."
            BookFeedback.play(.error)
        }
        #else
        onboardingPhotoMessage = "This build cannot save to Photos, but the plate is ready to share."
        #endif
    }

    private var firstSentenceHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 28, height: 28)
                    .background(BookPalette.nightPanel.opacity(0.9), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(BookPalette.lampGold.opacity(0.5), lineWidth: 1)
                    }
                    .shadow(color: BookPalette.lampGold.opacity(0.25), radius: 6)
	                Text("Sentence helper: Zara's margin notes")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                Spacer(minLength: 0)
            }

	            Text("\"This little helper is a work in progress,\" Zara says. \"Use it if the blank page goes stiff. Don't write like a professional writer. Write like someone leaving a pin in the day. It only has to be specific enough that, when you read it again, the moment comes back.\" Tap one to start, then change it until it sounds like your actual room.")
	                .font(.system(.callout, design: .serif))
	                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 7) {
                ForEach(firstSentenceStarters, id: \.self) { starter in
                    Button {
                        if firstSouvenir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            firstSouvenir = starter
                        }
                        isOnboardingFieldFocused = true
                        BookFeedback.play(.select)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(BookPalette.nightPanel)
                                .frame(width: 22, height: 22)
                                .background(BookPalette.lampGold.opacity(0.82), in: Circle())
	                            Text(starter)
	                                .font(.system(.callout, design: .serif))
	                                .foregroundStyle(BookPalette.ink.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BookPalette.paper.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.18), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Fills the first sentence field if it is empty")
                }
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.46), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.18), lineWidth: 1)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var closingProse: String {
        let planted = investedBelief
            ? "Somewhere deep in the Register, ink moves. Your belief now has a Glow of its own. It'll start shaping what finds you.\n\n"
            : "Zara nods. \"Wise. Some things you keep.\"\n\n"
        return """
        \(planted)"One last correction," Zara says, walking you toward a desk where a book lies open to a blank page — your page. "You didn't open an app. You entered the Book. You're standing in its story now, and your life outside is one of its Chapters. Both are real. The binding's simply strange."

        "Pages rise to meet your real day. Keep the ones worth keeping. Let the others wait without guilt."

        "The three wax seals are shortcuts: body, sky, and ground. Tap them when you want the Book to listen in that direction."

        "Give Belief to whatever you want the Book to treat as more real. More Belief means brighter Glow, more appearances, and more gravity in the story."

        "At night, read your Book of You. It'll braid what you kept into a fuller page. Those pages become patterns, friendships, rivalries, and eventually the evidence the Chapters use when they Bind you."

        A grey bite appears at the edge of the blank paper. Zara puts your first true sentence over it, and the damage stops.

        She taps the cover once. "That's the work. Re-enchant the Unwritten before the Nothing convinces you it was ordinary. Off you go."
        """
    }

    private var tasteTitle: String {
        tasteChoices.first { $0.id == tastePreference }?.title ?? "Pages"
    }

    private var comfortTitle: String {
        comfortChoices.first { $0.id == comfortBoundary }?.title ?? "Balanced"
    }

    private var whisperTitle: String {
        whisperChoices.first { $0.id == whisperCadence }?.title ?? "Only inside the covers"
    }

    private var drawnChapter: AcademyChapter? {
        AcademyChapterRegistry.chapter(id: drawnChapterID)
    }

    private var wickerModeTitle: String {
        wickerOutcome.flatMap { wickerChoice(for: $0.choiceID)?.title } ?? "an unanswered story"
    }

    private var wickerBraidLine: String {
        guard let outcome = wickerOutcome,
              let choice = wickerChoice(for: outcome.choiceID) else {
            return "Wicker stepped into the archway, but the Book left that page unchosen."
        }
        let result = outcome.succeeded ? "held" : "wobbled"
        let line = outcome.succeeded ? choice.successLine : choice.failureLine
        return "When Wicker challenged them, they chose \(choice.title.lowercased()). The Belief roll \(result): \(outcome.roll) against \(outcome.difficulty). \(line)"
    }

    private var firstDoorMiniStory: String {
        let reader = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"
        let ration = snack.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "an unnamed snack"
        let coreBelief = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "something still unnamed"
        let word = sleeveWord ?? "GLINT"
        let sentence = firstSouvenir.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let pageChoice: String
        if let sentence {
            pageChoice = "When the practice page rose, you kept it with one sentence: \"\(sentence)\""
        } else {
            pageChoice = "When the practice page rose, you let it wait, which is also a kind of accuracy."
        }
        let beliefLine = investedBelief
            ? "You planted three Belief in \"\(coreBelief),\" and the phrase began to Glow as if it had been waiting for a body."
            : "You named \"\(coreBelief)\" and kept your Belief in hand, which the Book marked as patience rather than refusal."
        let chapterLine = drawnChapter.map { chapter in
            "In the hall of banners, \(chapter.name) tugged first. Zara warmed \(chapter.talismanName) with three Belief, not as a Binding, but as an early scent for the shelves."
        } ?? "In the hall of banners, the Chapters watched without choosing a favorite yet."
        let whisperLine = whisperCadence == "inside"
            ? "The brass bell closed itself without complaint. The Book will keep its voice inside the covers."
            : "The brass bell learned your first preference: \(whisperTitle.lowercased()). It will ask the system politely before it speaks outside the app."

        return """
        Zara turns the blank page toward you, and for the first time it writes without asking a question.

        \(reader) came through the screen while the ink was still wet. They touched the first word, steadied the falling page, and chose \(word) from the flock of names that tried to catch on their sleeve. The margin accepted UNWRITTEN because they moved it there by hand.

        The Book wrote \(ration) beside their name as a private ration for long shelves and difficult footnotes. \(beliefLine)

        \(pageChoice)

        \(chapterLine)

        \(wickerBraidLine)

        By the time the cast noticed, the Book had learned a first appetite: \(tasteTitle.lowercased()). It also learned an edge: \(comfortTitle.lowercased()). \(whisperLine)

        A grey bite appears at the edge of the paper. Zara places the page you made over it. The damage stops.

        "There," she says. "Not a profile. A beginning."
        """
    }

	    private func guidePortrait(mood: String) -> some View {
	        HStack(spacing: 12) {
	            Image("LabyrinthCharacterZaraFinchGuidePortrait")
	                .resizable()
	                .scaledToFill()
	                .frame(width: 84, height: 84)
	                .clipShape(Circle())
	                .overlay {
	                    Circle()
	                        .stroke(BookPalette.lampGold.opacity(0.7), lineWidth: 1.6)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "sparkle")
                        .font(.caption.weight(.black))
                        .foregroundStyle(BookPalette.lampGold)
                        .padding(6)
                        .background(BookPalette.nightPanel, in: Circle())
                }
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 5)
                .accessibilityLabel("Zara Finch, your guide")

            Text(mood)
                .font(.system(.callout, design: .serif).italic())
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(BookPalette.paper.opacity(0.44), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func onboardingTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .bold, design: .serif))
            .foregroundStyle(BookPalette.ink)
            .shadow(color: BookPalette.page.opacity(0.75), radius: 2, x: 0, y: 1)
            .shadow(color: BookPalette.lampGold.opacity(0.20), radius: 8, x: 0, y: 2)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isOnboardingFieldFocused = false
            }
    }

    private func onboardingProse(_ text: String) -> some View {
        InkSettlingProse(text: text) {
            isOnboardingFieldFocused = false
        }
    }

    /// Onboarding prose that settles in like wet ink: each paragraph fades up
    /// and un-blurs in turn, giving every beat a small reading rhythm instead
    /// of a wall of text appearing at once. Falls back to an instant render
    /// when Reduce Motion is on. Re-runs whenever a new beat presents it.
    private struct InkSettlingProse: View {
        let text: String
        var onTap: () -> Void = {}

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var settled = false

        private var paragraphs: [String] {
            text
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    Text(paragraph)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.86))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(settled ? 1 : 0)
                        .blur(radius: settled ? 0 : 4)
                        .offset(y: settled ? 0 : 6)
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeOut(duration: 0.5).delay(min(Double(index) * 0.12, 1.2)),
                            value: settled
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onAppear { settled = true }
        }
    }

	    private func onboardingField(_ placeholder: String, text: Binding<String>) -> some View {
	        TextField(placeholder, text: text, axis: .vertical)
	            .font(.system(.title3, design: .serif))
	            .foregroundStyle(BookPalette.ink)
	            .textFieldStyle(.plain)
	            .lineLimit(1...3)
            .focused($isOnboardingFieldFocused)
            .dictationInput(text: text)
            .padding(12)
            .background(BookPalette.paper.opacity(0.8), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
            }
    }

	    private func continueButton(_ title: String, disabled: Bool = false) -> some View {
	        Button {
            isOnboardingFieldFocused = false
            BookFeedback.play(.openPage)
            advance()
	        } label: {
	            Label(title, systemImage: "arrow.right")
	                .font(.title3.weight(.bold))
	                .frame(maxWidth: .infinity)
	                .padding(.vertical, 14)
	        }
        .buttonStyle(.borderedProminent)
        .tint(BookPalette.teal)
        .disabled(disabled)
    }

    private func secondaryOnboardingButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            isOnboardingFieldFocused = false
            BookFeedback.play(.select)
            withAnimation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.84)) {
                action()
            }
	        } label: {
	            Label(title, systemImage: systemImage)
	                .font(.body.weight(.bold))
	                .foregroundStyle(BookPalette.ink.opacity(0.76))
	                .frame(maxWidth: .infinity)
	                .padding(.vertical, 12)
                .background(BookPalette.paper.opacity(0.64), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func onboardingSystemStrip(_ items: [(String, String)]) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.1) { item in
                VStack(spacing: 6) {
                    Image(systemName: item.0)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BookPalette.lampGold)
	                    Text(item.1)
	                        .font(.system(size: 12, weight: .bold))
	                        .foregroundStyle(BookPalette.ink.opacity(0.68))
	                        .multilineTextAlignment(.center)
	                        .lineLimit(2)
	                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity, minHeight: 66)
                .padding(.horizontal, 6)
                .background(BookPalette.paper.opacity(0.44), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.18), lineWidth: 1)
                }
            }
        }
    }

	    private func onboardingPreviewCard(symbol: String, title: String, body: String) -> some View {
	        HStack(alignment: .top, spacing: 12) {
	            Image(systemName: symbol)
	                .font(.system(size: 19, weight: .semibold))
	                .foregroundStyle(BookPalette.teal)
	                .frame(width: 34, height: 34)
	                .background(BookPalette.teal.opacity(0.12), in: Circle())

	            VStack(alignment: .leading, spacing: 6) {
	                Text(title)
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.78))
	                Text(body)
	                    .font(.system(.callout, design: .serif))
	                    .foregroundStyle(BookPalette.ink.opacity(0.66))
	                    .lineSpacing(2)
	                    .fixedSize(horizontal: false, vertical: true)
	            }
	        }
	        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.page.opacity(0.56), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            isOnboardingFieldFocused = false
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.18), lineWidth: 1)
        }
    }

	    private var onboardingScienceLedger: some View {
	        VStack(alignment: .leading, spacing: 16) {
	            HStack(alignment: .top, spacing: 10) {
	                Image(systemName: "text.book.closed")
	                    .font(.system(size: 18, weight: .black))
	                    .foregroundStyle(BookPalette.nightText)
	                    .frame(width: 38, height: 38)
	                    .background(BookPalette.nightPanel.opacity(0.92), in: Circle())
	                    .overlay {
	                        Circle()
	                            .stroke(BookPalette.lampGold.opacity(0.46), lineWidth: 1)
	                    }

	                VStack(alignment: .leading, spacing: 6) {
	                    Text("Proof it is not just you")
	                        .font(.subheadline.weight(.black))
	                        .foregroundStyle(BookPalette.ink.opacity(0.84))
	                    Text("The magic has receipts. The short version: minds drift, wonder helps, and writing one real detail helps memory.")
	                        .font(.system(.callout, design: .serif))
	                        .foregroundStyle(BookPalette.ink.opacity(0.72))
	                        .lineSpacing(2)
	                        .fixedSize(horizontal: false, vertical: true)
	                }
	            }

	            VStack(alignment: .leading, spacing: 10) {
		                Text("Studies show that we check out for 46.9% of our day.")
		                    .font(.system(.body, design: .serif).weight(.semibold))
		                    .foregroundStyle(BookPalette.ink.opacity(0.9))
		                    .fixedSize(horizontal: false, vertical: true)

		                Text("Almost half our waking lives are lost to \"autopilot\" - it's just how our brains are wired.")
		                    .font(.system(.callout, design: .serif))
		                    .foregroundStyle(BookPalette.ink.opacity(0.76))
	                    .lineSpacing(2)
	                    .fixedSize(horizontal: false, vertical: true)

		                Text("Autopilot leads to fewer memories, blurrier days, more rumination, and the feeling that whole weeks are disappearing. ReEnchanted helps by giving you tiny reasons to look, keep, and come back.")
		                    .font(.system(.callout, design: .serif))
		                    .foregroundStyle(BookPalette.teal.opacity(0.9))
	                    .lineSpacing(2)
	                    .fixedSize(horizontal: false, vertical: true)
	            }
	            .padding(13)
	            .background(BookPalette.page.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
	            .overlay {
	                RoundedRectangle(cornerRadius: 8, style: .continuous)
	                    .stroke(BookPalette.teal.opacity(0.2), lineWidth: 1)
	            }

	            VStack(alignment: .leading, spacing: 8) {
	                Text("The research behind the practice")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.82))
	                Text("These are citations, not endorsements. They explain why noticing, wonder, and writing can help.")
	                    .font(.system(.footnote, design: .default))
	                    .foregroundStyle(BookPalette.ink.opacity(0.66))
	                    .fixedSize(horizontal: false, vertical: true)
	            }

	            VStack(spacing: 8) {
	                ForEach(scienceCitationItems) { item in
	                    onboardingScienceRow(item)
	                }
	            }

	            Text("Citations, not endorsements. ReEnchanted is a wonder practice, not medical care.")
	                .font(.system(.footnote, design: .default).weight(.semibold))
	                .foregroundStyle(BookPalette.ink.opacity(0.54))
	                .fixedSize(horizontal: false, vertical: true)
	        }
	        .padding(14)
	        .frame(maxWidth: .infinity, alignment: .leading)
	        .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(BookPalette.lampGold.opacity(0.9))
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            isOnboardingFieldFocused = false
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
    }

	    private func onboardingScienceRow(_ item: ScienceCitationItem) -> some View {
	        HStack(alignment: .top, spacing: 12) {
	            Image(systemName: item.symbol)
	                .font(.system(size: 16, weight: .black))
	                .foregroundStyle(BookPalette.teal)
	                .frame(width: 30, height: 30)
	                .background(BookPalette.teal.opacity(0.12), in: Circle())

	            VStack(alignment: .leading, spacing: 5) {
	                Text(item.title)
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.78))
	                Text(item.finding)
	                    .font(.system(.footnote, design: .default))
	                    .foregroundStyle(BookPalette.ink.opacity(0.66))
	                    .fixedSize(horizontal: false, vertical: true)
	                Text(item.source)
	                    .font(.system(.footnote, design: .default).weight(.black))
	                    .foregroundStyle(BookPalette.teal.opacity(0.86))
	                    .fixedSize(horizontal: false, vertical: true)
	            }

            Spacer(minLength: 0)
        }
	        .padding(.horizontal, 12)
	        .padding(.vertical, 11)
	        .background(BookPalette.page.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.08), lineWidth: 1)
        }
    }

	    private var onboardingNotYourFaultCard: some View {
	        HStack(alignment: .top, spacing: 12) {
	            VStack(spacing: 2) {
	                Text("NOT")
	                    .font(.system(size: 19, weight: .black, design: .rounded))
	                    .foregroundStyle(BookPalette.nightText)
	                    .lineLimit(1)
	                Text("YOUR FAULT")
	                    .font(.system(size: 11, weight: .black))
	                    .foregroundStyle(BookPalette.nightText.opacity(0.78))
	                    .textCase(.uppercase)
	                    .lineLimit(1)
	            }
	            .frame(width: 92, height: 62)
	            .background(BookPalette.teal.opacity(0.96), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
	            .overlay {
	                RoundedRectangle(cornerRadius: 8, style: .continuous)
	                    .stroke(BookPalette.lampGold.opacity(0.45), lineWidth: 1)
	            }

	            VStack(alignment: .leading, spacing: 7) {
	                Text("It's not your fault.")
	                    .font(.title3.weight(.black))
	                    .foregroundStyle(BookPalette.ink)
	                Text("Boredom, routine, burnout, loneliness, and weeks that vanish aren't proof that you're broken. They're signs you're living on autopilot, and that you need to notice more of your life.")
	                    .font(.system(.callout, design: .serif))
	                    .foregroundStyle(BookPalette.ink.opacity(0.72))
	                    .lineSpacing(2)
	                    .fixedSize(horizontal: false, vertical: true)
	            }
	        }
	        .padding(14)
	        .frame(maxWidth: .infinity, alignment: .leading)
	        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
	        .overlay(alignment: .leading) {
	            Rectangle()
	                .fill(BookPalette.teal.opacity(0.95))
	                .frame(width: 4)
	        }
	        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
	        .overlay {
	            RoundedRectangle(cornerRadius: 10, style: .continuous)
	                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
	        }
	        .shadow(color: BookPalette.teal.opacity(0.12), radius: 16, x: 0, y: 8)
	        .contentShape(Rectangle())
	        .onTapGesture {
	            isOnboardingFieldFocused = false
	        }
	    }

	    private var onboardingBenefitChecklist: some View {
	        VStack(alignment: .leading, spacing: 14) {
	            VStack(alignment: .leading, spacing: 7) {
	                Text("What ReEnchanted gives back")
	                    .font(.title3.weight(.black))
	                    .foregroundStyle(BookPalette.ink)
	                Text("Not a perfect life. A more noticeable one: more scenes, more memory, more small reasons to feel present in the story you are already living.")
	                    .font(.system(.callout, design: .serif))
	                    .foregroundStyle(BookPalette.ink.opacity(0.72))
	                    .lineSpacing(2)
	                    .fixedSize(horizontal: false, vertical: true)
	            }

	            VStack(spacing: 10) {
	                ForEach(Array(benefitChecklistItems.enumerated()), id: \.element.id) { index, item in
	                    onboardingBenefitChecklistRow(item, isVisible: index < benefitChecklistVisibleCount)
	                }
	            }

		            Text("The point is simple: notice more, save more, remember more, and feel more alive in the life you already have.")
	                .font(.system(.footnote, design: .serif).weight(.semibold))
	                .foregroundStyle(BookPalette.ink.opacity(0.58))
	                .fixedSize(horizontal: false, vertical: true)
	                .opacity(benefitChecklistVisibleCount >= benefitChecklistItems.count ? 1 : 0)
                .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: benefitChecklistVisibleCount)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(BookPalette.teal.opacity(0.95))
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: BookPalette.teal.opacity(0.12), radius: 16, x: 0, y: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            isOnboardingFieldFocused = false
        }
        .onAppear {
            animateBenefitChecklist()
        }
    }

	    private func onboardingBenefitChecklistRow(_ item: BenefitChecklistItem, isVisible: Bool) -> some View {
	        HStack(alignment: .top, spacing: 12) {
	            Image(systemName: isVisible ? "checkmark.circle.fill" : item.symbol)
	                .font(.system(size: 19, weight: .black))
	                .foregroundStyle(isVisible ? BookPalette.teal : BookPalette.ink.opacity(0.34))
	                .frame(width: 28, height: 28)

	            VStack(alignment: .leading, spacing: 5) {
	                Text(item.title)
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(isVisible ? 0.84 : 0.46))
	                Text(item.detail)
	                    .font(.system(.footnote, design: .default))
	                    .foregroundStyle(BookPalette.ink.opacity(isVisible ? 0.68 : 0.38))
	                    .fixedSize(horizontal: false, vertical: true)
	            }

            Spacer(minLength: 0)
        }
	        .padding(.horizontal, 12)
	        .padding(.vertical, 11)
        .background(
            isVisible ? BookPalette.page.opacity(0.64) : BookPalette.page.opacity(0.26),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isVisible ? BookPalette.teal.opacity(0.18) : BookPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .opacity(isVisible ? 1 : 0.54)
        .offset(y: reduceMotion || isVisible ? 0 : 8)
        .animation(reduceMotion ? .none : .spring(response: 0.34, dampingFraction: 0.84), value: isVisible)
    }

    private func animateBenefitChecklist() {
        guard benefitChecklistVisibleCount < benefitChecklistItems.count else { return }
        if reduceMotion {
            benefitChecklistVisibleCount = benefitChecklistItems.count
            return
        }
        benefitChecklistVisibleCount = 0
        Task {
            for visibleCount in 1...benefitChecklistItems.count {
                try? await Task.sleep(nanoseconds: 190_000_000)
                await MainActor.run {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        benefitChecklistVisibleCount = visibleCount
                    }
                    BookFeedback.play(.select)
                }
            }
        }
    }

    private func onboardingBenefitCard(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(BookPalette.nightText)
                .frame(width: 32, height: 32)
                .background(BookPalette.teal.opacity(0.92), in: Circle())
                .overlay {
                    Circle()
                        .stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 5) {
	                Text(title)
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.84))
	                Text(body)
	                    .font(.system(.callout, design: .default))
	                    .foregroundStyle(BookPalette.ink.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(BookPalette.teal.opacity(0.88))
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            isOnboardingFieldFocused = false
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
    }

    private var resumePrompt: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 16) {
                Text("Welcome back")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                Text("You left off partway through. Pick up where you were, or begin again from the first page.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
	                Text("Step \(step + 1) of \(stepCount)")
	                    .font(.footnote.weight(.semibold))
	                    .foregroundStyle(.white.opacity(0.6))

                VStack(spacing: 10) {
                    Button {
                        BookFeedback.play(.openPage)
                        withAnimation(.easeOut(duration: 0.2)) { showResumePrompt = false }
                    } label: {
                        Text("Continue").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.lampGold)

                    Button {
                        BookFeedback.play(.openPage)
                        resetOnboardingInputs()
                        withAnimation(.easeOut(duration: 0.25)) {
                            step = 0
                            showResumePrompt = false
                        }
                    } label: {
                        Text("Start fresh").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.lampGold)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(BookPalette.nightPanel.opacity(0.97), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.4), lineWidth: 1)
            }
            .padding(.horizontal, 32)
            .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 8)
        }
        .transition(.opacity)
        .zIndex(50)
    }

    /// Clears the player's entered onboarding inputs so "Start fresh" begins clean.
    private func resetOnboardingInputs() {
        snack = ""
        name = ""
        belief = ""
        investedBelief = false
        rehearsalChoice = nil
        firstSouvenir = ""
        sleeveWord = nil
        drawnChapterID = ""
        didWakeFirstInk = false
        didTuckUnwrittenWord = false
    }

    private func advance() {
        if step >= stepCount - 1 {
            step = 0
            onFinished(onboardingResult(useDefaults: false))
            return
        }
        withAnimation(reduceMotion ? .none : .spring(response: 0.46, dampingFraction: 0.86)) {
            step += 1
        }
    }

    private func finishWithDefaults() {
        isOnboardingFieldFocused = false
        BookFeedback.play(.openPage)
        step = 0
        onFinished(onboardingResult(useDefaults: true))
    }

    private func onboardingResult(useDefaults: Bool) -> Result {
        let trimmedSnack = snack.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBelief = belief.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSouvenir = firstSouvenir.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSleeveWord = (sleeveWord ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChapter = drawnChapterID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTaste = tastePreference.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComfort = comfortBoundary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWhisper = whisperCadence.trimmingCharacters(in: .whitespacesAndNewlines)

        return Result(
            snack: trimmedSnack.nonEmpty ?? (useDefaults ? "a warm drink and a good page" : ""),
            name: trimmedName.nonEmpty ?? (useDefaults ? "Reader" : ""),
            belief: trimmedBelief.nonEmpty ?? (useDefaults ? "small true things matter" : ""),
            investedBelief: investedBelief,
            firstSouvenir: trimmedSouvenir.nonEmpty ?? (useDefaults ? "I opened the Book for the first time." : ""),
            sleeveWord: trimmedSleeveWord.nonEmpty ?? (useDefaults ? "GLINT" : ""),
            drawnChapterID: trimmedChapter.nonEmpty ?? (useDefaults ? (AcademyChapterRegistry.publicChapters.first?.id ?? "emberheart") : ""),
            wickerMode: wickerOutcome?.choiceID ?? (useDefaults ? "slice-of-life" : ""),
            wickerRollSucceeded: wickerOutcome?.succeeded ?? false,
            tastePreference: trimmedTaste.nonEmpty ?? (useDefaults ? "cozy" : ""),
            comfortBoundary: trimmedComfort.nonEmpty ?? (useDefaults ? "balanced" : ""),
            whisperCadence: trimmedWhisper.nonEmpty ?? (useDefaults ? "inside" : "")
        )
    }
}

/// A small parchment note from Zara that slides in the first time the player
/// touches something new. Tap to dismiss; it also fades on its own.
struct MarginTutorNoteCard: View {
    let note: MarginTutorNote
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image("LabyrinthCharacterZaraFinch")
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(BookPalette.lampGold.opacity(0.7), lineWidth: 1.2)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
	                    Text("ZARA'S MARGIN NOTE")
	                        .font(.system(size: 11, weight: .black))
	                        .kerning(1.1)
	                        .foregroundStyle(BookPalette.teal)
	                    Spacer()
	                    Image(systemName: "xmark")
	                        .font(.footnote.weight(.bold))
	                        .foregroundStyle(BookPalette.ink.opacity(0.4))
                }
                Text(note.title)
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundStyle(BookPalette.ink)
	                Text(note.text)
	                    .font(.callout)
	                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background {
            ZStack {
                Image("ParchmentFiber")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.3)
                BookPalette.page.opacity(0.97)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
        .rotationEffect(.degrees(-0.6))
        .contentShape(Rectangle())
        .onTapGesture {
            BookFeedback.play(.dismissPage)
            onDismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Margin note from Zara. \(note.title). \(note.text)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to dismiss")
    }
}

/// The Book's returning greeting: a temporary, animated overlay that bleeds in
/// from the top, greets the reader by name, and slips away on its own.
struct BookGreetingOverlay: View {
    let greeting: BookGreeting
    var onDismiss: () -> Void

    @State private var shimmer = false

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(greeting.greeting)
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(BookPalette.lampGold)
                    .shadow(color: BookPalette.lampGold.opacity(0.25), radius: 6, x: 0, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(greeting.line)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(BookPalette.nightText.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        BookPalette.nightPanel.opacity(0.95),
                        BookPalette.nightPanel.opacity(0.82)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(shimmer ? 0.55 : 0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture { onDismiss() }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// A character's portrait wherever they appear: the bundled dossier illustration
/// when one exists, otherwise a medallion of their initials over a gradient built
/// from their official palette words. Every character gets a face this way.
struct CharacterPortraitView: View {
    let name: String
    var size: CGFloat = 48
    /// A custom cast member's own attached photo, used first when present.
    var customAsset: BookPageMediaAsset? = nil

    private static let paletteColors: [String: Color] = [
        "ink": Color(red: 0.16, green: 0.14, blue: 0.12), "black": Color(red: 0.12, green: 0.11, blue: 0.13),
        "silver": Color(red: 0.66, green: 0.68, blue: 0.72), "grey": Color(red: 0.55, green: 0.55, blue: 0.55),
        "gray": Color(red: 0.55, green: 0.55, blue: 0.55), "gold": BookPalette.lampGold,
        "star-gold": BookPalette.lampGold, "amber": Color(red: 0.78, green: 0.52, blue: 0.20),
        "green": Color(red: 0.30, green: 0.50, blue: 0.32), "thorn": Color(red: 0.24, green: 0.40, blue: 0.30),
        "moss": Color(red: 0.36, green: 0.46, blue: 0.30), "violet": BookPalette.violet,
        "blue": Color(red: 0.24, green: 0.38, blue: 0.55), "teal": BookPalette.teal,
        "rose": Color(red: 0.72, green: 0.42, blue: 0.46), "pink": Color(red: 0.78, green: 0.52, blue: 0.56),
        "parchment": BookPalette.paper, "cream": Color(red: 0.92, green: 0.86, blue: 0.72),
        "warm": Color(red: 0.80, green: 0.60, blue: 0.38), "copper": Color(red: 0.72, green: 0.45, blue: 0.30),
        "tarnished": Color(red: 0.52, green: 0.52, blue: 0.46)
    ]

    private var gradientColors: [Color] {
        let words = CharacterPortrait.paletteWords(forName: name)
        let matched = words.compactMap { word -> Color? in
            Self.paletteColors[word] ?? Self.paletteColors.first(where: { word.contains($0.key) })?.value
        }
        if matched.count >= 2 { return Array(matched.prefix(3)) }
        if let one = matched.first { return [one, one.opacity(0.55)] }
        // No palette on file: a stable color from the name so each face is distinct.
        let hue = Double(abs(name.stableHash) % 360) / 360
        let base = Color(hue: hue, saturation: 0.32, brightness: 0.5)
        return [base, base.opacity(0.55)]
    }

    private var customImage: Image? {
        guard let customAsset else { return nil }
        switch customAsset.kind {
        case .bundledImage:
            return Image(customAsset.reference)
        case .renderedImageFile:
            #if canImport(UIKit)
            if let uiImage = UIImage(contentsOfFile: customAsset.reference) { return Image(uiImage: uiImage) }
            #endif
            return nil
        case .photoLibraryAsset, .audioFile:
            return nil
        }
    }

    /// A full-resolution URL to preview when the portrait is real art (nil for a
    /// medallion, which has nothing to enlarge).
    private var previewURL: URL? {
        if let customAsset {
            switch customAsset.kind {
            case .renderedImageFile: return ImagePreview.url(forFilePath: customAsset.reference)
            case .bundledImage: return ImagePreview.url(forAsset: customAsset.reference)
            case .photoLibraryAsset, .audioFile: return nil
            }
        }
        if let asset = CharacterPortrait.intendedAssetName(forName: name), UIImage(named: asset) != nil {
            return ImagePreview.url(forAsset: asset)
        }
        return nil
    }

    var body: some View {
        Group {
            if let customImage {
                customImage
                    .resizable()
                    .scaledToFill()
            } else if let asset = CharacterPortrait.intendedAssetName(forName: name), UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Text(CharacterPortrait.initials(forName: name))
                            .font(.system(size: size * 0.4, weight: .bold, design: .serif))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(BookPalette.lampGold.opacity(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
        .accessibilityLabel("Portrait of \(name)")
        .imagePreviewOnTap { previewURL }
    }
}

extension PageVisualStyle {
    /// A festival page recolors by the celebration's accent, so Samhain feels
    /// amber-dark, Beltane green, Yule candlelit, a full moon violet, and so on.
    static func festivalStyle(accent: String) -> PageVisualStyle {
        let accentColor: Color
        let symbolColor: Color
        let paperBottom: Color
        switch accent {
        case "amber":
            accentColor = Color(red: 0.62, green: 0.34, blue: 0.16); symbolColor = Color(red: 0.70, green: 0.40, blue: 0.18)
            paperBottom = Color(red: 0.52, green: 0.40, blue: 0.30)
        case "green":
            accentColor = Color(red: 0.26, green: 0.46, blue: 0.30); symbolColor = Color(red: 0.30, green: 0.52, blue: 0.34)
            paperBottom = Color(red: 0.46, green: 0.52, blue: 0.42)
        case "gold":
            accentColor = Color(red: 0.66, green: 0.48, blue: 0.18); symbolColor = BookPalette.lampGold
            paperBottom = Color(red: 0.58, green: 0.50, blue: 0.34)
        case "violet":
            accentColor = BookPalette.violet; symbolColor = Color(red: 0.52, green: 0.40, blue: 0.62)
            paperBottom = Color(red: 0.42, green: 0.38, blue: 0.50)
        case "candle":
            accentColor = Color(red: 0.58, green: 0.42, blue: 0.24); symbolColor = BookPalette.lampGold
            paperBottom = Color(red: 0.34, green: 0.30, blue: 0.30)
        case "slate":
            accentColor = Color(red: 0.34, green: 0.38, blue: 0.46); symbolColor = Color(red: 0.40, green: 0.44, blue: 0.52)
            paperBottom = Color(red: 0.40, green: 0.42, blue: 0.48)
        default:
            accentColor = Color(red: 0.44, green: 0.33, blue: 0.60); symbolColor = Color(red: 0.62, green: 0.46, blue: 0.24)
            paperBottom = Color(red: 0.42, green: 0.38, blue: 0.46)
        }
        return PageVisualStyle(
            accent: accentColor,
            symbolColor: symbolColor,
            paperTop: Color(red: 0.96, green: 0.90, blue: 0.74),
            paperMiddle: Color(red: 0.82, green: 0.74, blue: 0.58),
            paperBottom: paperBottom,
            scrapColor: Color(red: 0.85, green: 0.79, blue: 0.64),
            sideMarginalia: "IlluminationScrapS02_08",
            cornerMarginalia: "IlluminationScrapS03_24",
            smallMarginalia: "MarginaliaStar",
            watermarkMarginalia: "MarginaliaCompass",
            sideMarginaliaWidth: 70,
            cornerMarginaliaWidth: 86,
            sideMarginaliaOpacity: 0.42,
            watermarkOpacity: 0.14,
            scrapWidth: 92
        )
    }
}

#if canImport(QuickLook)
import QuickLook
#endif

/// Resolves an on-screen image to a file URL so the system Quick Look viewer can
/// present it full-screen. Temp files are written once and reused by key.
enum ImagePreview {
    private static let dir: URL = {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("ImagePreviews", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    /// URL for a catalog asset (written to a cached temp PNG the first time).
    static func url(forAsset name: String) -> URL? {
        #if canImport(UIKit)
        let target = dir.appendingPathComponent("asset-\(name).png")
        if FileManager.default.fileExists(atPath: target.path) { return target }
        guard let image = UIImage(named: name), let data = image.pngData() else { return nil }
        try? data.write(to: target, options: .atomic)
        return target
        #else
        return nil
        #endif
    }

    /// URL for an on-disk image file (used as-is when it exists).
    static func url(forFilePath path: String) -> URL? {
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// Tap any image to open it full-screen in the system Quick Look viewer. The
/// closure returns the URL to preview (nil = not previewable, e.g. a medallion).
struct ImagePreviewOnTap: ViewModifier {
    let urlProvider: () -> URL?
    @State private var previewURL: URL?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                if let url = urlProvider() {
                    BookFeedback.play(.openPage)
                    previewURL = url
                }
            }
            #if canImport(QuickLook)
            .quickLookPreview($previewURL)
            #endif
    }
}

extension View {
    /// Make this view open a full-screen Quick Look preview when tapped.
    func imagePreviewOnTap(_ urlProvider: @escaping () -> URL?) -> some View {
        modifier(ImagePreviewOnTap(urlProvider: urlProvider))
    }
}
