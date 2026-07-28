import SwiftUI
import OSLog
import Darwin.Mach
import NaturalLanguage
import AVFoundation
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
                connectionHeader(
                    title: cluster.name,
                    subtitle: cluster.strength >= 70 ? "These things have begun arriving together." : "A few ordinary things are starting to rhyme.",
                    symbol: "sparkles.rectangle.stack",
                    accent: BookPalette.teal
                )
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
                    subtitle: constellation.isNamed
                        ? "The Book knows this shape by name."
                        : "A shape is beginning to gather.",
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
                        Text(page.archivePreviewText ?? page.type.title)
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
            Text(page.archivePreviewText ?? page.type.title)
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

                Text("Made with ReEnchanted \u{00B7} reenchanted.app")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(width: Self.contentWidth)
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

struct BookOfYouShareArtifact: Equatable {
    var title: String
    var excerpt: String
    var dateLine: String
    var themeName: String?
    var chapterName: String?
    var seed: Int

    var contextLine: String {
        let pieces = [themeName, chapterName].compactMap { $0?.nonEmpty }
        return pieces.isEmpty ? "Pressed from the Book of You" : pieces.joined(separator: " · ")
    }

    static let publicSeal = "Make your own Book of You \u{00B7} reenchanted.app"

    static func make(from surface: SurfacePage) -> BookOfYouShareArtifact? {
        guard surface.type == .bookOfYou else { return nil }
        let tags = surface.payload.metadata["tags"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        let title = shareTitle(from: surface)
        guard let excerpt = shareExcerpt(from: surface.payload.body) else { return nil }
        return BookOfYouShareArtifact(
            title: title,
            excerpt: publicSafe(excerpt),
            dateLine: surface.detail.replacingOccurrences(of: "Kept ", with: "").nonEmpty
                ?? Date().formatted(date: .abbreviated, time: .omitted),
            themeName: tagValue(prefix: "theme:", in: tags),
            chapterName: tagValue(prefix: "chapter:", in: tags),
            seed: surface.id.stableHash ^ excerpt.stableHash
        )
    }

    private static func shareTitle(from surface: SurfacePage) -> String {
        let candidates = [
            surface.payload.headline,
            surface.prompt.replacingOccurrences(of: "Book of You:", with: "")
        ]
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = trimmed.nonEmpty, value.localizedCaseInsensitiveCompare("Book of You") != .orderedSame {
                return String(value.prefix(54))
            }
        }
        return "The Book of You"
    }

    private static func shareExcerpt(from body: String) -> String? {
        let normalized = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let keptLine = paragraphs
            .flatMap({ sentences(in: $0) })
            .first(where: { $0.hasPrefix("The Book kept the page:") }) {
            return clipped(keptLine.replacingOccurrences(of: "The Book kept the page:", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let ranked = paragraphs
            .flatMap { sentences(in: $0) }
            .filter { sentence in
                let words = sentence.split { !$0.isLetter && !$0.isNumber }.count
                return words >= 8 && words <= 34
            }
            .sorted { lhs, rhs in
                score(lhs) > score(rhs)
            }
        return clipped(ranked.first ?? paragraphs.first ?? normalized)
    }

    private static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var values: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let value = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                values.append(value)
            }
            return true
        }
        return values.isEmpty ? [text] : values
    }

    private static func score(_ sentence: String) -> Int {
        let lower = sentence.lowercased()
        var total = min(40, sentence.count / 8)
        for word in ["book", "kept", "door", "page", "rain", "lamp", "window", "key", "moon", "weather", "story"] where lower.contains(word) {
            total += 8
        }
        if lower.contains("the book kept") { total += 18 }
        if sentence.contains(":") { total += 4 }
        return total
    }

    private static func clipped(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        guard value.count > 190 else { return value }
        let end = value.index(value.startIndex, offsetBy: 187)
        return String(value[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func publicSafe(_ value: String) -> String {
        var text = value
        let replacements: [(String, String)] = [
            (#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, "an address"),
            (#"\b\d{3}[-. ]?\d{3}[-. ]?\d{4}\b"#, "a number"),
            (#"\b\d{1,5}\s+[A-Z][A-Za-z0-9.'-]*(\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Place|Pl))\b"#, "a street")
        ]
        for (pattern, replacement) in replacements {
            text = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return text
    }

    private static func tagValue(prefix: String, in tags: [String]) -> String? {
        tags.first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap(\.nonEmpty)
    }
}

struct BookOfYouShareCard: View {
    let artifact: BookOfYouShareArtifact

    static let renderSize = CGSize(width: 1080, height: 1350)
    private static let horizontalInset: CGFloat = 104
    private static var contentWidth: CGFloat { renderSize.width - horizontalInset * 2 }
    private static let quoteBoxHeight: CGFloat = 520

    private var composition: QuoteCardComposition {
        QuoteCardComposition(seed: artifact.seed, baseFontSize: excerptFontSize)
    }

    private var excerptFontSize: CGFloat {
        let count = artifact.excerpt.count
        if count > 165 { return 42 }
        if count > 130 { return 46 }
        if count > 95 { return 52 }
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
                .opacity(0.28)
                .blendMode(.multiply)

            Image("ParchmentFiber")
                .resizable()
                .scaledToFill()
                .frame(width: Self.renderSize.width, height: Self.renderSize.height)
                .clipped()
                .opacity(c.fiberOpacity)
                .blendMode(.overlay)

            ForEach(c.stains) { stain in
                Circle()
                    .fill(c.ink.accent.opacity(stain.opacity))
                    .frame(width: stain.size.width, height: stain.size.height)
                    .blur(radius: 16)
                    .position(stain.center)
            }

            marginaliaImage(c.watermark)
            ForEach(c.edgeMarginalia) { mark in
                marginaliaImage(mark)
            }

            VStack(spacing: 24) {
                Text("THE BOOK OF YOU")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(c.ink.accent.opacity(0.86))
                    .tracking(2.4)
                    .lineLimit(1)

                Text(artifact.title)
                    .font(.system(size: 54, weight: .semibold, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(width: Self.contentWidth, height: 128)

                ZStack {
                    Rectangle()
                        .fill(c.ink.accent.opacity(0.45))
                        .frame(width: c.dividerWidth, height: 1.6)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(c.ink.accent.opacity(0.72))
                        .padding(.horizontal, 7)
                        .background(c.ink.paperMid)
                }

                Text("“\(artifact.excerpt)”")
                    .font(.system(size: c.quoteFontSize, weight: c.quoteWeight, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .tracking(c.quoteTracking)
                    .lineLimit(8)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .frame(width: Self.contentWidth, height: Self.quoteBoxHeight)

                VStack(spacing: 12) {
                    Text(artifact.contextLine)
                        .font(.system(size: 21, weight: .semibold, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(width: Self.contentWidth)

                    Text(artifact.dateLine.uppercased())
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(c.ink.accent.opacity(0.86))
                        .tracking(1.2)

                    Text("Pressed in ReEnchanted")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.66))

                    Text(BookOfYouShareArtifact.publicSeal)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.54))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .frame(width: Self.contentWidth)
                }
            }
            .frame(width: Self.contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: c.verticalOffset)
            .rotationEffect(.degrees(c.contentRotation))
        }
        .frame(width: Self.renderSize.width, height: Self.renderSize.height)
        .overlay { shareBorder(c) }
        .clipShape(RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous))
        .background(BookPalette.paper)
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

    private func shareBorder(_ c: QuoteCardComposition) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(8, c.cornerRadius - 6), style: .continuous)
                .stroke(c.ink.gild.opacity(0.86), lineWidth: 14)
                .padding(c.borderInset)
            RoundedRectangle(cornerRadius: max(6, c.cornerRadius - 14), style: .continuous)
                .stroke(BookPalette.parchmentEdge.opacity(0.35), lineWidth: 2)
                .padding(c.borderInset + 22)
        }
    }
}

struct BookOfYouPressedPageSpotlight: View {
    let artifact: BookOfYouShareArtifact
    var isWorking = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let scale = proxy.size.width / BookOfYouShareCard.renderSize.width
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(BookPalette.nightPanel.opacity(0.82))
                        .shadow(color: BookPalette.lampGold.opacity(shimmer ? 0.26 : 0.12), radius: shimmer ? 28 : 16, x: 0, y: 12)

                    BookOfYouShareCard(artifact: artifact)
                        .frame(width: BookOfYouShareCard.renderSize.width, height: BookOfYouShareCard.renderSize.height)
                        .scaleEffect(scale * 0.92, anchor: .center)
                        .rotationEffect(.degrees(reduceMotion ? 0 : (shimmer ? 0.7 : -0.7)))
                        .shadow(color: .black.opacity(0.26), radius: 12, x: 0, y: 8)
                        // Rasterise the oversized, scaled card so it renders reliably
                        // as a thumbnail instead of dropping out to a blank slot.
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .drawingGroup()
                        .accessibilityHidden(true)

                    ForEach(0..<9, id: \.self) { index in
                        let angle = Double(index) / 9 * 2 * .pi
                        let reach: CGFloat = shimmer ? 58 : 38
                        Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                            .font(.system(size: index.isMultiple(of: 2) ? 12 : 7, weight: .black))
                            .foregroundStyle(BookPalette.lampGold.opacity(shimmer ? 0.78 : 0.32))
                            .shadow(color: BookPalette.lampGold.opacity(0.35), radius: 6)
                            .position(
                                x: proxy.size.width * 0.5 + CGFloat(cos(angle)) * reach,
                                y: proxy.size.height * 0.5 + CGFloat(sin(angle)) * reach
                            )
                            .opacity(reduceMotion ? 0 : 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Label(isWorking ? "pressing" : "pressed page", systemImage: isWorking ? "wand.and.sparkles" : "seal.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(BookPalette.lampGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(BookPalette.nightPanel.opacity(0.92), in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.36), lineWidth: 1)
                        }
                        .padding(10)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(shimmer ? 0.44 : 0.24), lineWidth: 1)
                }
            }
            .aspectRatio(BookOfYouShareCard.renderSize.width / BookOfYouShareCard.renderSize.height, contentMode: .fit)

            HStack(spacing: 8) {
                Label("keep", systemImage: "book.closed")
                Label("share", systemImage: "square.and.arrow.up")
                Label("public excerpt", systemImage: "lock.shield")
            }
            .font(.caption2.weight(.black))
            .foregroundStyle(BookPalette.lampGold.opacity(0.84))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear { syncShimmer() }
        .onChange(of: isWorking) { _, _ in syncShimmer() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pressed Book of You share page titled \(artifact.title). \(artifact.excerpt)")
    }

    /// The card only pulses while it is actively being pressed. At rest — the
    /// morning "waiting" state — it holds still instead of shimmering forever.
    private func syncShimmer() {
        guard !reduceMotion else { shimmer = true; return }
        if isWorking {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.6)) { shimmer = false }
        }
    }
}

/// The three edition-binding peaks, each with its own final motif and haptic.
enum EditionCelebrationKind: Equatable {
    /// Monthly PDF binding — a wax seal, the `monthBound` haptic.
    case sewn
    /// Print-ready hardcover export — a foil stamp, the heavier `pressReady` haptic.
    case press
    /// The onboarding finale — the reader's first edition, a wax seal + key.
    case firstEdition
}

/// A live edition-binding celebration: its cover embossing, its copy, and which
/// ceremonial variant to play.
struct EditionCelebrationInfo: Identifiable, Equatable {
    let kind: EditionCelebrationKind
    let coverKicker: String
    let coverTitle: String
    let headline: String
    let subtitle: String
    var id: String { "\(coverKicker)|\(coverTitle)|\(headline)" }
}

/// The edition-binding celebration — the app's grandest peaks. The signatures
/// gather, a gilt thread stitches the spine, the cover closes and embosses, and
/// a wax seal (or foil stamp) presses home inside a bloom of gold rays. Three
/// content-driven variants (monthly bind, print-ready, onboarding first edition);
/// it borrows nothing from the keep or braid celebrations.
struct EditionCelebration: View {
    let info: EditionCelebrationInfo
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var gather = false
    @State private var stitch: CGFloat = 0
    @State private var closed = false
    @State private var sealed = false
    @State private var rays = false
    @State private var didDismiss = false

    private let coverSize = CGSize(width: 190, height: 252)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.62))
                .ignoresSafeArea()

            raysLayer
                .scaleEffect(rays ? 1 : 0.2)
                .opacity(rays ? 0.85 : 0)
                .allowsHitTesting(false)

            VStack(spacing: 26) {
                bindingArt
                    .frame(width: coverSize.width, height: coverSize.height)

                VStack(spacing: 6) {
                    Text(info.headline)
                        .font(.system(.title2, design: .serif).weight(.bold))
                        .foregroundStyle(BookPalette.lampGold)
                        .multilineTextAlignment(.center)
                    Text(info.subtitle)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(BookPalette.nightText.opacity(0.82))
                        .multilineTextAlignment(.center)
                    Text("Tap to hold it.")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.nightText.opacity(0.5))
                        .padding(.top, 2)
                }
                .padding(.horizontal, 28)
                .opacity(closed ? 1 : 0)
                .offset(y: closed ? 0 : 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear(perform: runCeremony)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(info.headline). \(info.subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    private var raysLayer: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [BookPalette.lampGold.opacity(0), BookPalette.lampGold.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 280)
                    .offset(y: -160)
                    .rotationEffect(.degrees(Double(index) / 14 * 360))
            }
        }
        .blur(radius: 0.5)
    }

    private var bindingArt: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(BookPalette.paper.opacity(0.9))
                    .frame(width: coverSize.width - 26, height: coverSize.height - 26)
                    .rotationEffect(.degrees(gather ? Double(index - 1) * 1.5 : Double(index - 1) * 12))
                    .offset(
                        x: gather ? CGFloat(index - 1) * 3 : CGFloat(index - 1) * 26,
                        y: CGFloat(index - 1) * 2
                    )
                    .opacity(closed ? 0 : 0.85)
            }

            Capsule()
                .fill(BookPalette.lampGold)
                .frame(width: 3, height: (coverSize.height - 40) * stitch)
                .position(x: 11, y: coverSize.height / 2)
                .shadow(color: BookPalette.lampGold.opacity(0.7), radius: 4)

            coverFace
                .scaleEffect(closed ? 1 : 1.06)
                .opacity(closed ? 1 : 0)
                .rotation3DEffect(.degrees(closed ? 0 : -38), axis: (x: 0, y: 1, z: 0), anchor: .leading)

            sealMotif
                .scaleEffect(sealed ? 1 : 0.1)
                .opacity(sealed ? 1 : 0)
        }
    }

    @ViewBuilder
    private var sealMotif: some View {
        switch info.kind {
        case .press:
            foilStamp
        case .sewn:
            waxSeal(symbol: "sparkle")
        case .firstEdition:
            waxSeal(symbol: "key.fill")
        }
    }

    /// The print-ready hardcover's mark: a gilt foil stamp pressed into the board.
    private var foilStamp: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BookPalette.lampGold, Color(red: 0.72, green: 0.54, blue: 0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .rotationEffect(.degrees(45))
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.05))
        }
        .offset(y: 42)
        .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
    }

    private var coverFace: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.21, green: 0.13, blue: 0.09), Color(red: 0.12, green: 0.07, blue: 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.55), lineWidth: 1.5)
                    .padding(10)
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    Text(info.coverKicker)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(BookPalette.lampGold.opacity(0.85))
                        .multilineTextAlignment(.center)
                    Text(info.coverTitle)
                        .font(.system(.headline, design: .serif).weight(.bold))
                        .foregroundStyle(BookPalette.lampGold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                .padding(.horizontal, 18)
            }
            .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
    }

    private func waxSeal(symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.62, green: 0.11, blue: 0.12), Color(red: 0.40, green: 0.06, blue: 0.08)],
                        center: .center,
                        startRadius: 1,
                        endRadius: 30
                    )
                )
                .frame(width: 54, height: 54)
            Image(systemName: "seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color(red: 0.78, green: 0.22, blue: 0.22).opacity(0.5))
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(BookPalette.lampGold.opacity(0.9))
        }
        .offset(y: 42)
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
    }

    private func playCeremonyHaptic() {
        switch info.kind {
        case .press:
            BookFeedback.pressReady()
        case .sewn, .firstEdition:
            BookFeedback.monthBound()
        }
    }

    private func dismiss() {
        guard !didDismiss else { return }
        didDismiss = true
        onDismiss()
    }

    private func runCeremony() {
        guard !reduceMotion else {
            gather = true
            stitch = 1
            closed = true
            sealed = true
            rays = true
            playCeremonyHaptic()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { dismiss() }
            return
        }
        withAnimation(.easeOut(duration: 0.5)) { gather = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            playCeremonyHaptic()
            withAnimation(.easeInOut(duration: 0.7)) { stitch = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { closed = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { sealed = true }
            withAnimation(.easeOut(duration: 0.9)) { rays = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) { dismiss() }
    }
}

@MainActor
enum BookOfYouShareCardRenderer {
    static func render(artifact: BookOfYouShareArtifact) -> URL? {
        let content = BookOfYouShareCard(artifact: artifact)
            .frame(width: BookOfYouShareCard.renderSize.width, height: BookOfYouShareCard.renderSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            return nil
        }

        do {
            let directory = try renderedDirectory()
            let filename = "book-of-you-pressed-\(artifact.seed.magnitude).png"
            let url = directory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            appLog.error("Book of You share render failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func renderedDirectory() throws -> URL {
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("BookOfYouPressedPages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

struct BookOfYouPageRevealFrame: View {
    let artifact: BookOfYouShareArtifact
    let progress: Double

    static let renderSize = CGSize(width: 1080, height: 1920)
    private static let bookSize = CGSize(width: 820, height: 1160)
    private static let leatherTop = Color(red: 0.08, green: 0.09, blue: 0.18)
    private static let leatherMid = Color(red: 0.05, green: 0.055, blue: 0.12)
    private static let leatherLow = Color(red: 0.025, green: 0.03, blue: 0.07)

    private var eased: Double {
        let t = min(1, max(0, progress))
        return t * t * (3 - 2 * t)
    }

    private var appearProgress: Double {
        openingProgress(eased, from: 0.00, to: 0.14)
    }

    private var titleProgress: Double {
        openingProgress(eased, from: 0.12, to: 0.32)
    }

    private var openProgress: Double {
        openingProgress(eased, from: 0.28, to: 0.78)
    }

    private var pageProgress: Double {
        openingProgress(eased, from: 0.50, to: 0.90)
    }

    private var textProgress: Double {
        openingProgress(eased, from: 0.70, to: 1.0)
    }

    private var floodProgress: Double {
        openingProgress(eased, from: 0.64, to: 1.0)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.02, blue: 0.07),
                    Color(red: 0.09, green: 0.07, blue: 0.14),
                    Color(red: 0.02, green: 0.03, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            revealDust

            RadialGradient(
                colors: [
                    BookPalette.lampGold.opacity(0.72 * floodProgress),
                    BookPalette.gold.opacity(0.24 * floodProgress),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 900
            )
            .blendMode(.screen)

            ZStack {
                innerBookPage
                pressedPage
                frontCover
            }
            .frame(width: Self.bookSize.width, height: Self.bookSize.height)
            .scaleEffect(0.86 + 0.10 * appearProgress)
            .opacity(appearProgress)
            .shadow(color: .black.opacity(0.48 * appearProgress), radius: 40, x: 0, y: 26)
            .offset(y: -70 + 18 * (1 - appearProgress))

            VStack(spacing: 12) {
                Text(openProgress < 0.72 ? "THE BOOK OPENS" : "THE BOOK PRESSED A PAGE")
                    .font(.system(size: 23, weight: .bold, design: .serif))
                    .tracking(2.4)
                    .foregroundStyle(BookPalette.lampGold.opacity(0.82))
                Text("ReEnchanted")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.96, green: 0.88, blue: 0.70).opacity(0.88))
                Text(BookOfYouShareArtifact.publicSeal)
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.96, green: 0.88, blue: 0.70).opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: 900)
            }
            .opacity(textProgress)
            .offset(y: 760)
        }
        .frame(width: Self.renderSize.width, height: Self.renderSize.height)
    }

    private var innerBookPage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BookPalette.page, BookPalette.paper, BookPalette.page.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image("ParchmentTexture")
                .resizable()
                .scaledToFill()
                .opacity(0.34)
                .blendMode(.multiply)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.24), .clear, BookPalette.lampGold.opacity(0.16)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 34)
                .offset(x: -Self.bookSize.width / 2 + 22)
                .blur(radius: 5)
                .opacity(0.25 + 0.55 * openProgress)

            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(BookPalette.lampGold.opacity(0.86))
                Text("The Book of You")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                Rectangle()
                    .fill(BookPalette.lampGold.opacity(0.38))
                    .frame(width: 240, height: 1.5)
            }
            .opacity(openingProgress(openProgress, from: 0.22, to: 0.58) * (1 - pageProgress * 0.82))
            .offset(y: -20)

            ForEach(0..<18, id: \.self) { index in
                let x = Self.unit(seed: artifact.seed, key: "book-spark-x-\(index)")
                let rise = pageProgress * (40 + Self.unit(seed: artifact.seed, key: "book-spark-rise-\(index)") * 130)
                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "circle.fill")
                    .font(.system(size: index.isMultiple(of: 3) ? 13 : 5, weight: .black))
                    .foregroundStyle(BookPalette.lampGold.opacity(0.16 + 0.50 * pageProgress))
                    .position(
                        x: 120 + x * (Self.bookSize.width - 240),
                        y: 950 - rise - Self.unit(seed: artifact.seed, key: "book-spark-y-\(index)") * 360
                    )
            }
        }
        .frame(width: Self.bookSize.width, height: Self.bookSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BookPalette.parchmentEdge.opacity(0.42), lineWidth: 2)
        }
    }

    private var pressedPage: some View {
        BookOfYouShareCard(artifact: artifact)
            .scaleEffect(0.64 + 0.05 * pageProgress)
            .opacity(pageProgress)
            .blur(radius: (1 - pageProgress) * 7)
            .rotationEffect(.degrees(-2.6 + 2.6 * pageProgress))
            .shadow(color: BookPalette.lampGold.opacity(0.28 * pageProgress), radius: 30, x: 0, y: 18)
            .offset(y: 38 - 64 * pageProgress)
    }

    private var frontCover: some View {
        let faceOpacity = 1 - openingProgress(openProgress, from: 0.30, to: 0.62)
        return ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Self.leatherTop, Self.leatherMid, Self.leatherLow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(BookPalette.lampGold.opacity(0.14))
                        .frame(width: 28)
                        .blur(radius: 8)
                }

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.74), lineWidth: 4)
                .padding(42)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.42), lineWidth: 2)
                .padding(68)

            VStack(spacing: 18) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .shadow(color: BookPalette.lampGold.opacity(0.45), radius: 14)
                    .opacity(faceOpacity)

                WrittenGoldText(
                    "The Book",
                    font: .system(size: 70, weight: .semibold, design: .serif),
                    progress: titleProgress
                )
                WrittenGoldText(
                    "of You",
                    font: .system(size: 70, weight: .semibold, design: .serif),
                    progress: titleProgress
                )

                Text(String(artifact.title.prefix(48)))
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(BookPalette.gold.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.64)
                    .frame(width: 560)
                    .opacity(faceOpacity * titleProgress)
                    .padding(.top, 10)

                Rectangle()
                    .fill(BookPalette.lampGold.opacity(0.50))
                    .frame(width: 250, height: 2)
                    .opacity(faceOpacity)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 88)
        }
        .frame(width: Self.bookSize.width, height: Self.bookSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .rotation3DEffect(
            .degrees(-156 * openProgress),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.58
        )
        .shadow(color: .black.opacity(0.20 * (1 - openProgress)), radius: 24, x: 0, y: 18)
    }

    private var revealDust: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { index in
                let x = Self.unit(seed: artifact.seed, key: "dust-x-\(index)")
                let y = Self.unit(seed: artifact.seed, key: "dust-y-\(index)")
                let size = 3 + Self.unit(seed: artifact.seed, key: "dust-s-\(index)") * 9
                let drift = (eased - 0.5) * (24 + Self.unit(seed: artifact.seed, key: "dust-d-\(index)") * 46)
                Circle()
                    .fill(BookPalette.lampGold.opacity(0.12 + 0.46 * max(openProgress, textProgress)))
                    .frame(width: size, height: size)
                    .blur(radius: size > 8 ? 1.8 : 0.4)
                    .position(
                        x: 90 + x * (Self.renderSize.width - 180),
                        y: 80 + y * (Self.renderSize.height - 160) - drift
                    )
            }
        }
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
enum BookOfYouPageRevealVideoRenderer {
    static func render(artifact: BookOfYouShareArtifact) async -> URL? {
        let size = BookOfYouPageRevealFrame.renderSize
        let frameCount = 48
        let framesPerSecond = 12

        do {
            let directory = try renderedDirectory()
            let url = directory.appendingPathComponent("book-of-you-reveal-\(artifact.seed.magnitude).mp4")
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height)
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = false
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: attributes
            )
            guard writer.canAdd(input) else { return nil }
            writer.add(input)
            guard writer.startWriting() else { return nil }
            writer.startSession(atSourceTime: .zero)

            for frame in 0..<frameCount {
                let progress = Double(frame) / Double(frameCount - 1)
                let content = BookOfYouPageRevealFrame(artifact: artifact, progress: progress)
                    .frame(width: size.width, height: size.height)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 1
                guard let image = renderer.uiImage,
                      let buffer = pixelBuffer(from: image, size: size) else {
                    input.markAsFinished()
                    writer.cancelWriting()
                    return nil
                }
                while !input.isReadyForMoreMediaData {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
                let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(framesPerSecond))
                guard adaptor.append(buffer, withPresentationTime: time) else {
                    input.markAsFinished()
                    writer.cancelWriting()
                    return nil
                }
            }

            input.markAsFinished()
            await withCheckedContinuation { continuation in
                writer.finishWriting {
                    continuation.resume()
                }
            }
            return writer.status == .completed ? url : nil
        } catch {
            appLog.error("Book of You reveal video failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ), let cgImage = image.cgImage else {
            return nil
        }
        context.clear(CGRect(origin: .zero, size: size))
        // No vertical flip: CGContext.draw already composes the CGImage
        // top-side-up in the buffer AVFoundation reads, so flipping here
        // produced upside-down video frames.
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return pixelBuffer
    }

    private static func renderedDirectory() throws -> URL {
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("BookOfYouRevealVideos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

#if canImport(UIKit)
@MainActor
enum BookOfYouPDFRenderer {
    static func render(page: BookPage, surface: SurfacePage) -> URL? {
        let details = BraidPageDetails.details(for: page)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margins = UIEdgeInsets(top: 64, left: 70, bottom: 78, right: 70)
        let title = details.title.nonEmpty ?? surface.payload.headline.nonEmpty ?? "The Book of You"
        let body = details.body.nonEmpty ?? surface.payload.body
        let contextLine = [details.themeName, details.chapterName].compactMap { $0?.nonEmpty }.joined(separator: " \u{00B7} ")
        let dateLine = page.createdAt.formatted(date: .abbreviated, time: .omitted)

        do {
            let directory = try renderedDirectory()
            let url = directory.appendingPathComponent("book-of-you-\(page.id.stableHash.magnitude).pdf")
            let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

            try renderer.writePDF(to: url) { context in
                var y = beginPage(context, bounds: pageBounds, margins: margins, title: title)
                drawCentered("THE BOOK OF YOU", font: .systemFont(ofSize: 10, weight: .bold), color: accent, y: y, in: pageBounds, tracking: 1.8)
                y += 25
                y = drawWrapped(title, font: .serifFont(ofSize: 25, weight: .bold), color: ink, x: margins.left, y: y, width: contentWidth(pageBounds, margins), alignment: .center, spacingAfter: 8)
                if !contextLine.isEmpty {
                    y = drawWrapped(contextLine, font: .serifItalicFont(ofSize: 11), color: ink.withAlphaComponent(0.66), x: margins.left, y: y, width: contentWidth(pageBounds, margins), alignment: .center, spacingAfter: 3)
                }
                drawCentered(dateLine.uppercased(), font: .systemFont(ofSize: 8.5, weight: .bold), color: accent.withAlphaComponent(0.82), y: y, in: pageBounds, tracking: 1.1)
                y += 29
                drawRule(y: y, bounds: pageBounds, margins: margins)
                y += 25

                let chunks = bodyChunks(from: body)
                for chunk in chunks {
                    let height = measuredHeight(chunk, font: bodyFont, width: contentWidth(pageBounds, margins))
                    if y + height > pageBounds.height - margins.bottom {
                        y = beginPage(context, bounds: pageBounds, margins: margins, title: title)
                    }
                    y = drawWrapped(chunk, font: bodyFont, color: ink.withAlphaComponent(0.92), x: margins.left, y: y, width: contentWidth(pageBounds, margins), alignment: .natural, spacingAfter: 13)
                }
            }
            return url
        } catch {
            appLog.error("Book of You PDF render failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static let ink = UIColor(red: 0.13, green: 0.10, blue: 0.08, alpha: 1)
    private static let accent = UIColor(red: 0.48, green: 0.23, blue: 0.12, alpha: 1)
    private static let paperTop = UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 1)
    private static let paperBottom = UIColor(red: 0.82, green: 0.72, blue: 0.58, alpha: 1)
    private static let bodyFont = UIFont.serifFont(ofSize: 12.4, weight: .regular)

    private static func beginPage(
        _ context: UIGraphicsPDFRendererContext,
        bounds: CGRect,
        margins: UIEdgeInsets,
        title: String
    ) -> CGFloat {
        context.beginPage()
        guard let cg = UIGraphicsGetCurrentContext() else { return margins.top }
        let colors = [paperTop.cgColor, paperBottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: bounds.midX, y: bounds.minY),
                end: CGPoint(x: bounds.midX, y: bounds.maxY),
                options: []
            )
        }

        drawCentered(
            "Made with ReEnchanted \u{00B7} reenchanted.app",
            font: .systemFont(ofSize: 8.5, weight: .semibold),
            color: ink.withAlphaComponent(0.50),
            y: bounds.height - 42,
            in: bounds,
            tracking: 0
        )
        (String(title.prefix(68)).uppercased() as NSString).draw(
            at: CGPoint(x: margins.left, y: 32),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 7.5, weight: .semibold),
                .foregroundColor: ink.withAlphaComponent(0.38)
            ]
        )
        return margins.top
    }

    private static func bodyChunks(from body: String) -> [String] {
        body.components(separatedBy: "\n\n")
            .flatMap { paragraph -> [String] in
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return [] }
                let words = trimmed.split(separator: " ")
                guard words.count > 95 else { return [trimmed] }
                return stride(from: 0, to: words.count, by: 95).map { start in
                    words[start..<min(start + 95, words.count)].joined(separator: " ")
                }
            }
    }

    private static func contentWidth(_ bounds: CGRect, _ margins: UIEdgeInsets) -> CGFloat {
        bounds.width - margins.left - margins.right
    }

    private static func measuredHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3.6
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph
        ])
        return attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral.height + 5
    }

    private static func drawWrapped(
        _ text: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        alignment: NSTextAlignment,
        spacingAfter: CGFloat
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3.6
        paragraph.alignment = alignment
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let height = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral.height + 5
        attributed.draw(in: CGRect(x: x, y: y, width: width, height: height))
        return y + height + spacingAfter
    }

    private static func drawCentered(
        _ text: String,
        font: UIFont,
        color: UIColor,
        y: CGFloat,
        in bounds: CGRect,
        tracking: CGFloat
    ) {
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: tracking
        ])
        let size = attributed.size()
        attributed.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y))
    }

    private static func drawRule(y: CGFloat, bounds: CGRect, margins: UIEdgeInsets) {
        accent.withAlphaComponent(0.42).setFill()
        UIBezierPath(rect: CGRect(x: margins.left + 80, y: y, width: bounds.width - margins.left - margins.right - 160, height: 1.2)).fill()
    }

    private static func renderedDirectory() throws -> URL {
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("BookOfYouPDFs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
#endif

struct SurfaceCard: View {
    let surface: SurfacePage
    let isBusy: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var bookActedMargin: (title: String, line: String)? {
        guard let line = surface.payload.metadata["bookActedMargin"]?.nonEmpty else { return nil }
        return (
            surface.payload.metadata["bookActedMarginTitle"]?.nonEmpty ?? "The Book interfered",
            line
        )
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

    /// A Playful Mission works better as a sealed little invitation on the desk.
    /// Its title can tempt the reader, but the actual errand belongs to the page
    /// they choose to open — otherwise the shelf repeats it before the page can.
    private var hidesMissionFromPreview: Bool {
        surface.payload.metadata["playfulMissionID"]?.nonEmpty != nil
            && surface.payload.metadata["compassMode"] == "standalone"
    }

    private var previewText: String? {
        guard isReadingCard, !hidesMissionFromPreview else { return nil }
        let body = surface.payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        // Always cut on a complete sentence so the shelf can show the whole
        // preview instead of trailing off mid-word behind an ellipsis.
        let preview = body.bookPreviewSentenceLimit(previewSentenceLimit)
        // Some cards (e.g. Playful Missions) store the prompt as both `detail`
        // and the head of `body`; without this the same paragraph prints twice.
        if preview == surface.detail.trimmingCharacters(in: .whitespacesAndNewlines) {
            return nil
        }
        return preview
    }

    private var surfaceLabel: String {
        surface.payload.metadata["surfaceLabel"]?.nonEmpty ?? surface.type.shortTitle
    }

    private var openActionLabel: String {
        guard SurfaceReadinessState(surface: surface).needsLocalBrainToOpen,
              BeliefEconomyPolicy.generationKind(for: surface) != nil else {
            return "Open the page"
        }
        return "Open — the page will borrow some Belief"
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

    /// How many whole sentences of the body the shelf preview shows. The dense,
    /// frequently-surfaced types stay tight at two; everything else gets three
    /// so a short note can finish its thought. Bounding by sentences (not lines)
    /// means the card ends cleanly instead of trailing off mid-word.
    private var previewSentenceLimit: Int {
        if surface.payload.metadata["illustrationKind"] == "cast" { return 2 }
        switch surface.type {
        case .wonderCompass, .narrativeOS, .marginsAtlas, .bookConnections,
             .bookRemembered, .bookNotices, .theBleed, .radio, .gossip,
             .facultyResearch, .supportGuild:
            return 2
        default:
            return 3
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
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(visualStyle.accent)
                    .padding(.top, 2)

                if isShadowWonderVariant {
                    shadowWonderChip
                }

                Spacer()
            }
            .padding(.trailing, 38)

            Text(surface.prompt)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 26)

            if hidesMissionFromPreview {
                Text("A small, low-stakes invitation is waiting inside.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(surface.detail)
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let margin = bookActedMargin {
                VStack(alignment: .leading, spacing: 5) {
                    Text(margin.title.uppercased())
                        .font(.caption2.weight(.black))
                        .tracking(0.9)
                    Text(margin.line)
                        .font(.system(.callout, design: .serif).italic())
                        .lineSpacing(2)
                }
                .foregroundStyle(visualStyle.accent)
                .padding(.vertical, 9)
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(visualStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(visualStyle.accent.opacity(0.55))
                        .frame(width: 2)
                        .padding(.vertical, 5)
                }
                .accessibilityElement(children: .combine)
            }

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
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.94))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            Text(surface.reason)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            if let privacyNote {
                Label(privacyNote, systemImage: "lock.shield")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(visualStyle.accent)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack {
                Text(isBusy ? "Taking ink..." : openActionLabel)
                    .font(.footnote.weight(.bold))
                Spacer()
                Image(systemName: isBusy ? "circle.dotted" : "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .symbolEffect(.pulse, options: .speed(0.58), isActive: isBusy && !reduceMotion)
            }
            .foregroundStyle(visualStyle.accent)
        }
        .textSelection(.enabled)
        .padding(16)
        .frame(minHeight: isReadingCard ? 330 : 212, alignment: .topLeading)
        .parchmentSurface(style: visualStyle, isActive: true)
        // The drifting letters and pixies are the desk's ambient heartbeat.
        // Resting Pages stay still so an arrival, active scribe, or touch can
        // own the reader's attention instead of competing with six perpetual
        // card animations at once.
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(visualStyle.accent.opacity(isBusy ? 0.38 : 0.15), lineWidth: isBusy ? 1.5 : 1)
                .animation(BookMotion.direct(reduceMotion), value: isBusy)
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
    let isRetiring: Bool
    let animatesArrival: Bool
    var arrivalDelay: Double = 0
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var isTucking = false
    @State private var hasArrived = false

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

    private var arrivalIsVisible: Bool {
        reduceMotion || !animatesArrival || hasArrived
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .trailing) {
                marginReveal

                Button {
                    onOpen()
                } label: {
                    SurfaceCard(surface: surface, isBusy: isBusy)
                }
                .buttonStyle(.bookPress())
                .bookCardHover()
                .scaleEffect(reduceMotion ? 1 : (isTucking ? 0.9 : 1 - dragProgress * 0.03), anchor: .bottomLeading)
                .rotationEffect(.degrees(-tiltDegrees), anchor: .bottomLeading)
                .offset(x: dragOffset)
                .overlay(alignment: .topTrailing) {
                    Button {
                        performDismissal()
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
            .opacity(isRetiring ? 0 : (arrivalIsVisible ? 1 : 0))
            .offset(x: arrivalIsVisible ? 0 : 44)
            .scaleEffect(reduceMotion || arrivalIsVisible ? 1 : 0.975, anchor: .trailing)
            .accessibilityHidden(isRetiring)

            if isRetiring || (animatesArrival && !hasArrived && !reduceMotion) {
                SurfaceRetirementPlaceholder(surface: surface)
                    .transition(.opacity)
            }
        }
        // The real card remains mounted underneath the placeholder, preserving
        // its exact variable-height slot. The outgoing and incoming motion uses
        // offset/opacity only, so none of it can animate the surrounding shelves.
        .allowsHitTesting(!isRetiring)
        .accessibilityHint(isRetiring
            ? "The Book is choosing another page."
            : "Tap to open. Use the small right-edge tab or close button to let this page pass."
        )
        .onAppear {
            synchronizeArrival()
        }
        .onChange(of: animatesArrival) { _, _ in
            synchronizeArrival()
        }
        .onChange(of: reduceMotion) { _, _ in
            synchronizeArrival()
        }
    }

    /// A queued Page can already be mounted when it becomes the next visible
    /// card. `onAppear` will not run again in that case, so the arrival flag
    /// itself must start the reveal or the placeholder can remain forever.
    private func synchronizeArrival() {
        guard animatesArrival, !reduceMotion else {
            hasArrived = true
            return
        }

        hasArrived = false
        DispatchQueue.main.async {
            guard animatesArrival, !reduceMotion else {
                hasArrived = true
                return
            }
            withAnimation(BookMotion.deal(delay: arrivalDelay, reduceMotion: false)) {
                hasArrived = true
            }
        }
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
            performDismissal()
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

    private func performDismissal() {
        guard !isTucking, !isRetiring else { return }
        BookFeedback.play(.dismissPage)
        if reduceMotion {
            onDismiss()
            return
        }
        withAnimation(.easeIn(duration: 0.26)) {
            dragOffset = -520
            isTucking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
            dragOffset = 0
            isTucking = false
        }
    }
}

enum LaunchDeskRitualVariant: Int, CaseIterable {
    case bookmarks
    case quill
    case letters
    case seals

    /// Random within the bank, but never the same ritual twice in succession.
    /// The caller persists the returned raw value across cold launches.
    static func next(avoidingRawValue previousRawValue: Int) -> Self {
        let choices = allCases.filter { $0.rawValue != previousRawValue }
        return choices.randomElement() ?? .bookmarks
    }

    var title: String {
        switch self {
        case .bookmarks:
            return "The bookmarks are taking their places."
        case .quill:
            return "The quill is finding today's first lines."
        case .letters:
            return "Loose letters are listening."
        case .seals:
            return "Three pages are being called forward."
        }
    }

    var detail: String {
        switch self {
        case .bookmarks:
            return "The Book is choosing what rises."
        case .quill:
            return "Three pages are gathering at the edge of the desk."
        case .letters:
            return "They'll settle when the right pages answer."
        case .seals:
            return "The seals will brighten when the desk is ready."
        }
    }
}

/// A launch-only ritual occupying the whole Pages Rising shelf. Nothing here is
/// tappable, so the reader can never begin interacting with a provisional Page.
struct LaunchDeskRitualView: View {
    let variant: LaunchDeskRitualVariant
    let isPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAwake = false

    private var animates: Bool {
        !reduceMotion && !isPaused
    }

    var body: some View {
        VStack(spacing: 18) {
            artwork
                .frame(height: 92)

            VStack(spacing: 5) {
                Text(variant.title)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .multilineTextAlignment(.center)

                Text(variant.detail)
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.60))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BookPalette.paper.opacity(0.98),
                            BookPalette.parchmentEdge.opacity(0.82),
                            BookPalette.paper.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(isAwake && animates ? 0.48 : 0.25), lineWidth: 1.2)
        }
        .shadow(
            color: BookPalette.lampGold.opacity(isAwake && animates ? 0.18 : 0.08),
            radius: 14,
            y: 6
        )
        .animation(
            animates ? .easeInOut(duration: 1.35).repeatForever(autoreverses: true) : nil,
            value: isAwake
        )
        .onAppear {
            isAwake = animates
        }
        .onChange(of: animates) { _, shouldAnimate in
            isAwake = shouldAnimate
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(variant.title) \(variant.detail)")
    }

    @ViewBuilder
    private var artwork: some View {
        switch variant {
        case .bookmarks:
            bookmarkArtwork
        case .quill:
            quillArtwork
        case .letters:
            letterArtwork
        case .seals:
            sealArtwork
        }
    }

    private var bookmarkArtwork: some View {
        HStack(alignment: .top, spacing: 15) {
            ForEach(0..<3, id: \.self) { index in
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(BookPalette.page)
                        .frame(width: 58, height: 76)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(BookPalette.gold.opacity(0.30), lineWidth: 1)
                        }
                    Rectangle()
                        .fill(index == 1 ? BookPalette.teal : BookPalette.violet)
                        .frame(width: 12, height: 42)
                        .offset(y: isAwake && animates ? 22 : 8)
                        .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                }
                .rotationEffect(.degrees(animates && isAwake ? Double(index - 1) * 2.5 : 0))
            }
        }
    }

    private var quillArtwork: some View {
        ZStack {
            VStack(spacing: 13) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(BookPalette.ink.opacity(0.12 + Double(index) * 0.035))
                        .frame(width: 150 - CGFloat(index * 18), height: 2)
                }
            }
            Image(systemName: "pencil.tip")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(BookPalette.gold)
                .rotationEffect(.degrees(-42))
                .offset(
                    x: animates && isAwake ? 56 : -52,
                    y: animates && isAwake ? 18 : -23
                )
                .shadow(color: BookPalette.lampGold.opacity(0.32), radius: 8)
        }
    }

    private var letterArtwork: some View {
        HStack(spacing: 15) {
            ForEach(Array(["R", "I", "S", "E"].enumerated()), id: \.offset) { index, letter in
                Text(letter)
                    .font(.system(size: 31, weight: .bold, design: .serif))
                    .foregroundStyle(index.isMultiple(of: 2) ? BookPalette.teal : BookPalette.gold)
                    .rotationEffect(.degrees(animates && isAwake ? Double(index - 1) * 3 : Double(2 - index) * 7))
                    .offset(y: animates && isAwake ? 0 : CGFloat(index.isMultiple(of: 2) ? 12 : -10))
                    .shadow(color: BookPalette.lampGold.opacity(0.18), radius: 6)
            }
        }
    }

    private var sealArtwork: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(BookPalette.page)
                        .frame(width: 60, height: 78)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(BookPalette.parchmentEdge.opacity(0.65), lineWidth: 1)
                        }
                    Image(systemName: "seal.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(index == 1 ? BookPalette.violet : BookPalette.gold)
                        .scaleEffect(animates && isAwake ? 1.08 : 0.82)
                        .opacity(animates && isAwake ? 1 : 0.56)
                }
                .offset(y: animates && isAwake ? CGFloat(index.isMultiple(of: 2) ? -3 : 3) : 0)
            }
        }
    }
}

private struct SurfaceRetirementPlaceholder: View {
    let surface: SurfacePage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private var visualStyle: PageVisualStyle {
        PageVisualStyle.style(for: surface.type)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            visualStyle.paperTop.opacity(0.92),
                            visualStyle.paperMiddle.opacity(0.96),
                            visualStyle.paperBottom.opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.32), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(x: 0.42, y: 1.25)
                .offset(x: reduceMotion ? 0 : (breathing ? 190 : -190))
                .blendMode(.screen)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(visualStyle.accent.opacity(breathing && !reduceMotion ? 0.22 : 0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: "books.vertical.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(visualStyle.accent)
                        .rotationEffect(.degrees(breathing && !reduceMotion ? -3 : 3))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("The stacks are choosing...")
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.82))
                    Text("Another page is finding this place on the desk.")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(visualStyle.accent.opacity(breathing && !reduceMotion ? 0.44 : 0.24), lineWidth: 1.2)
        }
        .shadow(color: visualStyle.accent.opacity(breathing && !reduceMotion ? 0.20 : 0.08), radius: 12, y: 5)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.45).repeatForever(autoreverses: true),
            value: breathing
        )
        .onAppear {
            guard !reduceMotion else { return }
            breathing = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The Book is choosing another page")
    }
}

struct SwipeDismissBookOfYouHero<Content: View>: View {
    let content: Content
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var isTucking = false

    private let dismissThreshold: CGFloat = 96
    private let horizontalDragRatio: CGFloat = 1.6
    private let waxDeep = Color(red: 0.24, green: 0.06, blue: 0.08)
    private let waxRed = Color(red: 0.42, green: 0.13, blue: 0.13)

    init(@ViewBuilder content: () -> Content, onDismiss: @escaping () -> Void) {
        self.content = content()
        self.onDismiss = onDismiss
    }

    private var dragProgress: CGFloat {
        min(1, abs(min(0, dragOffset)) / dismissThreshold)
    }

    private var tiltDegrees: Double {
        guard !reduceMotion else { return 0 }
        let base = Double(dragProgress) * 2.5
        return isTucking ? base + 5 : base
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            marginReveal

            content
                .scaleEffect(reduceMotion ? 1 : (isTucking ? 0.92 : 1 - dragProgress * 0.025), anchor: .bottomLeading)
                .rotationEffect(.degrees(-tiltDegrees), anchor: .bottomLeading)
                .offset(x: dragOffset)
                .overlay(alignment: .topTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(BookPalette.nightText.opacity(0.48))
                            .padding(10)
                    }
                    .buttonStyle(.bookPress())
                    .accessibilityLabel("Dismiss Book of You preview")
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
        .accessibilityHint("Use the close button or small right-edge tab to dismiss this preview.")
    }

    private var marginReveal: some View {
        let sealed = dragProgress > 0.75 || isTucking
        return HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: sealed ? "seal.fill" : "seal")
                    .font(.title3.weight(.bold))
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragProgress) * -12))
                Text("Shelve preview")
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
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
            value: hinting
        )
        .contentShape(Rectangle())
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            hinting = true
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
        .buttonStyle(.bookPress(playsHaptic: false))
        .bookCardHover()
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

struct SourceSettingsSheet: View {
    let sources: [BookPageSource]
    let onSet: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Binding var publicMarginsIncomingOptIn: Bool
    @Binding var publicMarginsOutgoingOptIn: Bool
    @State private var preferences: [String: Bool]
    @State private var publicMarginsReceiptCount: Int
    @State private var isWithdrawingPublicMargins = false
    @State private var publicMarginsWithdrawalMessage = ""

    init(
        sources: [BookPageSource],
        preferences: [String: Bool],
        publicMarginsIncomingOptIn: Binding<Bool>,
        publicMarginsOutgoingOptIn: Binding<Bool>,
        onSet: @escaping (String, Bool) -> Void
    ) {
        self.sources = sources
        self.onSet = onSet
        _publicMarginsIncomingOptIn = publicMarginsIncomingOptIn
        _publicMarginsOutgoingOptIn = publicMarginsOutgoingOptIn
        _preferences = State(initialValue: preferences)
        _publicMarginsReceiptCount = State(initialValue: PublicMarginsAPI.storedDeletionReceiptCount)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        publicMarginsDoorways

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

    private var publicMarginsDoorways: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("The Public Margins", systemImage: "person.3.sequence.fill")
                .font(.headline)
                .foregroundStyle(BookPalette.ink)

            Text("Two separate doors. Both begin closed. Opening either one never opens the other.")
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.66))

            Toggle(isOn: $publicMarginsIncomingOptIn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Bring the Public Margins into my Book")
                        .font(.subheadline.weight(.semibold))
                    Text("Fetch automatically screened community souvenirs. No social feed or reader identity comes with them.")
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.60))
                }
            }
            .tint(BookPalette.teal)

            Divider().overlay(BookPalette.ink.opacity(0.10))

            Toggle(isOn: $publicMarginsOutgoingOptIn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Offer me ways to add to the Public Margins")
                        .font(.subheadline.weight(.semibold))
                    Text("Shows invitations only. Every sentence and quiet choice still requires its own exact public confirmation.")
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.60))
                }
            }
            .tint(BookPalette.lampGold)

            if publicMarginsReceiptCount > 0 {
                Divider().overlay(BookPalette.ink.opacity(0.10))
                Button(role: .destructive) {
                    Task { await withdrawPublicMarginsContributions() }
                } label: {
                    Label(
                        isWithdrawingPublicMargins
                            ? "Withdrawing..."
                            : "Withdraw \(publicMarginsReceiptCount) public sentence\(publicMarginsReceiptCount == 1 ? "" : "s")",
                        systemImage: "arrow.uturn.backward.circle"
                    )
                    .font(.caption.weight(.bold))
                }
                .disabled(isWithdrawingPublicMargins)
            }

            if !publicMarginsWithdrawalMessage.isEmpty {
                Text(publicMarginsWithdrawalMessage)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.64))
            }
        }
        .padding(16)
        .background(BookPalette.page.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.28), lineWidth: 1)
        }
    }

    @MainActor
    private func withdrawPublicMarginsContributions() async {
        guard !isWithdrawingPublicMargins else { return }
        isWithdrawingPublicMargins = true
        let before = publicMarginsReceiptCount
        let deleted = await PublicMarginsAPI.withdrawAllStoredContributions()
        publicMarginsReceiptCount = PublicMarginsAPI.storedDeletionReceiptCount
        isWithdrawingPublicMargins = false
        publicMarginsWithdrawalMessage = deleted == before
            ? "Those public sentences have been withdrawn."
            : "Withdrew \(deleted). \(publicMarginsReceiptCount) could not be reached yet; their private deletion receipts remain on this device."
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
    struct ExternalActions {
        var learningAllowed: Bool
        var weavingAllowed: Bool
        var sourceURL: URL?
        var attachments: [BookPageExternalAttachment]
        var onToggleLearning: () -> Void
        var onToggleWeaving: () -> Void
    }

    let page: BookPage
    let externalActions: ExternalActions?
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var dragOffset: CGFloat = 0

    init(
        page: BookPage,
        externalActions: ExternalActions? = nil,
        onOpen: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.page = page
        self.externalActions = externalActions
        self.onOpen = onOpen
        self.onRemove = onRemove
    }

    private let dismissThreshold: CGFloat = 82
    private let horizontalDragRatio: CGFloat = 1.6

    private var visualStyle: PageVisualStyle {
        PageVisualStyle.style(for: page.type)
    }

    private var isScrapbookPage: Bool {
        page.tags.contains("scrapbook") || page.tags.contains("pagewright")
    }

    private var displayTitle: String {
        guard isScrapbookPage else { return page.type.title }
        return page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Scrapbook Page"
    }

    private var thumbnailAsset: BookPageMediaAsset? {
        page.pagewrightPreviewImageAsset
            ?? page.mediaAssets.first { !$0.isPagewrightPDF }
            ?? page.mediaAssets.first
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
                if let mediaAsset = thumbnailAsset {
                    BookOfYouMediaThumbnail(asset: mediaAsset, width: 56, height: 48)
                } else {
                    Image(systemName: page.type.symbolName)
                        .foregroundStyle(visualStyle.symbolColor)
                        .frame(width: 28, height: 28)
                        .background(visualStyle.accent.opacity(0.12), in: Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
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
                VStack(spacing: 0) {
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

                    if let actions = externalActions {
                        Menu {
                            Button {
                                actions.onToggleLearning()
                            } label: {
                                Label(
                                    actions.learningAllowed
                                        ? "Keep, but don't teach curation"
                                        : "Let this teach curation",
                                    systemImage: actions.learningAllowed ? "brain.head.profile.slash" : "brain.head.profile"
                                )
                            }
                            Button {
                                actions.onToggleWeaving()
                            } label: {
                                Label(
                                    actions.weavingAllowed
                                        ? "Keep out of stories"
                                        : "Let the Book weave with this",
                                    systemImage: actions.weavingAllowed ? "text.badge.xmark" : "text.badge.plus"
                                )
                            }
                            if let sourceURL = actions.sourceURL {
                                Link(destination: sourceURL) {
                                    Label("Open original", systemImage: "arrow.up.right.square")
                                }
                            }
                            ForEach(actions.attachments) { attachment in
                                Link(destination: URL(fileURLWithPath: attachment.filePath)) {
                                    Label(
                                        attachment.originalFilename?.nonEmpty ?? "Open attachment",
                                        systemImage: attachment.kind == "image" ? "photo" : "doc"
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(BookPalette.teal.opacity(0.70))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .accessibilityLabel("Options for this imported scrap")
                    }
                }
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
        if isScrapbookPage {
            let note = text.components(separatedBy: "\n\nScraps bound here:").first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return note?.nonEmpty ?? "A kept scrapbook page. Tap to preview the page."
        }
        return page.archivePreviewText ?? page.type.title
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

struct ReturnedStacksDailyHeader: View {
    let cards: [ReturnedStackCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("TODAY'S THREE RETURNS")
                    .font(.caption2.smallCaps().weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(BookPalette.ink.opacity(0.92))

                Spacer(minLength: 8)

                Text("new at midnight")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
            }

            Text("One rhyme. One long memory. One page the Stacks chose simply to keep the Book from becoming predictable.")
                .font(.system(.callout, design: .serif))
                .lineSpacing(3)
                .foregroundStyle(BookPalette.ink.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                ForEach(cards, id: \.role.rawValue) { card in
                    Label(card.role.title, systemImage: card.role.symbolName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.88))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(roleChipFill(card.role))
                        )
                        .overlay {
                            Capsule()
                                .stroke(roleTint(card.role).opacity(0.52), lineWidth: 0.8)
                        }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BookPalette.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BookPalette.gold.opacity(0.52), lineWidth: 1)
                }
                .shadow(color: BookPalette.ink.opacity(0.16), radius: 5, y: 2)
        )
    }

    private func roleTint(_ role: ReturnedStackRole) -> Color {
        switch role {
        case .rhyme: return BookPalette.teal
        case .longMemory: return BookPalette.gold
        case .wildCard: return BookPalette.violet
        }
    }

    private func roleChipFill(_ role: ReturnedStackRole) -> Color {
        switch role {
        case .rhyme:
            return Color(red: 0.82, green: 0.90, blue: 0.85)
        case .longMemory:
            return Color(red: 0.94, green: 0.85, blue: 0.62)
        case .wildCard:
            return Color(red: 0.88, green: 0.80, blue: 0.86)
        }
    }
}

struct ResurfacedPageRow: View {
    let card: ReturnedStackCard
    let revealIndex: Int
    let onOpen: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    private var page: BookPage { card.page }

    private var visualStyle: PageVisualStyle {
        PageVisualStyle.style(for: page.type)
    }

    private var roleTint: Color {
        switch card.role {
        case .rhyme: return BookPalette.teal
        case .longMemory: return BookPalette.gold
        case .wildCard: return BookPalette.violet
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(card.role.title.uppercased(), systemImage: card.role.symbolName)
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(roleTint)

                Spacer(minLength: 8)

                Text("\(revealIndex + 1) of 3 · \(page.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.48))
            }

            Text(page.archivePreviewText ?? page.type.title)
                .font(.system(.body, design: .serif, weight: .semibold))
                .lineSpacing(4)
                .foregroundStyle(BookPalette.ink.opacity(0.84))
                .lineLimit(5)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(roleTint.opacity(0.88))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text("WHY IT FOUND THE STAIRS")
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                        .foregroundStyle(roleTint.opacity(0.82))

                    Text(card.reason)
                        .font(.caption)
                        .lineSpacing(2)
                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(roleTint.opacity(0.065))
            )

            HStack(spacing: 7) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.40))
                Text(card.tinyAction)
                    .font(.caption2.italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.54))
                    .lineLimit(2)
                Spacer(minLength: 6)
                Image(systemName: "book.pages")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(visualStyle.accent.opacity(0.72))
            }
        }
        .padding(15)
        .parchmentSurface(style: visualStyle, isActive: false)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            onOpen()
        }
        .opacity(isRevealed ? 1 : 0)
        .offset(y: reduceMotion || isRevealed ? 0 : 12)
        .onAppear {
            guard !isRevealed else { return }
            if reduceMotion {
                isRevealed = true
            } else {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.82).delay(Double(revealIndex) * 0.10)) {
                    isRevealed = true
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            MarginaliaImage(name: visualStyle.sideMarginalia, width: 62, opacity: 0.24)
                .rotationEffect(.degrees(4))
                .offset(x: 12, y: -10)
                .allowsHitTesting(false)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(card.role.title). \(page.archivePreviewText ?? page.type.title)")
        .accessibilityHint("\(card.reason) Opens this returned page.")
        .bookCardHover()
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

            if let echo = details.promiseEcho {
                Text(echo)
                    .font(.system(.footnote, design: .serif))
                    .italic()
                    .foregroundStyle(visualStyle.accent.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

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
        .bookCardHover()
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

struct BookOfYouMediaThumbnail: View {
    let asset: BookPageMediaAsset
    var width: CGFloat = 104
    var height: CGFloat = 82

    #if canImport(UIKit)
    @State private var photoLibraryImage: UIImage?
    #endif

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
        .onAppear {
            loadPhotoLibraryImageIfNeeded()
        }
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
        case .photoLibraryAsset:
            #if canImport(UIKit)
            return photoLibraryImage.map { Image(uiImage: $0) }
            #else
            return nil
            #endif
        case .audioFile:
            return nil
        }
    }

    private func loadPhotoLibraryImageIfNeeded() {
        #if canImport(Photos) && canImport(UIKit)
        guard asset.kind == .photoLibraryAsset,
              photoLibraryImage == nil,
              let photo = PHAsset.fetchAssets(withLocalIdentifiers: [asset.reference], options: nil).firstObject else {
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: photo,
            targetSize: CGSize(width: max(width * 3, 320), height: max(height * 3, 240)),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            guard let image else { return }
            DispatchQueue.main.async {
                photoLibraryImage = image
            }
        }
        #endif
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
        .bookCardHover()
    }
}

/// The larger rhythms of the Book of You live on the same shelf as its nightly
/// pages. A quiet disabled card lets the reader see what is gathering before a
/// week or month has enough ink to bind.
struct BookOfYouBindingCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let systemImage: String
    let isReady: Bool
    let readyLabel: String
    let onOpen: () -> Void

    var body: some View {
        Button {
            BookFeedback.play(.openPage)
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(eyebrow)
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(BookPalette.teal)

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BookPalette.ink)
                    .lineLimit(2)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .lineLimit(3)

                Spacer(minLength: 0)

                Text(isReady ? readyLabel : "Gathering")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isReady ? BookPalette.teal : BookPalette.ink.opacity(0.42))
            }
            .padding(14)
            .frame(width: 240, height: 170, alignment: .topLeading)
            .parchmentSurface(accent: isReady ? BookPalette.teal : BookPalette.gold.opacity(0.55), isActive: isReady)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.bookPress())
        .disabled(!isReady)
        .opacity(isReady ? 1 : 0.72)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityHint(isReady ? readyLabel : "This binding is still gathering pages.")
        .bookCardHover()
    }
}

struct WeeklyIssueArchiveCard: View {
    let artifact: KeptWeeklyIssueArtifact
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ISSUE NO. \(artifact.issue.number)")
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(BookPalette.teal)

                Text("Weekly Issue")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BookPalette.ink)

                Text(artifact.card.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .lineLimit(2)

                Text("\(artifact.issue.dateRange) · \(artifact.issue.keptCount) \(artifact.issue.keptCount == 1 ? "page" : "pages")")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .lineLimit(2)

                Spacer(minLength: 0)

                Text("Kept · Read issue")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }
            .padding(14)
            .frame(width: 240, height: 170, alignment: .topLeading)
            .parchmentSurface(accent: BookPalette.teal, isActive: false)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.bookPress())
        .accessibilityLabel("Kept Weekly Issue No. \(artifact.issue.number), \(artifact.issue.dateRange)")
        .accessibilityHint("Opens the saved weekly issue.")
        .bookCardHover()
    }
}

struct MonthlyEditionArchiveCard: View {
    let artifact: KeptMonthlyEditionArtifact
    let onOpen: () -> Void

    private var isFirstDoorEdition: Bool {
        artifact.monthKey == "first-door"
    }

    var body: some View {
        Button {
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(isFirstDoorEdition ? "FIRST EDITION" : "CHAPTER \(artifact.edition.chapterNumber)")
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(BookPalette.lampGold)

                Text(isFirstDoorEdition ? "The First Door" : "Monthly Edition")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BookPalette.ink)

                Text(isFirstDoorEdition ? artifact.edition.subtitle : artifact.monthLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .lineLimit(2)

                Text("\(artifact.edition.pageCount) \(artifact.edition.pageCount == 1 ? "page" : "pages") · \(artifact.edition.dayCount) \(artifact.edition.dayCount == 1 ? "day" : "days")")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .lineLimit(2)

                Spacer(minLength: 0)

                Text("Kept · Read edition")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
            }
            .padding(14)
            .frame(width: 240, height: 170, alignment: .topLeading)
            .parchmentSurface(accent: BookPalette.lampGold, isActive: false)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.bookPress())
        .accessibilityLabel(
            isFirstDoorEdition
                ? "Kept First Edition, The First Door"
                : "Kept Monthly Edition, \(artifact.monthLabel)"
        )
        .accessibilityHint(isFirstDoorEdition ? "Opens the saved first edition." : "Opens the saved monthly edition.")
        .bookCardHover()
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
            .animation(
                isAnimating ? .easeInOut(duration: 4.8).repeatForever(autoreverses: true) : nil,
                value: breath
            )
            .onAppear {
                guard isAnimating else { return }
                breath = true
            }
            .onChange(of: isPaused) { _, paused in
                if paused {
                    breath = false
                } else if !reduceMotion {
                    breath = true
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
            .animation(
                isAnimating ? .easeInOut(duration: period).repeatForever(autoreverses: true) : nil,
                value: phase
            )
            .onAppear {
                guard isAnimating else { return }
                phase = true
            }
            .onChange(of: isPaused) { _, paused in
                if paused {
                    phase = false
                } else if !reduceMotion {
                    phase = true
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
            .animation(
                isAnimating ? .easeInOut(duration: period).repeatForever(autoreverses: true) : nil,
                value: lit
            )
            .onAppear {
                guard isAnimating else { return }
                lit = true
            }
            .onChange(of: isPaused) { _, paused in
                if paused {
                    lit = false
                } else if !reduceMotion {
                    lit = true
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

struct BookWorkingAuthorityCard: View {
    let authority: BookWorkingAuthority
    let hasCurrentWorking: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: authority.isEnabled ? "key.fill" : "key")
                .font(.title3)
                .foregroundStyle(authority.isEnabled ? BookPalette.lampGold : BookPalette.nightText.opacity(0.48))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("The Book's Hands")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.9))
                Text(statusLine)
                    .font(.caption2)
                    .foregroundStyle(BookPalette.nightText.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(authority.isEnabled ? "Pact" : "Open") { onOpen() }
                .font(.caption.weight(.bold))
                .buttonStyle(.bordered)
                .tint(authority.isEnabled ? BookPalette.lampGold : BookPalette.teal)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BookPalette.paper.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BookPalette.nightText.opacity(0.1), lineWidth: 0.7)
                )
        )
    }

    private var statusLine: String {
        guard authority.isEnabled else {
            return "The house keys are sealed. Open one standing pact if the Book may arrange surprises beyond its pages."
        }
        if hasCurrentWorking {
            return "Something has been arranged. The receipts will tell the truth afterward."
        }
        return "\(authority.appetite.detail) Between \(authority.earliestHour):00 and \(authority.latestHour):00; never per-event permission buttons."
    }
}

struct BookWorkingAuthoritySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BookWorkingAuthority
    let onSave: (BookWorkingAuthority) -> Void

    init(
        authority: BookWorkingAuthority,
        onSave: @escaping (BookWorkingAuthority) -> Void
    ) {
        _draft = State(initialValue: authority)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Let the Book arrange Workings", isOn: $draft.isEnabled)
                        .tint(BookPalette.lampGold)
                } header: {
                    Text("A standing pact")
                } footer: {
                    Text("You choose the powers and frequency once. The Book or a character chooses the moment. You can close the pact here at any time.")
                }

                if draft.isEnabled {
                    Section("How alive should it be?") {
                        Picker("Appetite", selection: $draft.appetite) {
                            ForEach(BookWorkingAppetite.allCases) { appetite in
                                Text(appetite.title).tag(appetite)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(draft.appetite.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Toggle("Make openings in Calendar", isOn: $draft.allowsCalendarOpenings)
                            .tint(BookPalette.teal)
                        Toggle("Use a governed whisper seat", isOn: $draft.allowsNotificationSummons)
                            .tint(BookPalette.lampGold)
                    } header: {
                        Text("House keys")
                    } footer: {
                        Text("Workings use free patches between 5:00 PM and 10:00 PM, leave a fifteen-minute buffer around other events, and never add a third notification seat to a day.")
                    }

                    Section("What the pact cannot mean") {
                        Label("No purchases, messages, deletions, or public posts", systemImage: "nosign")
                        Label("No claim that an effect happened without a receipt", systemImage: "checkmark.seal")
                        Label("No punishment, streak, or meaning attached to saying no", systemImage: "hand.raised")
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("The Book's Hands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.isEnabled ? "Bind Pact" : "Seal") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.isEnabled && !draft.hasAnOutsideDoorway)
                }
            }
        }
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

/// The Book's recurring visual signature. It is always the same closed,
/// midnight-blue volume; lived state changes only the physical evidence around
/// it — a dog-ear, a guarded ribbon, a sealed leaf, or a pencil correction.
/// That keeps the Book recognizable without turning it into a face or mascot.
struct BookPresenceSilhouette: View {
    let stance: BookStance
    let interior: BookInteriorState
    var isPaused = false
    let onKnock: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didArrive = false
    @State private var isKnocking = false

    private enum MaterialMark: Equatable {
        case sealedLeaf
        case dogEar
        case keepingWatch
        case revision
        case longGame
        case none
    }

    private var mark: MaterialMark {
        if interior.secret?.status == .ready { return .sealedLeaf }
        if interior.favorite != nil, interior.favorite?.firstPresentedAt == nil { return .dogEar }
        if interior.promise?.status == .keeping { return .keepingWatch }
        if interior.opinion?.strength == .reconsidering,
           interior.opinion?.firstPresentedAt == nil { return .revision }
        if interior.longGame?.phasePresentedAt == nil, interior.longGame != nil { return .longGame }
        return .none
    }

    private var stanceRotation: Double {
        switch stance {
        case .curious: return -1.0
        case .protective: return 0
        case .mischievous: return 1.8
        case .hushed: return -0.3
        case .contrite: return -1.6
        case .intent: return 0.4
        case .pleased: return 1.0
        }
    }

    private var ribbonDrift: CGFloat {
        switch stance {
        case .protective: return -3
        case .mischievous: return 4
        case .contrite: return -1
        case .intent: return 2
        default: return 0
        }
    }

    private var glowOpacity: Double {
        switch stance {
        case .hushed: return 0.16
        case .protective, .contrite: return 0.24
        case .curious, .intent: return 0.34
        case .mischievous, .pleased: return 0.46
        }
    }

    private var accessibilityDescription: String {
        let disposition: String
        switch stance {
        case .curious: disposition = "listening with its cover slightly raised"
        case .protective: disposition = "keeping its covers close"
        case .mischievous: disposition = "sitting a little crooked, as if it knows something"
        case .hushed: disposition = "resting quietly"
        case .contrite: disposition = "holding a correction in pencil"
        case .intent: disposition = "holding its place with care"
        case .pleased: disposition = "settled and quietly pleased"
        }

        let evidence: String
        switch mark {
        case .sealedLeaf: evidence = " A sealed leaf is showing."
        case .dogEar: evidence = " One corner is dog-eared."
        case .keepingWatch: evidence = " Its ribbon is keeping an unfinished promise."
        case .revision: evidence = " A pencil correction crosses the cover."
        case .longGame: evidence = " Its ribbon marks a longer piece of business."
        case .none: evidence = ""
        }
        return "The Book is \(disposition).\(evidence)"
    }

    var body: some View {
        Button(action: knock) {
            ZStack(alignment: .topTrailing) {
                pageBlock
                cover
                ribbon
                materialEvidence
            }
            .frame(width: 54, height: 68)
            .rotationEffect(.degrees(isKnocking ? -2.4 : stanceRotation))
            .scaleEffect(didArrive ? 1 : 0.92, anchor: .bottom)
            .offset(y: didArrive ? 0 : 5)
            .opacity(didArrive ? 1 : 0)
            .shadow(
                color: BookPalette.lampGold.opacity(glowOpacity),
                radius: stance == .hushed ? 5 : 10,
                x: 0,
                y: 5
            )
            .animation(BookMotion.reveal(reduceMotion), value: stance)
            .animation(BookMotion.reveal(reduceMotion), value: mark)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Knock on the cover")
        .onAppear {
            guard !didArrive else { return }
            if reduceMotion || isPaused {
                didArrive = true
            } else {
                withAnimation(BookMotion.reveal(false)) {
                    didArrive = true
                }
            }
        }
    }

    private var pageBlock: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [BookPalette.page, BookPalette.paper, BookPalette.parchmentEdge],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 47, height: 61)
            .overlay(alignment: .trailing) {
                VStack(spacing: 1.5) {
                    ForEach(0..<12, id: \.self) { index in
                        Rectangle()
                            .fill(BookPalette.ink.opacity(index.isMultiple(of: 4) ? 0.16 : 0.07))
                            .frame(height: 0.55)
                    }
                }
                .frame(width: 4)
                .padding(.vertical, 6)
            }
            .offset(x: 3, y: 4)
    }

    private var cover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.035, green: 0.045, blue: 0.105))

            Image("EnchantedBookCoverPlate")
                .resizable()
                .scaledToFill()
                .saturation(0.9)
                .contrast(1.08)
                .opacity(stance == .hushed ? 0.72 : 0.94)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.68), lineWidth: 1)
                .padding(4)

            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BookPalette.lampGold.opacity(stance == .hushed ? 0.48 : 0.92))
                .shadow(color: BookPalette.lampGold.opacity(glowOpacity), radius: 5)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.42), .clear, .black.opacity(0.14)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 47, height: 61)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(.black.opacity(0.48), lineWidth: 0.7)
        }
    }

    private var ribbon: some View {
        VStack(spacing: -1) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.12, blue: 0.18), Color(red: 0.25, green: 0.03, blue: 0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 5, height: mark == .keepingWatch ? 57 : 50)
            BookRibbonTail()
                .fill(Color(red: 0.37, green: 0.05, blue: 0.10))
                .frame(width: 8, height: 9)
        }
        .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
        .offset(x: ribbonDrift - 7, y: 9)
        .rotationEffect(.degrees(stance == .mischievous ? 3 : stance == .protective ? -1.5 : 0), anchor: .top)
    }

    @ViewBuilder
    private var materialEvidence: some View {
        switch mark {
        case .sealedLeaf:
            VStack(spacing: -2) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(BookPalette.paper)
                    .frame(width: 18, height: 22)
                    .overlay {
                        VStack(spacing: 2) {
                            Rectangle().frame(width: 10, height: 0.6)
                            Rectangle().frame(width: 7, height: 0.6)
                        }
                        .foregroundStyle(BookPalette.ink.opacity(0.38))
                    }
                Circle()
                    .fill(Color(red: 0.46, green: 0.05, blue: 0.10))
                    .frame(width: 8, height: 8)
            }
            .rotationEffect(.degrees(5))
            .offset(x: 6, y: -7)
        case .dogEar:
            BookDogEar()
                .fill(BookPalette.paper)
                .frame(width: 15, height: 15)
                .overlay {
                    BookDogEar()
                        .stroke(BookPalette.lampGold.opacity(0.55), lineWidth: 0.8)
                }
                .offset(x: 1, y: 1)
        case .keepingWatch:
            Circle()
                .stroke(BookPalette.lampGold.opacity(0.86), lineWidth: 1.2)
                .frame(width: 11, height: 11)
                .overlay {
                    Circle().fill(BookPalette.lampGold.opacity(0.34)).padding(3)
                }
                .offset(x: -13, y: 42)
        case .revision:
            ZStack {
                Capsule()
                    .fill(BookPalette.paper.opacity(0.8))
                    .frame(width: 27, height: 1.2)
                    .rotationEffect(.degrees(-13))
                Capsule()
                    .fill(BookPalette.paper.opacity(0.52))
                    .frame(width: 19, height: 1)
                    .rotationEffect(.degrees(-5))
                    .offset(y: 5)
            }
            .offset(x: -9, y: 18)
        case .longGame:
            Image(systemName: "map.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(BookPalette.lampGold)
                .padding(4)
                .background(BookPalette.nightPanel.opacity(0.94), in: Circle())
                .overlay { Circle().stroke(BookPalette.lampGold.opacity(0.58), lineWidth: 0.8) }
                .offset(x: -11, y: 41)
        case .none:
            EmptyView()
        }
    }

    private func knock() {
        onKnock()
        guard !reduceMotion else { return }
        withAnimation(BookMotion.direct(false)) {
            isKnocking = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(130))
            withAnimation(BookMotion.result(false)) {
                isKnocking = false
            }
        }
    }
}

private struct BookRibbonTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.62))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct BookDogEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// The same physical book carries onboarding and everyday launch. The wrappers
/// own their timing; this view owns the cover, hinge, lit inner page, and sparks
/// so the two transitions cannot quietly drift into different visual languages.
private struct FallingBookArtwork: View {
    let width: CGFloat
    let height: CGFloat
    let coverTitleLines: [String]
    let insideTitle: String
    let titleWrite: Double
    let open: Double
    let idleTime: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let leatherTop = Color(red: 0.09, green: 0.10, blue: 0.19)
    private static let leatherMid = Color(red: 0.06, green: 0.07, blue: 0.14)
    private static let leatherLow = Color(red: 0.03, green: 0.04, blue: 0.09)

    var body: some View {
        ZStack {
            pageBlock
            innerPage
            frontCover
        }
        .frame(width: width, height: height)
    }

    private var pageBlock: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [BookPalette.page, BookPalette.paper, BookPalette.parchmentEdge],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .trailing) {
                VStack(spacing: 2.2) {
                    ForEach(0..<18, id: \.self) { index in
                        Rectangle()
                            .fill(BookPalette.ink.opacity(index.isMultiple(of: 4) ? 0.10 : 0.045))
                            .frame(height: 0.65)
                    }
                }
                .padding(.vertical, 10)
                .frame(width: 6)
            }
            .frame(width: width, height: height)
            .offset(x: 5, y: 4)
            .shadow(color: .black.opacity(0.32), radius: 7, x: 5, y: 7)
    }

    private var innerPage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BookPalette.page, BookPalette.paper, BookPalette.page],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image("ParchmentTexture")
                .resizable()
                .scaledToFill()
                .opacity(0.5)
                .blendMode(.multiply)

            RadialGradient(
                colors: [BookPalette.lampGold.opacity(0.6 * open), .clear],
                center: .init(x: 0.14, y: 0.5),
                startRadius: 0,
                endRadius: width * (0.5 + open)
            )

            VStack(spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .shadow(color: BookPalette.lampGold.opacity(0.6), radius: 10)
                Text(insideTitle)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(BookPalette.gold.opacity(0.8))
                    .tracking(1.4)
            }
            .opacity(openingProgress(open, from: 0.45, to: 1.0))

            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
                for index in 0..<12 {
                    let seed = Double(index) * 0.83
                    let rise = open * (0.8 + 0.4 * ((sin(seed) + 1) / 2))
                    let center = CGPoint(
                        x: width * (0.12 + 0.5 * CGFloat((sin(seed * 1.7) + 1) / 2)),
                        y: height * (0.9 - 0.7 * CGFloat(rise))
                    )
                    let color = BookPalette.lampGold.opacity(0.5 * open)

                    if index.isMultiple(of: 3) {
                        var sparkle = Path()
                        sparkle.move(to: CGPoint(x: center.x - 4, y: center.y))
                        sparkle.addLine(to: CGPoint(x: center.x + 4, y: center.y))
                        sparkle.move(to: CGPoint(x: center.x, y: center.y - 4))
                        sparkle.addLine(to: CGPoint(x: center.x, y: center.y + 4))
                        context.stroke(sparkle, with: .color(color), lineWidth: 1.2)
                    } else {
                        context.fill(
                            Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)),
                            with: .color(color)
                        )
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.parchmentEdge.opacity(0.4), lineWidth: 1)
        }
    }

    private var frontCover: some View {
        let faceOpacity = 1 - openingProgress(open, from: 0.32, to: 0.6)
        let idlePulse = reduceMotion ? 0 : (sin(idleTime * 1.75) + 1) / 2
        let shimmerProgress = reduceMotion
            ? 0.5
            : (idleTime.truncatingRemainder(dividingBy: 4.6) + 4.6).truncatingRemainder(dividingBy: 4.6) / 4.6
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Self.leatherTop, Self.leatherMid, Self.leatherLow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image("EnchantedBookCoverPlate")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .saturation(0.92)
                .contrast(1.04)

            RadialGradient(
                colors: [
                    Self.leatherMid.opacity(0.04),
                    Self.leatherLow.opacity(0.18),
                    Self.leatherLow.opacity(0.48)
                ],
                center: .center,
                startRadius: width * 0.12,
                endRadius: width * 0.78
            )

            LinearGradient(
                colors: [
                    .clear,
                    BookPalette.lampGold.opacity(0.02),
                    BookPalette.nightText.opacity(0.32),
                    BookPalette.lampGold.opacity(0.08),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.27, height: height * 1.25)
            .rotationEffect(.degrees(12))
            .offset(x: -width * 0.82 + width * 1.64 * CGFloat(shimmerProgress))
            .blendMode(.screen)
            .opacity(faceOpacity)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.42 + 0.12 * idlePulse), lineWidth: 1.25)
                .padding(12)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.22 + 0.10 * idlePulse), lineWidth: 0.85)
                .padding(18)

            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .shadow(
                        color: BookPalette.lampGold.opacity(0.46 + 0.24 * idlePulse),
                        radius: CGFloat(8 + 4 * idlePulse)
                    )
                    .scaleEffect(CGFloat(reduceMotion ? 1 : 0.96 + 0.07 * idlePulse))
                    .padding(.bottom, 6)
                    .opacity(faceOpacity)

                ForEach(coverTitleLines.indices, id: \.self) { index in
                    WrittenGoldText(
                        coverTitleLines[index],
                        font: .system(size: min(width * 0.13, 30), weight: .semibold, design: .serif),
                        progress: titleWrite
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .frame(maxWidth: max(1, width - 48))
                }

                Rectangle()
                    .fill(BookPalette.lampGold.opacity(0.5))
                    .frame(width: width * 0.34, height: 1.4)
                    .padding(.top, 6)
                    .opacity(faceOpacity)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .opacity(max(faceOpacity, titleWrite < 1 ? 1 : faceOpacity))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .rotation3DEffect(
            .degrees((reduceMotion ? -8 : -158) * open),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.55
        )
        .opacity(reduceMotion ? 1 - openingProgress(open, from: 0.08, to: 0.9) : 1)
    }
}

private struct LaunchOpeningBookPhase: Equatable {
    var leadIn: Double
    var reveal: Double
    var appear: Double
    var titleWrite: Double
    var open: Double
    var rush: Double
    var flood: Double
    var idleTime: TimeInterval
}

private struct LaunchOpeningBookFrame: View {
    let phase: LaunchOpeningBookPhase
    let showsLoadingCue: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let bookW = min(size.width * 0.60, 264)
            let bookH = bookW * 1.34
            let idleStrength = reduceMotion ? 0 : (1 - phase.open)
            let idleBob = sin(phase.idleTime * 1.25) * 3.5 * idleStrength
            let idleSway = sin(phase.idleTime * 0.72) * 0.65 * idleStrength
            let idleBreath = (sin(phase.idleTime * 1.05) + 1) * 0.006 * idleStrength
            let appearanceScale = CGFloat(0.88 + 0.12 * phase.appear)
            let revealScale = CGFloat(0.34 * phase.rush)
            let bookScale = appearanceScale + revealScale + CGFloat(idleBreath)
            let bookOffset = -size.height * CGFloat(0.04 * phase.rush) + CGFloat(idleBob)

            ZStack {
                BookBackground(isQuiet: true, showsAmbientLetters: false)
                    .overlay {
                        Rectangle()
                            .fill(BookPalette.nightPanel.opacity(0.34))
                    }

                AmbientLetterField(
                    isPaused: reduceMotion,
                    externallyDrivenTime: phase.idleTime
                )
                .opacity(0.90 * (1 - openingProgress(phase.flood, from: 0.48, to: 0.92)))
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

                FallingBookArtwork(
                    width: bookW,
                    height: bookH,
                    coverTitleLines: ["ReEnchanted"],
                    insideTitle: "The Book Remembers",
                    titleWrite: phase.titleWrite,
                    open: phase.open,
                    idleTime: phase.idleTime
                )
                .scaleEffect(bookScale)
                .rotationEffect(.degrees(idleSway))
                .offset(y: bookOffset)
                .opacity(phase.appear * (1 - openingProgress(phase.flood, from: 0.82, to: 1)))
                .shadow(
                    color: BookPalette.lampGold.opacity(0.18 + 0.08 * idleBreath + 0.34 * phase.open),
                    radius: CGFloat(23 + 80 * idleBreath + 24 * phase.open),
                    y: CGFloat(18 - 10 * phase.open + idleBob * 0.3)
                )

                RadialGradient(
                    colors: [
                        BookPalette.nightText.opacity(0.98 * phase.flood),
                        BookPalette.lampGold.opacity(0.82 * phase.flood),
                        BookPalette.gold.opacity(0.38 * phase.flood),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * CGFloat(0.18 + 0.82 * phase.flood)
                )
                .blendMode(.screen)
                .allowsHitTesting(false)

                Rectangle()
                    .fill(BookPalette.page)
                    .opacity(openingProgress(phase.flood, from: 0.72, to: 1))
                    .allowsHitTesting(false)

                if showsLoadingCue {
                    VStack {
                        Spacer()
                        Label("Opening your book…", systemImage: "book.closed")
                            .font(.system(.caption, design: .serif, weight: .semibold))
                            .textCase(.uppercase)
                            .kerning(1.1)
                            .foregroundStyle(BookPalette.nightText.opacity(0.66))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(BookPalette.nightPanel.opacity(0.52), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(BookPalette.lampGold.opacity(0.18), lineWidth: 1)
                            }
                            .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 16))
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
        }
    }
}

struct OpeningBookLoadingView: View {
    let isReadyToReveal: Bool
    let onReachedHold: () -> Void
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = StallTolerantClock()
    @State private var didReachHold = false
    @State private var skipToHold = false
    @State private var revealStartElapsed: TimeInterval?
    @State private var didFinish = false

    private var leadInDuration: TimeInterval {
        reduceMotion ? 0.22 : 0.65
    }

    private var revealDuration: TimeInterval {
        reduceMotion ? 0.22 : 0.45
    }

    private var isTimelinePaused: Bool {
        didFinish
    }

    var body: some View {
        TimelineView(.animation(paused: isTimelinePaused)) { timeline in
            let phase = phase(at: timeline.date)
            LaunchOpeningBookFrame(
                phase: phase,
                showsLoadingCue: didReachHold && revealStartElapsed == nil
            )
            .contentShape(Rectangle())
            .onTapGesture {
                fastForwardToHold()
            }
            .onChange(of: phase.leadIn) { _, newValue in
                guard newValue >= 1 else { return }
                reachHold()
            }
            .onChange(of: isReadyToReveal) { _, ready in
                guard ready else { return }
                beginRevealIfPossible()
            }
            .onChange(of: phase.reveal) { _, newValue in
                guard newValue >= 1 else { return }
                finish()
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(didReachHold
            ? "The ReEnchanted book is ready to open. Loading your pages."
            : "A closed ReEnchanted book is appearing."
        )
        .accessibilityHint("Double-tap to skip the cover flourish. The book opens when your pages are ready.")
        .accessibilityAddTraits(.isButton)
    }

    private func phase(at date: Date) -> LaunchOpeningBookPhase {
        let elapsed = clock.tick(date, maxDelta: 1.0 / 12.0)
        let leadIn = skipToHold ? 1.0 : min(max(elapsed / leadInDuration, 0), 1)
        let reveal: Double
        if let revealStartElapsed {
            reveal = min(max((elapsed - revealStartElapsed) / revealDuration, 0), 1)
        } else {
            reveal = 0
        }

        return LaunchOpeningBookPhase(
            leadIn: leadIn,
            reveal: reveal,
            appear: openingProgress(leadIn, from: 0, to: reduceMotion ? 0.35 : 0.48),
            titleWrite: openingProgress(leadIn, from: 0.18, to: reduceMotion ? 0.7 : 0.9),
            open: openingProgress(reveal, from: 0, to: reduceMotion ? 0.72 : 0.82),
            rush: reduceMotion ? 0 : openingProgress(reveal, from: 0.28, to: 1),
            flood: openingProgress(reveal, from: reduceMotion ? 0.45 : 0.52, to: 1),
            idleTime: reduceMotion ? 0 : elapsed
        )
    }

    private func fastForwardToHold() {
        guard !didReachHold, !didFinish else { return }
        skipToHold = true
        reachHold()
    }

    private func reachHold() {
        guard !didReachHold, !didFinish else { return }
        didReachHold = true
        onReachedHold()
        beginRevealIfPossible()
    }

    private func beginRevealIfPossible() {
        guard didReachHold,
              isReadyToReveal,
              revealStartElapsed == nil,
              !didFinish else { return }
        revealStartElapsed = clock.elapsed
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}

/// The book-cover-opening beat played over the step 0 → 1 onboarding
/// transition: an ornate closed volume named "The Labyrinth of Stories"
/// gleams, then its cover swings open and pours warm light, carrying the
/// reader from their pressed first page into the story. Tap to skip.
struct LabyrinthCoverOpeningView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = StallTolerantClock()
    @State private var didFinish = false
    @State private var didBeginFallFeedback = false
    @State private var didLandFeedback = false

    private var duration: TimeInterval { reduceMotion ? 3.4 : 5.8 }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = clock.tick(timeline.date, maxDelta: 1.0 / 8)
            let progress = min(max(elapsed / duration, 0), 1)

            let appear = openingProgress(progress, from: 0.0, to: 0.13)
            let titleWrite = openingProgress(progress, from: 0.10, to: reduceMotion ? 0.26 : 0.30)
            let open = openingProgress(progress, from: 0.20, to: reduceMotion ? 0.46 : 0.40)
            let fall = reduceMotion ? 0 : openingProgress(progress, from: 0.32, to: 0.88)
            let landing = openingProgress(progress, from: reduceMotion ? 0.72 : 0.86, to: reduceMotion ? 0.92 : 0.96)
            let flood = openingProgress(progress, from: reduceMotion ? 0.70 : 0.82, to: 1.0)

            GeometryReader { proxy in
                let size = proxy.size
                let bookW = min(size.width * 0.60, 264)
                let bookH = bookW * 1.34
                let rushScale = reduceMotion ? CGFloat(1) : CGFloat(1 + 2.15 * fall)
                let rushOffset = reduceMotion ? CGFloat(0) : -size.height * CGFloat(0.10 * fall)

                ZStack {
                    BookBackground(isQuiet: true)
                        .overlay { Rectangle().fill(BookPalette.nightPanel.opacity(0.55)) }

                    FallThroughStoryField(progress: fall, elapsed: elapsed)
                        .opacity(reduceMotion ? 0 : openingProgress(fall, from: 0.04, to: 0.36) * (1 - landing))
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)

                    FallingBookArtwork(
                        width: bookW,
                        height: bookH,
                        coverTitleLines: ["The Labyrinth", "of Stories"],
                        insideTitle: "The Unwritten",
                        titleWrite: titleWrite,
                        open: open,
                        idleTime: reduceMotion ? 0 : elapsed
                    )
                    .scaleEffect((0.9 + 0.1 * appear) * rushScale)
                    .offset(y: rushOffset)
                    .opacity(appear)
                    .shadow(color: .black.opacity(0.42 * appear), radius: 26, x: 0, y: 20)

                    RadialGradient(
                        colors: [
                            BookPalette.lampGold.opacity(0.95 * flood),
                            BookPalette.gold.opacity(0.45 * flood),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * (0.35 + 0.65 * flood)
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)

                    if reduceMotion {
                        sensoryLine(
                            "The cover opens. Light carries you through.",
                            opacity: beatOpacity(progress, rise: 0.22...0.34, fall: 0.50...0.62)
                        )
                        sensoryLine(
                            "Stone under your knees. A hand reaching down.",
                            opacity: beatOpacity(progress, rise: 0.58...0.70, fall: 0.88...1.0)
                        )
                    } else {
                        sensoryLine(
                            "The room tips.\nYour stomach stays behind.",
                            opacity: beatOpacity(progress, rise: 0.28...0.36, fall: 0.44...0.52)
                        )
                        sensoryLine(
                            "Salt. Dragonfire. Peppermint snow.",
                            opacity: beatOpacity(progress, rise: 0.44...0.51, fall: 0.59...0.66)
                        )
                        sensoryLine(
                            "There isn't any down.\nOnly chapters.",
                            opacity: beatOpacity(progress, rise: 0.62...0.69, fall: 0.77...0.84)
                        )
                        sensoryLine(
                            "Stone catches you.",
                            opacity: beatOpacity(progress, rise: 0.86...0.90, fall: 0.96...1.0)
                        )
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(reduceMotion ? 1 : 1 + 0.018 * sin(fall * .pi * 12) * (1 - landing))
                .offset(y: reduceMotion ? 0 : 7 * sin(fall * .pi * 9) * (1 - landing))
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .onChange(of: progress) { _, value in
                if value >= 0.32, !didBeginFallFeedback {
                    didBeginFallFeedback = true
                    BookFeedback.bookJump(.start)
                }
                if value >= 0.86, !didLandFeedback {
                    didLandFeedback = true
                    BookFeedback.bookJump(.stabilize)
                }
                if value >= 1 { finish() }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The Book opens beneath you. Cold ink crosses your fingers. Stories rush past in salt, heat, snow, and sound. There is no down, only chapters. Stone catches you inside the library.")
        .accessibilityHint("Double-tap to skip the fall through the Book.")
        .accessibilityAddTraits(.isButton)
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        BookFeedback.play(.openPage)
        onFinished()
    }

    private func beatOpacity(
        _ progress: Double,
        rise: ClosedRange<Double>,
        fall: ClosedRange<Double>
    ) -> Double {
        openingProgress(progress, from: rise.lowerBound, to: rise.upperBound)
            * (1 - openingProgress(progress, from: fall.lowerBound, to: fall.upperBound))
    }

    private func sensoryLine(_ line: String, opacity: Double) -> some View {
        VStack {
            Spacer()
            Text(line)
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundStyle(BookPalette.nightText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.72), radius: 10, x: 0, y: 3)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(BookPalette.nightPanel.opacity(0.50 * opacity), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(opacity)
                .scaleEffect(0.96 + 0.04 * opacity)
                .padding(.bottom, 54)
        }
        .allowsHitTesting(false)
    }
}

/// A short tunnel of page-light, punctuation, and differently colored story
/// weather. It turns the cover opening into forward motion without requiring a
/// long explanatory scene.
private struct FallThroughStoryField: View {
    let progress: Double
    let elapsed: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height * 0.46)
            let reach = max(size.width, size.height)

            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
                for index in 0..<34 {
                    let seed = Double(index) * 1.731
                    let angle = seed * 2.4 + elapsed * (0.08 + Double(index % 4) * 0.015)
                    let lane = 0.18 + 0.82 * ((sin(seed * 0.73) + 1) / 2)
                    let distance = reach * CGFloat(0.06 + lane * progress)
                    let length = reach * CGFloat(0.015 + (0.06 + 0.12 * lane) * progress)
                    let direction = CGVector(dx: cos(angle), dy: sin(angle))
                    let end = CGPoint(
                        x: center.x + direction.dx * distance,
                        y: center.y + direction.dy * distance
                    )
                    let start = CGPoint(
                        x: end.x - direction.dx * length,
                        y: end.y - direction.dy * length
                    )

                    var streak = Path()
                    streak.move(to: start)
                    streak.addLine(to: end)

                    let color: Color
                    switch index % 5 {
                    case 0: color = BookPalette.teal
                    case 1: color = .orange
                    case 2: color = BookPalette.nightText
                    default: color = BookPalette.lampGold
                    }
                    context.stroke(
                        streak,
                        with: .color(color.opacity(0.16 + 0.58 * progress)),
                        style: StrokeStyle(
                            lineWidth: CGFloat(0.7 + 2.2 * lane * progress),
                            lineCap: .round
                        )
                    )
                }
            }

            ForEach(Array(["HERO", "WITNESS", "LOST", "ARRIVING", "?", "…"].enumerated()), id: \.offset) { index, word in
                let seed = Double(index) * 1.17
                let angle = seed + elapsed * (index.isMultiple(of: 2) ? 0.18 : -0.14)
                let radius = min(size.width, size.height) * CGFloat(0.14 + 0.34 * progress)
                Text(word)
                    .font(.system(size: index < 4 ? 12 : 19, weight: .black, design: .serif))
                    .tracking(index < 4 ? 1.2 : 0)
                    .foregroundStyle(BookPalette.nightText.opacity(0.26 + 0.54 * progress))
                    .rotationEffect(.degrees(angle * 21))
                    .position(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                    .blur(radius: max(0, 2.8 - 2.8 * progress))
            }
        }
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
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
            for index in 0..<24 {
                let age = Double(index) / 24
                let opacity = max(0, 0.68 - age * 0.58) * (1 - openingProgress(progress, from: 0.82, to: 0.98))
                let angle = Double(index) * 1.37 + progress * 10
                let radius = CGFloat(6 + index * 2)
                let center = CGPoint(
                    x: fairyPosition.x - CGFloat(cos(angle)) * radius - CGFloat(index),
                    y: fairyPosition.y - CGFloat(sin(angle)) * radius + CGFloat(index) * 0.7
                )
                let size: CGFloat = index.isMultiple(of: 3) ? 4.5 : 2.5
                let color = index.isMultiple(of: 4) ? BookPalette.nightText : BookPalette.lampGold

                context.stroke(
                    sparklePath(center: center, radius: size),
                    with: .color(color.opacity(opacity)),
                    lineWidth: index.isMultiple(of: 3) ? 1.25 : 0.9
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .blendMode(.plusLighter)
    }

    private func sparklePath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x - radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        return path
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
    var showsAmbientLetters = true

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
            if showsAmbientLetters {
                AmbientLetterField(isPaused: isQuiet)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
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
        case .tarot:
            return PageVisualStyle(
                accent: Color(red: 0.34, green: 0.19, blue: 0.45),
                symbolColor: BookPalette.lampGold,
                paperTop: Color(red: 0.95, green: 0.91, blue: 0.82),
                paperMiddle: Color(red: 0.89, green: 0.84, blue: 0.73),
                paperBottom: Color(red: 0.69, green: 0.58, blue: 0.54),
                scrapColor: Color(red: 0.88, green: 0.81, blue: 0.68),
                sideMarginalia: "MarginaliaStar",
                cornerMarginalia: "MarginaliaCompass",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaCompass",
                watermarkOpacity: 0.12
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
        case .elective, .wickerDare:
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
        case .plainPage:
            // Deliberately the plainest surface in the Book: muted paper, the
            // faintest watermark. The sacred dumb door should not look enchanted.
            return PageVisualStyle(
                accent: Color(red: 0.34, green: 0.32, blue: 0.30),
                symbolColor: Color(red: 0.34, green: 0.32, blue: 0.30),
                paperTop: Color(red: 0.95, green: 0.93, blue: 0.87),
                paperMiddle: Color(red: 0.88, green: 0.85, blue: 0.78),
                paperBottom: Color(red: 0.72, green: 0.68, blue: 0.62),
                scrapColor: Color(red: 0.90, green: 0.87, blue: 0.80),
                sideMarginalia: "IlluminationScrapS02_08",
                cornerMarginalia: "IlluminationScrapS03_12",
                smallMarginalia: "IlluminationScrapS01_08",
                watermarkMarginalia: "IlluminationScrapS02_13",
                watermarkOpacity: 0.05
            )
        case .diary, .note:
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
        case .quip, .quotes:
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
        case .aboutYou, .affirmations:
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
        case .lore, .narrativeOS, .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .theBleed, .bookPocket:
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
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
            value: pulse
        )
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
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
                .scaleEffect(isPressed ? (reduceMotion ? 0.95 : 0.92) : 1)

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
        .bookCardHover()
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
    var externallyDrivenTime: TimeInterval? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let externallyDrivenTime, !reduceMotion, !isPaused {
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                AmbientLetterFieldRenderer.draw(
                    in: context,
                    size: size,
                    time: externallyDrivenTime,
                    reduceMotion: false
                )
            }
            .opacity(0.78)
        } else if reduceMotion || isPaused {
            Canvas { context, size in
                AmbientLetterFieldRenderer.draw(in: context, size: size, time: 0, reduceMotion: true)
            }
            .opacity(isPaused ? 0.24 : 0.36)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 12)) { timeline in
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

        // During the gather phase many letters overlap at once. Drawing a flare
        // plus six shadow-filtered sparks for every colliding pair can balloon to
        // hundreds of filtered layers in one full-screen frame and starve scroll
        // rendering. A few brightest collisions sell the same effect at a fixed
        // cost.
        let maximumDrawnCollisions = 4
        var drawnCollisions = 0

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

                drawnCollisions += 1
                if drawnCollisions >= maximumDrawnCollisions {
                    return
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

/// First-run story onboarding: one ordinary detail becomes a Page, an argument,
/// a consequence, and a bound edition before the Book makes its offer.
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

    /// Four narrative bands the Inkbones can land the Wicker scene in. Failure
    /// is never a pure loss — the low band still hands the reader a beginning
    /// (a grudge, an open road, a strange seed) that the rival can carry.
    private enum WickerOutcomeTier: String, Equatable {
        case triumph   // a bright fracture: the margin cracks open in your favor
        case hold      // clean success
        case glance    // just short: frayed but holding
        case cost      // Wicker gets a hook — kept as the first page of something

        var succeeded: Bool { self == .triumph || self == .hold }

        var badge: String {
            switch self {
            case .triumph: return "Better than you hoped"
            case .hold: return "It lands"
            case .glance: return "It just about holds"
            case .cost: return "He gets one over on you"
            }
        }

        var symbol: String {
            switch self {
            case .triumph: return "sparkles"
            case .hold: return "checkmark.seal.fill"
            case .glance: return "link"
            case .cost: return "exclamationmark.triangle"
            }
        }

        var accent: Color {
            switch self {
            case .triumph: return BookPalette.gold
            case .hold: return BookPalette.teal
            case .glance: return BookPalette.lampGold
            case .cost: return BookPalette.violet
            }
        }

        /// The rivalry mechanic, framed narratively: what thread this leaves in
        /// the braid, and whether Wicker walks off with an edge over you.
        var threadKept: String {
            switch self {
            case .triumph: return "Wicker walks away with nothing. Rare, for him."
            case .hold: return "Wicker walks away with nothing."
            case .glance: return "Wicker doesn't get much, but he got something."
            case .cost: return "Wicker pockets a piece of your story. You'll want it back."
            }
        }
    }

    private struct WickerModeChoice: Identifiable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
        var difficulty: Int
        var triumphLine: String
        var holdLine: String
        var glanceLine: String
        var costLine: String

        func line(for tier: WickerOutcomeTier) -> String {
            switch tier {
            case .triumph: return triumphLine
            case .hold: return holdLine
            case .glance: return glanceLine
            case .cost: return costLine
            }
        }
    }

    private struct WickerBeliefOutcome: Equatable {
        var choiceID: String
        var roll: Int
        var difficulty: Int
        var tier: WickerOutcomeTier
        var succeeded: Bool { tier.succeeded }
    }

    /// A character's fleeting reaction to something the reader just authored —
    /// the onboarding echo of the live app's keep-moment margin note. Kept
    /// self-contained here because the desk's `MarginTutorNote` is Zara-only
    /// and wired to the home screen.
    private struct OnboardingMarginEcho: Identifiable, Equatable {
        var id = UUID()
        var speaker: String
        var portraitAsset: String
        var accent: Color
        var line: String
    }

    private struct FirstPressPreset: Identifiable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
        var sentence: String
    }

    private struct FirstPressNarrativeChoice: Identifiable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
        var outcomeLine: String
    }

    private struct OnboardingShareItem: Identifiable {
        var url: URL
        var id: String { url.absoluteString }
    }

    struct Result {
        var skipped: Bool
        var momentFate: String
        var hiddenMagicStance: String
        var rutStrongest: String
        var mostAlive: String
        var magicSource: String
        var snack: String
        var favoritePerson: String
        var name: String
        var belief: String
        var investedBelief: Bool
        var firstSouvenir: String
        var sleeveWord: String
        var drawnChapterID: String
        var wickerMode: String
        var wickerRoll: Int
        var wickerTier: String
        var wickerThread: String
        var wickerRollSucceeded: Bool
        var tastePreference: String
        var comfortBoundary: String
        var whisperCadence: String
        var confirmedWagers: [String]
        var firstDoorEdition: MonthlyEdition?
        var firstDoorEditionPDFPath: String
    }

    let onGlowUnlocked: () -> Void
    let onKeepIlluminatedPhoto: (IlluminatedPhotoDraft, URL?) -> Void
    let onFinished: (Result) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isOnboardingFieldFocused: Bool
    // Persisted so a player who closes mid-onboarding reopens on the same page
    // instead of restarting. Reset to 0 when onboarding finishes (see `advance`
    // / `finishWithDefaults`) so a future re-onboard starts clean.
    @AppStorage("onboardingStep") private var step = 0
    // Shown on relaunch when there is saved onboarding progress to resume.
    @State private var showResumePrompt = false
    @AppStorage("onboardingDraftSnack") private var snack = ""
    @State private var favoritePerson = ""
    @State private var didOpenFavoritePersonQuestion = false
    @AppStorage("onboardingDraftName") private var name = ""
    @AppStorage("onboardingDraftBelief") private var belief = ""
    @AppStorage("onboardingDraftInvestedBelief") private var investedBelief = false
    @AppStorage("onboardingDraftKeepChoice") private var rehearsalChoiceStorage = ""
    @AppStorage("onboardingDraftFirstSouvenir") private var firstSouvenir = ""
    @State private var shimmer = false
    @State private var rehearsalInkBurstTrigger = 0
    @State private var pageTilt = false
    @State private var didNotifyGlowUnlocked = false
    @State private var castPreviewURL: URL?
    @State private var didWakeFirstInk = false
    @State private var didRevealRoutineEvidence = false
    @State private var sleeveWord: String?
    @State private var didSteadyFirstPage = false
    @State private var unwrittenWordDrag: CGSize = .zero
    @State private var didTuckUnwrittenWord = false
    @AppStorage("onboardingDraftChapterID") private var drawnChapterID = ""
    @State private var onboardingPhotoItem: PhotosPickerItem?
    @State private var onboardingPhotoImage: UIImage?
    @State private var onboardingPhotoDraft: IlluminatedPhotoDraft?
    @State private var onboardingPhotoPreviewURL: URL?
    @State private var onboardingPhotoMessage = "Pick a photo, or take one. It never leaves your phone."
    @State private var isOnboardingPhotoLoading = false
    @State private var isOnboardingCameraPresented = false
    @State private var isOnboardingPhotoPreviewPresented = false
    @State private var didKeepOnboardingPhoto = false
    @State private var isSavingOnboardingPhoto = false
    @AppStorage("onboardingDraftWickerChoiceID") private var wickerOutcomeChoiceID = ""
    @AppStorage("onboardingDraftWickerRoll") private var wickerOutcomeRoll = 0
    @AppStorage("onboardingDraftWickerDifficulty") private var wickerOutcomeDifficulty = 0
    @AppStorage("onboardingDraftWickerTier") private var wickerOutcomeTier = ""
    // Bumped on each Wicker answer so the Inkbones re-tumble and re-reveal.
    @State private var wickerThrowID = UUID()
    @AppStorage("onboardingDraftTastePreference") private var tastePreference = ""
    @AppStorage("onboardingDraftComfortBoundary") private var comfortBoundary = ""
    @AppStorage("onboardingDraftWhisperCadence") private var whisperCadence = ""
    // Night-one wagers the reader tapped to confirm — the Barnum beat, kept
    // honest by paying off later as receipts in First Reading.
    @State private var confirmedWagers: Set<String> = []
    @AppStorage("onboardingDraftFirstPressText") private var firstPressText = ""
    @State private var selectedFirstPressPresetID: String?
    @AppStorage("onboardingDraftNarrativeID") private var selectedFirstPressNarrativeID = ""
    @AppStorage("onboardingDraftDidKeepFirstPage") private var didCompleteFirstPress = false
    @AppStorage("onboardingDraftMomentFate") private var momentFate = ""
    @AppStorage("onboardingDraftHiddenMagicStance") private var hiddenMagicStance = ""
    @AppStorage("onboardingDraftRutStrongest") private var rutStrongest = ""
    @AppStorage("onboardingDraftMostAlive") private var mostAlive = ""
    @AppStorage("onboardingDraftMagicSource") private var magicSource = ""
    @AppStorage("onboardingOpeningMiniStep") private var openingMiniStep = 0
    @AppStorage("onboardingConclusionMiniStep") private var conclusionMiniStep = 0
    @AppStorage("onboardingFlowVersion") private var onboardingFlowVersion = 0
    @State private var isOnboardingHeaderVisible = true
    @State private var onboardingHeaderFadeTask: Task<Void, Never>?
    @State private var isOpeningOvertureTitleVisible = true
    @State private var openingOvertureTitleFadeTask: Task<Void, Never>?
    // The instant the player arrived, captured once so the loose Page keeps
    // naming the same moment even after a relaunch.
    @AppStorage("onboardingDraftArrivalTimestamp") private var arrivalTimestamp = 0.0
    @State private var didRevealOpeningCard = false
    @State private var onboardingShareItem: OnboardingShareItem?
    @State private var bookOfYouPreviewURL: URL?
    @State private var isPressingOpeningRevealVideo = false
    @State private var isBindingFirstEdition = false
    // Plays the book-cover-opening beat over the step 0 → 1 transition.
    @State private var isCoverOpeningVisible = false
    // Character margin-note echoes fired on authored inputs (keep, belief).
    @State private var marginEcho: OnboardingMarginEcho?
    @State private var openingKeepBurst = 0
    @State private var beliefPlantBurst = 0
    // A short "sewing" beat before the finale mini-edition opens in QuickLook.
    @State private var isSewingFirstEdition = false
    @State private var didReadFirstDoorWriteback = false
    @State private var didBindFirstEdition = false
    @State private var boundFirstDoorEdition: MonthlyEdition?
    @State private var firstDoorEditionPDFPath = ""
    @State private var didCloseFirstEditionPreview = false
    @State private var didRevealDayThirtyAfter = false
    @State private var didRevealHabitScience = false
    @State private var firstEditionBindingError = ""
    // Guards the belief-planting ceremony so its burst can play before advancing.
    @State private var isPlantingBelief = false
    // Drives the gold gild-sweep across the illuminated photograph when it is kept.
    @State private var photoGildSweep: Double = 0

    // Six short opening beats plus twelve story pages. The added pages are not a
    // settings form: each is a small ritual that gives the Book something it
    // can visibly return before the Standing Order appears.
    private let stepCount = 13
    private let currentOnboardingFlowVersion = 7
    private let momentFateChoices = [
        OnboardingChoice(id: "keep", title: "I keep them", detail: "I already save small moments somewhere.", symbol: "bookmark"),
        OnboardingChoice(id: "forget", title: "I mean to, then forget", detail: "I notice, but the day usually carries it off.", symbol: "wind"),
        OnboardingChoice(id: "blur", title: "Most days blur first", detail: "I want more small interruptions that bring me back.", symbol: "cloud.fog")
    ]
    private let hiddenMagicChoices = [
        OnboardingChoice(id: "yes", title: "Yes. There it was.", detail: "The room changed when I looked twice.", symbol: "eye"),
        OnboardingChoice(id: "maybe", title: "A little.", detail: "Something shifted, even if I can't name it.", symbol: "sparkle.magnifyingglass"),
        OnboardingChoice(id: "prove", title: "Not yet. Show me more.", detail: "One glimpse isn't evidence yet.", symbol: "questionmark.diamond")
    ]
    private let rutChoices = [
        OnboardingChoice(id: "work", title: "Work swallows the day", detail: "", symbol: "briefcase"),
        OnboardingChoice(id: "phone", title: "My phone eats the edges", detail: "", symbol: "iphone"),
        OnboardingChoice(id: "chores", title: "Chores all blur together", detail: "", symbol: "checklist"),
        OnboardingChoice(id: "exhaustion", title: "I'm tired before I begin", detail: "", symbol: "battery.25percent"),
        OnboardingChoice(id: "sameness", title: "My days feel the same", detail: "", symbol: "repeat"),
        OnboardingChoice(id: "later", title: "I keep waiting for later", detail: "", symbol: "hourglass")
    ]
    private let aliveChoices = [
        OnboardingChoice(id: "making", title: "Making something", detail: "", symbol: "hammer"),
        OnboardingChoice(id: "outside", title: "Outside somewhere", detail: "", symbol: "leaf"),
        OnboardingChoice(id: "people", title: "With people I love", detail: "", symbol: "person.2"),
        OnboardingChoice(id: "movement", title: "Moving my body", detail: "", symbol: "figure.run"),
        OnboardingChoice(id: "learning", title: "Learning something", detail: "", symbol: "lightbulb"),
        OnboardingChoice(id: "solitude", title: "Alone and unhurried", detail: "", symbol: "cup.and.saucer"),
        OnboardingChoice(id: "helping", title: "Helping someone", detail: "", symbol: "hands.sparkles"),
        OnboardingChoice(id: "story", title: "Lost in a story", detail: "", symbol: "book")
    ]
    private let magicSourceChoices = [
        OnboardingChoice(id: "music", title: "Music landing just right", detail: "", symbol: "music.note"),
        OnboardingChoice(id: "weather", title: "Wild weather", detail: "", symbol: "cloud.bolt"),
        OnboardingChoice(id: "places", title: "Places with a charge", detail: "", symbol: "map"),
        OnboardingChoice(id: "coincidence", title: "Strange coincidences", detail: "", symbol: "point.3.connected.trianglepath.dotted"),
        OnboardingChoice(id: "details", title: "Tiny beautiful details", detail: "", symbol: "sparkle.magnifyingglass"),
        OnboardingChoice(id: "laughter", title: "Making someone laugh", detail: "", symbol: "theatermasks"),
        OnboardingChoice(id: "imagination", title: "Dreams and imagination", detail: "", symbol: "moon.stars"),
        OnboardingChoice(id: "love", title: "People I love", detail: "", symbol: "heart"),
        OnboardingChoice(id: "unsure", title: "I'm not sure yet", detail: "", symbol: "questionmark")
    ]
    private let sleeveWords = ["GLINT", "MARGIN", "THRESHOLD"]
    private let tasteChoices = [
        OnboardingChoice(id: "letters", title: "Letters and voices", detail: "People inside the Book should look up sooner.", symbol: "envelope.open"),
        OnboardingChoice(id: "errands", title: "Strange errands", detail: "Small impossible invitations should find the desk.", symbol: "wand.and.stars"),
        OnboardingChoice(id: "cozy", title: "Cozy noticing", detail: "Warm, exact, ordinary magic should come first.", symbol: "mug"),
        OnboardingChoice(id: "weather-place", title: "Weather and place", detail: "Sky, ground, rooms, and thresholds should speak up.", symbol: "cloud.sun"),
        OnboardingChoice(id: "eerie", title: "Eerie story threads", detail: "Let the edges get a little haunted.", symbol: "moon.stars"),
        OnboardingChoice(id: "oddities", title: "Funny little oddities", detail: "Give the Book permission to be peculiar.", symbol: "sparkles")
    ]
    private let comfortChoices = [
        OnboardingChoice(id: "gentle", title: "Invite me", detail: "Offer doors, but never push me through them.", symbol: "leaf"),
        OnboardingChoice(id: "balanced", title: "Nudge me", detail: "Remind me, return things, and challenge routine a little.", symbol: "scalemass"),
        OnboardingChoice(id: "strange", title: "Call me on my nonsense", detail: "Cajole me. Provoke me. Never confuse pressure with permission.", symbol: "eye")
    ]
    private let whisperChoices = [
        OnboardingChoice(id: "morning", title: "Morning", detail: "One keepable prompt near the start of the day.", symbol: "sunrise"),
        OnboardingChoice(id: "evening", title: "Evening", detail: "One return when the day's ready to braid.", symbol: "moon"),
        OnboardingChoice(id: "both", title: "Both", detail: "One morning prompt and one evening return.", symbol: "sunrise.fill"),
        OnboardingChoice(id: "inside", title: "Only inside the covers", detail: "No outside whispers or keepable prompts. The Book waits until opened.", symbol: "bell.slash")
    ]
    private let wickerChoices = [
        WickerModeChoice(
            id: "slice-of-life",
            title: "Something Small and True",
            detail: "Tell him one exact, unglamorous detail from your actual life.",
            symbol: "mug",
            difficulty: 42,
            triumphLine: "You give him one exact, unglamorous detail. It lands so cleanly the sneer slides off his face. A shelf leans closer. “Beginner's luck,” Wicker says, which is what people say when the beginner has just beaten them.",
            holdLine: "The ordinary detail lands square. Wicker was ready for something grand; he wasn't ready for something specific. He recovers a half-beat late. The Book writes the half-beat down.",
            glanceLine: "The detail comes out smaller than you meant. “That's your evidence?” Wicker asks. Zara doesn't rescue you. She only says, “Truth doesn't need to be large.” Annoyingly, it holds.",
            costLine: "It comes out mumbled. Wicker pockets the mumble like a coin. “Lovely,” he says. “You've brought me almost a thought.” The Book turns the insult into the opening line of a grudge."
        ),
        WickerModeChoice(
            id: "arc",
            title: "Where This Is Going",
            detail: "Don't answer the insult. Tell him where your story is headed.",
            symbol: "arrow.triangle.turn.up.right.diamond",
            difficulty: 56,
            triumphLine: "You name where this is going before he can name what's wrong with it. The corridor tilts toward a door that wasn't there a breath ago. “Cheap architecture,” Wicker mutters, glaring at the door as if it cheated.",
            holdLine: "You point at a future and the hall leans that way. Wicker feels it move under his boots. “A direction isn't a destiny,” he says. No—but it is a direction, and he has to step aside.",
            glanceLine: "The promise wobbles. Wicker hears it; he collects wobbles. “Future tense in a heroic little costume.” Still, a wobbling arrow's an arrow. The Book pins its heading to the wall.",
            costLine: "The direction leaves your mouth as a question. Wicker circles the question mark. “There. The first honest thing you've said.” The Book files it as an open road—and puts his name at the next bend."
        ),
        WickerModeChoice(
            id: "surprise",
            title: "Something He Won't Expect",
            detail: "Refuse the obvious reply and let something odd out instead.",
            symbol: "sparkles",
            difficulty: 64,
            triumphLine: "Your answer arrives so far sideways that Wicker forgets to be superior for one entire second. A shelf laughs in dry, rustling paper. He'll deny this. The Book has already underlined it twice.",
            holdLine: "You let something odd through the gap. Wicker blinks. “Did you rehearse that, or are you naturally inconvenient?” Odd is the one weather he's never learned to out-sneer.",
            glanceLine: "The surprise half-lands: a spark where you meant a flourish. Wicker slow-claps. “Nearly an event.” Zara murmurs, “Useful data,” which is less satisfying than punching him but more useful.",
            costLine: "The odd thing fizzles at your feet. Wicker applauds with real pleasure. “Courageous,” he says, in the least flattering way possible. The Book keeps the misfire. Strange failures are seeds—and this one now wants a rematch."
        )
    ]
    private let firstSentenceStarters = [
        "I almost missed what the light was doing in this room.",
        "I heard one small sound under everything else.",
        "Today I carried a feeling with no good name yet.",
        "I noticed the weather outside had changed the room.",
        "Something ordinary near me looked like a sign when I let it."
    ]

    /// The proof-funnel draft survives a relaunch. These values are deliberately
    /// small and local: one Page decision and one character consequence.
    private var rehearsalChoice: OnboardingRehearsalChoice? {
        get {
            switch rehearsalChoiceStorage {
            case "keep": return .keep
            case "wait": return .wait
            default: return nil
            }
        }
        nonmutating set {
            switch newValue {
            case .keep: rehearsalChoiceStorage = "keep"
            case .wait: rehearsalChoiceStorage = "wait"
            case nil: rehearsalChoiceStorage = ""
            }
        }
    }

    private var arrivalMoment: Date {
        arrivalTimestamp > 0
            ? Date(timeIntervalSince1970: arrivalTimestamp)
            : Date()
    }

    private var wickerOutcome: WickerBeliefOutcome? {
        get {
            guard !wickerOutcomeChoiceID.isEmpty,
                  let tier = WickerOutcomeTier(rawValue: wickerOutcomeTier) else {
                return nil
            }
            return WickerBeliefOutcome(
                choiceID: wickerOutcomeChoiceID,
                roll: wickerOutcomeRoll,
                difficulty: wickerOutcomeDifficulty,
                tier: tier
            )
        }
        nonmutating set {
            guard let newValue else {
                wickerOutcomeChoiceID = ""
                wickerOutcomeRoll = 0
                wickerOutcomeDifficulty = 0
                wickerOutcomeTier = ""
                return
            }
            wickerOutcomeChoiceID = newValue.choiceID
            wickerOutcomeRoll = newValue.roll
            wickerOutcomeDifficulty = newValue.difficulty
            wickerOutcomeTier = newValue.tier.rawValue
        }
    }

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
                onboardingLayout(in: proxy.size)
            }

            if showResumePrompt {
                resumePrompt
            }

            if let echo = marginEcho {
                VStack {
                    Spacer(minLength: 0)
                    onboardingMarginEchoCard(echo)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(38)
            }

            if isSewingFirstEdition {
                BinderySewingOverlay()
                    .transition(.opacity)
                    .zIndex(41)
            }

            if isCoverOpeningVisible {
                LabyrinthCoverOpeningView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isCoverOpeningVisible = false
                    }
                }
                .transition(.opacity)
                .zIndex(40)
            }
        }
        .transition(.opacity)
        #if canImport(QuickLook)
        .quickLookPreview($castPreviewURL)
        .quickLookPreview($bookOfYouPreviewURL)
        .onChange(of: castPreviewURL) { oldValue, newValue in
            guard oldValue != nil, newValue == nil, didBindFirstEdition else { return }
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.32)) {
                didCloseFirstEditionPreview = true
            }
        }
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
        .fullScreenCover(isPresented: $isOnboardingPhotoPreviewPresented) {
            if let draft = onboardingPhotoDraft {
                OnboardingIlluminatedPhotoBindingPreview(
                    draft: draft,
                    renderedURL: onboardingPhotoPreviewURL,
                    sourceImage: onboardingPhotoImage,
                    onPutInBook: {
                        keepOnboardingIlluminatedPhoto()
                        isOnboardingPhotoPreviewPresented = false
                    }
                )
            } else {
                BookBackground()
                    .overlay {
                        ProgressView("Illuminating your photograph…")
                            .font(.headline)
                            .tint(BookPalette.lampGold)
                            .foregroundStyle(BookPalette.nightText)
                    }
                    .ignoresSafeArea()
            }
        }
        .sheet(item: $onboardingShareItem) { item in
            #if canImport(UIKit)
            OnboardingActivityShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
            #else
            ShareLink(item: item.url) {
                Label("Share the pressed page", systemImage: "square.and.arrow.up")
                    .padding()
            }
            #endif
        }
        .onAppear {
            let wasOlderFlow = onboardingFlowVersion != currentOnboardingFlowVersion
            if wasOlderFlow {
                resetOnboardingInputs()
                step = 0
                openingMiniStep = 0
                onboardingFlowVersion = currentOnboardingFlowVersion
            }
            if arrivalTimestamp <= 0 {
                arrivalTimestamp = Date().timeIntervalSince1970
            }
            if openingMiniStep > 5 {
                openingMiniStep = 5
            }
            if step >= stepCount {
                step = stepCount - 1
            }
            scheduleOnboardingHeaderFade()
            scheduleOpeningOvertureTitleFadeIfNeeded()
            // If the player closed the app partway through, offer to resume.
            if !wasOlderFlow, step > 0 || openingMiniStep > 0 {
                showResumePrompt = true
            }
            notifyGlowUnlockedIfNeeded()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                shimmer = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                pageTilt = true
            }
        }
        .onDisappear {
            onboardingHeaderFadeTask?.cancel()
            onboardingHeaderFadeTask = nil
            openingOvertureTitleFadeTask?.cancel()
            openingOvertureTitleFadeTask = nil
        }
    }

    private var isPadOnboardingDevice: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    @ViewBuilder
    private func onboardingLayout(in size: CGSize) -> some View {
        if isPadOnboardingDevice {
            iPadOnboardingLayout(in: size)
        } else {
            compactOnboardingLayout(in: size)
        }
    }

    /// The phone composition remains the original short reading card. Keeping
    /// it in its own branch also preserves the current iPhone landscape and
    /// keyboard behavior byte-for-byte while iPad receives a real stage.
    private func compactOnboardingLayout(in size: CGSize) -> some View {
        let isPortrait = size.height >= size.width
        let headerInset: CGFloat = 14
        let scrollMaxHeight: CGFloat = isPortrait
            ? min(640, max(420, size.height - 116))
            : min(540, max(360, size.height - 120))

        return VStack(spacing: 0) {
            Spacer(minLength: isPortrait ? 12 : 18)

            VStack(spacing: 0) {
                if isOnboardingHeaderVisible {
                    onboardingHeader
                        .padding(.horizontal, headerInset)
                        .padding(.top, headerInset)
                        .padding(.bottom, 10)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }

                onboardingPageScroll(
                    horizontalPadding: 22,
                    readingMaxWidth: nil,
                    showsInlineChrome: true,
                    keepsOpeningTopVisible: false
                )
            }
            .frame(maxHeight: scrollMaxHeight)
            .background { onboardingParchmentBackground(cornerRadius: 14) }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(shimmer ? 0.62 : 0.34), lineWidth: 1)
            }
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (pageTilt ? 0.8 : -0.8)),
                axis: (x: 0, y: 1, z: 0)
            )
            .padding(.top, isPortrait ? 8 : 12)
            .padding(.horizontal, 22)
            .shadow(color: BookPalette.lampGold.opacity(shimmer ? 0.18 : 0.08), radius: 22, x: 0, y: 8)
            .shadow(color: .black.opacity(0.32), radius: 12, x: 0, y: 18)

            if step > 0 {
                stepDots
                    .padding(.top, isPortrait ? 18 : 16)
            }

            Spacer(minLength: 30)
        }
        .frame(width: size.width, height: size.height)
    }

    /// Regular-width iPad becomes a folio in roomy landscape windows. In
    /// portrait, Split View, accessibility text sizes, and smaller iPads the
    /// same reading page simply occupies the full stage without a side rail.
    private func iPadOnboardingLayout(in size: CGSize) -> some View {
        let showsFolioRail = size.width >= 980
            && size.width > size.height
            && horizontalSizeClass == .regular
            && !dynamicTypeSize.isAccessibilitySize
        let railWidth: CGFloat = showsFolioRail
            ? min(330, max(286, size.width * 0.27))
            : 0
        let outerHorizontalPadding: CGFloat = showsFolioRail ? 24 : 16
        let folioSpacing: CGFloat = showsFolioRail ? 22 : 0
        let stageHeight = max(0, size.height - 32)

        return HStack(spacing: folioSpacing) {
            onboardingFolioRail(width: railWidth)
                .frame(width: railWidth, height: stageHeight)
                .opacity(showsFolioRail ? 1 : 0)
                .clipped()
                .allowsHitTesting(showsFolioRail)
                .accessibilityHidden(!showsFolioRail)

            iPadOnboardingReadingPage(showsFolioRail: showsFolioRail)
                .frame(maxWidth: showsFolioRail ? 780 : 840)
                .frame(height: stageHeight)
        }
        .frame(maxWidth: showsFolioRail ? 1_180 : 840, maxHeight: stageHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, outerHorizontalPadding)
        .padding(.vertical, 16)
    }

    private func iPadOnboardingReadingPage(showsFolioRail: Bool) -> some View {
        VStack(spacing: 0) {
            if !showsFolioRail {
                onboardingHeader
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
            }

            onboardingPageScroll(
                horizontalPadding: showsFolioRail ? 34 : 30,
                readingMaxWidth: 720,
                showsInlineChrome: !showsFolioRail,
                keepsOpeningTopVisible: !showsFolioRail
            )
            .id(showsFolioRail ? "onboarding-folio-scroll" : "onboarding-portrait-scroll")

            if !showsFolioRail, step > 0 {
                stepDots
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { onboardingParchmentBackground(cornerRadius: 18) }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(shimmer ? 0.62 : 0.34), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: BookPalette.lampGold.opacity(shimmer ? 0.16 : 0.06), radius: 28, x: 0, y: 8)
        .shadow(color: .black.opacity(0.36), radius: 20, x: 0, y: 18)
    }

    private func onboardingFolioRail(width: CGFloat) -> some View {
        ZStack {
            BookPalette.nightPanel

            Image("LabyrinthLocationStacks")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.22)
                .overlay {
                    LinearGradient(
                        colors: [
                            BookPalette.nightPanel.opacity(0.18),
                            BookPalette.nightPanel.opacity(0.82),
                            BookPalette.nightPanel
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipped()

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: onboardingSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(BookPalette.nightPanel)
                        .frame(width: 48, height: 48)
                        .background(BookPalette.lampGold, in: Circle())
                        .shadow(color: BookPalette.lampGold.opacity(0.34), radius: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("THE FIRST DOOR")
                            .font(.caption2.weight(.black))
                            .tracking(1.4)
                            .foregroundStyle(BookPalette.lampGold.opacity(0.78))
                        Text(step == 0 ? "Opening the Book" : "One small Page at a time")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.62))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(step == 0 ? openingMiniStageName : onboardingStageName)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.lampGold)
                    Text(onboardingHeaderLine)
                        .font(.system(.body, design: .serif, weight: .semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                ProgressView(value: onboardingProgress)
                    .tint(BookPalette.lampGold)

                if step > 0 {
                    stepDots
                }

                Spacer(minLength: 20)

                VStack(alignment: .leading, spacing: 8) {
                    Label("A living first edition", systemImage: "book.closed")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                    Text("Your answers stay on this device and become the first handwriting in the Book.")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(BookPalette.nightText.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if step < stepCount - 1 {
                    Button {
                        finishWithDefaults()
                    } label: {
                        Label("Open the free Book now", systemImage: "forward.end")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.lampGold)
                    .accessibilityLabel("Skip the First Door and open the free Book")
                }
            }
            .frame(width: max(0, width - 48), alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 18, y: 12)
    }

    private var onboardingProgress: Double {
        if step == 0 {
            return Double(openingMiniStep + 1) / 6.0 / Double(stepCount)
        }
        return Double(step) / Double(stepCount - 1)
    }

    private func onboardingParchmentBackground(cornerRadius: CGFloat) -> some View {
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func onboardingPageScroll(
        horizontalPadding: CGFloat,
        readingMaxWidth: CGFloat?,
        showsInlineChrome: Bool,
        keepsOpeningTopVisible: Bool
    ) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(height: 1)
                        .id("onboarding-page-top")

                    if showsInlineChrome {
                        if step == 0 {
                            openingMiniPill
                        } else {
                            stagePill
                        }
                    } else {
                        onboardingFolioReadingPill
                    }

                    stepContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                        .id(step == 0 ? "opening-\(openingMiniStep)" : "step-\(step)")
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 74)
                .frame(maxWidth: readingMaxWidth ?? .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.top)
            .onChange(of: step) { _, _ in
                scheduleOnboardingHeaderFade()
                turnOnboardingPage(to: "onboarding-page-top", with: scrollProxy)
                notifyGlowUnlockedIfNeeded()
            }
            .onChange(of: openingMiniStep) { _, _ in
                guard step == 0 else { return }
                scheduleOnboardingHeaderFade()
                scheduleOpeningOvertureTitleFadeIfNeeded()
                // The bitten Page reveals the Rut's receipt below the control.
                // Keep that answer in view even on the roomy iPad page, where
                // the opening otherwise remains pinned to the top.
                let target = (keepsOpeningTopVisible && openingMiniStep != 2)
                    ? "onboarding-page-top"
                    : openingMiniScrollTargetID
                turnOnboardingPage(to: target, with: scrollProxy)
            }
            .onChange(of: conclusionMiniStep) { _, _ in
                turnOnboardingPage(to: "onboarding-page-top", with: scrollProxy)
            }
            .onChange(of: didReadFirstDoorWriteback) { _, didRead in
                guard didRead else { return }
                revealOnboarding("onboarding-personalized-return", with: scrollProxy)
            }
            .onChange(of: belief) { _, _ in
                notifyGlowUnlockedIfNeeded()
            }
            .onChange(of: didRevealRoutineEvidence) { _, didReveal in
                guard step == 0, openingMiniStep == 2, didReveal else { return }
                revealOnboarding("onboarding-opening-routine-evidence", with: scrollProxy)
            }
            .onChange(of: momentFate) { _, answer in
                guard step == 0, openingMiniStep == 3, !answer.isEmpty else { return }
                revealOnboarding("onboarding-moment-reflection", with: scrollProxy)
            }
            .onChange(of: hiddenMagicStance) { _, answer in
                guard step == 0, openingMiniStep == 4, !answer.isEmpty else { return }
                revealOnboarding("onboarding-hidden-magic-reflection", with: scrollProxy)
            }
            .onChange(of: rutStrongest) { _, answer in
                guard step == 2, !answer.isEmpty else { return }
                revealOnboarding("onboarding-rut-reflection", with: scrollProxy)
            }
            .onChange(of: mostAlive) { _, answer in
                guard step == 3, !answer.isEmpty else { return }
                revealOnboarding("onboarding-alive-reflection", with: scrollProxy)
            }
            .onChange(of: magicSource) { _, answer in
                guard step == 4, !answer.isEmpty else { return }
                revealOnboarding("onboarding-magic-source-reflection", with: scrollProxy)
            }
            .onChange(of: didSteadyFirstPage) { _, didStand in
                guard step == 1, didStand else { return }
                revealOnboarding("onboarding-arrival-standing", with: scrollProxy)
            }
            .onChange(of: wickerThrowID) { _, _ in
                guard wickerOutcome != nil else { return }
                revealOnboarding("onboarding-wicker-inkbones", with: scrollProxy, delay: 0.12)
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(
                OnboardingLateRevealScrolling(
                    step: step,
                    snack: snack,
                    name: name,
                    investedBelief: investedBelief,
                    whisperCadence: whisperCadence,
                    didRevealDayThirtyAfter: didRevealDayThirtyAfter,
                    didRevealHabitScience: didRevealHabitScience,
                    reveal: { id, delay in
                        revealOnboarding(id, with: scrollProxy, delay: delay)
                    }
                )
            )
        }
    }

    private var onboardingFolioReadingPill: some View {
        Label(
            step == 0 ? openingMiniStageName : onboardingStageName,
            systemImage: step == 0 ? openingMiniSymbol : onboardingSymbol
        )
        .font(.subheadline.weight(.bold))
        .foregroundStyle(BookPalette.teal)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(BookPalette.paper.opacity(0.48), in: Capsule())
        .accessibilityAddTraits(.isHeader)
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
            ForEach(1..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index == step ? BookPalette.lampGold : BookPalette.nightText.opacity(0.3))
                    .frame(width: index == step ? 9 : 6, height: index == step ? 9 : 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var firstPressTrimmedText: String {
        firstPressText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var firstPressTimeName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "late night"
        }
    }

    private var onboardingOpeningTimeName: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        switch minuteOfDay {
        case 0..<240: return "deep night"
        case 240..<360: return "early morning"
        case 360..<480: return "sunrise"
        case 480..<720: return "morning"
        case 720..<1020: return "afternoon"
        case 1020..<1140: return "sunset"
        case 1140..<1320: return "evening"
        default: return "deep night"
        }
    }

    private var firstPressTimeTexture: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<8: return "the day's still deciding what kind of page it'll be"
        case 8..<12: return "the morning's already left fingerprints on the room"
        case 12..<17: return "the afternoon's warm with unfinished errands"
        case 17..<22: return "the evening's gathering the day back into its sleeves"
        default: return "the late hour makes even small things sound like secrets"
        }
    }

    private var firstPressSeasonTexture: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return "spring light"
        case 6...8: return "summer heat"
        case 9...11: return "autumn edge"
        default: return "winter quiet"
        }
    }

    private var firstPressPresets: [FirstPressPreset] {
        let hour = Calendar.current.component(.hour, from: Date())
        let skySentence: String
        let roomSentence: String
        let bodySentence: String
        let objectSentence: String
        switch hour {
        case 5..<12:
            skySentence = "I almost missed the morning light on the edge of everything."
            roomSentence = "I found the room still carrying sleep in its corners."
            bodySentence = "I was here before the day had fully named me."
            objectSentence = "I noticed the nearest cup or object waiting like evidence."
        case 12..<17:
            skySentence = "I saw the afternoon put its hand on the window."
            roomSentence = "I caught the room pretending to be ordinary."
            bodySentence = "I was in the middle of the day, not outside it."
            objectSentence = "I found one object nearby holding the whole afternoon still."
        case 17..<22:
            skySentence = "I watched the evening fold the day into darker paper."
            roomSentence = "I heard the room start to sound like an ending."
            bodySentence = "I made it this far into the day."
            objectSentence = "One ordinary thing nearby survived the day with me."
        default:
            skySentence = "I noticed the night awake at the edge of the glass."
            roomSentence = "I found the room quieter than it was supposed to be."
            bodySentence = "I was still here while the day turned secret."
            objectSentence = "I noticed one small object nearby keeping watch."
        }
        return [
            FirstPressPreset(id: "sky", title: "The sky", detail: firstPressTimeName, symbol: "cloud.moon", sentence: skySentence),
            FirstPressPreset(id: "room", title: "This room", detail: firstPressSeasonTexture, symbol: "door.left.hand.open", sentence: roomSentence),
            FirstPressPreset(id: "body", title: "My mood", detail: "right now", symbol: "heart.text.square", sentence: bodySentence),
            FirstPressPreset(id: "object", title: "One object", detail: "nearby", symbol: "cup.and.saucer", sentence: objectSentence)
        ]
    }

    private let firstPressNarrativeChoices = [
        FirstPressNarrativeChoice(
            id: "slice-of-life",
            title: "Something Small and True",
            detail: "Keep it ordinary. Don't let the Page improve it.",
            symbol: "mug",
            outcomeLine: "The Page answered, \"Then I wouldn't improve it.\" The ordinary detail stayed ordinary, and that was why it held: no thunder, no prophecy, just one true thing made harder to lose."
        ),
        FirstPressNarrativeChoice(
            id: "arc",
            title: "Where This Is Going",
            detail: "Ask the Page where this moment is trying to lead.",
            symbol: "arrow.triangle.turn.up.right.diamond",
            outcomeLine: "The Page answered, \"Then I'd give it a hinge.\" A thin gold arrow appeared under the line. It pointed at you, then at the door, then at you again, which wasn't helpful but was definitely a plot."
        ),
        FirstPressNarrativeChoice(
            id: "surprise",
            title: "Something Unexpected",
            detail: "Stand back and let the Page do the uninvited thing.",
            symbol: "sparkles",
            outcomeLine: "The Page answered, \"Then you left room for what you didn't mean.\" The margin sneezed out a gold comma, a little door appeared where punctuation had no business being, and neither one explained itself."
        )
    ]

    private var firstPressPreviewTitle: String {
        let text = firstPressTrimmedText
        guard !text.isEmpty else {
            return "The Small Thing Waited"
        }
        let words = text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !["the", "and", "that", "this", "with", "from", "here", "there", "still", "already"].contains($0) }
        let anchor = words.first { $0.count >= 4 } ?? words.first ?? "thing"
        let place = firstPressTimeName == "late night" ? "Night" : firstPressTimeName.capitalized
        return "The \(anchor.capitalized) at the \(place)"
    }

    private var firstPressPreviewExcerpt: String {
        let text = firstPressTrimmedText
        guard let detail = firstPressPreviewDetail(from: text).nonEmpty else {
            if didChooseFirstPressNarrative {
                return "\(openingArrivalExcerpt) \(firstPressNarrativeResultLine)"
            }
            return "\(openingArrivalExcerpt) The page waited at a fork in the ink."
        }
        return "\(openingArrivalExcerpt) You gave the page this line: \"\(detail).\" \(firstPressNarrativeResultLine)"
    }

    private func firstPressPreviewDetail(from text: String) -> String {
        let clipped = String(text.prefix(140))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trailingSentenceMarks = CharacterSet(charactersIn: ".?!,;:")
        return clipped
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(trailingSentenceMarks))
            .nonEmpty ?? clipped
    }

    private var firstPressPreviewSeed: Int {
        firstPressTrimmedText.stableHash
            ^ firstPressTimeName.stableHash
            ^ firstPressSeasonTexture.stableHash
            ^ selectedFirstPressNarrativeID.stableHash
    }

    private var selectedFirstPressNarrativeChoice: FirstPressNarrativeChoice? {
        firstPressNarrativeChoices.first { $0.id == selectedFirstPressNarrativeID }
    }

    private var didChooseFirstPressNarrative: Bool {
        selectedFirstPressNarrativeChoice != nil
    }

    private var firstPressNarrativeResultLine: String {
        selectedFirstPressNarrativeChoice?.outcomeLine
            ?? "The page waited at a fork in the ink."
    }

    private var firstPressSouvenirLine: String {
        if let detail = firstPressPreviewDetail(from: firstPressTrimmedText).nonEmpty {
            return "\(openingArrivalExcerpt) You gave the page this line: \"\(detail).\" \(firstPressNarrativeResultLine)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "\(openingArrivalExcerpt) \(didChooseFirstPressNarrative ? firstPressNarrativeResultLine : "")"
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Turns to a new onboarding page and pins it to the top of the reading
    /// area. Scrolls twice on purpose: once immediately, so the reader never
    /// sees the old scroll offset on the new page, and once after layout has
    /// settled, because a taller or shorter page can otherwise leave the reader
    /// looking at its middle.
    private func turnOnboardingPage(to id: String, with proxy: ScrollViewProxy) {
        proxy.scrollTo(id, anchor: .top)
        DispatchQueue.main.async {
            proxy.scrollTo(id, anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.18)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    /// Brings content that has just been revealed *below* a control to the top
    /// of the reading area, so the reader never has to go looking for the thing
    /// their own tap produced. The delay lets the inserted view lay out first —
    /// scrolling to an id in the same runloop as its insertion lands short.
    private func revealOnboarding(
        _ id: String,
        with proxy: ScrollViewProxy,
        delay: Double = 0.08
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.30)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    private func scheduleOnboardingHeaderFade() {
        onboardingHeaderFadeTask?.cancel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.9)) {
            isOnboardingHeaderVisible = true
        }
        onboardingHeaderFadeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1900))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .easeOut(duration: 0.46)) {
                isOnboardingHeaderVisible = false
            }
        }
    }

    private func scheduleOpeningOvertureTitleFadeIfNeeded() {
        openingOvertureTitleFadeTask?.cancel()
        guard step == 0, openingMiniStep == 0 else {
            isOpeningOvertureTitleVisible = false
            return
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.9)) {
            isOpeningOvertureTitleVisible = true
        }
        openingOvertureTitleFadeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(3200))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .easeOut(duration: 0.46)) {
                isOpeningOvertureTitleVisible = false
            }
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
	            Label("THE FIRST DOOR", systemImage: onboardingSymbol)
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
	                    Text("Open the free Book now")
	                        .font(.subheadline.weight(.bold))
	                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.teal)
                .accessibilityLabel("Skip the First Door and open the free Book")
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
        if step == 0 {
            onboardingOpeningPage
        } else {
            switch step - 1 {
            case 0:
                onboardingTitle("Through the Page")
                onboardingProse(firstDoorFallThroughProse)
                guidePortrait(mood: "Zara Finch's already noticed what you did with the Page.")
                onboardingProse("""
                "You're from the Great Unwritten," Zara says. "No one inside this Book can enter your ordinary world. We only know it through the Pages you choose to give us."
                """)
                onboardingTakeZarasHandAction

                if didSteadyFirstPage {
                    VStack(alignment: .leading, spacing: 18) {
                        onboardingProse("""
                        Zara pulls you upright. The Page follows and settles against your palm.

                        "That's why you're the reader," she says. "Not because you consume the story. Because your life outside the covers can change what happens in here."

                        She points to a grey nick at the Page's edge. "And that's the Rut of Routine. It makes whole parts of a life feel like they never happened. It gets in somewhere different for everyone."
                        """)
                        continueButton("Show her where it gets in")
                    }
                    .id("onboarding-arrival-standing")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

            case 1:
                guidePortrait(mood: "Zara turns the Page sideways, looking for the place the grey gets in.")
                onboardingTitle("Where Does Your Life Go On Autopilot?")
                onboardingProse("""
                "No speeches," Zara says. "Just point at the door it comes through most."

                "Where do whole hours go missing on you?"
                """)
                onboardingChipChoices(choices: rutChoices, selection: $rutStrongest)
                if !rutStrongest.isEmpty {
                    onboardingPreviewCard(
                        symbol: "scope",
                        title: "Right, that's the one",
                        body: rutReflection
                    )
                    .id("onboarding-rut-reflection")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                continueButton("That's the one", disabled: rutStrongest.isEmpty)

            case 2:
                onboardingTitle("And Where Do You Feel Most Awake?")
                onboardingProse("""
                Zara taps the corner of the Page the grey couldn't get to.

                "Opposite question. When are you completely, unmistakably here?"
                """)
                onboardingChipChoices(choices: aliveChoices, selection: $mostAlive)
                if !mostAlive.isEmpty {
                    onboardingPreviewCard(
                        symbol: "waveform.path.ecg",
                        title: "Good. It'll come back to this",
                        body: aliveReflection
                    )
                    .id("onboarding-alive-reflection")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                continueButton("Keep that", disabled: mostAlive.isEmpty)

            case 3:
                onboardingTitle("What Actually Feels Like Magic?")
                onboardingProse("""
                "Not what photographs well," Zara says. "What genuinely puts a charge through you."

                "First honest answer. Don't overthink it — there's time for the rest."
                """)
                onboardingChipChoices(choices: magicSourceChoices, selection: $magicSource)
                if !magicSource.isEmpty {
                    onboardingPreviewCard(
                        symbol: "sparkles",
                        title: "So that's your kind",
                        body: magicSourceReflection
                    )
                    .id("onboarding-magic-source-reflection")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                continueButton("That's my kind", disabled: magicSource.isEmpty)

            case 4:
                guidePortrait(mood: "Zara has one urgent question, and it isn't a serious one.")
                onboardingTitle("What Do You Snack On?")
                onboardingProse("""
                "While you're reading, I mean. Mine's sharp green apples. They keep me awake when the footnotes get long."

                She's already holding the pencil. "Big questions later. Small true things are how a Book stops sounding like everybody's Book."
                """)
                onboardingField("I snack on...", text: $snack)
                if let answer = snack.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                    onboardingPreviewCard(
                        symbol: "takeoutbag.and.cup.and.straw",
                        title: "Noted, very seriously",
                        body: "\(answer) goes in the margin, in tiny careful ink, like it matters. It sort of does."
                    )
                    .overlay(alignment: .topLeading) {
                        OnboardingSparkleSettle()
                            .frame(width: 60, height: 60)
                            .offset(x: 6, y: 6)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
                continueButton(
                    "Write it down",
                    disabled: snack.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

            case 5:
                onboardingTitle("What Should It Call You?")
                onboardingProse("""
                Zara taps a blank line. "Not your legal anything. The name that sounds right when someone says it kindly."
                """)
                onboardingField("What should the Book call you?", text: $name)
                if let answer = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                    onboardingNameSignature(answer)
                        .id("onboarding-name-signature")
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    onboardingPreviewCard(
                        symbol: "person.crop.circle.badge.checkmark",
                        title: "\"\(answer),\" Zara tries.",
                        body: "\"Good. Now when the Book writes back, it knows who it's speaking to.\""
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                continueButton("That's my name", disabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            case 6:
                onboardingTitle("What Do You Believe?")
                onboardingProse("""
                The grey creeps back at the corner of your Page. A word starts to fade.

                "That's Routine," Zara says. "It turns a whole life into wallpaper. The only thing that holds it off is something you actually believe."

                She goes first: "I believe every book is a door."

                "Your turn. Anything you'd argue for."
                """)
                onboardingField("I believe...", text: $belief)
                if let answer = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                    onboardingBeliefSigil(answer)
                        .id("onboarding-belief-sigil")
                        .overlay {
                            LivingInkBurst(
                                trigger: beliefPlantBurst,
                                text: answer,
                                mood: .belief,
                                intensity: 0.7
                            )
                            .allowsHitTesting(false)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))

                    if investedBelief {
                        onboardingPreviewCard(
                            symbol: "person.crop.circle.badge.checkmark",
                            title: "\"\(answer)\" is in the story now",
                            body: "It'll turn up again — in pages, in the moments that agree with it, in where the story decides to go next."
                        )
                        continueButton("Good")
                    } else {
                        onboardingBeliefEconomyCard

                        Button {
                            plantBeliefWithCeremony()
                        } label: {
                            Label(
                                isPlantingBelief ? "Writing it in..." : "Put it in the story",
                                systemImage: "person.crop.circle.badge.plus"
                            )
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.teal)
                        .disabled(isPlantingBelief)

                        secondaryOnboardingButton("Just keep the answer for now", systemImage: "hand.raised") {
                            investedBelief = false
                            advance()
                        }
                    }
                }

            case 7:
                onboardingTitle("What Should Turn Up First?")
                onboardingProse("""
                Blank cards sort themselves into six impatient piles.

                "The Book learns from everything you keep and everything you throw away," Zara says. "But something has to knock first."

                "Pick what you're hungry for today. You're not signing up to be a type of person."
                """)
                onboardingChoiceList(choices: tasteChoices, selection: $tastePreference)
                continueButton("Start with that", disabled: tastePreference.isEmpty)

            case 8:
                onboardingTitle("How Hard Should It Push?")
                onboardingProse("""
                The grey bite at the Page's edge stops, listening.

                "This Book can be gentle," Zara says. "It can also be strange, and pointed, and a bit too accurate about you. Say how hard to push to start with — you can change its mind later."
                """)
                onboardingChoiceList(choices: comfortChoices, selection: $comfortBoundary)
                continueButton("Start there", disabled: comfortBoundary.isEmpty)

            case 9:
                onboardingTitle("Five People Want To Read It")
                onboardingProse("""
                Five banners lean toward the answer still warm in your hands.

                "These aren't teams, and they're definitely not houses with nicer robes," Zara says. "They're five arguments about what makes an ordinary life worth anything. They don't agree."

                "Tap one. Hear what it thinks your page means."
                """)
                onboardingChapterAffinityPicker
                continueButton("Let them go first", disabled: drawnChapterID.isEmpty)
                if drawnChapterID.isEmpty {
                    secondaryOnboardingButton("You pick for me", systemImage: "sparkles") {
                        drawnChapterID = bookChosenChapterID
                        advance()
                    }
                }

            case 10:
                onboardingTitle("Wicker Disagrees")
                onboardingProse(firstDoorWickerIntroduction)
                onboardingWickerProof
                continueButton("Let the Page come home", disabled: wickerOutcome == nil)

            default:
                onboardingSystemStrip([
                    ("signature", name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"),
                    ("flag.2.crossed", drawnChapter?.name ?? "First argument"),
                    ("rectangle.stack", "Real edition")
                ])
                onboardingTitle("The First Door Writes Back")

                if didReadFirstDoorWriteback {
                    switch conclusionMiniStep {
                    case 0:
                        onboardingPersonalizedReturn
                            .id("onboarding-personalized-return")
                            .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.08))
                        onboardingConclusionButton("See the next thirty days") {
                            conclusionMiniStep = 1
                        }

                    case 1:
                        onboardingThirtyDayPromise
                            .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.06))
                        onboardingConclusionButton(
                            "Bind the proof I made",
                            disabled: whisperCadence.isEmpty
                        ) {
                            conclusionMiniStep = 2
                        }

                    default:
                        onboardingPhotoBindingChoice
                            .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.04))

                        onboardingFirstBindingInvite
                            .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.06))

                        if didBindFirstEdition {
                            onboardingPreviewCard(
                                symbol: "checkmark.seal.fill",
                                title: "Your first edition's yours.",
                                body: didCloseFirstEditionPreview
                                    ? "It's saved in the Book's own files. Read it, share it, print it, or keep it. The Standing Order can't take it away."
                                    : "Open it. The full write-back, your Chapter's reading, Wicker's consequence, and Zara's letter wait inside."
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            if didCloseFirstEditionPreview {
                                continueButton("See what scratched behind the cover")
                            }
                        } else if !firstEditionBindingError.isEmpty {
                            onboardingPreviewCard(
                                symbol: "exclamationmark.triangle",
                                title: "The thread snagged.",
                                body: firstEditionBindingError
                            )
                        }
                    }
                } else {
                    onboardingProse("""
                    The Book turns your Page around.

                    "You gave it one true thing," Zara says. "Now see whether it actually listened."
                    """)
                    Button {
                        BookFeedback.play(.openPage)
                        withAnimation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.82)) {
                            didReadFirstDoorWriteback = true
                            conclusionMiniStep = 0
                        }
                    } label: {
                        Label("Read what it kept", systemImage: "text.book.closed.fill")
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                }
            }
        }
    }

    private var onboardingSymbol: String {
        guard step > 0 else { return "book.pages" }
        switch step - 1 {
        case 0: return "door.left.hand.open"
        case 1: return "cloud.fog"
        case 2: return "waveform.path.ecg"
        case 3: return "sparkles"
        case 4: return "takeoutbag.and.cup.and.straw"
        case 5: return "signature"
        case 6: return "leaf.fill"
        case 7: return "rectangle.stack.badge.play"
        case 8: return "scalemass"
        case 9: return "flag.2.crossed"
        case 10: return "theatermasks"
        default: return "rectangle.stack"
        }
    }

    private var onboardingStageName: String {
        guard step > 0 else { return "First Page" }
        switch step - 1 {
        case 0: return "Through the Page"
        case 1: return "Autopilot"
        case 2: return "Wide Awake"
        case 3: return "Your Kind of Magic"
        case 4: return "Snacks"
        case 5: return "Your Name"
        case 6: return "What You Believe"
        case 7: return "First Pages"
        case 8: return "How Hard to Push"
        case 9: return "Five Arguments"
        case 10: return "A Consequence"
        default: return "Your First Edition"
        }
    }

    private var onboardingHeaderLine: String {
        guard step > 0 else { return "An ordinary day, turned into something you can hold." }
        switch step - 1 {
        case 0: return "The Page pulls you in and shows you what it's up against."
        case 1: return "Show it where your life goes grey."
        case 2: return "Now the part that wakes you up."
        case 3: return "What magic actually means to you."
        case 4: return "One small true thing, so it isn't everybody's Book."
        case 5: return "It needs something to call you."
        case 6: return "One thing you'd argue for."
        case 7: return "What you'd like to hear from first."
        case 8: return "How hard the story is allowed to push."
        case 9: return "Five old arguments, disagreeing about you."
        case 10: return "Somebody in here remembers what you chose."
        default: return "Your ordinary moment comes back as a real edition."
        }
    }

    private var openingMiniPill: some View {
        HStack(spacing: 8) {
            Label(openingMiniStageName, systemImage: openingMiniSymbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BookPalette.teal)
            Spacer(minLength: 0)
            if step < stepCount - 1 {
                Button {
                    finishWithDefaults()
                } label: {
                    Text("Open the free Book now")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.teal)
                .accessibilityLabel("Skip the First Door and open the free Book")
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

    private var onboardingResumeProgressLine: String {
        step == 0 ? "First Page: \(openingMiniStageName)" : "Return to \(onboardingStageName)"
    }

    private var openingMiniStageName: String {
        switch openingMiniStep {
        case 0: return "The Page Finds You"
        case 1: return "Press One True Thing"
        case 2: return "The Grey Bite"
        case 3: return "What Usually Happens"
        case 4: return "Hidden Magic"
        default: return "Choose How It Keeps"
        }
    }

    private var openingMiniSymbol: String {
        switch openingMiniStep {
        case 0: return "doc.text.fill"
        case 1: return "pencil"
        case 2: return "cloud.fog"
        case 3: return "arrow.uturn.backward.circle"
        case 4: return "sparkle.magnifyingglass"
        default: return "sparkles"
        }
    }

    private var openingMiniScrollTargetID: String {
        switch openingMiniStep {
        case 1: return "onboarding-opening-press"
        case 2: return "onboarding-opening-grey-bite"
        case 3: return "onboarding-opening-moment-fate"
        case 4: return "onboarding-opening-hidden-magic"
        case 5: return "onboarding-opening-keeps"
        default: return "onboarding-page-top"
        }
    }

    private var onboardingOpeningPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch openingMiniStep {
            case 0:
                onboardingOpeningOverture
                onboardingOpeningHeroIntro
                onboardingOpeningCard
                openingMiniContinueButton("The ink is still wet. Touch it.") {
                    advanceOpeningMiniStep()
                }
            case 1:
                onboardingOpeningPress
                    .id("onboarding-opening-press")
                if firstPressTrimmedText.isEmpty {
                    onboardingFirstPressLocalPreview
                } else {
                    onboardingNoticedLine
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    onboardingOpeningKeepDecision
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    onboardingFirstPressLocalPreview
                }
                openingMiniContinueButton(
                    firstPressTrimmedText.isEmpty
                        ? "Find one true thing"
                        : (rehearsalChoice == nil ? "Keep it or let it wait" : "Let the Rut try"),
                    disabled: firstPressTrimmedText.isEmpty || rehearsalChoice == nil
                ) {
                    advanceOpeningMiniStep()
                }
            case 2:
                onboardingProse(firstPressRutArrivalProse)
                .id("onboarding-opening-grey-bite")
                onboardingRoutineRevealAction

                if didRevealRoutineEvidence {
                    VStack(alignment: .leading, spacing: 16) {
                        onboardingNotYourFaultCard
                            .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.10))
                        openingMiniContinueButton("Tell the Page what usually happens") {
                            advanceOpeningMiniStep()
                        }
                    }
                    .id("onboarding-opening-routine-evidence")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            case 3:
                onboardingTitle("What Usually Happens Next?")
                    .id("onboarding-opening-moment-fate")
                onboardingProse("""
                The Page studies the true thing you gave it.

                "What usually happens to small moments like this?"
                """)
                onboardingChoiceList(choices: momentFateChoices, selection: $momentFate)
                if !momentFate.isEmpty {
                    onboardingPreviewCard(
                        symbol: "text.bubble.fill",
                        title: "The Page answers",
                        body: momentFateReflection
                    )
                    .id("onboarding-moment-reflection")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                openingMiniContinueButton(
                    "One more honest question",
                    disabled: momentFate.isEmpty
                ) {
                    advanceOpeningMiniStep()
                }

            case 4:
                onboardingTitle("Did the Ordinary Thing Move?")
                    .id("onboarding-opening-hidden-magic")
                onboardingProse("""
                The ink gathers itself into one last question.

                "Be honest. Did that ordinary thing feel a little less ordinary when you looked twice?"
                """)
                onboardingChoiceList(choices: hiddenMagicChoices, selection: $hiddenMagicStance)
                if !hiddenMagicStance.isEmpty {
                    onboardingPreviewCard(
                        symbol: "sparkles",
                        title: "The Book writes back",
                        body: hiddenMagicReflection
                    )
                    .id("onboarding-hidden-magic-reflection")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                openingMiniContinueButton(
                    "Now decide how it reads you",
                    disabled: hiddenMagicStance.isEmpty
                ) {
                    advanceOpeningMiniStep()
                }

            default:
                onboardingFirstPressScene
                    .id("onboarding-opening-keeps")

                if didChooseFirstPressNarrative {
                    onboardingFirstPressLocalPreview
                    onboardingProse(firstPressTransitionProse)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    onboardingStoryCardShareButton
                    onboardingOpenBookTab
                }
            }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.84), value: didCompleteFirstPress)
        .animation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.84), value: openingMiniStep)
    }

    /// The very first words of the whole app: the reader opens the app, finds
    /// the Book, and sees a loose page slip out before the Book itself opens.
    private var onboardingOpeningOverture: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isOpeningOvertureTitleVisible || isPadOnboardingDevice {
                Text("You open the Book.")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .shadow(color: BookPalette.lampGold.opacity(0.18), radius: 8, x: 0, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isOpeningOvertureTitleVisible ? 1 : 0)
                    .accessibilityHidden(!isOpeningOvertureTitleVisible)
                    .modifier(OnboardingGhostInModifier(delay: 0.04))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }

            onboardingOpeningPullQuote
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var onboardingOpeningPullQuote: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("“")
                .font(.system(size: 42, weight: .semibold, design: .serif))
                .foregroundStyle(BookPalette.lampGold.opacity(0.86))
                .offset(y: -6)
                .accessibilityHidden(true)

            Text("Between the covers of the Book you just found, a loose Page slips out and lands with your \(onboardingOpeningTimeName) already on it.")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(BookPalette.lampGold.opacity(0.82))
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .modifier(OnboardingGhostInModifier(delay: 0.12))
    }

    /// The first thing a new player ever sees: a finished Book of You page
    /// pressed from the real moment of arrival. Typing or tapping a preset
    /// re-forms the same page live.
    private var onboardingOpeningHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            onboardingOpeningHeroIntro
            onboardingOpeningCard
            onboardingNoticedLine
        }
    }

    private var onboardingOpeningHeroIntro: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 38, height: 38)
                .background(BookPalette.nightPanel.opacity(0.92), in: Circle())
                .overlay {
                    Circle()
                        .stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR FIRST PAGE, ALREADY WRITTEN")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(BookPalette.teal)
                Text("An ordinary day, turned into a page from a storybook.")
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .modifier(OnboardingGhostInModifier(delay: 0.08))
        }
    }

    private var onboardingOpeningCard: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / BookOfYouShareCard.renderSize.width
            BookOfYouShareCard(artifact: onboardingOpeningArtifact)
                .frame(width: BookOfYouShareCard.renderSize.width, height: BookOfYouShareCard.renderSize.height)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(BookOfYouShareCard.renderSize.width / BookOfYouShareCard.renderSize.height, contentMode: .fit)
        .frame(maxWidth: isPadOnboardingDevice ? 620 : .infinity)
        .frame(maxWidth: .infinity)
        .overlay {
            LivingInkBurst(
                trigger: openingKeepBurst,
                text: "KEPT",
                mood: .kept,
                intensity: 0.6
            )
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            if didCompleteFirstPress {
                Label("KEPT", systemImage: "bookmark.fill")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(BookPalette.nightText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(BookPalette.teal.opacity(0.94), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(BookPalette.lampGold.opacity(0.5), lineWidth: 1)
                    }
                    .padding(12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .rotationEffect(.degrees(reduceMotion ? 0 : (didRevealOpeningCard ? 1.1 : -2.4)))
        .scaleEffect(didRevealOpeningCard ? 1 : 0.94)
        .opacity(didRevealOpeningCard ? 1 : 0)
        .blur(radius: didRevealOpeningCard ? 0 : 6)
        .shadow(color: BookPalette.lampGold.opacity(didCompleteFirstPress ? 0.34 : 0.20), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.16), radius: 9, x: 0, y: 6)
        .padding(.horizontal, 4)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.3), value: onboardingOpeningArtifact)
        .contentShape(Rectangle())
        .onTapGesture {
            previewBookOfYouPage(onboardingOpeningArtifact)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A finished storybook page titled \(onboardingOpeningArtifact.title): \(onboardingOpeningArtifact.excerpt)")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            guard !didRevealOpeningCard else { return }
            guard !reduceMotion else {
                didRevealOpeningCard = true
                return
            }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.78).delay(0.12)) {
                didRevealOpeningCard = true
            }
        }
    }

    private var onboardingNoticedLine: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: firstPressTrimmedText.isEmpty ? "eye" : "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 26, height: 26)
                .background(BookPalette.nightPanel.opacity(0.9), in: Circle())

            Text(firstPressTrimmedText.isEmpty
                ? "The Page slipped out the moment you found the Book — \(arrivalClockTime), \(arrivalWeekdayName) \(firstPressTimeName). It noticed you arrive."
                : "That was already happening before I asked. Routine had filed it as scenery. You just made it an event.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(BookPalette.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.2), lineWidth: 1)
        }
        .modifier(OnboardingGhostInModifier(delay: 0.10))
    }

    private var onboardingOpeningPress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A ten-second mission")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(OnboardingGhostInModifier(delay: 0.06))

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "pencil.and.outline")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                Text("Look away from the screen. Find the nearest ordinary thing that seems to have an opinion about this room. What tiny thing is it doing that gives it away?")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .modifier(OnboardingGhostInModifier(delay: 0.10))

            onboardingEmbeddedDetailField

            Text("Write one sentence, change one of mine, or keep it exactly as it is. An unimpressed answer counts if it's true.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(firstPressPresets) { preset in
                    firstPressPresetButton(preset)
                }
            }
        }
        .padding(13)
        .background(BookPalette.page.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.24), lineWidth: 1)
        }
    }

    private var onboardingFirstPressScene: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 54, height: 54)
                    .background(BookPalette.nightPanel.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(0.34), lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("THE PAGE ASKS HOW TO KEEP YOU")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(BookPalette.gold)
                    Text("A small narrative decision")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .modifier(OnboardingGhostInModifier(delay: 0.06))
            }

            Text("""
            The loose Page lifts. "I can leave this ordinary, bend it toward what happens next, or let the margin surprise us both."

            It waits. Something inside the covers is asking how you want your life to be read.
            """)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(OnboardingGhostInModifier(delay: 0.16))

            VStack(spacing: 7) {
                ForEach(firstPressNarrativeChoices) { choice in
                    let selected = selectedFirstPressNarrativeID == choice.id
                    Button {
                        chooseFirstPressNarrative(choice)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: selected ? "checkmark.circle.fill" : choice.symbol)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(selected ? BookPalette.teal : BookPalette.lampGold)
                                .frame(width: 28, height: 28)
                                .background((selected ? BookPalette.teal : BookPalette.lampGold).opacity(0.13), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.title)
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                                Text(choice.detail)
                                    .font(.system(.caption, design: .serif))
                                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected ? BookPalette.teal.opacity(0.12) : BookPalette.paper.opacity(0.48), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke((selected ? BookPalette.teal : BookPalette.lampGold).opacity(selected ? 0.42 : 0.18), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            if let choice = selectedFirstPressNarrativeChoice {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(BookPalette.lampGold)
                        .frame(width: 26, height: 26)
                        .background(BookPalette.nightPanel.opacity(0.90), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(choice.title): the Page answers")
                            .font(.caption.weight(.black))
                            .foregroundStyle(BookPalette.ink.opacity(0.76))
                        Text(choice.outcomeLine)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(BookPalette.paper.opacity(0.48), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.20), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(11)
        .background(BookPalette.page.opacity(0.50), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.18), lineWidth: 1)
        }
    }

    private var onboardingEmbeddedDetailField: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "The lamp keeps leaning over the chair like it wants the seat.",
                text: firstPressTextBinding,
                axis: .vertical
            )
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .focused($isOnboardingFieldFocused)
                .dictationInput(text: firstPressTextBinding)
                .accessibilityLabel("Your sentence")
        }
        .padding(14)
        .background(BookPalette.page.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if !firstPressTrimmedText.isEmpty {
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .padding(8)
                    .background(BookPalette.nightPanel.opacity(0.94), in: Circle())
                    .offset(x: 8, y: 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((firstPressTrimmedText.isEmpty ? BookPalette.gold : BookPalette.teal).opacity(firstPressTrimmedText.isEmpty ? 0.34 : 0.50), lineWidth: 1)
        }
    }

    private var onboardingFirstPressLocalPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.teal)
                Text("YOUR PAGE NOW")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(BookPalette.teal)
                Spacer(minLength: 0)
                Text(selectedFirstPressNarrativeChoice?.title.uppercased() ?? "WAITING")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(BookPalette.ink.opacity(0.42))
            }

            GeometryReader { proxy in
                let scale = proxy.size.width / BookOfYouShareCard.renderSize.width
                BookOfYouShareCard(artifact: onboardingOpeningArtifact)
                    .frame(width: BookOfYouShareCard.renderSize.width, height: BookOfYouShareCard.renderSize.height)
                    .scaleEffect(scale, anchor: .topLeading)
            }
            .aspectRatio(BookOfYouShareCard.renderSize.width / BookOfYouShareCard.renderSize.height, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomTrailing) {
                if didCompleteFirstPress {
                    Label("KEPT", systemImage: "bookmark.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(BookPalette.nightText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(BookPalette.teal.opacity(0.94), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(BookPalette.lampGold.opacity(0.5), lineWidth: 1)
                        }
                        .padding(12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: BookPalette.lampGold.opacity(0.16), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.13), radius: 7, x: 0, y: 5)
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(BookPalette.paper.opacity(0.58), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            previewBookOfYouPage(onboardingOpeningArtifact)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current Book of You page preview titled \(onboardingOpeningArtifact.title): \(onboardingOpeningArtifact.excerpt)")
        .accessibilityAddTraits(.isButton)
    }

    private var onboardingOpeningKeepDecision: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THE PAGE ANSWERED. NOW YOU DO.")
                .font(.system(size: 10, weight: .black))
                .tracking(1.1)
                .foregroundStyle(BookPalette.ink.opacity(0.46))

            Text("Keep this moment, or let it wait. Both choices teach the Book how to read your life.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    letFirstPressPageWait()
                } label: {
                    Label(
                        rehearsalChoice == .wait ? "Waiting" : "Let it wait",
                        systemImage: rehearsalChoice == .wait ? "checkmark.circle.fill" : "clock"
                    )
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.ink.opacity(0.72))
                .accessibilityAddTraits(rehearsalChoice == .wait ? .isSelected : [])

                Button {
                    keepFirstPressPage()
                } label: {
                    Label(
                        didCompleteFirstPress ? "Kept" : "Keep this Page",
                        systemImage: didCompleteFirstPress ? "checkmark.seal.fill" : "bookmark.fill"
                    )
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
                .accessibilityAddTraits(didCompleteFirstPress ? .isSelected : [])
            }

            if rehearsalChoice == .wait {
                Text("The Page folds the sentence inward. It won't pretend every offered moment belongs in your archive.")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if didCompleteFirstPress {
                Text("The Page stamps itself KEPT. A small hand in the margin gives you an approving thumbs-up.")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        }
    }

    private var onboardingArtifactSeals: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS PAGE IS ALREADY REAL — TRY IT")
                .font(.system(size: 10, weight: .black))
                .tracking(1.1)
                .foregroundStyle(BookPalette.ink.opacity(0.46))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                onboardingArtifactSealButton(
                    symbol: didCompleteFirstPress ? "checkmark.seal.fill" : "bookmark.fill",
                    title: "Keep",
                    detail: didCompleteFirstPress ? "kept" : (didChooseFirstPressNarrative ? "private" : "choose"),
                    isActive: didCompleteFirstPress,
                    isDisabled: !didChooseFirstPressNarrative
                ) {
                    keepFirstPressPage()
                }

                onboardingArtifactSealButton(symbol: "square.and.arrow.up", title: "Share", detail: "card") {
                    shareOpeningCard()
                }

                onboardingArtifactSealButton(
                    symbol: "play.rectangle.fill",
                    title: ".mp4",
                    detail: isPressingOpeningRevealVideo ? "pressing" : "reveal",
                    isBusy: isPressingOpeningRevealVideo
                ) {
                    pressOpeningRevealVideo()
                }
            }
        }
    }

    private func onboardingArtifactSealButton(
        symbol: String,
        title: String,
        detail: String,
        isActive: Bool = false,
        isBusy: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(BookPalette.nightText)
                        .opacity(isBusy ? 0 : 1)
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(BookPalette.nightText)
                    }
                }
                .frame(width: 26, height: 26)
                .background((isActive ? BookPalette.lampGold : BookPalette.teal).opacity(0.92), in: Circle())
                .overlay {
                    Circle()
                        .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                }
                Text(title)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(BookPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.46))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(BookPalette.paper.opacity(isActive ? 0.78 : 0.58), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke((isActive ? BookPalette.lampGold : BookPalette.gold).opacity(isActive ? 0.44 : 0.20), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy || isDisabled)
        .opacity(isDisabled ? 0.58 : 1)
    }

    private var onboardingOpenBookTab: some View {
        Button {
            openBookFromLivingPage()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16, weight: .black))
                Text(rehearsalChoice == nil ? "Choose what the Page should do" : "Pull the Page open")
                    .font(.body.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundStyle(BookPalette.nightText)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(BookPalette.teal.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1)
            }
            .shadow(color: BookPalette.teal.opacity(0.20), radius: 14, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(!didChooseFirstPressNarrative || rehearsalChoice == nil)
        .opacity(didChooseFirstPressNarrative && rehearsalChoice != nil ? 1 : 0.62)
        .modifier(OnboardingSectionArrivalModifier(kind: .control, delay: 0.30))
    }

    /// The completed card gets one quiet, ordinary way out of the Book before
    /// the cover opens: Apple's system share sheet with the rendered image.
    private var onboardingStoryCardShareButton: some View {
        Button {
            shareOpeningCard()
        } label: {
            Label("Share this story card", systemImage: "square.and.arrow.up")
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(BookPalette.teal)
        .accessibilityHint("Opens the Apple share sheet for your completed story card")
        .modifier(OnboardingSectionArrivalModifier(kind: .control, delay: 0.24))
    }

    private func openBookFromLivingPage() {
        isOnboardingFieldFocused = false
        guard didChooseFirstPressNarrative, rehearsalChoice != nil else {
            BookFeedback.play(.error)
            return
        }
        BookFeedback.play(.openPage)
        // Advance underneath, then reveal step 1 through the opening cover.
        advance()
        withAnimation(.easeInOut(duration: 0.3)) {
            isCoverOpeningVisible = true
        }
    }

    private var arrivalClockTime: String {
        arrivalMoment.formatted(date: .omitted, time: .shortened)
    }

    private var arrivalWeekdayName: String {
        arrivalMoment.formatted(.dateTime.weekday(.wide))
    }

    private var arrivalMonthName: String {
        arrivalMoment.formatted(.dateTime.month(.wide))
    }

    private var openingArrivalTitle: String {
        firstPressTimeName == "late night"
            ? "The Night You Arrived"
            : "The \(firstPressTimeName.capitalized) You Arrived"
    }

    /// A second-person kept line the Page writes on the player's behalf, so the
    /// opening card is finished before they have typed a single word.
    private var openingArrivalExcerpt: String {
        "You picked up this Page on \(arrivalWeekdayName) at \(arrivalClockTime), while \(firstPressTimeTexture)."
    }

    /// Pinned to the arrival moment rather than the typed text so the card's
    /// palette, border, and marginalia stay steady while the player writes,
    /// and only the words re-form.
    private var openingArtifactSeed: Int {
        "opening-artifact".stableHash
            ^ arrivalMoment.formatted(date: .abbreviated, time: .omitted).stableHash
            ^ firstPressTimeName.stableHash
    }

    private var onboardingOpeningArtifact: BookOfYouShareArtifact {
        let hasPageDecision = !firstPressTrimmedText.isEmpty || didChooseFirstPressNarrative
        return BookOfYouShareArtifact(
            title: firstPressTrimmedText.isEmpty ? openingArrivalTitle : firstPressPreviewTitle,
            excerpt: hasPageDecision ? firstPressPreviewExcerpt : openingArrivalExcerpt,
            dateLine: arrivalMoment.formatted(date: .abbreviated, time: .omitted),
            themeName: "Ordinary life",
            chapterName: didCompleteFirstPress
                ? "First kept Page"
                : (rehearsalChoice == .wait ? "Allowed to wait" : (hasPageDecision ? "Forming now" : "Written at your arrival")),
            seed: openingArtifactSeed
        )
    }

    private var onboardingFirstDoorBookOfYouArtifact: BookOfYouShareArtifact {
        let reader = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"
        let decision = rehearsalChoice == .keep
            ? "kept one true Page"
            : "let the first Page wait"
        let chapter = drawnChapter?.name ?? "five arguing banners"
        let excerpt = "\(reader) arrived while the ink was wet, \(decision), and watched \(chapter) change what happened next. The Book followed one ordinary moment all the way into a consequence. Not a profile. A beginning."
        return BookOfYouShareArtifact(
            title: "The First Door Writes Back",
            excerpt: excerpt,
            dateLine: arrivalMoment.formatted(date: .abbreviated, time: .omitted),
            themeName: "First Door",
            chapterName: "The Book of You",
            seed: "first-door-book-of-you".stableHash
                ^ reader.stableHash
                ^ firstPressTrimmedText.stableHash
                ^ drawnChapterID.stableHash
                ^ selectedFirstPressNarrativeID.stableHash
        )
    }

    @MainActor
    private func shareOpeningCard() {
        isOnboardingFieldFocused = false
        if let url = BookOfYouShareCardRenderer.render(artifact: onboardingOpeningArtifact) {
            BookFeedback.play(.braidComplete)
            onboardingShareItem = OnboardingShareItem(url: url)
        } else {
            BookFeedback.play(.error)
        }
    }

    @MainActor
    private func previewBookOfYouPage(_ artifact: BookOfYouShareArtifact) {
        isOnboardingFieldFocused = false
        if let url = BookOfYouShareCardRenderer.render(artifact: artifact) {
            BookFeedback.play(.openPage)
            bookOfYouPreviewURL = url
        } else {
            BookFeedback.play(.error)
        }
    }

    private func pressOpeningRevealVideo() {
        isOnboardingFieldFocused = false
        guard !isPressingOpeningRevealVideo else { return }
        isPressingOpeningRevealVideo = true
        let artifact = onboardingOpeningArtifact
        Task { @MainActor in
            defer { isPressingOpeningRevealVideo = false }
            if let url = await BookOfYouPageRevealVideoRenderer.render(artifact: artifact) {
                BookFeedback.play(.braidComplete)
                onboardingShareItem = OnboardingShareItem(url: url)
            } else {
                BookFeedback.play(.error)
            }
        }
    }

    /// A lightweight facsimile of the monthly bound edition — the "remember"
    /// horizon. Deliberately not a real PDF render; it only has to make the
    /// promise visible, with the player's own page as the first entry.
    private var onboardingBindingFacsimile: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 7) {
                Text("THE \(arrivalMonthName.uppercased()) EDITION")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.3)
                    .foregroundStyle(BookPalette.gold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                ZStack {
                    Rectangle()
                        .fill(BookPalette.gold.opacity(0.5))
                        .frame(width: 54, height: 1.4)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(BookPalette.gold.opacity(0.8))
                }

                Text("The Book of You")
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink)

                Text("ready when \(arrivalMonthName) has Pages")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.5))
                    .multilineTextAlignment(.center)

                Text("· \(onboardingOpeningArtifact.title) ·")
                    .font(.system(.caption2, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .frame(width: 150)
            .background(
                LinearGradient(
                    colors: [
                        BookPalette.page.opacity(0.98),
                        BookPalette.paper.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(BookPalette.gold.opacity(0.5), lineWidth: 1.4)
                    .padding(3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.18), lineWidth: 1)
            }
            .rotationEffect(.degrees(reduceMotion ? 0 : -2))
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text("Where kept pages end up")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                Text("When you're ready, the Book can bind \(arrivalMonthName)'s kept Pages into a real edition — a PDF to keep, print at home, or later order as a physical book from the Bindery.")
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Label("A kept Page can become its first entry.", systemImage: "bookmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }
        }
        .padding(13)
        .background(BookPalette.paper.opacity(0.54), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var onboardingPersonalizedReturn: some View {
        let ration = snack.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "an unnamed reading snack"
        let planted = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "one still-unwritten belief"
        let narrative = selectedFirstPressNarrativeChoice?.title ?? "Something Small and True"
        let decision = rehearsalChoice == .keep
            ? "You kept \(firstDoorChapterSubject) before the day could carry it off."
            : "You let the Page wait, and I kept your no as carefully as a yes."
        let argument = drawnChapter.map {
            "\($0.name) read your Page as an argument: \(chapterArgument(for: $0))"
        } ?? "The five Chapters are still arguing over what your Page means."
        let consequence = wickerOutcome.flatMap { outcome in
            wickerChoice(for: outcome.choiceID).map { choice in
                "\(argument) Your first instinct was \(narrative); when Wicker interrupted, you chose \(choice.title.lowercased()). \(wickerConsequence(for: choice, tier: outcome.tier))"
            }
        } ?? "\(argument) The Page kept a clean margin where Wicker's answer would've gone."

        return VStack(alignment: .leading, spacing: 13) {
            Text("THE PATH YOUR PAGE MADE")
                .font(.system(size: 10, weight: .black))
                .tracking(1.2)
                .foregroundStyle(BookPalette.gold)

            Text(firstPressPreviewTitle)
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(BookPalette.ink)

            Text("At \(arrivalClockTime), you gave me \(firstDoorChapterSubject). I didn't leave it where you typed it.")
                .font(.system(.callout, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            onboardingJourneyRow(
                symbol: "hand.draw.fill",
                title: "Your first choice stayed chosen",
                detail: "\(decision) The margin tucked \(ration) beside it—a fact this Book couldn't have guessed."
            )
            onboardingJourneyRow(
                symbol: "scope",
                title: "The Book learned where to look",
                detail: "It'll watch for the Rut around “\(rutTitle.lowercased()),” and for signs of life in “\(mostAliveTitle.lowercased())” and “\(magicSourceTitle.lowercased()).”"
            )
            onboardingJourneyRow(
                symbol: "person.crop.circle.badge.checkmark",
                title: investedBelief ? "\"\(planted)\" joined the Cast" : "The answer is saved",
                detail: investedBelief
                    ? "You lent it Belief. It can now connect related moments, return across Pages, and pull story toward what it means."
                    : "You named “\(planted)” without lending it Belief yet. It can join the Cast later, if you choose."
            )
            onboardingJourneyRow(
                symbol: "rectangle.stack.badge.play",
                title: "The shelves leaned your way",
                detail: "\(tasteTitle) knocks first. The Book begins \(comfortTitle.lowercased())."
            )

            Text(consequence)
                .font(.system(.callout, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Text("You noticed. You chose what to keep. I let those choices change what returned.")
                .font(.system(.callout, design: .serif).weight(.bold))
                .foregroundStyle(BookPalette.teal)
                .fixedSize(horizontal: false, vertical: true)

            Text("That's the living loop.")
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.ink.opacity(0.62))
        }
        .padding(14)
        .background(BookPalette.paper.opacity(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.34), lineWidth: 1)
        }
    }

    private func onboardingJourneyRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 28, height: 28)
                .background(BookPalette.nightPanel.opacity(0.92), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.ink.opacity(0.84))
                Text(detail)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var onboardingThirtyDayPromise: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(BookPalette.teal.opacity(0.14))
                        .frame(width: 54, height: 54)
                    Text("30")
                        .font(.system(.title3, design: .serif).weight(.black))
                        .foregroundStyle(BookPalette.teal)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("THE NEXT THIRTY DAYS")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(BookPalette.gold)
                    Text("Make the month feel longer.")
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                }
            }

            Text("Repeat this small loop when you can:")
                .font(.body.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.64))

            Text("Notice one true thing.  Keep it, or let it wait.  See what returns.")
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("What you pay attention to is your life. The rest doesn't get lived — it just passes.")
                .font(.system(.body, design: .serif).weight(.black))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("So: look for the wonder, then pin what you find into one true sentence. Your attention learns where to look. The month gets fuller because you caught more of what was already there — not because I painted sparkles over it.")
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("CHOOSE THE HINGE")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(BookPalette.gold)
                Text("A new habit sticks best when it hangs off one you already have. When should I tap on the glass?")
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                onboardingChipChoices(
                    choices: whisperChoices,
                    selection: $whisperCadence,
                    largeText: true
                )
                if !whisperCadence.isEmpty {
                    onboardingPreviewCard(
                        symbol: "bell.badge.fill",
                        title: "\(whisperTitle) becomes the hinge",
                        body: whisperCueReflection,
                        largeText: true
                    )
                    .id("onboarding-whisper-hinge")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("Pick one to carry on. Silence counts too — I'm happy to wait inside the covers.")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !whisperCadence.isEmpty {
                Button {
                    BookFeedback.play(.openPage)
                    withAnimation(reduceMotion ? .none : .spring(response: 0.48, dampingFraction: 0.80)) {
                        didRevealDayThirtyAfter.toggle()
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: didRevealDayThirtyAfter ? "book.pages.fill" : "sparkles.rectangle.stack")
                        Text(didRevealDayThirtyAfter ? "Close Day 30" : "Show me the after")
                        Spacer(minLength: 0)
                        Image(systemName: didRevealDayThirtyAfter ? "chevron.up" : "chevron.down")
                            .font(.body.weight(.black))
                    }
                    .font(.body.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 15)
                    .background(
                        LinearGradient(
                            colors: [
                                BookPalette.violet.opacity(0.18),
                                BookPalette.gold.opacity(0.13)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(BookPalette.gold.opacity(0.42), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.ink)
                .accessibilityHint("Reveals or hides a possible picture of your life after thirty days of noticing")

                if didRevealDayThirtyAfter {
                    onboardingDayThirtyAfterCard
                        .id("onboarding-day-thirty-after")
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            )
                        )
                }
            }

            Text("Two things the research is clear about: thirty days is an opening chapter, not a finish line. And missing days \u{2014} several of them, not just one \u{2014} does not undo the habit. Almost nobody builds one cleanly.")
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                BookFeedback.play(.select)
                withAnimation(reduceMotion ? .none : .spring(response: 0.36, dampingFraction: 0.84)) {
                    didRevealHabitScience.toggle()
                }
            } label: {
                Label(
                    didRevealHabitScience ? "Close the research" : "Show me the research",
                    systemImage: didRevealHabitScience ? "chevron.up" : "text.book.closed"
                )
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)
            .accessibilityHint("Reveals or hides the studies behind the Book's thirty-day practice")

            if didRevealHabitScience {
                onboardingHabitScienceCard
                    .id("onboarding-habit-science")
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("Give it one chance a day. Thirty days from now you won't just know that a month went by — you'll have up to thirty specific moments the blur would have eaten. Proof of where your life actually went.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Text("Nobody can give you more days. But when more of them stay, the month feels longer. That's the whole trick: making more of your life stay.")
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            Text("Every Page you keep gives me one specific piece of magic I can return and bind.")
                .font(.body.weight(.black))
                .foregroundStyle(BookPalette.teal)
        }
        .padding(18)
        .background(BookPalette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
    }

    private var onboardingDayThirtyAfterCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(BookPalette.lampGold.opacity(0.95))
                        .frame(width: 42, height: 42)
                    Image(systemName: "sun.max.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(BookPalette.ink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("A POSSIBLE DAY THIRTY")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1.05)
                        .foregroundStyle(BookPalette.lampGold)
                    Text("Your life gets harder to lose.")
                        .font(.system(.title3, design: .serif).weight(.black))
                        .foregroundStyle(BookPalette.nightText)
                }
            }

            Text("I probably won't fix your life. That's not how magic works. But I might make your life much harder to lose.")
                .font(.system(.title3, design: .serif).weight(.black))
                .foregroundStyle(BookPalette.nightText)
                .fixedSize(horizontal: false, vertical: true)

            Text("The Rut still gets loud when \(dayThirtyRutClause). Then, on some completely ordinary \(dayThirtyHingeMoment), you notice \(dayThirtyMagicPhrase) before I ask. You keep one sentence. Later, I hand it back—and a day that would've disappeared has weather, edges, and a name again.")
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            Text("You may still have the same inbox, dishes, aches, and unfinished problems. But you're becoming the person who catches the moon between two buildings, the joke somebody nearly swallowed, the exact Tuesday you felt like yourself again—and stays long enough to write it down.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 9) {
                Text("A POSSIBLE LEDGER — NOT A QUOTA")
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.9)
                    .foregroundStyle(BookPalette.lampGold.opacity(0.92))

                onboardingDayThirtyMeasure(
                    number: "UP TO 30",
                    title: "moments the blur didn't get",
                    body: "Dated, specific, and written in your own words."
                )
                onboardingDayThirtyMeasure(
                    number: "1 LINE",
                    title: "can reopen a whole day",
                    body: "Enough to recover the room, the weather, the face, or the feeling."
                )
                onboardingDayThirtyMeasure(
                    number: "3 SIGNALS",
                    title: "may keep making you feel awake",
                    body: "People, places, sounds, weather, or tiny details you can look for again."
                )
                onboardingDayThirtyMeasure(
                    number: "1 MONTH",
                    title: "you can actually account for",
                    body: "Bound into a Book you can reread, share, and point to when you ask where the time went."
                )
            }
            .padding(12)
            .background(BookPalette.paper.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
            }

            Text("That's the transformation: you don't escape your ordinary life. Your ordinary life stops escaping you.")
                .font(.system(.body, design: .serif).weight(.black))
                .foregroundStyle(BookPalette.lampGold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    BookPalette.nightPanel.opacity(0.98),
                    BookPalette.violet.opacity(0.38),
                    BookPalette.nightPanel.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.46), lineWidth: 1.2)
        }
        .shadow(color: BookPalette.violet.opacity(0.18), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.04))
    }

    private func onboardingDayThirtyMeasure(
        number: String,
        title: String,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(BookPalette.ink)
                .frame(width: 82)
                .padding(.vertical, 9)
                .background(BookPalette.lampGold, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.black))
                    .foregroundStyle(BookPalette.nightText)
                Text(body)
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var onboardingHabitScienceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 9) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BookPalette.nightText)
                    .frame(width: 34, height: 34)
                    .background(BookPalette.teal.opacity(0.94), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("THE HABIT SCIENCE")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(BookPalette.gold)
                    Text("Thirty days is the opening chapter.")
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                }
            }

            Text("Not a finish line, and definitely not a streak. Thirty chances to teach your attention the same short route \u{2014} and you do not have to take all of them.")
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.80))
                .fixedSize(horizontal: false, vertical: true)

            onboardingHabitScienceStat(
                number: "30",
                title: "goes at something you already do",
                body: "Your first coffee, lunch, getting into bed. Open the Book there. Notice one true thing, keep one sentence, see what comes back."
            )

            onboardingHabitScienceStat(
                number: "66",
                title: "days was the median",
                body: "In a real study of everyday habits, the median time for one to become near-automatic was 66 days — though people ranged from 18 days to 254. So Day 30 is real progress, not a finished job."
            )

            onboardingHabitScienceStat(
                number: "0",
                title: "days you have to do in a row",
                body: "This is the part people get wrong. Missing a day didn't set anyone in the study back \u{2014} and the people who did build the habit missed plenty of days along the way. Patchy, uneven, on-and-off is not the failed version of this. It is the normal one, and it still works."
            )

            onboardingHabitScienceStat(
                number: "101",
                title: "people kept a 30-day diary",
                body: "The ones who paused to savour things were in better spirits, and their good days counted for more. Nobody tested this app — I'm just borrowing the principle. Don't only have the moment. Stop, name it exactly, let it land."
            )

            VStack(alignment: .leading, spacing: 3) {
                Label("Lally et al., European Journal of Social Psychology (2010)", systemImage: "text.book.closed")
                Label("Jose, Lim & Bryant, Journal of Positive Psychology (2012)", systemImage: "text.book.closed")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(BookPalette.ink.opacity(0.50))
        }
        .padding(16)
        .background(BookPalette.paper.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(BookPalette.teal.opacity(0.94))
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
        .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.10))
    }

    private func onboardingHabitScienceStat(
        number: String,
        title: String,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number)
                .font(.system(size: number.count > 2 ? 29 : 34, weight: .black, design: .rounded))
                .foregroundStyle(BookPalette.teal)
                .frame(width: 66, alignment: .trailing)
                .minimumScaleFactor(0.74)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                Text(body)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func onboardingConclusionButton(
        _ title: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            BookFeedback.play(.openPage)
            withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.84)) {
                action()
            }
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

    /// An optional final piece of real-world evidence. The first handmade Page
    /// is already in the edition; this lets the reader put one ordinary
    /// photograph beside it without making Photos access a prerequisite.
    private var onboardingPhotoBindingChoice: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: didKeepOnboardingPhoto ? "photo.badge.checkmark.fill" : "photo.artframe")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(didKeepOnboardingPhoto ? BookPalette.teal : BookPalette.lampGold)
                    .frame(width: 38, height: 38)
                    .background(BookPalette.nightPanel.opacity(0.92), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(
                                (didKeepOnboardingPhoto ? BookPalette.teal : BookPalette.lampGold).opacity(0.42),
                                lineWidth: 1
                            )
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(didKeepOnboardingPhoto ? "YOUR WORLD IS BETWEEN THE COVERS" : "PUT YOUR WORLD BETWEEN THE COVERS")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.0)
                        .foregroundStyle(didKeepOnboardingPhoto ? BookPalette.teal : BookPalette.gold)
                    Text(
                        didKeepOnboardingPhoto
                            ? "This illuminated photograph will appear in your First Edition."
                            : "Your handmade Page is already waiting inside. You can place one ordinary photograph beside it."
                    )
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if didKeepOnboardingPhoto, let draft = onboardingPhotoDraft {
                HStack(alignment: .center, spacing: 12) {
                    onboardingIlluminatedBindingThumbnail(draft)
                        .frame(width: 78, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Label("Inside your First Edition", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(BookPalette.teal)
                        Text("The full-size illuminated page will sit beside the words you made. The PDF keeps both.")
                            .font(.system(.caption, design: .serif).weight(.semibold))
                            .foregroundStyle(BookPalette.ink.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(BookPalette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Text("A room, a coffee cup, someone you love, the light right now. Boring is fine — boring is usually the honest one. It gets decorated right here on your phone, and nothing gets uploaded anywhere.")
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isOnboardingPhotoLoading {
                HStack(spacing: 9) {
                    ProgressView()
                        .tint(BookPalette.teal)
                    Text("Illuminating here on your phone…")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 10) {
                    #if canImport(PhotosUI)
                    PhotosPicker(selection: $onboardingPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Label(didKeepOnboardingPhoto ? "Choose another" : "Choose photo", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
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
                    }
                    #endif
                }
                .font(.subheadline.weight(.bold))
                .tint(BookPalette.teal)
            }

            if !didKeepOnboardingPhoto {
                Text("Optional. Bind the edition as it is, or add one photograph and see it full-screen before it enters the Book.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.54))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    BookPalette.page.opacity(0.72),
                    BookPalette.violet.opacity(0.07),
                    BookPalette.page.opacity(0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    (didKeepOnboardingPhoto ? BookPalette.teal : BookPalette.lampGold).opacity(0.30),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private func onboardingIlluminatedBindingThumbnail(_ draft: IlluminatedPhotoDraft) -> some View {
        #if canImport(UIKit)
        if let url = onboardingPhotoPreviewURL,
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            IlluminatedArtifactPreview(draft: draft, sourceImage: onboardingPhotoImage)
        }
        #else
        IlluminatedArtifactPreview(draft: draft, sourceImage: nil)
        #endif
    }

    /// The finale payoff: the Bindery presses a real mini Monthly Edition —
    /// cover, star chart, foreword, Zara's letter, and the pages the player
    /// authored during onboarding — through the same PDF pipeline as the
    /// month-end bindings. Opens in QuickLook, which carries its own share.
    private var onboardingFirstBindingInvite: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 38, height: 38)
                    .background(BookPalette.nightPanel.opacity(0.92), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(BookPalette.lampGold.opacity(0.44), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text("THE BINDERY IS ALREADY WORKING")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(BookPalette.gold)
                    Text(didBindFirstEdition ? "Your first edition's bound." : "What's just happened is enough to bind a first edition.")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(
                        didKeepOnboardingPhoto
                            ? "A real PDF with a cover, your handmade Page, your illuminated photograph, the Chapter's reading, Wicker's consequence, the Book's write-back, and a letter from Zara. Keep it, share it, print it."
                            : "A real PDF with a cover, the Page you kept or dismissed, the Chapter's reading, Wicker's consequence, the Book's write-back, and a letter from Zara. Keep it, share it, print it."
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                bindFirstDoorEdition()
            } label: {
                Label(
                    isBindingFirstEdition
                        ? "The Bindery's sewing…"
                        : (didBindFirstEdition ? "Open my first edition again" : "Bind my first edition"),
                    systemImage: isBindingFirstEdition
                        ? "hourglass"
                        : (didBindFirstEdition ? "book.pages.fill" : "book.closed.fill")
                )
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(isBindingFirstEdition)

            if didBindFirstEdition {
                Button {
                    shareBoundFirstDoorEdition()
                } label: {
                    Label("Share my first edition", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.teal)
                .accessibilityHint("Opens the Apple share sheet for your bound First Door PDF")
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    BookPalette.page.opacity(0.76),
                    BookPalette.lampGold.opacity(0.10),
                    BookPalette.page.opacity(0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.32), lineWidth: 1)
        }
    }

    @MainActor
    private func bindFirstDoorEdition() {
        isOnboardingFieldFocused = false
        guard !isBindingFirstEdition else { return }
        isBindingFirstEdition = true
        didCloseFirstEditionPreview = false
        firstEditionBindingError = ""
        let sampleBookOfYouPageURL = BookOfYouShareCardRenderer.render(artifact: onboardingFirstDoorBookOfYouArtifact)
        let edition = firstDoorEdition(sampleBookOfYouPageURL: sampleBookOfYouPageURL)
        BookFeedback.play(.braidStart)
        withAnimation(.easeIn(duration: 0.3)) { isSewingFirstEdition = true }
        Task { @MainActor in
            do {
                let url = try firstDoorEditionArchiveURL()
                try MonthlyEditionPDFWriter.write(edition, to: url)
                // Let the sewing beat play through before the book opens.
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 320 : 1200))
                BookFeedback.play(.braidComplete)
                withAnimation(.easeOut(duration: 0.35)) { isSewingFirstEdition = false }
                isBindingFirstEdition = false
                didBindFirstEdition = true
                boundFirstDoorEdition = edition
                firstDoorEditionPDFPath = url.path
                castPreviewURL = url
            } catch {
                withAnimation(.easeOut(duration: 0.3)) { isSewingFirstEdition = false }
                isBindingFirstEdition = false
                firstEditionBindingError = "The Bindery couldn't finish the PDF this time. Tap Bind my first edition to let it try the stitch again."
                BookFeedback.play(.error)
            }
        }
    }

    @MainActor
    private func shareBoundFirstDoorEdition() {
        isOnboardingFieldFocused = false
        let path = firstDoorEditionPDFPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            firstEditionBindingError = "The bound edition slipped out of reach. Open it again so the Bindery can find the file."
            BookFeedback.play(.error)
            return
        }
        BookFeedback.play(.select)
        onboardingShareItem = OnboardingShareItem(url: URL(fileURLWithPath: path))
    }

    /// The first edition is a possession, not a disposable preview. Keep its
    /// reading copy in the app's durable support library and hand that same URL
    /// to QuickLook.
    private func firstDoorEditionArchiveURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        let directory = base
            .appendingPathComponent(bundle, isDirectory: true)
            .appendingPathComponent("FirstDoorEditions", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ReEnchanted-First-Door-Edition.pdf")
    }

    /// Synthesizes a real `MonthlyEdition` from the onboarding answers by
    /// authoring genuine `BookPage`s for the arrival day and running the same
    /// deterministic builder the month-end Bindery uses — theme, curator,
    /// foreword, and star chart all real, just fed by one remarkable day.
    private func firstDoorEdition(sampleBookOfYouPageURL: URL? = nil) -> MonthlyEdition {
        let calendar = Calendar.current
        let now = arrivalMoment
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)
        let readerName = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"
        let narrativeShape = selectedFirstPressNarrativeChoice?.title ?? "Something Small and True"
        let decisionDescription = rehearsalChoice == .keep
            ? "The reader kept the first offered Page."
            : "The reader let the first offered Page wait, and the Book folded its words away."

        var pages: [BookPage] = [
            BookPage(
                type: .souvenir,
                createdAt: now,
                promptText: "The Page that knew the hour",
                userInput: openingArrivalExcerpt,
                tags: ["onboarding", "arrival", "first-door"],
                sourceID: "first-door"
            ),
            BookPage(
                type: .souvenir,
                createdAt: now.addingTimeInterval(60),
                promptText: rehearsalChoice == .keep ? "The first kept Page" : "The Page allowed to wait",
                userInput: rehearsalChoice == .keep
                    ? (firstSouvenir.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? decisionDescription)
                    : decisionDescription,
                tags: ["onboarding", "first-page", rehearsalChoice == .keep ? "kept" : "waited"],
                sourceID: "first-door"
            )
        ]

        pages.append(BookPage(
            type: .souvenir,
            createdAt: now.addingTimeInterval(120),
            promptText: "What the reader told the Page",
            userInput: """
            What usually happens: \(momentFateTitle)
            Hidden magic right now: \(hiddenMagicTitle)

            \(hiddenMagicReflection)
            """,
            tags: ["onboarding", "reflection", "hidden-magic"],
            sourceID: "first-door"
        ))

        pages.append(BookPage(
            type: .souvenir,
            createdAt: now.addingTimeInterval(150),
            promptText: "The Book learns its manners",
            userInput: """
            Margin ration: \(snack.trimmingCharacters(in: .whitespacesAndNewlines))
            First belief: \(belief.trimmingCharacters(in: .whitespacesAndNewlines))
            \(investedBelief ? "The answer joined the Cast." : "The answer is resting in the margin.")
            Pages invited first: \(tasteTitle)
            Opening edge: \(comfortTitle)
            """,
            tags: ["onboarding", "reader-texture", "belief", "taste", "edge"],
            sourceID: "first-door"
        ))

        if let chapter = drawnChapter {
            pages.append(BookPage(
                type: .souvenir,
                createdAt: now.addingTimeInterval(180),
                promptText: "\(chapter.name) reads the Page",
                userInput: chapterReading(for: chapter),
                tags: ["onboarding", "chapter", chapter.id],
                sourceID: "first-door"
            ))
        }

        if let outcome = wickerOutcome,
           let mode = wickerChoices.first(where: { $0.id == outcome.choiceID }) {
            pages.append(BookPage(
                type: .souvenir,
                createdAt: now.addingTimeInterval(240),
                promptText: "Wicker reads the margin",
                userInput: "Your first instinct was \(narrativeShape). When Wicker interrupted, you answered with \(mode.title.lowercased()). \(wickerConsequence(for: mode, tier: outcome.tier))",
                tags: ["onboarding", "wicker", mode.id],
                sourceID: "first-door"
            ))
        }

        if didKeepOnboardingPhoto,
           let draft = onboardingPhotoDraft,
           let renderedURL = onboardingPhotoPreviewURL,
           FileManager.default.fileExists(atPath: renderedURL.path) {
            let photoSource = BookPageSourceRegistry.source(for: .illuminatedPhoto)
            let illuminatedAsset = BookPageMediaAsset(
                kind: .renderedImageFile,
                reference: renderedURL.path,
                caption: draft.analysis.marginalia.closingLine,
                sourceID: photoSource.id,
                metadata: [
                    "assetLocalIdentifier": draft.assetLocalIdentifier,
                    "template": draft.compositionPlan.templateId.rawValue,
                    "assetPack": draft.compositionPlan.assetPackId,
                    "firstDoorDemo": "true",
                    "monthlyEditionPresentation": "fullPage",
                    "monthlyEditionRole": "first-door-illuminated-photo"
                ]
            )
            pages.append(BookPage(
                type: .illuminatedPhoto,
                createdAt: now.addingTimeInterval(270),
                promptText: "One piece of the reader's world",
                userInput: draft.analysis.marginalia.observationList.joined(separator: "\n"),
                tags: ["illuminated-photo", "photo", "first-door", "onboarding"],
                sourceID: photoSource.id,
                origin: photoSource.origin,
                privacy: photoSource.privacy,
                promptVersion: "first-door-photo-v2",
                mediaAssets: [illuminatedAsset]
            ))
        }

        let sampleBookOfYouAssets = sampleBookOfYouPageURL.map { url in
            [
                BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: url.path,
                    caption: "A pressed sample Book of You page, braided from the threshold.",
                    sourceID: "first-door",
                    metadata: [
                        "monthlyEditionPresentation": "fullPage",
                        "monthlyEditionRole": "sample-book-of-you"
                    ]
                )
            ]
        } ?? []
        pages.append(BookPage(
            type: .bookOfYou,
            createdAt: now.addingTimeInterval(300),
            promptText: "The First Door Writes Back",
            userInput: firstDoorMiniStory,
            tags: ["onboarding", "book-of-you", "daily-braid", "first-door"],
            usedInBookOfYou: true,
            sourceID: "first-door",
            mediaAssets: sampleBookOfYouAssets
        ))

        pages.append(BookPage(
            type: .letter,
            createdAt: now.addingTimeInterval(360),
            promptText: """
            Dear \(readerName),

            You fell out of the Unwritten this \(firstPressTimeName) and taught the Book two things before anyone could give you a tour: how you want a moment read, and whether that moment deserved to stay.

            Bring the ordinary evidence. The Academy will argue about it. The Book will remember what you actually chose.

            — Zara Finch, who found you in the sentence-dust
            """,
            tags: ["onboarding", "zara", "letter"],
            // A reply-less letter has no userInput; this flag is what tells the
            // curator the Book already wove it, so it binds instead of being
            // set aside as an unanswered page.
            usedInBookOfYou: true,
            sourceID: "zara-finch"
        ))

        let day = BookDay(id: BookDay.id(for: now), date: calendar.startOfDay(for: now), pages: pages)
        let dayID = BookDay.id(for: now)

        let constellations: [Constellation] = drawnChapter.map { chapter in
            [
            Constellation(
                id: "onboarding-first-argument",
                signalID: "onboarding-first-argument",
                kind: .pattern,
                subjectID: chapter.id,
                subjectName: chapter.name,
                name: "The First Argument",
                phase: .named,
                firstNoticedAt: now,
                lastSeenAt: now,
                namedAt: now,
                wovenAt: nil,
                fadedAt: nil,
                sightingDayIDs: [dayID],
                strengthPeak: 1,
                latestLine: "\(chapter.name) was given the first word at the threshold.",
                evidencePageIDs: [],
                relatedEntityIDs: [],
                tags: ["onboarding"]
            )
            ]
        } ?? []

        var edition = MonthlyEditionBuilder.edition(
            from: [day],
            constellations: constellations,
            readerName: readerName,
            startDate: monthStart,
            endDate: now,
            generatedAt: now,
            calendar: calendar
        )
        edition.title = "Book of You: The First Door"
        edition.subtitle = "\(readerName) — bound at the threshold"
        return edition
    }

    private var firstPressTransitionProse: String {
        switch rehearsalChoice {
        case .keep:
            return """
            There. That's the whole spell: ordinary detail, pressed page, something from your life made keepable.

            Now the loose page slides back between the covers. The Book opens underneath it.
            """
        case .wait:
            return """
            Good. Even the page that waits proves the point: the story is looking for real details, not perfect ones.

            Now the sample page turns in the air. The cover opens underneath it.
            """
        case nil:
            return """
            The artifact is the promise. One real detail is enough to begin.

            Now the cover opens the wrong way.
            """
        }
    }

    private var firstPressRutArrivalProse: String {
        switch rehearsalChoice {
        case .keep:
            return """
            You keep the Page. Before the stamp dries, something starts eating its edge. One word goes grey and begins to disappear.
            """
        case .wait:
            return """
            You let the Page wait. It starts folding itself away — but something grey reaches the edge first. One word begins to disappear.
            """
        case nil:
            return """
            The Page waits for your decision. Something grey waits with it.
            """
        }
    }

    private var firstPressLoopReceipt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(BookPalette.teal)
                Text("YOUR FIRST KEPT PAGE")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1)
                    .foregroundStyle(BookPalette.teal)
                Spacer(minLength: 0)
                Text(firstPressSeasonTexture.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(BookPalette.ink.opacity(0.46))
            }

            Text(firstPressPreviewTitle)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(firstPressPreviewExcerpt)
                .font(.system(.callout, design: .serif))
                .italic()
                .foregroundStyle(BookPalette.ink.opacity(0.76))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Label("Ordinary detail -> pressed page -> kept memory.", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.lampGold)
        }
        .padding(14)
        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topTrailing) {
            MarginaliaImage(name: "MarginaliaStar", width: 54, opacity: 0.20)
                .rotationEffect(.degrees(Double(firstPressPreviewSeed % 11) - 5))
                .offset(x: 6, y: -6)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.28), lineWidth: 1)
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

            Text("There's hidden magic in this room. Find one piece before you go.")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("The Book lends the lens; the seeing's yours. Look away for thirty seconds and find one real detail: a color, a sound, a shadow, the weight of your phone, the weather through the window. Bring back one true sentence—or let the page wait. Both are correct.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                rehearsalButton(.wait, title: "Let it wait", symbol: "clock")
                rehearsalButton(.keep, title: "Keep this page", symbol: "archivebox")
            }

            if rehearsalChoice == .keep {
                firstKeptPageReceipt
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
	                Text("One photograph between the covers")
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
                    .overlay {
                        onboardingGildSweepOverlay
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: isOnboardingPhotoLoading ? "hourglass" : "photo.on.rectangle.angled")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(BookPalette.lampGold)
                    VStack(alignment: .leading, spacing: 4) {
	                        Text(isOnboardingPhotoLoading ? "The illumination's settling." : "Hand the Book one picture.")
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

    /// A single gold band that sweeps diagonally across the kept photograph as it
    /// "develops," plus a settling gilded edge. Idle (invisible) until the keep
    /// drives `photoGildSweep` from 0 to 1.
    @ViewBuilder
    private var onboardingGildSweepOverlay: some View {
        if photoGildSweep > 0 {
            GeometryReader { proxy in
                let w = proxy.size.width
                let x = w * (photoGildSweep * 1.6 - 0.3)
                let bandVisible = photoGildSweep < 1
                ZStack {
                    if bandVisible {
                        LinearGradient(
                            colors: [.clear, BookPalette.lampGold.opacity(0.75), BookPalette.page.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: 70)
                        .blur(radius: 8)
                        .rotationEffect(.degrees(18))
                        .position(x: x, y: proxy.size.height / 2)
                        .blendMode(.screen)
                    }
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.5 * min(1, photoGildSweep)), lineWidth: 1.4)
                }
            }
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .bookPhotographArrival(reduceMotion: reduceMotion)
        } else {
            IlluminatedArtifactPreview(draft: draft, sourceImage: onboardingPhotoImage)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }
                .bookPhotographArrival(reduceMotion: reduceMotion)
        }
        #else
        IlluminatedArtifactPreview(draft: draft, sourceImage: nil)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
        #endif
    }

    private func onboardingChoiceList(choices: [OnboardingChoice], selection: Binding<String>) -> some View {
        LazyVGrid(columns: onboardingChoiceColumns, alignment: .leading, spacing: 10) {
            ForEach(choices.indices, id: \.self) { index in
                let choice = choices[index]
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
                .modifier(
                    OnboardingSectionArrivalModifier(
                        kind: .section,
                        delay: 0.10 + min(Double(index) * 0.055, 0.32)
                    )
                )
            }
        }
    }

    /// Faster, more instinctive than the full preference cards: one compact
    /// answer per tap, with enough physical response to feel like the reader
    /// has pressed a fact into the Page.
    private func onboardingChipChoices(
        choices: [OnboardingChoice],
        selection: Binding<String>,
        largeText: Bool = false
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 142), spacing: 9, alignment: .leading)],
            alignment: .leading,
            spacing: 9
        ) {
            ForEach(choices.indices, id: \.self) { index in
                let choice = choices[index]
                let selected = selection.wrappedValue == choice.id
                Button {
                    isOnboardingFieldFocused = false
                    BookFeedback.play(.select)
                    withAnimation(reduceMotion ? .none : .spring(response: 0.30, dampingFraction: 0.74)) {
                        selection.wrappedValue = choice.id
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selected ? "checkmark" : choice.symbol)
                            .font((largeText ? Font.body : Font.caption).weight(.black))
                            .frame(width: 18)
                        Text(choice.title)
                            .font((largeText ? Font.body : Font.subheadline).weight(selected ? .black : .semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(selected ? BookPalette.nightText : BookPalette.ink.opacity(0.78))
                    .padding(.horizontal, 12)
                    .padding(.vertical, largeText ? 13 : 10)
                    .frame(maxWidth: .infinity, minHeight: largeText ? 50 : 44, alignment: .leading)
                    .background(
                        selected ? BookPalette.teal.opacity(0.94) : BookPalette.paper.opacity(0.72),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(
                                selected ? BookPalette.lampGold.opacity(0.62) : BookPalette.ink.opacity(0.16),
                                lineWidth: selected ? 1.4 : 1
                            )
                    }
                    .shadow(
                        color: selected ? BookPalette.teal.opacity(0.20) : .clear,
                        radius: selected ? 8 : 0,
                        y: selected ? 4 : 0
                    )
                    .scaleEffect(selected && !reduceMotion ? 1.025 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .modifier(
                    OnboardingSectionArrivalModifier(
                        kind: .section,
                        delay: 0.08 + min(Double(index) * 0.045, 0.28)
                    )
                )
            }
        }
    }

    private var onboardingChoiceColumns: [GridItem] {
        if isPadOnboardingDevice {
            return [GridItem(.adaptive(minimum: 260), spacing: 10, alignment: .top)]
        }
        return [GridItem(.flexible())]
    }

    private var onboardingWickerChoice: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
	                Image(systemName: "dice")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 28, height: 28)
                    .background(BookPalette.nightPanel.opacity(0.9), in: Circle())
	                Text("Pick your answer")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                Spacer(minLength: 0)
            }

	            Text("One answer, one roll of the dice — so pick the one you mean. You can't lose this: the scene ends either way. It only decides whether Wicker walks off with something of yours, or nothing at all.")
	                .font(.system(.callout, design: .serif))
	                .foregroundStyle(BookPalette.ink.opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(wickerChoices) { choice in
                    let selected = wickerOutcome?.choiceID == choice.id
                    let spent = wickerOutcome != nil && !selected
                    let wasFirstInstinct = selectedFirstPressNarrativeID == choice.id
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
                                    if wasFirstInstinct {
                                        Text("FIRST INSTINCT")
                                            .font(.system(size: 8, weight: .black))
                                            .tracking(0.7)
                                            .foregroundStyle(BookPalette.violet)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 3)
                                            .background(BookPalette.violet.opacity(0.1), in: Capsule())
                                    }
	                                    Text(wickerRiskLabel(for: choice))
	                                        .font(.system(size: 9, weight: .black))
	                                        .tracking(0.6)
	                                        .foregroundStyle(BookPalette.ink.opacity(0.5))
	                                        .padding(.horizontal, 5)
	                                        .padding(.vertical, 3)
	                                        .background(BookPalette.ink.opacity(0.07), in: Capsule())
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
                    .disabled(wickerOutcome != nil)
                    .opacity(spent ? 0.4 : 1)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            if let outcome = wickerOutcome,
               let choice = wickerChoice(for: outcome.choiceID) {
                WickerBonesReveal(
                    throwID: wickerThrowID,
                    roll: outcome.roll,
                    difficulty: outcome.difficulty,
                    badge: outcome.tier.badge,
                    badgeSymbol: outcome.tier.symbol,
                    accent: outcome.tier.accent,
                    consequence: wickerConsequence(for: choice, tier: outcome.tier),
                    threadKept: outcome.tier.threadKept,
                    reduceMotion: reduceMotion
                )
                .id("onboarding-wicker-inkbones")
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

    /// Wicker reads the reader's earlier answers back as ammunition, then makes
    /// them choose how to answer him. Their first narrative instinct stays
    /// visible, but confirming or betraying it is a fresh, consequential act.
    private var onboardingWickerProof: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image("LabyrinthCharacterWickerEddies")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(BookPalette.violet.opacity(0.55), lineWidth: 1.3)
                    }
                    .accessibilityLabel("Wicker, reading over the margin")

                VStack(alignment: .leading, spacing: 4) {
                    Text("EVERYTHING YOU'VE TOLD THE BOOK SO FAR")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.05)
                        .foregroundStyle(BookPalette.violet)
                    Text("“You left an awful lot lying around,” Wicker says. “Let's see how much of it survives me.”")
                        .font(.system(.callout, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                wickerMemoryRow(
                    symbol: "scope",
                    text: "Your life goes on autopilot around \(rutTitle.lowercased())."
                )
                wickerMemoryRow(
                    symbol: "sparkles",
                    text: "You're most awake \(mostAliveTitle.lowercased()), and magic, to you, is \(magicSourceTitle.lowercased())."
                )
                wickerMemoryRow(
                    symbol: drawnChapter?.symbolName ?? "flag.2.crossed",
                    text: drawnChapter.map { "You let \($0.name) speak first, and asked for \(tasteTitle.lowercased()) pages." }
                        ?? "You asked for \(tasteTitle.lowercased()) pages."
                )
                wickerMemoryRow(
                    symbol: investedBelief ? "person.crop.circle.badge.checkmark" : "pencil.and.outline",
                    text: investedBelief
                        ? "You believe “\(namedOnboardingBelief)” — and you put weight behind it."
                        : "You believe “\(namedOnboardingBelief)” — though you haven't backed it yet."
                )
            }

            onboardingWickerChoice
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.52), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.violet.opacity(0.24), lineWidth: 1)
        }
    }

    private func wickerMemoryRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.violet)
                .frame(width: 18)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The Glow-waking act break: plant the belief, burst gold ink from the
    /// sigil, let Zara's margin note land, and give the new Glow a beat to wake
    /// before the page turns.
    private func plantBeliefWithCeremony() {
        guard !isPlantingBelief else { return }
        isPlantingBelief = true
        investedBelief = true
        BookFeedback.play(.braidStart)
        beliefPlantBurst += 1
        presentMarginEcho(.zara, seed: belief)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 220 : 950))
            isPlantingBelief = false
            advance()
        }
    }

    private func resolveWicker(_ choice: WickerModeChoice) {
        // One answer, one throw. Tapping a second choice must not re-roll a
        // result the reader has already seen.
        guard wickerOutcome == nil else { return }
        isOnboardingFieldFocused = false
        let roll = wickerRoll()
        let tier = wickerTier(roll: roll, difficulty: choice.difficulty)
        wickerThrowID = UUID()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
            wickerOutcome = WickerBeliefOutcome(
                choiceID: choice.id,
                roll: roll,
                difficulty: choice.difficulty,
                tier: tier
            )
        }
        BookFeedback.play(tier.succeeded ? .braidComplete : .select)
    }

    /// Plain-language odds, because "DC 56" means nothing to a first-time reader.
    private func wickerRiskLabel(for choice: WickerModeChoice) -> String {
        switch choice.difficulty {
        case ..<50: return "SAFE BET"
        case 50..<60: return "A REACH"
        default: return "LONG SHOT"
        }
    }

    private func wickerTier(roll: Int, difficulty: Int) -> WickerOutcomeTier {
        if roll <= 5 { return .cost }
        if roll >= 96 || roll >= difficulty + 28 { return .triumph }
        if roll >= difficulty { return .hold }
        if roll >= difficulty - 12 { return .glance }
        return .cost
    }

    private func wickerRoll() -> Int {
        // The Inkbones decide this in the moment. Once revealed, the outcome
        // remains persisted for this First Door, so reopening it cannot reroll.
        Int.random(in: 1...100)
    }

    private func wickerChoice(for id: String) -> WickerModeChoice? {
        wickerChoices.first { $0.id == id }
    }

    private var didCompleteFirstDoorArrival: Bool {
        didWakeFirstInk && sleeveWord != nil && didSteadyFirstPage
    }

    private var firstPressTextBinding: Binding<String> {
        Binding(
            get: { firstPressText },
            set: { newValue in
                firstPressText = newValue
                selectedFirstPressPresetID = nil
                didCompleteFirstPress = false
                rehearsalChoice = nil
                firstSouvenir = ""
            }
        )
    }

    private func firstPressPresetButton(_ preset: FirstPressPreset) -> some View {
        let selected = selectedFirstPressPresetID == preset.id
        return Button {
            isOnboardingFieldFocused = false
            selectedFirstPressPresetID = preset.id
            firstPressText = preset.sentence
            didCompleteFirstPress = false
            rehearsalChoice = nil
            firstSouvenir = ""
            BookFeedback.play(.select)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: preset.symbol)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(selected ? BookPalette.nightText : BookPalette.lampGold)
                    .frame(width: 24, height: 24)
                    .background((selected ? BookPalette.teal : BookPalette.lampGold.opacity(0.16)), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title)
                        .font(.caption.weight(.black))
                        .foregroundStyle(BookPalette.ink.opacity(0.78))
                    Text(preset.detail)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.52))
                }
                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? BookPalette.teal.opacity(0.13) : BookPalette.paper.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((selected ? BookPalette.teal : BookPalette.lampGold).opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chooseFirstPressNarrative(_ choice: FirstPressNarrativeChoice) {
        isOnboardingFieldFocused = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedFirstPressNarrativeID = choice.id
            if rehearsalChoice == .keep {
                firstSouvenir = firstPressSouvenirLine
            }
        }
        BookFeedback.play(.select)
    }

    private func keepFirstPressPage() {
        isOnboardingFieldFocused = false
        guard !firstPressTrimmedText.isEmpty else {
            BookFeedback.play(.error)
            return
        }
        let alreadyKept = didCompleteFirstPress
        // With no typed detail yet, the Book's own arrival line is the souvenir:
        // even a player who keeps the untouched page keeps something true.
        firstSouvenir = firstPressSouvenirLine
        rehearsalChoice = .keep
        didCompleteFirstPress = true
        BookFeedback.play(.braidComplete)
        // Celebrate authorship, not navigation: fire the burst + character echo
        // only on the first keep, and let the ink land before the note (the
        // live desk's sequencing rule).
        guard !alreadyKept else { return }
        openingKeepBurst += 1
        presentMarginEcho(.pippa, seed: firstSouvenir)
    }

    private func letFirstPressPageWait() {
        isOnboardingFieldFocused = false
        guard !firstPressTrimmedText.isEmpty else {
            BookFeedback.play(.error)
            return
        }
        firstSouvenir = ""
        didCompleteFirstPress = false
        rehearsalChoice = .wait
        BookFeedback.play(.dismissPage)
    }

    private var onboardingRoutineRevealAction: some View {
        Button {
            isOnboardingFieldFocused = false
            guard !didRevealRoutineEvidence else { return }
            withAnimation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.78)) {
                didRevealRoutineEvidence = true
            }
            BookFeedback.play(.openPage)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: didRevealRoutineEvidence ? "doc.text.magnifyingglass" : "hand.tap")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(didRevealRoutineEvidence ? BookPalette.teal : BookPalette.lampGold)
                    .frame(width: 44, height: 44)
                    .background(BookPalette.paper.opacity(0.68), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(didRevealRoutineEvidence ? "The missing part leaves a number." : "Touch the bitten page.")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(BookPalette.ink.opacity(0.82))
                    Text(didRevealRoutineEvidence ? "The Book kept the receipt." : "See what the Rut takes while life's still happening.")
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
                    .stroke((didRevealRoutineEvidence ? BookPalette.teal : BookPalette.lampGold).opacity(0.30), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(didRevealRoutineEvidence ? "The missing part leaves a number" : "Touch the bitten page to reveal what the Rut takes")
    }

    private var onboardingTakeZarasHandAction: some View {
        Button {
            isOnboardingFieldFocused = false
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                didSteadyFirstPage = true
            }
            BookFeedback.play(.openPage)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: didSteadyFirstPage ? "hand.raised.fill" : "hand.wave")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(didSteadyFirstPage ? BookPalette.teal : BookPalette.lampGold)
                    .frame(width: 44, height: 44)
                    .background(BookPalette.paper.opacity(0.68), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(didSteadyFirstPage ? "Zara's got you." : "Take Zara's hand.")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(BookPalette.ink.opacity(0.82))
                    Text(didSteadyFirstPage
                         ? "The floor stays under you. The Page stays in your hand."
                         : "You came through a Page. Standing up should count as an ending.")
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
                    .stroke((didSteadyFirstPage ? BookPalette.teal : BookPalette.lampGold).opacity(0.30), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(didSteadyFirstPage ? "Zara's helped you stand" : "Take Zara's hand")
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
	                    Text(didWakeFirstInk ? "It leaves a tiny black star on your fingertip." : "The word's looking back. It shouldn't be able to do that.")
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

    /// Fires a character's margin-note echo for an authored moment. Copy is
    /// drawn from a per-speaker pool by stable seed so repeat runs feel varied
    /// without becoming a reward schedule (design rule: no variable ratio).
    private func presentMarginEcho(_ speaker: OnboardingEchoSpeaker, seed: String) {
        let pool = speaker.lines
        guard !pool.isEmpty else { return }
        let index = abs(seed.stableHash) % pool.count
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            marginEcho = OnboardingMarginEcho(
                speaker: speaker.name,
                portraitAsset: speaker.portraitAsset,
                accent: speaker.accent,
                line: pool[index]
            )
        }
    }

    private enum OnboardingEchoSpeaker {
        case pippa
        case zara
        case penny

        var name: String {
            switch self {
            case .pippa: return "Pippa Pilcrow"
            case .zara: return "Zara Finch"
            case .penny: return "Penny Blackletter"
            }
        }

        var portraitAsset: String {
            switch self {
            case .pippa: return "LabyrinthCharacterPilcrow"
            case .zara: return "LabyrinthCharacterZaraFinch"
            case .penny: return "LabyrinthCharacterPennyBlackletter"
            }
        }

        var accent: Color {
            switch self {
            case .pippa: return BookPalette.lampGold
            case .zara: return BookPalette.teal
            case .penny: return BookPalette.gold
            }
        }

        var lines: [String] {
            switch self {
            case .penny:
                return [
                    "Oh, that gilds beautifully. See how the page keeps the ordinary and adds the light? That's the whole art — reverence, not decoration.",
                    "A brass frame suits it. You didn't need a grand photo, just a true one; the illumination does the rest.",
                    "There. Now it's evidence with a halo. Photos were always little spells — you just let this one finish casting."
                ]
            case .pippa:
                return [
                    "Kept already? Before the tutorial even cleared its throat? I set punctuation loose for a living — I respect a rule-breaker.",
                    "That's a real page now, not a rehearsal. First one to the margin gets to write the note, and I was already here.",
                    "Ooh, you kept the ordinary one. Good. The ordinary ones are where the doors hide their handles.",
                    "One true thing, pressed and kept. That's the whole trick, and you found it before anyone lectured you about it."
                ]
            case .zara:
                return [
                    "You gave it weight. Most people just say a belief and hope; you planted it. The Labyrinth remembers what costs something.",
                    "There — feel that? The Glow just woke. That's the Book's attention, and it's pointed at what you care about now.",
                    "A belief with Belief behind it. That's how a stubborn little light becomes a motif the whole Book starts leaning toward."
                ]
            }
        }
    }

    private func onboardingMarginEchoCard(_ echo: OnboardingMarginEcho) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(echo.portraitAsset)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(echo.accent.opacity(0.7), lineWidth: 1.2)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(echo.speaker.split(separator: " ").first.map(String.init)?.uppercased() ?? echo.speaker.uppercased())'S MARGIN NOTE")
                        .font(.system(size: 10, weight: .black))
                        .kerning(1.0)
                        .foregroundStyle(echo.accent)
                    Spacer(minLength: 0)
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.4))
                }
                Text(echo.line)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                    .lineSpacing(2)
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
                .stroke(echo.accent.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 14, x: 0, y: 8)
        .rotationEffect(.degrees(-0.6))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            BookFeedback.play(.dismissPage)
            withAnimation(.easeOut(duration: 0.35)) { marginEcho = nil }
        }
        .task(id: echo.id) {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) { marginEcho = nil }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Margin note from \(echo.speaker). \(echo.line)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to dismiss")
    }

    /// The name moment: the Book writes the reader's chosen name once, in gold,
    /// as a nibbed signature that draws itself on — the small ceremony of being
    /// named by the story. Re-writes whenever the name text changes.
    private func onboardingNameSignature(_ name: String) -> some View {
        OnboardingNameSignatureCard(name: name, reduceMotion: reduceMotion)
    }

    private func onboardingBeliefSigil(_ belief: String) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(BookPalette.lampGold.opacity(0.18))
                        .frame(width: 58, height: 58)
                    Circle()
                        .stroke(BookPalette.lampGold.opacity(0.48), lineWidth: 1.4)
                        .frame(width: 58, height: 58)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(BookPalette.lampGold)
                        .shadow(color: BookPalette.lampGold.opacity(0.45), radius: 8)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\"\(belief)\" can become a Cast Member")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(BookPalette.ink.opacity(0.78))
                    Text("Lend your answer some Belief and it can become a living thread the Book recognizes and brings back.")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                onboardingBeliefBenefitRow("Connects moments that belong together", symbol: "link")
                onboardingBeliefBenefitRow("Can return across future Pages", symbol: "arrow.triangle.2.circlepath")
                onboardingBeliefBenefitRow("Pulls your living story toward what it means", symbol: "book.pages")
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

    private var onboardingBeliefEconomyCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("\"Belief's what you give,\" Zara says.")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)

            onboardingBeliefRule(
                "EARN IT",
                "Keep a real observation, answer a real question, or finish a Compass Run or quest.",
                symbol: "eye"
            )
            onboardingBeliefRule(
                "SEE IT",
                "The Glow at the top tells you how warmly the Book is answering. You never need to count it.",
                symbol: "sparkle"
            )
            onboardingBeliefRule(
                "SPEND IT",
                "Lend it to Cast Members, Pages, and parts of the Book you care about. The Book will tell you when it has enough.",
                symbol: "arrow.up.right.circle"
            )
        }
        .padding(13)
        .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func onboardingBeliefBenefitRow(_ line: String, symbol: String) -> some View {
        Label(line, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(BookPalette.ink.opacity(0.68))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func onboardingBeliefRule(_ title: String, _ body: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.teal)
                .frame(width: 24, height: 24)
                .background(BookPalette.teal.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(BookPalette.teal)
                Text(body)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                let firstKeep = rehearsalInkBurstTrigger == 0
                rehearsalInkBurstTrigger += 1
                if firstKeep {
                    presentMarginEcho(.pippa, seed: "rehearsal-\(firstSouvenir)")
                }
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

    /// The three wagers for this reader — stable per install so the payoff can
    /// name exactly what was guessed.
    private var onboardingWagers: [FirstWagers.Wager] {
        FirstWagers.three(seed: name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "reader")
    }

    /// The Barnum beat, made honest: the Book ventures three guesses before it
    /// has read a page, framed as wagers. Tapping one lets it stand; each
    /// confirmed guess is kept and paid off later as a receipt.
    private var onboardingWagerBeat: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 26, height: 26)
                    .background(BookPalette.nightPanel.opacity(0.88), in: Circle())
                Text("Three guesses, before I've read a page of you")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BookPalette.ink.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            Text("\"Let me wager,\" the Book says, quieter than Zara. \"I haven't read a word you've kept yet, so these are only guesses. Tap the ones that land. I'll remember the bets — and one day I'll show you where you proved me right.\"")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(onboardingWagers) { wager in
                    let confirmed = confirmedWagers.contains(wager.id)
                    Button {
                        isOnboardingFieldFocused = false
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                            if confirmed {
                                confirmedWagers.remove(wager.id)
                            } else {
                                confirmedWagers.insert(wager.id)
                            }
                        }
                        BookFeedback.play(.select)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: confirmed ? "checkmark.seal.fill" : "seal")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(confirmed ? BookPalette.lampGold : BookPalette.ink.opacity(0.4))
                                .padding(.top, 1)
                            Text(wager.guess)
                                .font(.system(.callout, design: .serif))
                                .foregroundStyle(BookPalette.ink.opacity(confirmed ? 0.9 : 0.72))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(confirmed ? BookPalette.lampGold.opacity(0.13) : BookPalette.page.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke((confirmed ? BookPalette.lampGold : BookPalette.lampGold.opacity(0.18)), lineWidth: confirmed ? 1.3 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(confirmed ? .isSelected : [])
                }
            }

            Text(confirmedWagers.isEmpty
                 ? "None yet? That's an answer too. Guessing is the Book's job, not yours."
                 : "The Book seals \(confirmedWagers.count == 1 ? "that bet" : "those bets"). It won't forget \(confirmedWagers.count == 1 ? "it" : "them").")
                .font(.footnote.weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.25), value: confirmedWagers)
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.2), lineWidth: 1)
        }
        .padding(.top, 10)
    }

    private var onboardingChapterAffinityPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
	                Image(systemName: "sparkles")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 26, height: 26)
                    .background(BookPalette.nightPanel.opacity(0.88), in: Circle())
	                Text("Five answers. One gets the first turn.")
	                    .font(.subheadline.weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.74))
                Spacer(minLength: 0)
            }

	            Text("Tap a banner. You're testing an argument, not choosing an identity.")
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
	                                    Text(selected ? "FIRST WORD" : "HEAR IT")
	                                        .font(.system(size: 12, weight: .black))
	                                        .foregroundStyle(selected ? BookPalette.nightText : BookPalette.teal)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background((selected ? BookPalette.teal : BookPalette.teal.opacity(0.12)), in: Capsule())
                                        .lineLimit(1)
                                }

                                Text(chapterArgument(for: chapter))
                                    .font(.system(.callout, design: .serif))
                                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                                    .fixedSize(horizontal: false, vertical: true)

                                if selected {
                                    Text(chapterReading(for: chapter))
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
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

            if let chapter = drawnChapter {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(BookPalette.teal)
                        .frame(width: 32, height: 32)
                        .background(BookPalette.paper.opacity(0.72), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(chapter.talismanName) warms.")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(BookPalette.ink.opacity(0.84))
                        Text("It's a first tug, not your Binding. The Book tests this argument first. What you keep answers more honestly later.")
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(BookPalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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

    private func chapterArgument(for chapter: AcademyChapter) -> String {
        switch chapter.id {
        case "emberheart":
            return "Life's a story you write yourself."
        case "mossbloom":
            return "Life's written by something larger. Your work's to listen."
        case "tidecrest":
            return "Life isn't a story at all. Each surprising moment's complete in itself."
        case "riddlewind":
            return "Life's a story we write together."
        case "duskthorn":
            return "There's no story without conflict. Honest friction keeps a life from going blank."
        default:
            return chapter.philosophy
        }
    }

    private func chapterReading(for chapter: AcademyChapter) -> String {
        let subject = firstDoorChapterSubject
        let reading: String
        switch chapter.id {
        case "emberheart":
            reading = "Emberheart reads \(subject) as authorship: you decided this moment deserved a shape."
        case "mossbloom":
            reading = "Mossbloom reads \(subject) as an invitation that was already waiting for you to notice it."
        case "tidecrest":
            reading = "Tidecrest refuses to turn \(subject) into a lesson. The moment's complete because it happened."
        case "riddlewind":
            reading = "Riddlewind reads \(subject) as co-written: you noticed, but the world supplied the line."
        case "duskthorn":
            reading = "Duskthorn looks for the friction inside \(subject): the small fight against letting a real moment disappear."
        default:
            reading = "\(chapter.name) bends your Page through this argument: \(chapter.philosophy)"
        }
        return "\(reading) \(chapterReflectionCoda)"
    }

    private var chapterReflectionCoda: String {
        let fateLine: String
        switch momentFate {
        case "keep":
            fateLine = "You already keep small moments; this argument asks what they should become when they return."
        case "forget":
            fateLine = "You said moments often escape after you notice them; this argument gives one a handle."
        case "blur":
            fateLine = "You said the blur often arrives first; this argument's one way of interrupting it."
        default:
            fateLine = "The Page keeps one line blank rather than guessing what usually happens."
        }

        let magicLine: String
        switch hiddenMagicStance {
        case "yes":
            magicLine = "It agrees the magic was already there."
        case "maybe":
            magicLine = "It treats “maybe” as an open door, not a promise."
        case "prove":
            magicLine = "It accepts your condition: the claim has to survive evidence."
        default:
            magicLine = "Belief remains optional."
        }
        return "\(fateLine) \(magicLine)"
    }

    private func chapterSurprise(for chapter: AcademyChapter) -> String {
        switch chapter.id {
        case "emberheart":
            return "\"Surprising thing,\" Zara says. \"The brave Chapter's mostly afraid of wasting its life.\""
        case "mossbloom":
            return "\"Surprising thing,\" Zara says. \"The quiet Chapter notices trouble first.\""
        case "tidecrest":
            return "\"Surprising thing,\" Zara says. \"The playful Chapter's serious about not making everything useful.\""
        case "riddlewind":
            return "\"Surprising thing,\" Zara says. \"The friendly Chapter wins more arguments than the clever one.\""
        case "duskthorn":
            return "\"Surprising thing,\" Zara says. \"The thorny Chapter's often the kindest, because it names the real wound.\""
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
        defer { onboardingPhotoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            BookFeedback.play(.error)
            onboardingPhotoMessage = "That photo wouldn't open. You can bind without one and still continue."
            return
        }
        await loadOnboardingPhoto(imageData: data)
    }
    #endif

    @MainActor
    private func loadOnboardingPhoto(imageData data: Data) async {
        isOnboardingPhotoLoading = true
        onboardingPhotoMessage = "The Book's gilding the edges. Won't be a moment."
        defer { isOnboardingPhotoLoading = false }

        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            BookFeedback.play(.error)
            onboardingPhotoMessage = "That photo wouldn't open. You can bind without one and still continue."
            return
        }
        let profileSignature = [
            name,
            rutStrongest,
            mostAlive,
            magicSource,
            drawnChapterID,
            "\(Int(image.size.width))x\(Int(image.size.height))",
            "\(data.count)",
            "\(Date().timeIntervalSinceReferenceDate)"
        ]
        .joined(separator: "|")
        let compositionSeed = profileSignature.stableHash.stableScramble
        let analysis = onboardingPhotoDemoAnalysis(
            for: image,
            seed: compositionSeed
        )
        let draft = IlluminatedPageComposer.compose(
            analysis: analysis,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: compositionSeed,
            assetLocalIdentifier: "onboarding-local:\(UUID().uuidString)"
        )
        let renderedURL = IlluminatedPageRenderer.renderPreview(draft: draft, sourceImage: image)
        onboardingPhotoImage = image
        onboardingPhotoDraft = draft
        onboardingPhotoPreviewURL = renderedURL
        didKeepOnboardingPhoto = false
        photoGildSweep = 0
        onboardingPhotoMessage = renderedURL == nil
            ? "That one didn't come out. Try another photo, or carry on without one."
            : "There it is. Made on your phone, kept on your phone."
        if renderedURL != nil {
            BookFeedback.play(.braidComplete)
            isOnboardingPhotoPreviewPresented = true
        } else {
            BookFeedback.play(.error)
        }
        #else
        BookFeedback.play(.error)
        onboardingPhotoMessage = "Photo illumination needs image support on this device."
        #endif
    }

    #if canImport(UIKit)
    private func onboardingPhotoDemoAnalysis(for image: UIImage, seed: Int) -> PhotoAnalysis {
        let size = image.size
        let orientation = size.width > size.height ? "landscape" : (size.height > size.width ? "portrait" : "square")

        func choose(_ options: [String], salt: Int) -> String {
            guard !options.isEmpty else { return "" }
            let scrambled = UInt(bitPattern: (seed &+ salt &* 7_919).stableScramble)
            return options[Int(scrambled % UInt(options.count))]
        }

        let fieldNote = choose([
            "The ordinary arrived carrying its own light.",
            "A private moment volunteered for illumination.",
            "The day left this where you'd notice.",
            "Real light, caught behaving strangely.",
            "Evidence that this day actually happened.",
            "The Book found gold in the ordinary."
        ], salt: 11)
        let stampLabel = choose([
            "LIFE, NOTICED",
            "PRIVATE WONDER",
            "DAYLIGHT EVIDENCE",
            "FOUND ALIVE",
            "ORDINARY MAGIC",
            "FIELD PROOF",
            "MOMENT KEPT",
            "YOUR WORLD"
        ], salt: 23)
        let openingObservation = choose([
            "Real light entered the record",
            "The ordinary held still",
            "One moment refused the blur",
            "The day supplied its evidence",
            "Attention changed the frame",
            "A true thing caught light"
        ], salt: 37)
        let materialObservation = choose([
            "\(orientation.capitalized) light, kept by hand",
            "Private light stayed in the room",
            "Nothing outside read this moment",
            "The frame came from your day",
            "Real color supplied its own spell",
            "The photograph kept its secrets"
        ], salt: 41)
        let closingLine = choose([
            "The Book kept the page: your world answered.",
            "The Book kept the page: attention made it larger.",
            "The Book kept the page: the ordinary held.",
            "The Book kept the page: this day left proof.",
            "The Book kept the page: real light stayed.",
            "The Book kept the page: you were here."
        ], salt: 53)
        let template = onboardingPhotoTemplate(seed: seed)
        let motifs = [
            orientation,
            onboardingPhotoAliveMotif,
            onboardingPhotoMagicMotif,
            onboardingPhotoRutMotif,
            "photo",
        ]

        return PhotoAnalysisValidator.validate(PhotoAnalysis(
            scene: "A private \(orientation) photo chosen at the First Door.",
            motifs: motifs,
            mood: choose(["fresh evidence", "private wonder", "lived light", "ordinary magic"], salt: 67),
            suggestedTemplate: template,
            marginalia: PhotoMarginalia(
                fieldNote: fieldNote,
                stampLabel: stampLabel,
                observationList: [
                    openingObservation,
                    onboardingPhotoAliveObservation,
                    onboardingPhotoMagicObservation,
                    onboardingPhotoRutObservation,
                    materialObservation
                ],
                closingLine: closingLine
            ),
            souvenirCandidates: [
                choose([
                    "A real photograph became evidence that this day was lived.",
                    "One ordinary moment accepted gold without pretending to be grand.",
                    "The reader's own world became the First Edition's brightest proof.",
                    "Attention found a page where routine would've left a blur."
                ], salt: 79),
                choose([
                    "The image stayed private while the Book changed its edges.",
                    "No model interpreted the moment; the reader gave it meaning.",
                    "A photograph from real life entered the living story.",
                    "The day supplied the light. The Book only made room."
                ], salt: 83)
            ]
        ))
    }

    private func onboardingPhotoTemplate(seed: Int) -> IlluminatedTemplateID {
        switch (mostAlive, magicSource) {
        case ("people", _), (_, "love"), (_, "laughter"):
            return .goodCompany
        case ("outside", _), (_, "weather"), (_, "places"):
            return .harborFieldNote
        case ("solitude", _), (_, "imagination"):
            return .restAndQuiet
        case ("making", _), (_, "details"):
            return .homeVessel
        default:
            let choices: [IlluminatedTemplateID] = [.academyFieldStudy, .homeVessel, .restAndQuiet]
            let index = Int(UInt(bitPattern: seed.stableScramble) % UInt(choices.count))
            return choices[index]
        }
    }

    private var onboardingPhotoAliveMotif: String {
        switch mostAlive {
        case "making": return "making"
        case "outside": return "outside"
        case "people": return "company"
        case "movement": return "movement"
        case "learning": return "curiosity"
        case "solitude": return "quiet"
        case "helping": return "care"
        case "story": return "story"
        default: return "alive"
        }
    }

    private var onboardingPhotoMagicMotif: String {
        switch magicSource {
        case "music": return "music"
        case "weather": return "weather"
        case "places": return "place"
        case "coincidence": return "strange"
        case "details": return "detail"
        case "laughter": return "laughter"
        case "imagination": return "imagination"
        case "love": return "love"
        default: return "wonder"
        }
    }

    private var onboardingPhotoRutMotif: String {
        switch rutStrongest {
        case "work": return "work"
        case "phone": return "screen"
        case "chores": return "home"
        case "exhaustion": return "rest"
        case "sameness": return "change"
        case "later": return "today"
        default: return "ordinary"
        }
    }

    private var onboardingPhotoAliveObservation: String {
        switch mostAlive {
        case "making": return "Made by a person who makes"
        case "outside": return "Outside is one live wire"
        case "people": return "Company makes the day brighter"
        case "movement": return "Movement wakes the edges"
        case "learning": return "Curiosity was already awake"
        case "solitude": return "Quiet made room around it"
        case "helping": return "Care left fingerprints here"
        case "story": return "A story found another doorway"
        default: return "One live wire, still unnamed"
        }
    }

    private var onboardingPhotoMagicObservation: String {
        switch magicSource {
        case "music": return "Music was named as a door"
        case "weather": return "Weather was named as a door"
        case "places": return "Charged places were named first"
        case "coincidence": return "Coincidence still owes an explanation"
        case "details": return "Tiny details were invited first"
        case "laughter": return "Laughter was named as proof"
        case "imagination": return "Imagination left the door open"
        case "love": return "Love was named as evidence"
        default: return "Wonder remains an open question"
        }
    }

    private var onboardingPhotoRutObservation: String {
        switch rutStrongest {
        case "work": return "Work didn't swallow this"
        case "phone": return "The screen missed this edge"
        case "chores": return "Repetition failed to erase it"
        case "exhaustion": return "Small enough to notice tired"
        case "sameness": return "Today differed right here"
        case "later": return "Life happened before later"
        default: return "Routine failed to hide everything"
        }
    }
    #endif

    @MainActor
    private func keepOnboardingIlluminatedPhoto() {
        guard let draft = onboardingPhotoDraft else { return }
        let firstKeep = !didKeepOnboardingPhoto
        onKeepIlluminatedPhoto(draft, onboardingPhotoPreviewURL)
        didKeepOnboardingPhoto = true
        onboardingPhotoMessage = "Kept. The illuminated photograph is inside your First Edition and Today's Margins."
        BookFeedback.play(.keepPage)
        guard firstKeep else { return }
        // A single gold gild-sweep across the photograph as it "develops," then
        // Penny's margin note as the echo.
        photoGildSweep = 0
        if reduceMotion {
            photoGildSweep = 1
        } else {
            withAnimation(.easeInOut(duration: 0.9)) { photoGildSweep = 1 }
        }
        presentMarginEcho(.penny, seed: "photo-\(draft.id)")
    }

    @MainActor
    private func saveOnboardingIlluminatedPhotoToPhotos() async {
        guard let artifactURL = onboardingPhotoPreviewURL else {
            BookFeedback.play(.error)
            onboardingPhotoMessage = "The illuminated photograph isn't ready to save yet."
            return
        }
        isSavingOnboardingPhoto = true
        defer { isSavingOnboardingPhoto = false }

        #if canImport(Photos)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: artifactURL)
            }
            onboardingPhotoMessage = "Saved. The illuminated photograph is tucked into Photos."
            BookFeedback.play(.keepPage)
        } catch {
            onboardingPhotoMessage = "Photos wouldn't take the illuminated photograph yet. Check photo permissions, then try again."
            BookFeedback.play(.error)
        }
        #else
        onboardingPhotoMessage = "This build can't save to Photos, but the illuminated photograph is ready to share."
        #endif
    }

    private var firstKeptPageReceipt: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(BookPalette.teal)
                .frame(width: 30, height: 30)
                .background(BookPalette.paper.opacity(0.74), in: Circle())
                .overlay {
                    Circle()
                        .stroke(BookPalette.teal.opacity(0.36), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("There. Not a task. Evidence you were here.")
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                Text("The Book isn't grading the sentence. It's keeping a handle for the day.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(BookPalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .transition(.opacity.combined(with: .move(edge: .top)))
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

	            Text("\"This little helper's a work in progress,\" Zara says. \"Use it if the blank page goes stiff. Don't write like a professional writer. Write like someone leaving a pin in the day. It only has to be specific enough that, when you read it again, the moment comes back.\" Tap one to start, then change it until it sounds like your actual room.")
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
                    .accessibilityHint("Fills the first sentence field if it's empty")
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
            ? "Somewhere deep in the Register, ink moves. The thing you believe in has joined your Cast. It can return in Pages and help shape what finds you.\n\n"
            : "Zara nods. \"Wise. Some things you keep.\"\n\n"
        return """
        \(planted)"One last correction," Zara says, walking you toward a desk where a book lies open to a blank page — your page. "You didn't open an app. You entered the Book. You're standing in its story now, and your life outside is one of its Chapters. Both are real. The binding's simply strange."

        "Pages rise to meet your real day. Keep the ones worth keeping. Let the others wait without guilt."

        "Later, when you've got energy or interest, the three wax seals are shortcuts: body, sky, and ground. Tap them when you want the Book to listen in that direction."

        "Lend Belief to whatever you want the Book to hold closer. The Glow will tell you when something has brightened; you never need to mind the arithmetic."

        "At night, read your Book of You. It'll braid what you kept into a fuller page. Those pages become patterns, friendships, rivalries, and eventually the evidence the Chapters use when they Bind you."

        A grey bite appears at the edge of the blank paper. Zara puts your first true sentence over it, and the damage stops.

        She taps the cover once. "That's the work. Re-enchant the Unwritten before Routine convinces you it was ordinary. Off you go."
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

    private var whisperCueReflection: String {
        switch whisperCadence {
        case "morning":
            return "A morning whisper can catch the day before it starts moving too fast."
        case "evening":
            return "An evening return can catch one true thing before the day folds itself away."
        case "both":
            return "A morning invitation and an evening return give the loop two gentle handles. You can change either later."
        default:
            return "No outside whisper. Opening the covers is the cue, and the Book waits without pestering you."
        }
    }

    private var dayThirtyHingeMoment: String {
        switch whisperCadence {
        case "morning":
            return "morning"
        case "evening":
            return "evening"
        case "both":
            return "day"
        default:
            return "moment when you open the covers"
        }
    }

    private var dayThirtyRutClause: String {
        switch rutStrongest {
        case "work":
            return "work swallows the day"
        case "phone":
            return "your phone eats the edges"
        case "chores":
            return "the chores blur together"
        case "exhaustion":
            return "you're tired before you begin"
        case "sameness":
            return "today looks exactly like yesterday"
        case "later":
            return "everything important keeps getting postponed"
        default:
            return "the day starts disappearing"
        }
    }

    private var dayThirtyMagicPhrase: String {
        switch magicSource {
        case "music":
            return "the music landing exactly right"
        case "weather":
            return "wild weather changing the room"
        case "places":
            return "a place carrying a strange little charge"
        case "coincidence":
            return "a coincidence with suspiciously good timing"
        case "details":
            return "one tiny, beautiful detail"
        case "laughter":
            return "the second before somebody laughs"
        case "imagination":
            return "your imagination opening a side door"
        case "love":
            return "some small, specific evidence of love"
        default:
            return "something you can't quite explain yet"
        }
    }

    private var drawnChapter: AcademyChapter? {
        AcademyChapterRegistry.chapter(id: drawnChapterID)
    }

    private var momentFateTitle: String {
        momentFateChoices.first { $0.id == momentFate }?.title ?? "You didn't answer for the day."
    }

    private var hiddenMagicTitle: String {
        hiddenMagicChoices.first { $0.id == hiddenMagicStance }?.title ?? "You didn't pretend to know."
    }

    private var rutTitle: String {
        rutChoices.first { $0.id == rutStrongest }?.title ?? "an unnamed part of the day"
    }

    private var mostAliveTitle: String {
        aliveChoices.first { $0.id == mostAlive }?.title ?? "a place the Book hasn't learned yet"
    }

    private var magicSourceTitle: String {
        magicSourceChoices.first { $0.id == magicSource }?.title ?? "a kind of magic still waiting to be noticed"
    }

    private var namedOnboardingBelief: String {
        belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "the thing you believe in"
    }

    private var rutReflection: String {
        switch rutStrongest {
        case "work":
            return "“Then I won't ask work to become magical,” the Book writes. “I'll look for the moments it failed to swallow.”"
        case "phone":
            return "“Then we'll look at the life around the screen—not with guilt. Just before the edges disappear.”"
        case "chores":
            return "“Then ordinary repetition is where we'll hunt for differences. No two Tuesdays are actually the same.”"
        case "exhaustion":
            return "“Then I won't demand more effort. We'll look for wonder small enough to notice while tired.”"
        case "sameness":
            return "“Then I'll pay attention to the tiny changes sameness hides.”"
        case "later":
            return "“Then we'll keep proof that your life is already happening—not only after everything else is done.”"
        default:
            return "The Book leaves the seam unmarked rather than guessing."
        }
    }

    private var aliveReflection: String {
        "“\(mostAliveTitle),” the Book repeats. “Good. That's a live wire. I'll learn what it looks like in your actual days—and notice when it goes missing.”"
    }

    private var magicSourceReflection: String {
        if magicSource == "unsure" {
            return "“Good answer,” the Book writes. “We won't manufacture certainty. I'll show you small evidence and let you decide what earns the word.”"
        }
        return "“\(magicSourceTitle),” the Book writes. “That's one door. I'll begin there, then keep enough room to surprise you.”"
    }

    private var momentFateReflection: String {
        switch momentFate {
        case "keep":
            return "“Then I should do more than store it,” the Page writes. “I should let it return changed, when it can mean more.”"
        case "forget":
            return "“Then I can give it a place before the rest of the day carries it off.”"
        case "blur":
            return "“Then my first job isn't to give you more content. It's to interrupt the blur with one small thing worth noticing.”"
        default:
            return "The Page leaves a blank line. It'd rather wait than put words in your mouth."
        }
    }

    private var hiddenMagicReflection: String {
        switch hiddenMagicStance {
        case "yes":
            return "“Then I won't invent magic,” the Book writes. “I'll help you catch what's already there.”"
        case "maybe":
            return "“Then we'll look together, and keep only what earns it.”"
        case "prove":
            return "“Good,” the Book writes. “I'd rather prove it than ask you to pretend.”"
        default:
            return "The Book waits. Belief isn't an admission fee."
        }
    }

    private var firstDoorChapterSubject: String {
        if rehearsalChoice == .keep,
           let detail = firstPressPreviewDetail(from: firstPressTrimmedText).nonEmpty {
            return "“\(detail)”"
        }
        return "the choice to let the first offered Page wait"
    }

    private var firstDoorFallThroughProse: String {
        let decisionLine = rehearsalChoice == .keep
            ? "The kept Page grows a paper handle beneath your thumb."
            : "The folded Page returns anyway, not as evidence, but as a door."
        return """
        \(decisionLine) You pull. It pulls back.

        Cold ink slips over your knuckles. The room tips. Your stomach stays behind.

        Stories strike in flashes: salt on your lips, dragonfire under your feet, peppermint snow in your hair. Train brakes. Wolves. Applause. There isn't any down. Only chapters.

        Words wheel around you. LOST crosses itself out and becomes ARRIVING.

        Then stone catches your knees beneath a library sky. The Page is still in your hand. A girl with quick grey eyes reaches down.
        """
    }

    private var bookChosenChapterID: String {
        let chapters = AcademyChapterRegistry.publicChapters
        guard !chapters.isEmpty else { return "emberheart" }
        let seed = [
            firstPressTrimmedText,
            name.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedFirstPressNarrativeID,
            rehearsalChoiceStorage
        ].joined(separator: "|")
        return chapters[abs(seed.stableHash) % chapters.count].id
    }

    private var wickerModeTitle: String {
        wickerOutcome.flatMap { wickerChoice(for: $0.choiceID)?.title } ?? "an unanswered story"
    }

    /// Every shape and roll band leaves a personalized thread in the larger
    /// story. A low roll gives Wicker leverage; it never erases the player's act.
    private func wickerConsequence(
        for choice: WickerModeChoice,
        tier: WickerOutcomeTier
    ) -> String {
        let carriedThread: String
        switch choice.id {
        case "slice-of-life":
            switch tier {
            case .triumph:
                carriedThread = "He has to admit \(rutTitle.lowercased()) can't erase a detail that exact. The Book keeps it as evidence."
            case .hold:
                carriedThread = "The Book marks \(rutTitle.lowercased()) as the place your next undeniable detail can prove him wrong again."
            case .glance:
                carriedThread = "Wicker dares you to bring back one detail from \(rutTitle.lowercased()) that even he can't call ordinary."
            case .cost:
                carriedThread = "He writes a debt in the margin: catch one thing \(rutTitle.lowercased()) would've made you miss, then take your thread back."
            }
        case "arc":
            switch tier {
            case .triumph:
                carriedThread = "The new door labels itself \(mostAliveTitle.uppercased()). Wicker has to follow your direction or admit he's afraid of it."
            case .hold:
                carriedThread = "The Book points your next page toward \(mostAliveTitle.lowercased()), with \(magicSourceTitle.lowercased()) waiting at the hinge."
            case .glance:
                carriedThread = "He pins you to the promise: find one real sign of \(magicSourceTitle.lowercased()) where you feel \(mostAliveTitle.lowercased())."
            case .cost:
                carriedThread = "Wicker writes himself into the route. Your open question now leads through \(mostAliveTitle.lowercased())—and he intends to heckle every step."
            }
        default:
            let surpriseSubject = investedBelief
                ? "“\(namedOnboardingBelief),” now in your Cast"
                : magicSourceTitle.lowercased()
            switch tier {
            case .triumph:
                carriedThread = "\(surpriseSubject) flicks one gold speck into Wicker's cuff. The Book records his face for future use."
            case .hold:
                carriedThread = "The Book gives \(surpriseSubject) permission to interrupt a future Page when Wicker thinks he's won."
            case .glance:
                carriedThread = "The awkward spark smells faintly of \(surpriseSubject). Wicker calls that a coincidence, much too quickly."
            case .cost:
                carriedThread = "He names the misfire after \(surpriseSubject). Unfortunately for him, named things in this Book have a habit of coming back."
            }
        }
        return "\(choice.line(for: tier))\n\n\(carriedThread)"
    }

    private var wickerBraidLine: String {
        guard let outcome = wickerOutcome,
              let choice = wickerChoice(for: outcome.choiceID) else {
            return "Wicker stepped into the archway, but the Book left that page unchosen."
        }
        return "When Wicker challenged the Page, you answered with \(choice.title.lowercased()). \(wickerConsequence(for: choice, tier: outcome.tier))"
    }

    private var firstDoorWickerIntroduction: String {
        let chapterLine = drawnChapter.map {
            "“And you've already picked a side. \($0.name).” He says it like a diagnosis."
        } ?? "“You haven't even picked a side yet.”"
        let namedBelief = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "an unnamed belief"
        let beliefLine = investedBelief
            ? "He finds “\(namedBelief)” glowing in your margin. “You've already put weight behind it. Before it's done a day's work.”"
            : "He finds “\(namedBelief)” pencilled faintly in your margin. “Nothing behind it. A slogan in a nice coat.”"
        let edgeLine: String
        switch comfortBoundary {
        case "gentle":
            edgeLine = "The Page shifts a little, making room. You did ask it to be kind."
        case "strange":
            edgeLine = "The Page leans in, delighted. You did give it permission to be strange."
        default:
            edgeLine = "The Page holds steady, waiting to see what you do."
        }
        let magicChallenge: String
        switch hiddenMagicStance {
        case "yes":
            magicChallenge = "“Magic everywhere, is it? Handy, that. Means you never have to point at any.”"
        case "maybe":
            magicChallenge = "“Maybe,” he reads off your page. “That's doubt in a nicer hat.”"
        case "prove":
            magicChallenge = "“Not yet, show me,” he reads off your page, and looks almost pleased. “Terms. Finally.”"
        default:
            magicChallenge = "“You've left the important line blank. Bold.”"
        }
        return """
        A boy in a green-black coat steps out from behind a shelf at the worst possible moment. He is holding your page, and he has clearly read all of it.

        “So you're the impossible reader.” He looks you up and down. “I expected taller.” \(magicChallenge)

        Zara's jaw goes tight. “That's Wicker. He collects the beginnings of other people's stories. Don't hand him one for free.”

        \(beliefLine) \(chapterLine)

        \(edgeLine)

        He's waiting. Say something back.
        """
    }

    private var firstDoorMiniStory: String {
        let reader = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"
        let narrative = selectedFirstPressNarrativeChoice?.title ?? "Something Small and True"
        let ration = snack.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "a still-secret reading snack"
        let namedBelief = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "one small true thing"
        let decisionLine: String
        if rehearsalChoice == .keep {
            decisionLine = "You pressed \(firstDoorChapterSubject) into me and said Keep. I stamped it before the moment could wander off."
        } else {
            decisionLine = "You gave me a true sentence, then let it wait. I folded the words away. Accuracy includes knowing what not to keep."
        }
        let chapterLine = drawnChapter.map { chapter in
            "\(chapter.name) argued that your Page meant this: \(chapterReading(for: chapter))"
        } ?? "The five Chapters argued in the margin and failed, briefly, to behave like banners."

        let ending = rehearsalChoice == .keep
            ? "Tonight, if you keep more, I can return the day with its threads showing."
            : "The Page you let wait stays folded. The next Page gets a clean chance."

        return """
        \(reader), I noticed you arrive at \(arrivalClockTime).

        You told me, “\(momentFateTitle).” When I asked about hidden magic, you answered, “\(hiddenMagicTitle).” I wrote both in the margin because doubt, hope, and habit all leave different fingerprints.

        You showed me where the Rut gets in: \(rutTitle.lowercased()). You feel most alive \(mostAliveTitle.lowercased()). The first kind of magic you asked me to recognize was \(magicSourceTitle.lowercased()). Those aren't labels. They're places to begin paying attention.

        Zara asked for one tiny human fact and you gave her \(ration). The margin kept it. Then you named “\(namedBelief).” \(investedBelief ? "You lent those words Belief, so they joined the Cast and can pull future Pages toward what they mean." : "You kept the answer without lending it Belief, so it hasn't joined the Cast yet.")

        You asked the shelves to lead with \(tasteTitle.lowercased()), and told me to begin \(comfortTitle.lowercased()). That didn't make a profile. It gave the living Book manners.

        \(decisionLine) You asked me to hold it as \(narrative.lowercased()), and I carried that choice through the door.

        \(chapterLine)

        \(wickerBraidLine)

        I didn't collect a profile. I followed one real thing until it became a Page, an argument, a consequence, and now this.

        \(ending)

        Zara reads over the margin. “There. A beginning with your fingerprints on it.”
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
        .modifier(OnboardingSectionArrivalModifier(kind: .section, delay: 0.12))
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
            .modifier(OnboardingSectionArrivalModifier(kind: .title, delay: 0.02))
    }

    private func onboardingProse(_ text: String) -> some View {
        InkSettlingProse(text: text) {
            isOnboardingFieldFocused = false
        }
    }

    /// Onboarding prose that settles in like wet ink: each paragraph ghosts up
    /// and un-blurs in turn, noticeable but still quick enough not to delay
    /// reading. Falls back to an instant render when Reduce Motion is on.
    /// Re-runs whenever a new beat presents it.
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
                        .opacity(settled ? 1 : 0.03)
                        .blur(radius: settled ? 0 : 7)
                        .offset(y: settled ? 0 : 8)
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeOut(duration: 0.52).delay(min(Double(index) * 0.085, 0.58)),
                            value: settled
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onAppear { settled = true }
        }
    }

    /// Scroll handling for beats that reveal content only after the reader has
    /// typed or toggled something. Extracted from the scroll view's own modifier
    /// chain purely so the type-checker can cope — the chain had grown past what
    /// it would solve in reasonable time.
    private struct OnboardingLateRevealScrolling: ViewModifier {
        let step: Int
        let snack: String
        let name: String
        let investedBelief: Bool
        let whisperCadence: String
        let didRevealDayThirtyAfter: Bool
        let didRevealHabitScience: Bool
        let reveal: (String, Double) -> Void

        func body(content: Content) -> some View {
            content
                .onChange(of: snack) { _, answer in
                    guard step == 5, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    // Typed answers reveal their card a keystroke at a time; wait
                    // for the reader to stop before moving the page under them.
                    reveal("onboarding-page-top", 0.45)
                }
                .onChange(of: name) { _, answer in
                    guard step == 6, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    reveal("onboarding-name-signature", 0.45)
                }
                .onChange(of: investedBelief) { _, invested in
                    guard invested else { return }
                    reveal("onboarding-belief-sigil", 0.08)
                }
                .onChange(of: whisperCadence) { _, cadence in
                    guard !cadence.isEmpty else { return }
                    reveal("onboarding-whisper-hinge", 0.08)
                }
                .onChange(of: didRevealDayThirtyAfter) { _, revealed in
                    guard revealed else { return }
                    reveal("onboarding-day-thirty-after", 0.08)
                }
                .onChange(of: didRevealHabitScience) { _, revealed in
                    guard revealed else { return }
                    reveal("onboarding-habit-science", 0.08)
                }
        }
    }

    private struct OnboardingGhostInModifier: ViewModifier {
        var delay: Double = 0

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var visible = false

        func body(content: Content) -> some View {
            content
                .opacity(visible ? 1 : 0.08)
                .blur(radius: reduceMotion ? 0 : (visible ? 0 : 5))
                .offset(y: reduceMotion ? 0 : (visible ? 0 : 7))
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.12)
                        : .easeOut(duration: 0.38).delay(delay),
                    value: visible
                )
                .onAppear {
                    visible = true
                }
        }
    }

    /// The page's section choreography. Titles enter from the binding, ordinary
    /// sections slide and settle, controls rise last, and earned artifacts land
    /// with a slightly less well-behaved tilt. Every style becomes instant and
    /// stationary under Reduce Motion.
    private struct OnboardingSectionArrivalModifier: ViewModifier {
        enum Kind {
            case title
            case section
            case control
            case artifact
        }

        let kind: Kind
        var delay: Double = 0

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var visible = false

        private var hiddenOffset: CGSize {
            switch kind {
            case .title: return CGSize(width: -24, height: 7)
            case .section: return CGSize(width: 20, height: 11)
            case .control: return CGSize(width: 0, height: 16)
            case .artifact: return CGSize(width: 8, height: 24)
            }
        }

        private var hiddenRotation: Double {
            switch kind {
            case .title: return -1.1
            case .section: return 0.55
            case .control: return 0
            case .artifact: return 1.25
            }
        }

        private var hiddenScale: CGFloat {
            switch kind {
            case .title: return 0.97
            case .section: return 0.985
            case .control: return 0.97
            case .artifact: return 0.945
            }
        }

        private var arrivalAnimation: Animation {
            switch kind {
            case .title:
                return .spring(response: 0.62, dampingFraction: 0.78)
            case .section:
                return .spring(response: 0.68, dampingFraction: 0.83)
            case .control:
                return .spring(response: 0.56, dampingFraction: 0.82)
            case .artifact:
                return .spring(response: 0.78, dampingFraction: 0.73)
            }
        }

        func body(content: Content) -> some View {
            content
                .opacity(reduceMotion || visible ? 1 : 0.025)
                .blur(radius: reduceMotion || visible ? 0 : 7)
                .offset(
                    x: reduceMotion || visible ? 0 : hiddenOffset.width,
                    y: reduceMotion || visible ? 0 : hiddenOffset.height
                )
                .rotationEffect(
                    .degrees(reduceMotion || visible ? 0 : hiddenRotation),
                    anchor: .leading
                )
                .scaleEffect(
                    reduceMotion || visible ? 1 : hiddenScale,
                    anchor: .leading
                )
                .animation(
                    reduceMotion ? nil : arrivalAnimation.delay(delay),
                    value: visible
                )
                .onAppear {
                    visible = true
                }
        }
    }

	    private func onboardingField(_ placeholder: String, text: Binding<String>) -> some View {
	        TextField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .foregroundStyle(BookPalette.ink.opacity(0.52)),
                axis: .vertical
            )
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
            .modifier(OnboardingSectionArrivalModifier(kind: .control, delay: 0.18))
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
        .modifier(OnboardingSectionArrivalModifier(kind: .control, delay: 0.26))
    }

    private func openingMiniContinueButton(
        _ title: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Button(action: action) {
                Label(title, systemImage: "arrow.right")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(disabled)

            if openingMiniStep > 0 {
                Button {
                    retreatOpeningMiniStep()
                } label: {
                    Label("Back", systemImage: "arrow.left")
                        .font(.body.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(BookPalette.paper.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .modifier(OnboardingSectionArrivalModifier(kind: .control, delay: 0.26))
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
        .modifier(OnboardingSectionArrivalModifier(kind: .control, delay: 0.22))
    }

    private func onboardingSystemStrip(_ items: [(String, String)]) -> some View {
        HStack(spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
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
                .modifier(
                    OnboardingSectionArrivalModifier(
                        kind: .section,
                        delay: 0.04 + Double(index) * 0.07
                    )
                )
            }
        }
    }

	    private func onboardingPreviewCard(
            symbol: String,
            title: String,
            body: String,
            largeText: Bool = false
        ) -> some View {
	        HStack(alignment: .top, spacing: 12) {
	            Image(systemName: symbol)
	                .font(.system(size: 19, weight: .semibold))
	                .foregroundStyle(BookPalette.teal)
	                .frame(width: 34, height: 34)
	                .background(BookPalette.teal.opacity(0.12), in: Circle())

	            VStack(alignment: .leading, spacing: 6) {
	                Text(title)
	                    .font((largeText ? Font.headline : Font.subheadline).weight(.black))
	                    .foregroundStyle(BookPalette.ink.opacity(0.78))
	                Text(body)
	                    .font(.system(largeText ? .body : .callout, design: .serif))
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
        .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.10))
    }

	    private var onboardingNotYourFaultCard: some View {
		        VStack(alignment: .leading, spacing: 12) {
		            HStack(alignment: .center, spacing: 10) {
		                Text("WAIT. WHAT?")
		                    .font(.system(size: 11, weight: .black))
	                    .tracking(1.1)
	                    .foregroundStyle(BookPalette.nightText)
	                    .padding(.horizontal, 10)
	                    .padding(.vertical, 7)
	                    .background(BookPalette.teal.opacity(0.96), in: Capsule())
	                    .overlay {
	                        Capsule()
	                            .stroke(BookPalette.lampGold.opacity(0.45), lineWidth: 1)
	                    }

	                Spacer(minLength: 0)

	                Image(systemName: "text.book.closed")
	                    .font(.caption.weight(.bold))
	                    .foregroundStyle(BookPalette.ink.opacity(0.42))
	                    .accessibilityHidden(true)
		            }

		            VStack(alignment: .leading, spacing: 0) {
		                Text("YOU'RE MISSING")
		                    .font(.system(.title3, design: .serif).weight(.bold))
		                    .foregroundStyle(BookPalette.ink)
		                Text("46.9%")
		                    .font(.system(size: 50, weight: .black, design: .rounded))
		                    .foregroundStyle(BookPalette.gold)
		                    .minimumScaleFactor(0.8)
		                Text("OF YOUR DAYS TO AUTOPILOT")
		                    .font(.system(.title3, design: .serif).weight(.bold))
		                    .foregroundStyle(BookPalette.ink)
		            }

                Text("Did you know this?")
                    .font(.system(.title2, design: .serif).weight(.black))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

	            Text("In a 2010 experience-sampling study, people said their minds were somewhere else in 46.9% of the moments researchers checked.")
		                .font(.system(.callout, design: .serif))
	                .foregroundStyle(BookPalette.ink.opacity(0.72))
	                .lineSpacing(2)
	                .fixedSize(horizontal: false, vertical: true)

		            Text("They were awake. They were living. But their attention—the part that meets the room, the face, the weather, and the Tuesday in front of them—was somewhere else.")
		                .font(.system(.title3, design: .serif).weight(.bold))
		                .foregroundStyle(BookPalette.ink)
		                .lineSpacing(2)
	                .fixedSize(horizontal: false, vertical: true)

                Text("Where are you in your life right now? How many years have already gone? How many do you have left?")
                    .font(.system(.callout, design: .serif).weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("10")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(BookPalette.ink)
                        Text("YEARS PASS")
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(BookPalette.ink.opacity(0.52))
                    }

                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.black))
                        .foregroundStyle(BookPalette.gold)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("~5")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(BookPalette.teal)
                        Text("YEARS ON AUTOPILOT")
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(BookPalette.ink.opacity(0.52))
                    }
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("The study measured mind wandering. If 46.9 percent held across ten waking years, nearly five years of your life happened while you weren't there to meet it.")

                Text("The study's number stops at 46.9%. I'm doing the next bit of arithmetic. Carry that rate across ten waking years and nearly five years of your life happened while you weren't there to meet it.")
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("You were alive. But you weren't there for your own life.")
                    .font(.system(.title3, design: .serif).weight(.black))
                    .foregroundStyle(BookPalette.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("How much of it ever had a fair chance to become a memory? That's how five years vanish while you're standing inside them.")
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

		            VStack(alignment: .leading, spacing: 4) {
		                Text("Can we afford to miss any more?")
		                    .font(.system(.title3, design: .serif).weight(.black))
		                    .foregroundStyle(BookPalette.ink)
		                Text("I don't think we can. When you're on your deathbed, I want you to look back and say, ‘Holy shit. That really was magical.’ Not, ‘Where did it go?’")
		                    .font(.system(.callout, design: .serif).weight(.semibold))
	                    .foregroundStyle(BookPalette.teal.opacity(0.94))
	                    .lineSpacing(2)
	                    .fixedSize(horizontal: false, vertical: true)

                        Text("\"That's the Rut of Routine: not losing your life all at once. Losing it while it's happening. You gave me one true sentence. I'll help you keep it before it disappears.\"")
                            .font(.system(.callout, design: .serif).weight(.semibold))
                            .foregroundStyle(BookPalette.teal.opacity(0.94))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
	            }

	            Label("Killingsworth & Gilbert, Science (2010)", systemImage: "text.book.closed")
	                .font(.footnote.weight(.bold))
	                .foregroundStyle(BookPalette.ink.opacity(0.52))
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
	                Text(onboardingResumeProgressLine)
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
        favoritePerson = ""
        name = ""
        belief = ""
        investedBelief = false
        rehearsalChoice = nil
        firstSouvenir = ""
        firstPressText = ""
        selectedFirstPressPresetID = nil
        selectedFirstPressNarrativeID = ""
        didCompleteFirstPress = false
        momentFate = ""
        hiddenMagicStance = ""
        rutStrongest = ""
        mostAlive = ""
        magicSource = ""
        whisperCadence = ""
        openingMiniStep = 0
        conclusionMiniStep = 0
        sleeveWord = nil
        drawnChapterID = ""
        didWakeFirstInk = false
        didRevealRoutineEvidence = false
        didSteadyFirstPage = false
        unwrittenWordDrag = .zero
        didTuckUnwrittenWord = false
        wickerOutcome = nil
        didReadFirstDoorWriteback = false
        onboardingPhotoItem = nil
        onboardingPhotoImage = nil
        onboardingPhotoDraft = nil
        onboardingPhotoPreviewURL = nil
        onboardingPhotoMessage = "Pick a photo, or take one. It never leaves your phone."
        isOnboardingPhotoLoading = false
        isOnboardingCameraPresented = false
        isOnboardingPhotoPreviewPresented = false
        didKeepOnboardingPhoto = false
        isSavingOnboardingPhoto = false
        photoGildSweep = 0
        didBindFirstEdition = false
        boundFirstDoorEdition = nil
        firstDoorEditionPDFPath = ""
        didCloseFirstEditionPreview = false
        didRevealDayThirtyAfter = false
        didRevealHabitScience = false
        firstEditionBindingError = ""
        arrivalTimestamp = Date().timeIntervalSince1970
    }

    private func advance() {
        if step >= stepCount - 1 {
            let result = onboardingResult(useDefaults: false)
            step = 0
            openingMiniStep = 0
            resetOnboardingInputs()
            onFinished(result)
            return
        }
        withAnimation(reduceMotion ? .none : .spring(response: 0.46, dampingFraction: 0.86)) {
            step += 1
        }
    }

    private func finishWithDefaults() {
        isOnboardingFieldFocused = false
        BookFeedback.play(.openPage)
        let result = onboardingResult(useDefaults: true)
        step = 0
        openingMiniStep = 0
        resetOnboardingInputs()
        onFinished(result)
    }

    private func advanceOpeningMiniStep() {
        isOnboardingFieldFocused = false
        guard openingMiniStep < 5 else { return }
        BookFeedback.play(.openPage)
        withAnimation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.84)) {
            openingMiniStep += 1
        }
    }

    private func retreatOpeningMiniStep() {
        isOnboardingFieldFocused = false
        guard openingMiniStep > 0 else { return }
        BookFeedback.play(.select)
        withAnimation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.84)) {
            openingMiniStep -= 1
        }
    }

    private func onboardingResult(useDefaults: Bool) -> Result {
        let trimmedSnack = snack.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFavoritePerson = favoritePerson.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBelief = belief.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSouvenir = firstSouvenir.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSleeveWord = (sleeveWord ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChapter = drawnChapterID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTaste = tastePreference.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComfort = comfortBoundary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWhisper = whisperCadence.trimmingCharacters(in: .whitespacesAndNewlines)

        return Result(
            skipped: useDefaults,
            momentFate: momentFate,
            hiddenMagicStance: hiddenMagicStance,
            rutStrongest: rutStrongest,
            mostAlive: mostAlive,
            magicSource: magicSource,
            snack: trimmedSnack,
            favoritePerson: trimmedFavoritePerson,
            name: trimmedName,
            belief: trimmedBelief,
            investedBelief: investedBelief,
            firstSouvenir: trimmedSouvenir,
            sleeveWord: trimmedSleeveWord,
            drawnChapterID: trimmedChapter,
            wickerMode: wickerOutcome?.choiceID ?? "",
            wickerRoll: wickerOutcome?.roll ?? 0,
            wickerTier: wickerOutcome?.tier.rawValue ?? "",
            wickerThread: wickerOutcome.flatMap { outcome in
                wickerChoice(for: outcome.choiceID).map {
                    wickerConsequence(for: $0, tier: outcome.tier)
                }
            } ?? "",
            wickerRollSucceeded: wickerOutcome?.succeeded ?? false,
            tastePreference: trimmedTaste,
            comfortBoundary: trimmedComfort,
            whisperCadence: trimmedWhisper,
            confirmedWagers: useDefaults
                ? []
                : onboardingWagers.map(\.id).filter(confirmedWagers.contains),
            firstDoorEdition: useDefaults ? nil : boundFirstDoorEdition,
            firstDoorEditionPDFPath: useDefaults ? "" : firstDoorEditionPDFPath
        )
    }
}

/// The reader sees the finished local illumination at full size before it
/// becomes edition material. Confirming sends the image visibly toward a
/// miniature First Edition; only after that motion completes does the parent
/// keep the photo and make it eligible for the PDF.
private struct OnboardingIlluminatedPhotoBindingPreview: View {
    let draft: IlluminatedPhotoDraft
    let renderedURL: URL?
    #if canImport(UIKit)
    let sourceImage: UIImage?
    #else
    let sourceImage: Never?
    #endif
    let onPutInBook: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isEnteringBook = false
    @State private var didEnterBook = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BookBackground()
                    .overlay {
                        LinearGradient(
                            colors: [
                                BookPalette.nightPanel.opacity(0.72),
                                BookPalette.violet.opacity(0.22),
                                BookPalette.nightPanel.opacity(0.90)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("YOUR WORLD, ILLUMINATED")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.35)
                            .foregroundStyle(BookPalette.lampGold)
                        Text(isEnteringBook ? "The Book makes room." : "Look before it becomes a page.")
                            .font(.system(.title2, design: .serif).weight(.black))
                            .foregroundStyle(BookPalette.nightText)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(isEnteringBook ? 0.48 : 1)

                    illuminatedPhoto
                        .frame(maxWidth: min(proxy.size.width - 32, 560))
                        .frame(maxHeight: max(260, proxy.size.height * 0.57))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.58), lineWidth: 1.4)
                        }
                        .shadow(color: BookPalette.lampGold.opacity(0.20), radius: 18, y: 8)
                        .scaleEffect(isEnteringBook ? 0.19 : 1)
                        .offset(y: isEnteringBook ? max(150, proxy.size.height * 0.30) : 0)
                        .rotationEffect(.degrees(isEnteringBook && !reduceMotion ? -4 : 0))
                        .opacity(didEnterBook ? 0 : 1)
                        .zIndex(3)

                    Spacer(minLength: 0)

                    firstEditionTarget
                        .scaleEffect(isEnteringBook ? 1.08 : 1)
                        .opacity(isEnteringBook ? 1 : 0.72)

                    if !isEnteringBook {
                        VStack(spacing: 10) {
                            if let renderedURL {
                                ShareLink(item: renderedURL) {
                                    Label("Share this illumination", systemImage: "square.and.arrow.up")
                                        .font(.headline.weight(.black))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)
                                .tint(BookPalette.lampGold)
                                .accessibilityHint("Opens the Apple share sheet before this photograph enters the First Edition.")
                            }

                            Button {
                                putPhotoInBook()
                            } label: {
                                Label("Put this in my First Edition", systemImage: "book.closed.fill")
                                    .font(.headline.weight(.black))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BookPalette.teal)

                            Button {
                                BookFeedback.play(.dismissPage)
                                dismiss()
                            } label: {
                                Text("Choose a different photograph")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(BookPalette.nightText.opacity(0.72))
                        }
                    } else {
                        Label(
                            didEnterBook ? "Inside the First Edition" : "Becoming part of the Book…",
                            systemImage: didEnterBook ? "checkmark.seal.fill" : "sparkles"
                        )
                        .font(.headline.weight(.black))
                        .foregroundStyle(didEnterBook ? BookPalette.teal : BookPalette.lampGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, max(20, proxy.safeAreaInsets.top + 8))
                .padding(.bottom, max(14, proxy.safeAreaInsets.bottom + 8))
            }
        }
        .interactiveDismissDisabled(isEnteringBook)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var illuminatedPhoto: some View {
        #if canImport(UIKit)
        if let renderedURL,
           let image = UIImage(contentsOfFile: renderedURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .background(BookPalette.paper.opacity(0.94))
        } else {
            IlluminatedArtifactPreview(draft: draft, sourceImage: sourceImage)
                .background(BookPalette.paper.opacity(0.94))
        }
        #else
        IlluminatedArtifactPreview(draft: draft, sourceImage: nil)
            .background(BookPalette.paper.opacity(0.94))
        #endif
    }

    private var firstEditionTarget: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                BookPalette.violet.opacity(0.96),
                                BookPalette.nightPanel
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 76)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(0.62), lineWidth: 1.2)
                    }

                VStack(spacing: 4) {
                    Image(systemName: didEnterBook ? "checkmark.seal.fill" : "sparkles")
                        .font(.headline.weight(.black))
                    Text("I")
                        .font(.system(size: 11, weight: .black, design: .serif))
                }
                .foregroundStyle(didEnterBook ? BookPalette.teal : BookPalette.lampGold)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("THE FIRST EDITION")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(BookPalette.lampGold)
                Text(didEnterBook ? "Your photograph is inside." : "Waiting for one piece of your world.")
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.nightText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private func putPhotoInBook() {
        guard !isEnteringBook else { return }
        BookFeedback.play(.braidStart)
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(response: 0.82, dampingFraction: 0.80)
        ) {
            isEnteringBook = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 820))
            BookFeedback.play(.braidComplete)
            withAnimation(.easeOut(duration: reduceMotion ? 0.10 : 0.22)) {
                didEnterBook = true
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 420))
            onPutInBook()
        }
    }
}

/// The finale act break: a brief "sewing" beat over the whole onboarding while
/// the first mini-edition binds, so the bound book feels made, not merely
/// produced. Gold stitches walk down a spine and the signatures cinch shut,
/// then the QuickLook opens on the finished PDF.
private struct BinderySewingOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stitched: Double = 0
    @State private var pulse = false

    private let stitchCount = 6

    var body: some View {
        ZStack {
            BookBackground()
                .overlay { Rectangle().fill(BookPalette.nightPanel.opacity(0.72)) }
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    // The two signatures cinching together as the thread pulls.
                    HStack(spacing: reduceMotion ? 6 : (10 - 8 * stitched)) {
                        signaturePage(trailing: false)
                        signaturePage(trailing: true)
                    }

                    // Gold stitches walking down the spine.
                    VStack(spacing: 10) {
                        ForEach(0..<stitchCount, id: \.self) { index in
                            let threshold = Double(index) / Double(stitchCount)
                            Capsule()
                                .fill(BookPalette.lampGold)
                                .frame(width: 22, height: 3)
                                .shadow(color: BookPalette.lampGold.opacity(0.6), radius: 4)
                                .opacity(stitched > threshold ? 1 : 0.12)
                                .scaleEffect(x: stitched > threshold ? 1 : 0.3, anchor: .center)
                        }
                    }

                    // The needle riding the seam.
                    Image(systemName: "needle")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(BookPalette.page)
                        .rotationEffect(.degrees(30))
                        .shadow(color: BookPalette.lampGold.opacity(0.5), radius: 6)
                        .offset(y: reduceMotion ? 0 : (-70 + 140 * stitched))
                        .opacity(reduceMotion ? 0 : (stitched < 1 ? 1 : 0))
                }
                .frame(height: 170)

                VStack(spacing: 6) {
                    Text("THE BINDERY")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1.6)
                        .foregroundStyle(BookPalette.lampGold.opacity(0.86))
                    Text("Sewing your first edition…")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(BookPalette.nightText)
                }
                .opacity(pulse ? 1 : 0.7)
            }
            .padding(40)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The Bindery is sewing your first edition.")
        .onAppear {
            guard !reduceMotion else { stitched = 1; return }
            withAnimation(.easeInOut(duration: 1.1)) { stitched = 1 }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func signaturePage(trailing: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [BookPalette.page, BookPalette.paper],
                    startPoint: trailing ? .topTrailing : .topLeading,
                    endPoint: trailing ? .bottomLeading : .bottomTrailing
                )
            )
            .frame(width: 84, height: 150)
            .overlay {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(0..<5, id: \.self) { _ in
                        Capsule()
                            .fill(BookPalette.ink.opacity(0.16))
                            .frame(height: 3)
                    }
                }
                .padding(14)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(BookPalette.parchmentEdge.opacity(0.4), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 10, x: trailing ? 4 : -4, y: 8)
    }
}

/// The Wicker belief-throw reveal used in onboarding. Reuses the same tumbling
/// `InkbonesPiece` bones as the live story pages, then settles the roll number
/// and the imaginative, tier-specific consequence in as the echo — the one
/// sanctioned variable-outcome dopamine beat of onboarding.
private struct WickerBonesReveal: View {
    let throwID: UUID
    let roll: Int
    let difficulty: Int
    let badge: String
    let badgeSymbol: String
    let accent: Color
    let consequence: String
    let threadKept: String
    let reduceMotion: Bool

    @State private var thrown = false
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "die.face.5.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("The Book rolls")
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(BookPalette.lampGold)
                    Text(revealed ? badge : "Rolling…")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(BookPalette.nightText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if revealed {
                    HStack(spacing: 4) {
                        Image(systemName: badgeSymbol)
                            .font(.caption.weight(.black))
                            .foregroundStyle(accent)
                        Text("\(roll)")
                            .font(.system(.title2, design: .serif).weight(.black))
                            .foregroundStyle(BookPalette.page)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                }
            }

            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    InkbonesPiece(index: index, thrown: thrown, reduceMotion: reduceMotion)
                }
            }
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            if revealed {
                VStack(alignment: .leading, spacing: 8) {
                    Text(consequence)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.nightText.opacity(0.86))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        Image(systemName: "scissors")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(accent)
                        Text(threadKept)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.7))
                        Spacer(minLength: 0)
                        Text("Rolled \(roll), needed \(difficulty)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(BookPalette.nightText.opacity(0.5))
                            .monospacedDigit()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [BookPalette.nightPanel.opacity(0.98), accent.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: BookPalette.ink.opacity(0.34), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge). Rolled \(roll), needed \(difficulty). \(consequence)")
        .task(id: throwID) {
            thrown = false
            revealed = false
            if reduceMotion {
                thrown = true
                revealed = true
                return
            }
            withAnimation(.spring(response: 0.82, dampingFraction: 0.66)) {
                thrown = true
            }
            try? await Task.sleep(for: .milliseconds(1120))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.36)) {
                revealed = true
            }
        }
    }
}

/// The name-signature card: draws the reader's chosen name on in gold as if a
/// nib were signing it, then holds. Debounced so it re-signs when they settle
/// on a name rather than flickering on every keystroke.
private struct OnboardingNameSignatureCard: View {
    let name: String
    let reduceMotion: Bool

    @State private var writeProgress: Double = 0
    @State private var signTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "signature")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
                Text("THE BOOK WRITES YOU IN")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(BookPalette.lampGold.opacity(0.86))
                Spacer(minLength: 0)
            }

            WrittenGoldText(
                name,
                font: .system(size: 34, weight: .semibold, design: .serif),
                progress: reduceMotion ? 1 : writeProgress
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Rectangle()
                .fill(BookPalette.lampGold.opacity(0.42))
                .frame(height: 1)
                .scaleEffect(x: reduceMotion ? 1 : writeProgress, anchor: .leading)

            Text("Zara says it once, carefully, and the Book darkens the letters so future pages can find you.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.page.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
        .onAppear { scheduleSign() }
        .onChange(of: name) { _, _ in scheduleSign() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The Book writes your name: \(name)")
    }

    private func scheduleSign() {
        guard !reduceMotion else { writeProgress = 1; return }
        signTask?.cancel()
        writeProgress = 0
        signTask = Task { @MainActor in
            // Wait for typing to settle before signing, so the nib draws the
            // finished name once instead of chasing each keystroke.
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.85)) {
                writeProgress = 1
            }
        }
    }
}

/// A small one-shot sparkle that pops and settles when a delight card first
/// appears (e.g. the snack "margin ration") — the lightest celebration in the
/// grammar, for a low-stakes authored input. Plays once on appear; fades to
/// nothing on Reduce Motion.
private struct OnboardingSparkleSettle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bloom = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<7, id: \.self) { index in
                    let angle = Double(index) / 7 * 2 * .pi
                    let reach: CGFloat = bloom ? 30 : 4
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                        .font(.system(size: index.isMultiple(of: 2) ? 11 : 6, weight: .black))
                        .foregroundStyle(BookPalette.lampGold)
                        .shadow(color: BookPalette.lampGold.opacity(0.6), radius: 4)
                        .position(
                            x: proxy.size.width * 0.5 + CGFloat(cos(angle)) * reach,
                            y: proxy.size.height * 0.5 + CGFloat(sin(angle)) * reach
                        )
                        .scaleEffect(bloom ? 1 : 0.2)
                        .opacity(bloom ? 0 : 1)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.75)) { bloom = true }
        }
    }
}

#if canImport(UIKit)
/// System share sheet for onboarding's rendered card, reveal video, and bound
/// PDF, so every earned artifact uses ordinary Apple sharing.
private struct OnboardingActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to dismiss this greeting")
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
