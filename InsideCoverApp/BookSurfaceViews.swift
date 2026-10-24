import SwiftUI
import OSLog
import Darwin.Mach
import NaturalLanguage
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
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
    enum RenderLayer { case all, paper, pigment, clock }
    var renderLayer: RenderLayer = .all
    let draft: IlluminatedPhotoDraft
    var sourceImage: UIImage? = nil
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private static let fileDecorationImages: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 16 * 1_024 * 1_024
        return cache
    }()

    private var plan: IlluminatedCompositionPlan {
        draft.compositionPlan
    }

    private var hasUnifiedLayout: Bool { (plan.layoutVersion ?? 0) >= 2 }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / plan.canvasSize.width,
                proxy.size.height / plan.canvasSize.height
            )
            let xOffset = (proxy.size.width - plan.canvasSize.width * scale) / 2
            let yOffset = (proxy.size.height - plan.canvasSize.height * scale) / 2

            ZStack {
                if renderLayer == .all || renderLayer == .paper {
                    Image(plan.backgroundAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: plan.canvasSize.width * scale, height: plan.canvasSize.height * scale)
                        .clipped()
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    textureOverlays(scale: scale, proxySize: proxy.size)
                }

                if renderLayer != .paper {
                    illuminatedPhoto(scale: scale, xOffset: xOffset, yOffset: yOffset)

                    ForEach(plan.decorations) { decoration in
                        illuminatedDecoration(decoration, scale: scale, xOffset: xOffset, yOffset: yOffset)
                    }
                }

                ForEach(plan.textSlots) { slot in
                    illuminatedTextSlot(slot, scale: scale, xOffset: xOffset, yOffset: yOffset)
                }

                if renderLayer == .all || renderLayer == .paper {
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
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(renderLayer == .clock ? Color.black : (renderLayer == .all ? BookPalette.nightPanel : Color.clear))
        }
    }

    private func illuminatedPhoto(scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> some View {
        let frame = plan.photoFrame
        let variation = OrganicPlacementVariation(seed: plan.randomSeed, key: "photo-frame",
            maxOffset: hasUnifiedLayout ? 0 : 6, maxRotation: hasUnifiedLayout ? 0 : 3)
        return Group {
            if renderLayer == .clock {
                illuminationClock(0)
            } else {
                photoImage
            }
        }
            .saturation(renderLayer == .clock ? 1 : saturation(for: plan.photoTreatment))
            .contrast(renderLayer == .clock ? 1 : contrast(for: plan.photoTreatment))
            .brightness(renderLayer == .clock ? 0 : brightness(for: plan.photoTreatment))
            .frame(width: frame.size.width * scale, height: frame.size.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: frame.cornerRadius * scale, style: .continuous))
            .overlay {
                if renderLayer != .clock {
                    RoundedRectangle(cornerRadius: frame.cornerRadius * scale, style: .continuous)
                        .stroke(BookPalette.paper.opacity(0.82), lineWidth: max(2, 8 * scale))
                }
            }
            .shadow(color: renderLayer == .clock ? .clear : .black.opacity(0.28), radius: 18 * scale, x: 0, y: 10 * scale)
            .bookInkEmergence(seed: "photo-\(plan.randomSeed)")
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

    @ViewBuilder
    private func illuminatedTextSlot(_ slot: IlluminatedTextSlot, scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> some View {
        if hasUnifiedLayout {
            unifiedAnnotation(slot, scale: scale, xOffset: xOffset, yOffset: yOffset)
        } else {
            legacyIlluminatedTextSlot(slot, scale: scale, xOffset: xOffset, yOffset: yOffset)
        }
    }

    private func unifiedAnnotation(_ slot: IlluminatedTextSlot, scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> some View {
        let isPaper = slot.annotationStyle == .tornPaper
        let isStamp = slot.annotationStyle == .stamp
        let padding: CGFloat = isPaper ? 22 : 8
        return ZStack(alignment: .topLeading) {
            if renderLayer == .all || renderLayer == .paper {
                if isPaper {
                    IlluminatedTornNote(seed: plan.randomSeed)
                        .fill(BookPalette.paper.opacity(0.91))
                        .overlay {
                            Image(slot.paperAssetName)
                                .resizable()
                                .scaledToFill()
                                .opacity(0.18)
                                .blendMode(.multiply)
                                .clipShape(IlluminatedTornNote(seed: plan.randomSeed))
                        }
                        .shadow(color: .black.opacity(0.10), radius: 3 * scale, x: 0, y: 2 * scale)
                }
            }
            if renderLayer == .clock {
                illuminationClock(1 + 2 * (plan.textSlots.firstIndex { $0.id == slot.id } ?? 0))
            } else if renderLayer != .paper {
                VStack(alignment: .leading, spacing: 9 * scale) {
                    if let title = slot.title, !title.isEmpty {
                        Text(title.uppercased())
                            .font(.system(size: 25 * scale, weight: .semibold, design: .serif))
                            .tracking(2 * scale)
                            .foregroundStyle(BookPalette.ink.opacity(0.82))
                    }
                    Text(slot.body)
                        .font(annotationFont(for: slot.fontStyle, scale: scale))
                        .foregroundStyle(BookPalette.ink.opacity(isStamp ? 0.84 : 0.96))
                        .tracking(isStamp ? 2.5 * scale : 0)
                        .lineSpacing(5 * scale)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    if isStamp {
                        Rectangle()
                            .fill(BookPalette.ink.opacity(0.68))
                            .frame(height: max(0.5, scale))
                    }
                }
                .padding(padding * scale)
                .bookInkEmergence(seed: "note-\(slot.slotId)")
            }
        }
        .frame(width: slot.size.width * scale, height: slot.size.height * scale)
        .rotationEffect(.degrees(slot.rotationDegrees))
        .position(x: xOffset + (slot.position.x + slot.size.width / 2) * scale,
                  y: yOffset + (slot.position.y + slot.size.height / 2) * scale)
    }

    private func annotationFont(for style: IlluminatedFontStyle, scale: CGFloat) -> Font {
        switch style {
        case .handwritten:
            if UIFont(name: "BradleyHandITCTT-Bold", size: 34) != nil {
                return .custom("BradleyHandITCTT-Bold", fixedSize: 36 * scale)
            }
            return .system(size: 34 * scale, design: .serif).italic()
        case .stamp:
            return .system(size: 27 * scale, weight: .semibold, design: .serif)
        case .serifTitle:
            return .system(size: 36 * scale, weight: .semibold, design: .serif)
        case .serifBody:
            return .system(size: 32 * scale, design: .serif)
        }
    }

    private func legacyIlluminatedTextSlot(_ slot: IlluminatedTextSlot, scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> some View {
        let variation = OrganicPlacementVariation(seed: plan.randomSeed, key: "text-\(slot.slotId)", maxOffset: 5, maxRotation: 2.2)
        let safeFrame = marginaliaSafeTextFrame(for: slot, variation: variation)
        return ZStack(alignment: .topLeading) {
            if renderLayer == .all || renderLayer == .paper {
                illuminatedPaperScrap(slot, scale: scale)
            }
            if renderLayer == .clock {
                illuminationClock(1 + 2 * (plan.textSlots.firstIndex { $0.id == slot.id } ?? 0))
            } else if renderLayer != .paper {
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
                .bookInkEmergence(seed: "note-\(slot.slotId)")
            }
        }
        .frame(width: slot.size.width * scale, height: slot.size.height * scale)
        .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
        .shadow(color: renderLayer == .clock ? .clear : .black.opacity(0.18), radius: 10 * scale, x: 0, y: 6 * scale)
        .rotationEffect(.degrees(slot.rotationDegrees + variation.rotationDegrees))
        .position(
            x: xOffset + safeFrame.midX * scale,
            y: yOffset + safeFrame.midY * scale
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
        let variation = OrganicPlacementVariation(
            seed: plan.randomSeed,
            key: "decoration-\(decoration.assetName)-\(decoration.position.x)-\(decoration.position.y)",
            maxOffset: 7,
            maxRotation: 3,
            maxScaleVariation: 0.18
        )
        let adaptiveFrame = adaptiveDecorationFrame(for: decoration, variation: variation)
        let isUnderText = !hasUnifiedLayout && decorationIsUnderText(adaptiveFrame)
        let opacity = hasUnifiedLayout ? decoration.opacity : isUnderText
            ? (decoration.kind == .stamp
                ? max(0.12, min(0.62, decoration.opacity + variation.opacityLift * 0.16 - 0.08))
                : max(0.16, min(0.86, decoration.opacity + variation.opacityLift * 0.10 - 0.04)))
            : 1
        Group {
            if renderLayer == .clock {
                illuminationClock(2 + 2 * (plan.decorations.firstIndex { $0.id == decoration.id } ?? 0))
            } else if decoration.kind == .stamp,
               let stamp = distressedStampImage(assetName: decoration.assetName, variation: variation) {
                Image(uiImage: stamp)
                    .resizable()
                    .scaledToFit()
            } else if decoration.assetName.hasPrefix("/"),
                      let image = snapshotDecorationImage(assetName: decoration.assetName) {
                // ImageRenderer does not run a view's asynchronous .task.
                // Resolve downloaded cabinet marks before taking its snapshot.
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                BookMarginaliaImage(assetName: decoration.assetName)
                    .scaledToFit()
            }
        }
        .opacity(renderLayer == .clock ? 1 : opacity)
        .blendMode(!hasUnifiedLayout && renderLayer != .clock && decoration.kind == .stamp ? .multiply : .normal)
        .frame(width: adaptiveFrame.width * scale, height: adaptiveFrame.height * scale)
        .bookInkEmergence(seed: "decoration-\(decoration.assetName)")
        .rotationEffect(.degrees(decoration.rotationDegrees + (hasUnifiedLayout ? 0 : variation.rotationDegrees)))
        .position(
            x: xOffset + adaptiveFrame.midX * scale,
            y: yOffset + adaptiveFrame.midY * scale
        )
    }

    private func illuminationClock(_ index: Int) -> Color {
        // Photo, first margin and first ornament occupy different start bands.
        Color(uiColor: BookInkTiming.clockColor("illumination-\(plan.randomSeed)", index: index))
    }

    private func adaptiveDecorationFrame(
        for decoration: DecorationPlacement,
        variation: OrganicPlacementVariation
    ) -> CGRect {
        if hasUnifiedLayout {
            return CGRect(x: decoration.position.x, y: decoration.position.y,
                          width: decoration.size.width, height: decoration.size.height)
        }
        let asset = IlluminationPackRegistry.pack(for: plan.assetPackId)?
            .allAssets
            .first(where: { $0.assetName == decoration.assetName })
        let proposedWidth = max(1, decoration.size.width)
        let proposedHeight = max(1, decoration.size.height)
        let proposedRatio = proposedWidth / proposedHeight
        let aspectRatio = min(5, max(0.2, asset?.leafTraits?.aspectRatio ?? proposedRatio))
        let visualWeight = min(1.7, max(0.55, asset?.leafTraits?.visualWeight ?? 1))
        let targetArea = proposedWidth * proposedHeight * visualWeight * variation.sizeScale * variation.sizeScale
        var height = sqrt(targetArea / aspectRatio)
        var width = height * aspectRatio

        // A slot is an invitation, not a rigid stamp size. Let the asset's own
        // proportions and visual weight determine its footprint, then fit the
        // result back into the physical illuminated page.
        let canvasInset = 28.0
        let availableWidth = max(1, plan.canvasSize.width - canvasInset * 2)
        let availableHeight = max(1, plan.canvasSize.height - canvasInset * 2)
        let fitScale = min(1, min(availableWidth / width, availableHeight / height))
        width *= fitScale
        height *= fitScale

        let proposedX = decoration.position.x + variation.xOffset
        let proposedY = decoration.position.y + variation.yOffset
        let maximumX = max(canvasInset, plan.canvasSize.width - canvasInset - width)
        let maximumY = max(canvasInset, plan.canvasSize.height - canvasInset - height)
        return marginaliaSafeFrame(CGRect(
            x: min(max(canvasInset, proposedX), maximumX),
            y: min(max(canvasInset, proposedY), maximumY),
            width: width,
            height: height
        ))
    }

    /// Preserve every authored size, asset, rotation, opacity, and initial
    /// anchor. Only marks that would cover the protected subject are nudged to
    /// the nearest legal side of it.
    private func marginaliaSafeFrame(_ proposedFrame: CGRect) -> CGRect {
        guard let exclusion = plan.marginaliaExclusionRect else {
            return proposedFrame
        }
        let protected = CGRect(
            x: exclusion.x,
            y: exclusion.y,
            width: exclusion.width,
            height: exclusion.height
        ).insetBy(dx: -18, dy: -18)
        let footprint = proposedFrame.insetBy(dx: -10, dy: -10)
        guard footprint.intersects(protected) else { return proposedFrame }

        let canvasInset: CGFloat = 28
        let maximumX = max(canvasInset, plan.canvasSize.width - canvasInset - proposedFrame.width)
        let maximumY = max(canvasInset, plan.canvasSize.height - canvasInset - proposedFrame.height)
        func clampedFrame(x: CGFloat, y: CGFloat) -> CGRect {
            CGRect(
                x: min(max(canvasInset, x), maximumX),
                y: min(max(canvasInset, y), maximumY),
                width: proposedFrame.width,
                height: proposedFrame.height
            )
        }

        let gap: CGFloat = 18
        let left = protected.minX - gap - proposedFrame.width
        let right = protected.maxX + gap
        let above = protected.minY - gap - proposedFrame.height
        let below = protected.maxY + gap
        let candidates = [
            clampedFrame(x: left, y: proposedFrame.minY),
            clampedFrame(x: right, y: proposedFrame.minY),
            clampedFrame(x: proposedFrame.minX, y: above),
            clampedFrame(x: proposedFrame.minX, y: below),
            clampedFrame(x: left, y: above),
            clampedFrame(x: right, y: above),
            clampedFrame(x: left, y: below),
            clampedFrame(x: right, y: below)
        ]
        let legal = candidates.filter { !$0.insetBy(dx: -10, dy: -10).intersects(protected) }
        return legal.min { lhs, rhs in
            let lhsDistance = pow(lhs.midX - proposedFrame.midX, 2) + pow(lhs.midY - proposedFrame.midY, 2)
            let rhsDistance = pow(rhs.midX - proposedFrame.midX, 2) + pow(rhs.midY - proposedFrame.midY, 2)
            return lhsDistance < rhsDistance
        } ?? proposedFrame
    }

    private func marginaliaSafeTextFrame(
        for slot: IlluminatedTextSlot,
        variation: OrganicPlacementVariation? = nil
    ) -> CGRect {
        let variation = variation ?? OrganicPlacementVariation(
            seed: plan.randomSeed,
            key: "text-\(slot.slotId)",
            maxOffset: 5,
            maxRotation: 2.2
        )
        return marginaliaSafeFrame(CGRect(
            x: slot.position.x + variation.xOffset,
            y: slot.position.y + variation.yOffset,
            width: slot.size.width,
            height: slot.size.height
        ))
    }

    private func decorationIsUnderText(_ decorationFrame: CGRect) -> Bool {
        return plan.textSlots.contains { slot in
            marginaliaSafeTextFrame(for: slot)
            .insetBy(dx: -12, dy: -12)
            .intersects(decorationFrame)
        }
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

    private func snapshotDecorationImage(assetName: String) -> UIImage? {
        guard assetName.hasPrefix("/") else { return UIImage(named: assetName) }
        if let cached = Self.fileDecorationImages.object(forKey: assetName as NSString) { return cached }
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: assetName) as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_536,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        Self.fileDecorationImages.setObject(image, forKey: assetName as NSString,
            cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    private func distressedStampImage(assetName: String, variation: OrganicPlacementVariation) -> UIImage? {
        guard let image = snapshotDecorationImage(assetName: assetName),
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

private struct IlluminatedTornNote: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 17
        for edge in 0..<4 {
            for step in 0..<steps {
                let fraction = CGFloat(step) / CGFloat(steps - 1)
                let tooth = CGFloat(IlluminatedPhotoLayout.bucket(seed, salt: edge * steps + step, count: 7))
                    / 7 * min(rect.width, rect.height) * 0.022
                let point: CGPoint
                switch edge {
                case 0: point = CGPoint(x: rect.minX + fraction * rect.width, y: rect.minY + tooth)
                case 1: point = CGPoint(x: rect.maxX - tooth, y: rect.minY + fraction * rect.height)
                case 2: point = CGPoint(x: rect.maxX - fraction * rect.width, y: rect.maxY - tooth)
                default: point = CGPoint(x: rect.minX + tooth, y: rect.maxY - fraction * rect.height)
                }
                if edge == 0 && step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Connections
//
// Clusters, constellations, and monthly themes are three engines behind one
// sentence: *these things keep arriving together*. The old sheet made the
// reader learn all three names — Knots, Stars, Months — before it would say
// it, and then drew an unlabelled dot map that answered nothing. So: one
// strongest-first list, the kind reduced to a plain-words chip, and a map
// whose points are labelled and tap through to their own card.

struct BookConnectionItem: Identifiable, Equatable {
    enum Kind: String, Hashable, CaseIterable {
        /// A motif cluster: several subjects orbiting one place.
        case together
        /// A constellation: one subject that keeps returning.
        case thread
        /// A monthly theme: what a whole month leaned toward.
        case month

        var chip: String {
            switch self {
            case .together: return "ARRIVES TOGETHER"
            case .thread: return "A THREAD I'M KEEPING"
            case .month: return "A MONTH'S WEATHER"
            }
        }

        var symbol: String {
            switch self {
            case .together: return "sparkles.rectangle.stack"
            case .thread: return "star.fill"
            case .month: return "moon.stars"
            }
        }

        var accent: Color {
            switch self {
            case .together: return BookPalette.teal
            case .thread: return BookPalette.lampGold
            case .month: return BookPalette.violet
            }
        }

        /// One plain sentence saying what this kind of finding *is*. No reader
        /// should have to infer that from a colour.
        var legend: String {
            switch self {
            case .together: return "things that keep showing up together"
            case .thread: return "one thing that keeps coming back"
            case .month: return "what a whole month leaned toward"
            }
        }
    }

    var id: String
    var kind: Kind
    var title: String
    var line: String
    /// The literal words the finding rests on. Shown labelled, never as a
    /// naked row of nouns.
    var words: [String]
    var strength: Int
    var evidencePageIDs: [String]
    var footnote: String?

    /// How sure the Book is, said in words. A reader has no use for "78".
    var strengthWord: String {
        switch strength {
        case ..<62: return "still faint"
        case ..<78: return "holding"
        default: return "hard to miss"
        }
    }

    /// Short enough to sit under a point on the map without shoving the
    /// neighbouring one off the edge.
    var mapLabel: String {
        var label = title
        for article in ["The ", "A ", "An "] where label.hasPrefix(article) {
            label.removeFirst(article.count)
        }
        guard label.count > 18 else { return label }
        return label.prefix(17).trimmingCharacters(in: .whitespaces) + "…"
    }
}

struct BookConnectionsSheet: View {
    let days: [BookDay]
    let inputs: BookSourceInputs
    var onOpenPage: (BookPage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var focusedID: String?

    private var items: [BookConnectionItem] {
        let clusterItems = derivedClusters.map { cluster in
            BookConnectionItem(
                id: cluster.id,
                kind: .together,
                title: cluster.name,
                line: cluster.line,
                words: cluster.motifs,
                strength: cluster.strength,
                evidencePageIDs: cluster.evidencePageIDs,
                footnote: nil
            )
        }
        // A faded constellation is not a connection any more; it is a memory
        // of one. Leaving it in the list is how the old sheet ended up
        // calling a dead thread "hard to miss".
        let threadItems = inputs.constellations.filter(\.isAlive).map { constellation in
            BookConnectionItem(
                id: constellation.id,
                kind: .thread,
                title: constellation.displayName,
                line: constellation.latestLine,
                words: Array(constellation.tags.prefix(8)),
                strength: constellation.strengthPeak,
                evidencePageIDs: constellation.evidencePageIDs,
                footnote: Self.footnote(for: constellation)
            )
        }
        let monthItems = inputs.themes.map { theme in
            BookConnectionItem(
                id: theme.id,
                kind: .month,
                title: theme.name,
                line: theme.line,
                words: theme.motifs,
                strength: theme.strength,
                evidencePageIDs: theme.evidencePageIDs,
                footnote: Self.footnote(for: theme)
            )
        }
        return (clusterItems + threadItems + monthItems).sorted { left, right in
            if left.strength == right.strength {
                return left.title < right.title
            }
            return left.strength > right.strength
        }
    }

    private var derivedClusters: [BookMotifCluster] {
        inputs.clusters.isEmpty
            ? BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: inputs.constellations, themes: inputs.themes)
            : inputs.clusters
    }

    private var pageByID: [String: BookPage] {
        Dictionary(days.flatMap(\.pages).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // Both of these walk the whole archive, so they are resolved once per
    // render and handed down rather than read from half a dozen computed
    // properties that would each rebuild them.
    var body: some View {
        let items = self.items
        let pageByID = self.pageByID
        return BookLeafFrame(
            title: "What Keeps Finding What",
            paperType: .bookConnections,
            seedID: "connections"
        ) {
            ScrollViewReader { scroll in

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(count: items.count)
                        if items.isEmpty {
                            EmptyBookCard(
                                title: "Nothing has crossed yet",
                                message: "Keep more Pages. The moment two of them share a word, or one thing comes back on its own, I'll draw the line and show you where I got it."
                            )
                        } else {
                            BookConnectionsMapView(items: Array(items.prefix(5)), focusedID: focusedID) { item in
                                BookFeedback.play(.openPage)
                                focusedID = item.id
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                                    scroll.scrollTo(item.id, anchor: .top)
                                }
                            }
                            .frame(height: 280)
                            .accessibilityLabel("A map of the strongest connections. Tap a point to read it.")
                            legend(for: items)
                            ForEach(items) { item in
                                BookConnectionCard(
                                    item: item,
                                    evidencePages: item.evidencePageIDs
                                        .compactMap { pageByID[$0] }
                                        .sorted { $0.createdAt > $1.createdAt },
                                    isFocused: focusedID == item.id,
                                    onOpenPage: onOpenPage
                                )
                                .id(item.id)
                            }
                        }
                    }
                    .padding(18)
                }
            }

        }
    }

    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(openingLine(count: count))
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(MaterialInk.gilt)
                .fixedSize(horizontal: false, vertical: true)
            Text(explainerLine(count: count))
                .font(.callout)
                .foregroundStyle(MaterialInk.text.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(BookNightCard(
            cornerRadius: 8,
            padding: 16,
            fillOpacity: 0.52,
            stroke: BookPalette.teal,
            strokeOpacity: 0.22
        ))

    }

    private func openingLine(count: Int) -> String {
        count == 0
            ? "I have nothing to connect yet."
            : "I found \(count) connection\(count == 1 ? "" : "s") in your Pages."
    }

    /// Says what a connection *is*, once, in plain words. The old sheet never
    /// did: it opened with three one-word tab titles and let the reader guess.
    private func explainerLine(count: Int) -> String {
        count == 0
            ? "The pins are out and getting cross about it. Give me two Pages that share something."
            : "A connection is one of two things: something that came back on its own, or two things that keep sharing a day. Strongest first. Tap any point on the map to jump to it."
    }

    private func legend(for items: [BookConnectionItem]) -> some View {
        let kinds = BookConnectionItem.Kind.allCases.filter { kind in
            items.contains { $0.kind == kind }
        }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(kinds, id: \.self) { kind in
                HStack(spacing: 8) {
                    Circle()
                        .fill(kind.accent)
                        .frame(width: 7, height: 7)
                    Text(kind.legend)
                        .font(.caption)
                        .foregroundStyle(MaterialInk.text.opacity(0.66))
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private static func footnote(for constellation: Constellation) -> String? {
        switch constellation.phase {
        case .noticed:
            return "I've only just started watching this one."
        case .watched:
            return "I'm watching this one. Not naming it yet."
        case .named:
            return "I named this one. It earned that."
        case .woven:
            return "This one's in the story now. It turns up in what I write you."
        case .faded:
            return nil
        }
    }

    private static func footnote(for theme: BookTheme) -> String? {
        let month = monthName(from: theme.monthKey)
        return theme.isStable
            ? "\(month), settled. I've stopped changing my mind about it."
            : "\(month), still gathering. The month can still turn."
    }

    private static func monthName(from key: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: key) else { return key }
        let printer = DateFormatter()
        printer.dateFormat = "LLLL yyyy"
        return printer.string(from: date)
    }
}

/// The map earns its space by being a way in: every point is named, and
/// tapping one scrolls to the card that explains it.
private struct BookConnectionsMapView: View {
    let items: [BookConnectionItem]
    let focusedID: String?
    var onSelect: (BookConnectionItem) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.46)
            let radius = min(size.width * 0.32, size.height * 0.34)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(BookPalette.nightPanel.opacity(0.44))
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(BookPalette.gold.opacity(0.10 - Double(ring) * 0.025), lineWidth: 1)
                        .frame(
                            width: radius * 2 * (0.55 + Double(ring) * 0.3),
                            height: radius * 2 * (0.55 + Double(ring) * 0.3)
                        )
                        .position(center)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let point = point(for: index, count: items.count, center: center, radius: radius, in: size)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point)
                    }
                    .stroke(item.kind.accent.opacity(focusedID == item.id ? 0.66 : 0.26), lineWidth: 1)
                    node(item, at: point)
                }
                centerMark
                    .position(center)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.18), lineWidth: 1)
        )
    }

    /// The hub's caption sits *above* its dot. Every point's label hangs
    /// below its own dot, and the east and west points share the hub's
    /// baseline - captioning the hub downward puts three labels in one place.
    private var centerMark: some View {
        ZStack {
            Circle()
                .fill(BookPalette.gold.opacity(0.85))
                .frame(width: 9, height: 9)
            Text("your Pages")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BookPalette.gold.opacity(0.72))
                .fixedSize()
                .offset(y: -17)
        }
    }

    private func node(_ item: BookConnectionItem, at point: CGPoint) -> some View {
        let isFocused = focusedID == item.id
        return Button {
            onSelect(item)
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(item.kind.accent)
                    .frame(width: isFocused ? 16 : 11, height: isFocused ? 16 : 11)
                    .shadow(color: item.kind.accent.opacity(0.45), radius: isFocused ? 10 : 5)
                Text(item.mapLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isFocused ? item.kind.accent : BookPalette.nightText.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 84)
            }
        }
        .buttonStyle(.plain)
        .position(point)
        .accessibilityLabel("\(item.title). \(item.kind.legend).")
    }

    private func point(for index: Int, count: Int, center: CGPoint, radius: CGFloat, in size: CGSize) -> CGPoint {
        let angle = (Double(index) / Double(max(1, count))) * Double.pi * 2 - Double.pi / 2
        let raw = CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
        return CGPoint(
            x: min(max(raw.x, 52), size.width - 52),
            y: min(max(raw.y, 26), size.height - 34)
        )
    }
}

private struct BookConnectionCard: View {
    let item: BookConnectionItem
    let evidencePages: [BookPage]
    let isFocused: Bool
    var onOpenPage: (BookPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.kind.chip, systemImage: item.kind.symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(item.kind.accent)
                Spacer(minLength: 8)
                Text(item.strengthWord)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MaterialInk.text.opacity(0.5))
            }
            Text(item.title)
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(MaterialInk.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.line)
                .font(.callout)
                .foregroundStyle(MaterialInk.text.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            if let footnote = item.footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(item.kind.accent.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !item.words.isEmpty {
                labelledRow("THE WORDS UNDER IT") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(item.words.prefix(10), id: \.self) { word in
                                Text(word)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(item.kind.accent.opacity(0.92))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.kind.accent.opacity(0.10), in: Capsule())
                            }
                        }
                    }
                }
            }
            if !evidencePages.isEmpty {
                labelledRow("WHERE I GOT IT") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(evidencePages.prefix(3)) { page in
                            Button {
                                BookFeedback.play(.openPage)
                                onOpenPage(page)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundStyle(item.kind.accent)
                                    Text(page.archivePreviewText ?? page.type.title)
                                        .font(.caption)
                                        .foregroundStyle(MaterialInk.text.opacity(0.76))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .padding(8)
                                .background(BookPalette.ink.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.bookPress())
                        }
                        if evidencePages.count > 3 {
                            Text("And \(evidencePages.count - 3) more kept Page\(evidencePages.count - 3 == 1 ? "" : "s") under this one.")
                                .font(.caption2)
                                .foregroundStyle(MaterialInk.text.opacity(0.52))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(BookNightCard(
            cornerRadius: 8,
            padding: 14,
            fillOpacity: isFocused ? 0.62 : 0.44,
            stroke: item.kind.accent,
            strokeOpacity: isFocused ? 0.62 : 0.22,
            strokeWidth: isFocused ? 2 : 1,
            onPaper: .aside
        ))

        .animation(.easeOut(duration: 0.24), value: isFocused)
    }

    private func labelledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MaterialInk.text.opacity(0.46))
            content()
        }
    }
}

private struct OrganicPlacementVariation {
    let xOffset: Double
    let yOffset: Double
    let rotationDegrees: Double
    let sizeScale: Double
    let opacityLift: Double
    let distress: Double

    init(
        seed: Int,
        key: String,
        maxOffset: Double = 6,
        maxRotation: Double = 3,
        maxScaleVariation: Double = 0
    ) {
        xOffset = Self.signed(seed: seed, key: "\(key)-x", range: maxOffset)
        yOffset = Self.signed(seed: seed, key: "\(key)-y", range: maxOffset)
        rotationDegrees = Self.signed(seed: seed, key: "\(key)-r", range: maxRotation)
        sizeScale = 1 + Self.signed(seed: seed, key: "\(key)-s", range: maxScaleVariation)
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
    /// Generated upstream of page turns. Only the coloured marks are stored;
    /// ordinary paper remains a live, still composition underneath them.
    static func renderPigment(draft: IlluminatedPhotoDraft, sourceImage: UIImage) -> (Data, UIImage)? {
        let size = draft.compositionPlan.canvasSize
        let scale = min(1, 1_000 / max(size.width, size.height))
        let ink = ImageRenderer(content: IlluminatedArtifactPreview(renderLayer: .pigment, draft: draft, sourceImage: sourceImage)
            .frame(width: size.width, height: size.height))
        ink.scale = scale
        let timing = ImageRenderer(content: IlluminatedArtifactPreview(renderLayer: .clock, draft: draft)
            .frame(width: size.width, height: size.height))
        timing.scale = min(scale, 256 / max(size.width, size.height))
        // ImageRenderer can defer drawing until pixels are read. Consume its
        // output on this actor before handing ordinary image bytes to workers.
        guard let data = ink.uiImage?.pngData(), let clock = timing.uiImage else { return nil }
        return (data, clock)
    }

    static func renderPreview(draft: IlluminatedPhotoDraft, sourceImage: UIImage?) -> URL? {
        guard let data = previewImage(draft: draft, sourceImage: sourceImage)?.jpegData(compressionQuality: 0.9) else { return nil }
        return writePreview(data, draftID: draft.id)
    }

    /// Consume SwiftUI's potentially lazy rendering on the main actor. File
    /// writing and display decoding work with the resulting bytes off actor.
    static func preparePreview(draft: IlluminatedPhotoDraft, sourceImage: UIImage, persist: Bool = true) async -> UIImage? {
        guard let data = previewImage(draft: draft, sourceImage: sourceImage)?.jpegData(compressionQuality: 0.9) else { return nil }
        let draftID = draft.id
        return await Task.detached(priority: .utility) { () -> UIImage? in
            // Decode the exact JPEG bytes just written. Reading the file back
            // adds I/O and could race another render of the same draft.
            guard (!persist || writePreview(data, draftID: draftID) != nil),
                  let decoded = UIImage(data: data) else { return nil }
            return decoded.preparingForDisplay() ?? decoded
        }.value
    }

    private static func previewImage(draft: IlluminatedPhotoDraft, sourceImage: UIImage?) -> UIImage? {
        AppMemoryLedger.record("illumination-render-enter")
        let plan = draft.compositionPlan
        let content = IlluminatedArtifactPreview(draft: draft, sourceImage: sourceImage)
            .frame(width: plan.canvasSize.width, height: plan.canvasSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return renderer.uiImage
    }

    nonisolated private static func writePreview(_ data: Data, draftID: UUID) -> URL? {
        do {
            let directory = try renderedDirectory()
            let filename = "illuminated-\(draftID.uuidString).jpg"
            let url = directory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            AppMemoryLedger.record("illumination-render-exit")
            return url
        } catch {
            appLog.error("Illuminated render failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    nonisolated private static func renderedDirectory() throws -> URL {
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

    /// A fully deterministic, per-card layout derived from the seed: palette,
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

/// Deterministic, seed-driven layout plan for one souvenir card: the quote-card
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

    /// FNV-1a over the seed + a per-knob key, mapped to a stable 0...1 value:
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

        // The composition is seed-deterministic: the same quote at the same
        // seed always composes the same card. `ImageRenderer` is the expensive
        // half and it is main-actor bound, so a cache hit is the difference
        // between a free plate and a frozen frame, which matters most when a
        // binding wants several of these at once.
        let filename = "illuminated-quote-v\(designVersion)-\(seed.magnitude)-\(quote.stableHash.magnitude).png"
        let directory: URL
        do {
            directory = try renderedDirectory()
        } catch {
            appLog.error("Illuminated quote directory failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }
        let url = directory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) { return url }

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            return nil
        }

        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            appLog.error("Illuminated quote render failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    /// Bump when the card's layout or palette changes, so cached plates from an
    /// older design are orphaned rather than served forever.
    private static let designVersion = 1

    private static func renderedDirectory() throws -> URL {
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("IlluminatedQuoteCards", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

struct BookOfYouShareArtifact: Hashable {
    var title: String
    var excerpt: String
    var dateLine: String
    var themeName: String?
    var chapterName: String?
    var seed: Int
    /// Overprinted across the top of the Page, above its title. The loose Page
    /// that falls out of the Book at the very start of everything lands with
    /// its warning already on it, so the warning belongs to the Page, not to
    /// the app's narration. Stays put when the reader writes their own first
    /// line and the rest of the Page re-forms around it.
    var stamp: String? = nil

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
            .first(where: { BraidColophon.starts($0) }) {
            return clipped(BraidColophon.removingStems(from: keptLine).trimmingCharacters(in: .whitespacesAndNewlines))
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
        if lower.contains("the book kept") || lower.hasPrefix("i kept the page") { total += 18 }
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

                if let stamp = artifact.stamp?.nonEmpty {
                    // Overprinted, so it outweighs the Page's own title: this
                    // is the thing the Page came to say. Fixed height keeps the
                    // rest of the plate from shifting when the copy changes.
                    Text(stamp)
                        .font(.system(size: 62, weight: .heavy, design: .serif))
                        .foregroundStyle(BookPalette.rubricRed)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .lineLimit(3)
                        .minimumScaleFactor(0.55)
                        .frame(width: Self.contentWidth, height: 196)
                        .shadow(color: BookPalette.page.opacity(0.8), radius: 1, x: 0, y: 1)
                }

                Text(artifact.title)
                    .font(.system(size: 54, weight: .semibold, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(width: Self.contentWidth, height: artifact.stamp?.nonEmpty == nil ? 128 : 78)

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
    @State private var plate: UIImage?

    init(artifact: BookOfYouShareArtifact, isWorking: Bool = false) {
        self.artifact = artifact
        self.isWorking = isWorking
        // A plate already pressed arrives with the view, not a frame after it.
        _plate = State(initialValue: BookOfYouPressedPlate.cached(artifact))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(BookPalette.nightPanel.opacity(0.82))
                        .shadow(color: BookPalette.lampGold.opacity(shimmer ? 0.26 : 0.12), radius: shimmer ? 28 : 16, x: 0, y: 12)

                    // The pressed page as the bitmap it is, not the card drawn
                    // live. Drawn live, the 1080-point card had to sit in a
                    // `drawingGroup` to show at all, and that offscreen texture
                    // was rebuilt every time the leaf around it redisplayed:
                    // every frame of a scroll, and every frame of the banner's
                    // drift on the same leaf. Book Today delivered 59 frames in
                    // 245 while it was on the page.
                    if let plate {
                        Image(uiImage: plate)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .scaleEffect(0.92, anchor: .center)
                            .rotationEffect(.degrees(reduceMotion ? 0 : (shimmer ? 0.7 : -0.7)))
                            .shadow(color: .black.opacity(0.26), radius: 12, x: 0, y: 8)
                            .transition(.opacity)
                            .accessibilityHidden(true)
                    }

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
        .task(id: artifact) {
            if let pressed = BookOfYouPressedPlate.cached(artifact) {
                plate = pressed
                return
            }
            // Let the leaf finish arriving before the one-time pressing.
            await Task.yield()
            guard !Task.isCancelled else { return }
            let pressed = BookOfYouPressedPlate.plate(for: artifact)
            withAnimation(.easeOut(duration: 0.25)) { plate = pressed }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pressed Book of You share page. \(artifact.stamp.map { $0 + ". " } ?? "")Titled \(artifact.title). \(artifact.excerpt)")
    }

    /// The card only pulses while it is actively being pressed. At rest: the
    /// morning "waiting" state: it holds still instead of shimmering forever.
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
    /// Monthly PDF binding: a wax seal, the `monthBound` haptic.
    case sewn
    /// Print-ready hardcover export: a foil stamp, the heavier `pressReady` haptic.
    case press
    /// The onboarding finale: the reader's first edition, a wax seal + key.
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

/// The edition-binding celebration: the app's grandest peaks. The signatures
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

/// The Book of You share card, pressed once into pixels.
///
/// The thumbnail on a leaf and the PNG that leaves the app are the same
/// picture, so they are the same bitmap: whichever asks first pays for the
/// pressing and the other finds it done.
@MainActor
enum BookOfYouPressedPlate {
    /// The latest braid's plate and at most one other. Each is 1080x1350, about
    /// 5.8 MB, so this is not a gallery.
    private static var plates: [(artifact: BookOfYouShareArtifact, image: UIImage)] = []

    static func cached(_ artifact: BookOfYouShareArtifact) -> UIImage? {
        plates.first { $0.artifact == artifact }?.image
    }

    static func plate(for artifact: BookOfYouShareArtifact) -> UIImage? {
        if let pressed = cached(artifact) { return pressed }
        let renderer = ImageRenderer(
            content: BookOfYouShareCard(artifact: artifact)
                .frame(width: BookOfYouShareCard.renderSize.width, height: BookOfYouShareCard.renderSize.height)
        )
        renderer.scale = 1
        guard let drawing = renderer.cgImage, let pixels = rasterized(drawing) else { return nil }
        let image = UIImage(cgImage: pixels, scale: 1, orientation: .up)
        plates.insert((artifact, image), at: 0)
        if plates.count > 2 { plates.removeLast(plates.count - 2) }
        return image
    }

    /// `ImageRenderer` does not rasterize when asked; it hands back an image
    /// that draws the card when something first needs its pixels. Shown as it
    /// is, every redisplay of the layer holding it would draw the whole card
    /// again. Drawn into memory here, it is a bitmap.
    private static func rasterized(_ drawing: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: drawing.width,
                height: drawing.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return nil }
        context.draw(drawing, in: CGRect(x: 0, y: 0, width: drawing.width, height: drawing.height))
        return context.makeImage()
    }
}

@MainActor
enum BookOfYouShareCardRenderer {
    static func render(artifact: BookOfYouShareArtifact) -> URL? {
        guard let image = BookOfYouPressedPlate.plate(for: artifact) else { return nil }
        return write(image, seed: artifact.seed)
    }

    /// The same pressing, with the PNG encoded and written off the main
    /// thread. Encoding a 1080x1350 plate is the slow half, and it used to land
    /// in the first frames of Book Today opening.
    static func renderInBackground(artifact: BookOfYouShareArtifact) async -> URL? {
        guard let image = BookOfYouPressedPlate.plate(for: artifact) else { return nil }
        let seed = artifact.seed
        return await Task.detached(priority: .utility) {
            write(image, seed: seed)
        }.value
    }

    nonisolated private static func write(_ image: UIImage, seed: Int) -> URL? {
        guard let data = image.pngData() else { return nil }
        do {
            let directory = try renderedDirectory()
            let filename = "book-of-you-pressed-\(seed.magnitude).png"
            let url = directory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            appLog.error("Book of You share render failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    nonisolated private static func renderedDirectory() throws -> URL {
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
            appLog.error("Book of You reveal video failed: \(error.localizedDescription, privacy: .private)")
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
            appLog.error("Book of You PDF render failed: \(error.localizedDescription, privacy: .private)")
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
            surface.payload.metadata["bookActedMarginTitle"]?.nonEmpty ?? "I interfered",
            line
        )
    }

    private var bookInterjectionPhysicalAct: String? {
        surface.payload.metadata["bookInterjectionPhysicalAct"]?.nonEmpty
    }

    private var bookInterjectionTargetExcerpt: String? {
        surface.payload.metadata["bookInterjectionTargetExcerpt"]?.nonEmpty
    }

    private var bookCharacterCadence: String? {
        surface.payload.metadata["bookCharacterCadence"]?.nonEmpty
    }

    private var bookCharacterPromptStyle: Font.TextStyle {
        switch bookCharacterCadence {
        case "small-hand": return .title3
        case "spilling-over": return .title
        default: return .title2
        }
    }

    private var bookCharacterCardTilt: Double {
        switch bookCharacterCadence {
        case "crooked": return surface.id.stableHash.isMultiple(of: 2) ? -1.15 : 1.05
        case "both-paws": return 0
        default: return surface.id.stableHash.isMultiple(of: 2) ? -0.6 : 0.5
        }
    }

    private var bookInterjectionSymbol: String {
        switch bookInterjectionPhysicalAct {
        case "dog-ear": return "bookmark.fill"
        case "underline": return "underline"
        case "smudge": return "fingerprint"
        case "left-open": return "book.pages"
        case "sprawling-hand": return "pencil.line"
        case "tiny-hand": return "pencil.tip"
        default: return "pencil.and.scribble"
        }
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
    /// they choose to open: otherwise the shelf repeats it before the page can.
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
        return "Open: the page will borrow some Belief"
    }

    /// True when the shelf card is a Shadow Wonder variant of an ordinary page
    /// type: surfaced once the Dusk Thorn is invested in and the world turns
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
                .font(.system(bookCharacterPromptStyle, design: .serif, weight: .semibold))
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
                    Label(margin.title.uppercased(), systemImage: bookInterjectionSymbol)
                        .font(.caption2.weight(.black))
                        .tracking(0.9)
                    if bookInterjectionPhysicalAct == "underline",
                       let excerpt = bookInterjectionTargetExcerpt {
                        Text("“\(excerpt)”")
                            .font(.system(.callout, design: .serif, weight: .semibold))
                            .underline(true, color: visualStyle.accent.opacity(0.9))
                            .accessibilityLabel("I underlined: \(excerpt)")
                    }
                    Text(margin.line)
                        .font(.system(
                            bookInterjectionPhysicalAct == "sprawling-hand" ? .body : .callout,
                            design: .serif
                        ).italic())
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
            if bookInterjectionPhysicalAct == "dog-ear" {
                BookInterjectionDogEarMark(tint: visualStyle.accent)
                    .frame(width: 52, height: 52)
                    .accessibilityLabel("I dog-eared this Page")
            } else {
                PageCurl()
                    .fill(visualStyle.accent.opacity(0.16))
                    .frame(width: 34, height: 34)
                    .opacity(0.72)
                    .allowsHitTesting(false)
            }
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
        .overlay(alignment: .trailing) {
            if bookInterjectionPhysicalAct == "smudge" {
                BookInterjectionSmudgeMark(tint: visualStyle.accent)
                    .frame(width: 58, height: 86)
                    .offset(x: 8, y: 22)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if bookInterjectionPhysicalAct == "left-open" {
                BookInterjectionOpenLeafMark(tint: visualStyle.accent)
                    .frame(width: 72, height: 42)
                    .offset(x: 7, y: 12)
                    .allowsHitTesting(false)
                    .accessibilityLabel("I left an older Page open here")
            }
        }
        .rotationEffect(.degrees(bookCharacterCardTilt))
    }

    @ViewBuilder
    private func illuminatedCardPreview(draft: IlluminatedPhotoDraft) -> some View {
        if let renderedPath = surface.payload.metadata["renderedPreviewPath"],
           let image = BookRenderedImageCache.shared.image(for: renderedPath) {
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
    @State private var sealEngaged = false

    private let dismissThreshold: CGFloat = 96
    private let horizontalDragRatio: CGFloat = 1.6

    /// How far into the dismissal the drag has travelled, 0…1.
    private var dragProgress: CGFloat {
        min(1, abs(min(0, dragOffset)) / dismissThreshold)
    }

    /// True exactly when letting go now would let the page pass. The seal and
    /// the tick both key off this rather than a nearby-looking fraction, so the
    /// Book never shows a sealed page it would then hand back.
    private var wouldDismissOnRelease: Bool {
        dragProgress >= 1
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
            ? "I'm choosing another page."
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

    /// The oxblood margin that the page slips into: with a wax seal that
    /// closes as the drag crosses the dismiss threshold.
    private var marginReveal: some View {
        BookMarginReveal(
            label: "Let it pass",
            dragProgress: dragProgress,
            sealed: wouldDismissOnRelease || isTucking
        )
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        guard isDeliberateHorizontalDismiss(value) else {
            dragOffset = 0
            updateSealEngagement()
            return
        }
        dragOffset = min(0, value.translation.width)
        updateSealEngagement()
    }

    /// Fires once on each crossing of the commit threshold, in either
    /// direction, never per frame, or the drag would buzz continuously.
    private func updateSealEngagement() {
        let engaged = wouldDismissOnRelease
        guard engaged != sealEngaged else { return }
        sealEngaged = engaged
        BookFeedback.sealTick(engaged: engaged)
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
            sealEngaged = false
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
        sealEngaged = false
        if reduceMotion {
            dragOffset = 0
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

/// The inside cover exposed while the first real Pages are being selected.
/// Nothing here is tappable, so provisional Pages never appear under a finger.
struct LaunchFrontMatterView: View {
    let cover: PagesRisingMonthlyCover
    let isReady: Bool
    let isPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.bookReadingWindow) private var readingWindow
    @State private var isAwake = false

    private var animates: Bool {
        !reduceMotion && !isPaused && !isReady
    }

    /// On an iPad the title leaf is cut to the Book's own leaf, so the Book
    /// that replaces it arrives in the same place at the same size.
    private var lecternLeaf: CGSize? {
        PagesRisingFolio.lecternLeafSize(in: readingWindow)
    }

    /// A phone on its side. This leaf stands in for the Book while the Curator
    /// is still choosing, so it has to keep the Book's shape when it does —
    /// spread edge to edge on a sideways phone and the reader is handed a slab
    /// of parchment where a title page should be.
    private var isLyingOnItsSide: Bool {
        verticalSizeClass == .compact
    }

    private var readerLine: String {
        let name = cover.readerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty
            ? "A private field book"
            : "Prepared for \(name)"
    }

    private var statusLine: String {
        isReady ? "Found your place." : "I’m gathering today’s loose pages."
    }

    private var versionLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "1"
        return "Digital edition · Version \(version) (\(build))"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BookPalette.page,
                            BookPalette.paper.opacity(0.95),
                            BookPalette.page.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            endpaperPattern
                .opacity(0.72)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            BookPalette.parchmentEdge.opacity(0.13),
                            .clear,
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Text("A LIVING FIELD BOOK")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .tracking(2.2)
                    .foregroundStyle(BookPalette.parchmentEdge.opacity(0.68))

                titleRule
                    .padding(.top, 13)

                Spacer(minLength: 24)

                Text("ReEnchanted")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.92))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)

                Text("THE BOOK OF YOU")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(3.4)
                    .foregroundStyle(BookPalette.gold.opacity(0.86))
                    .padding(.top, 9)

                Text(readerLine)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.top, 15)

                titleOrnament
                    .padding(.top, 20)
                    .opacity(isReady ? 0.88 : (isAwake && animates ? 1 : 0.48))
                    .scaleEffect(isReady ? 1 : (isAwake && animates ? 1.035 : 0.97))

                Text("\(cover.monthLine) · \(cover.dateLine)")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(1.4)
                    .foregroundStyle(BookPalette.parchmentEdge.opacity(0.62))
                    .padding(.top, 13)

                Spacer(minLength: 25)

                colophon

                Spacer(minLength: 22)

                findingMark

                Text(statusLine)
                    .font(.system(.callout, design: .serif, weight: .semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.22), value: isReady)
                    .padding(.top, 15)

            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
        }
        .frame(
            maxWidth: lecternLeaf?.width ?? (isLyingOnItsSide ? 344 : .infinity),
            minHeight: lecternLeaf?.height ?? (isLyingOnItsSide ? 372 : 520),
            maxHeight: lecternLeaf?.height
        )
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(BookPalette.parchmentEdge.opacity(0.52), lineWidth: 1.2)
                .padding(7)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(isAwake && animates ? 0.34 : 0.19), lineWidth: 0.8)
                .padding(11)
        }
        .shadow(
            color: Color.black.opacity(0.24),
            radius: 18,
            y: 10
        )
        // The row it sits in is leading-aligned, so a leaf narrower than the
        // row would hang off one edge. Upright it already fills the row and
        // this changes nothing.
        .frame(maxWidth: .infinity)
        .animation(
            animates ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : nil,
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
        .accessibilityLabel("ReEnchanted. The Book of You. \(readerLine). \(statusLine)")
    }

    private var endpaperPattern: some View {
        Canvas { context, size in
            let step: CGFloat = 34
            let columns = Int(size.width / step) + 3
            let rows = Int(size.height / step) + 3

            for row in 0..<rows {
                for column in 0..<columns {
                    let stagger = row.isMultiple(of: 2) ? 0 : step / 2
                    let center = CGPoint(
                        x: CGFloat(column - 1) * step + stagger,
                        y: CGFloat(row - 1) * step
                    )
                    var diamond = Path()
                    diamond.move(to: CGPoint(x: center.x, y: center.y - 8))
                    diamond.addLine(to: CGPoint(x: center.x + 8, y: center.y))
                    diamond.addLine(to: CGPoint(x: center.x, y: center.y + 8))
                    diamond.addLine(to: CGPoint(x: center.x - 8, y: center.y))
                    diamond.closeSubpath()
                    context.stroke(
                        diamond,
                        with: .color(BookPalette.teal.opacity(0.12)),
                        lineWidth: 0.7
                    )

                    if (row + column).isMultiple(of: 3) {
                        let dot = Path(
                            ellipseIn: CGRect(
                                x: center.x - 1.5,
                                y: center.y - 1.5,
                                width: 3,
                                height: 3
                            )
                        )
                        context.fill(dot, with: .color(BookPalette.gold.opacity(0.14)))
                    }
                }
            }
        }
        .mask {
            LinearGradient(
                colors: [.black, .black.opacity(0.12), .black.opacity(0.12), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    private var titleRule: some View {
        ZStack {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(BookPalette.parchmentEdge.opacity(0.42))
                    .frame(height: 1)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(BookPalette.gold.opacity(0.84))

                Rectangle()
                    .fill(BookPalette.parchmentEdge.opacity(0.42))
                    .frame(height: 1)
            }

            if animates {
                Circle()
                    .fill(BookPalette.lampGold.opacity(0.82))
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: BookPalette.lampGold.opacity(0.52), radius: 3)
                    .offset(x: isAwake && animates ? 108 : -108)
            }
        }
        .frame(height: 7)
        .clipped()
    }

    private var titleOrnament: some View {
        HStack(spacing: 9) {
            Image(systemName: "leaf.fill")
                .rotationEffect(.degrees(-38))
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .semibold))
            Image(systemName: "leaf.fill")
                .rotationEffect(.degrees(38))
                .scaleEffect(x: -1, y: 1)
        }
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(BookPalette.gold.opacity(0.76))
    }

    private var colophon: some View {
        VStack(spacing: 4) {
            Text(versionLine)
            Text("Copyright © 2026 teign")
            Text("Source code licensed under Mozilla Public License 2.0")
            Text("github.com/teign07/ReEnchanted")
            Text("Artwork, audio, content, and ReEnchanted marks · All Rights Reserved")
            Text("Reader save data belongs to the reader")
        }
        .font(.system(size: 8.5, weight: .regular, design: .serif))
        .foregroundStyle(BookPalette.ink.opacity(0.58))
        .multilineTextAlignment(.center)
        .lineSpacing(1.5)
        .padding(.horizontal, 8)
    }

    private var findingMark: some View {
        ZStack {
            Circle()
                .stroke(BookPalette.gold.opacity(0.54), lineWidth: 1)
                .frame(width: 48, height: 48)

            Circle()
                .stroke(BookPalette.parchmentEdge.opacity(0.26), lineWidth: 1)
                .frame(width: 36, height: 36)

            Image(systemName: isReady ? "bookmark.fill" : "bookmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isReady ? BookPalette.teal : BookPalette.gold)
        }
        .scaleEffect(isReady ? 1.05 : (isAwake && animates ? 1.03 : 0.96))
        .shadow(
            color: (isReady ? BookPalette.teal : BookPalette.lampGold).opacity(0.20),
            radius: isReady ? 8 : 5
        )
        .animation(.easeInOut(duration: 0.24), value: isReady)
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
        .accessibilityLabel("I'm choosing another page")
    }
}

struct SwipeDismissBookOfYouHero<Content: View>: View {
    let content: Content
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var isTucking = false
    @State private var sealEngaged = false

    private let dismissThreshold: CGFloat = 96
    private let horizontalDragRatio: CGFloat = 1.6

    init(@ViewBuilder content: () -> Content, onDismiss: @escaping () -> Void) {
        self.content = content()
        self.onDismiss = onDismiss
    }

    private var dragProgress: CGFloat {
        min(1, abs(min(0, dragOffset)) / dismissThreshold)
    }

    /// True exactly when letting go now would let the page pass.
    private var wouldDismissOnRelease: Bool {
        dragProgress >= 1
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
                        performDismissal()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(MaterialInk.text.opacity(0.48))
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
        BookMarginReveal(
            label: "Shelve preview",
            dragProgress: dragProgress,
            sealed: wouldDismissOnRelease || isTucking
        )
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        guard isDeliberateHorizontalDismiss(value) else {
            dragOffset = 0
            updateSealEngagement()
            return
        }
        dragOffset = min(0, value.translation.width)
        updateSealEngagement()
    }

    /// Fires once on each crossing of the commit threshold, in either
    /// direction, never per frame, or the drag would buzz continuously.
    private func updateSealEngagement() {
        let engaged = wouldDismissOnRelease
        guard engaged != sealEngaged else { return }
        sealEngaged = engaged
        BookFeedback.sealTick(engaged: engaged)
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
            sealEngaged = false
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
        guard !isTucking else { return }
        BookFeedback.play(.dismissPage)
        sealEngaged = false
        if reduceMotion {
            dragOffset = 0
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

/// The oxblood margin a page slips into as it is swiped away, with a wax seal
/// that closes at the moment letting go would actually part with the page.
///
/// Shared by every swipe-dismiss surface, so releasing a full card and
/// releasing a single kept scrap are the same gesture in the reader's hand.
/// Three hand-copied versions of this had already drifted apart once.
private struct BookMarginReveal: View {
    let label: String
    let dragProgress: CGFloat
    let sealed: Bool
    /// Cards stand a full 176pt; a scrap row is a smaller object, so the
    /// margin it slips into is proportionate to what is being pushed.
    var minHeight: CGFloat = 176

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Deep oxblood wax, so the reveal reads as the Book's margin rather than
    /// a system delete action.
    private let waxDeep = Color(red: 0.24, green: 0.06, blue: 0.08)
    private let waxRed = Color(red: 0.42, green: 0.13, blue: 0.13)

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: sealed ? "seal.fill" : "seal")
                    .font(.title3.weight(.bold))
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragProgress) * -12))
                Text(label)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(BookPalette.page.opacity(0.9))
            .scaleEffect(reduceMotion ? 1 : 0.84 + dragProgress * 0.2)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            .padding(.trailing, 26)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
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
        .accessibilityHidden(true)
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
    /// A page or scene the reader kept after tonight's braid was written is waiting.
    var hasLaterKeeps: Bool = false
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
                            Text("I need one true fragment kept today before I can braid.")
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
                                subtitle: hasLaterKeeps
                                    ? "You kept something since this braid was written. Weave it in now, or I'll save it for the next one."
                                    : "Unravel the most recent braid and weave today's fragments again.",
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
                        if PublicMarginsAPI.isAvailable || publicMarginsReceiptCount > 0 {
                            publicMarginsDoorways
                        }

                        ForEach(visibleSources) { source in
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

    private var visibleSources: [BookPageSource] {
        guard !PublicMarginsAPI.isAvailable else { return sources }
        return sources.filter { !$0.id.hasPrefix("public-margins") }
    }

    private var publicMarginsDoorways: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("The Public Margins", systemImage: "person.3.sequence.fill")
                .font(.headline)
                .foregroundStyle(BookPalette.ink)

            if PublicMarginsAPI.isAvailable {
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
                .bookToggleSound(publicMarginsIncomingOptIn)

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
                .bookToggleSound(publicMarginsOutgoingOptIn)
            } else {
                Text("Shut for now. Your Book stays yours. Anything you already sent can still come back.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
            }

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
            .bookToggleSound(isEnabled)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var sealEngaged = false
    @State private var isRemoving = false

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

    /// Shorter than a full surface card's 96pt, because a row is a smaller
    /// object under the thumb: the travel stays proportionate to what is
    /// being pushed, even though the feel of committing is the same.
    private let dismissThreshold: CGFloat = 82
    private let horizontalDragRatio: CGFloat = 1.6

    /// How far into the dismissal the drag has travelled, 0…1.
    private var dragProgress: CGFloat {
        min(1, abs(min(0, dragOffset)) / dismissThreshold)
    }

    /// True exactly when letting go now would remove the scrap.
    private var wouldDismissOnRelease: Bool {
        dragProgress >= 1
    }

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
            BookMarginReveal(
                label: "Remove",
                dragProgress: dragProgress,
                sealed: wouldDismissOnRelease,
                minHeight: 92
            )

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
                        performRemoval()
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
            updateSealEngagement()
            return
        }
        dragOffset = min(0, value.translation.width)
        updateSealEngagement()
    }

    /// Fires once on each crossing of the commit threshold, in either
    /// direction, never per frame, or the drag would buzz continuously.
    private func updateSealEngagement() {
        let engaged = wouldDismissOnRelease
        guard engaged != sealEngaged else { return }
        sealEngaged = engaged
        BookFeedback.sealTick(engaged: engaged)
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
            performRemoval()
        } else {
            sealEngaged = false
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

    private func performRemoval() {
        guard !isRemoving else { return }
        isRemoving = true
        BookFeedback.play(.dismissPage)
        sealEngaged = false
        if reduceMotion {
            dragOffset = 0
            onRemove()
            isRemoving = false
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            dragOffset = -500
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onRemove()
            dragOffset = 0
            isRemoving = false
        }
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

            Text("One rhyme. One long memory. One page the Stacks chose purely to stop me getting predictable.")
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

            // Below the ritual ending, never above it: the Book gets the last
            // word on the day, and then asks one thing in a quieter voice.
            if let question = details.backwardQuestion {
                Divider()
                    .overlay(visualStyle.accent.opacity(0.28))
                    .padding(.top, 4)
                Text(question)
                    .font(.system(.footnote, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(inkVisible ? 1 : 0)
            }
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

    /// A file that cannot be loaded is not shown as a broken picture: there is simply no thumbnail.
    /// A library photo may still be arriving, so only it keeps its placeholder.
    var body: some View {
        let image = self.image
        if asset.kind != .photoLibraryAsset && image == nil { EmptyView() }
        else { thumbnail(image: image) }
    }

    private func thumbnail(image: Image?) -> some View {
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
            if let uiImage = BookRenderedImageCache.shared.image(for: asset.reference) {
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

                Text("Weekly Literary Magazine")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BookPalette.ink)

                Text(artifact.issue.resolvedEditorialTitle)
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
        .accessibilityLabel("Kept Weekly Issue No. \(artifact.issue.number), \(artifact.issue.resolvedEditorialTitle), \(artifact.issue.dateRange)")
        .accessibilityHint("Opens the saved weekly issue.")
        .bookCardHover()
    }
}

// The ground under these two cards is always paper — a parchment card
// against the night, an entry on a leaf — so their gilt is bronze on
// both. Lamp gold was tuned for the dark and washed out here even before
// the shelves became leaves.
struct MonthlyEditionArchiveCard: View {
    let artifact: KeptMonthlyEditionArtifact
    let onOpen: () -> Void

    private var isInscriptionEdition: Bool {
        artifact.monthKey == "first-door" || artifact.edition.isInscriptionEdition
    }

    private var isSeasonalEdition: Bool {
        artifact.edition.publicationKind == .seasonal
    }

    private var editionKindLabel: String {
        if isInscriptionEdition { return "FIRST EDITION" }
        if isSeasonalEdition { return "SEASONAL VOLUME" }
        return "CHAPTER \(artifact.edition.chapterNumber)"
    }

    private var editionTitle: String {
        if isInscriptionEdition { return "The Inscription" }
        if isSeasonalEdition { return "Seasonal Edition" }
        return "Monthly Edition"
    }

    private var editionSubtitle: String {
        if isInscriptionEdition { return artifact.edition.subtitle }
        if isSeasonalEdition { return artifact.edition.monthName }
        return artifact.monthLabel
    }

    var body: some View {
        Button {
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(editionKindLabel)
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(LeafInk.gold)

                Text(editionTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BookPalette.ink)

                Text(editionSubtitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .lineLimit(2)

                Text(isInscriptionEdition
                    ? "Four signatures · one threshold"
                    : "\(artifact.edition.pageCount) \(artifact.edition.pageCount == 1 ? "page" : "pages") · \(artifact.edition.dayCount) \(artifact.edition.dayCount == 1 ? "day" : "days")")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .lineLimit(2)

                Spacer(minLength: 0)

                Text("Kept · Read edition")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(LeafInk.gold)
            }
            .padding(14)
            .frame(width: 240, height: 170, alignment: .topLeading)
            .parchmentSurface(accent: BookPalette.lampGold, isActive: false)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.bookPress())
        .accessibilityLabel(
            isInscriptionEdition
                ? "Kept First Edition, The Inscription"
                : (isSeasonalEdition
                    ? "Kept Seasonal Edition, \(editionSubtitle)"
                    : "Kept Monthly Edition, \(artifact.monthLabel)")
        )
        .accessibilityHint("Opens the saved PDF.")
        .bookCardHover()
    }
}

struct AnnualEditionArchiveCard: View {
    let artifact: KeptAnnualEditionArtifact
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("BOUND ANNUAL")
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(LeafInk.gold)

                Text("The \(artifact.edition.year) Annual")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BookPalette.ink)

                Text(artifact.edition.resolvedCoverLine())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .lineLimit(2)

                Text("\(artifact.edition.chapters.count) \(artifact.edition.chapters.count == 1 ? "chapter" : "chapters") · \(artifact.edition.pageCount) \(artifact.edition.pageCount == 1 ? "page" : "pages")")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .lineLimit(2)

                Spacer(minLength: 0)

                Text("Kept · Read annual")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(LeafInk.gold)
            }
            .padding(14)
            .frame(width: 240, height: 170, alignment: .topLeading)
            .parchmentSurface(accent: BookPalette.lampGold, isActive: false)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.bookPress())
        .accessibilityLabel("Kept annual, \(artifact.edition.resolvedCoverLine())")
        .accessibilityHint("Opens the saved annual PDF.")
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

/// A marginal drawing that breathes: a slow swell and a sway, forever.
///
/// The breath runs in the render server (see `AmbientInkView`), not in
/// SwiftUI. Held still, it stops where it is.
struct LivingMarginaliaImage: View {
    let name: String
    let width: CGFloat
    var opacity: Double = 0.28
    var glow = false
    var isPaused = false
    /// Degrees of gentle side-to-side sway riding the breath cycle.
    var sway: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var moves: Bool {
        #if DEBUG
        if PerfProbeSwitches.shared.stillMarginalia { return false }
        #endif
        return !reduceMotion
    }

    var body: some View {
        let aspect = AmbientInkView.aspectRatio(of: name)
        BreathingInk(
            name: name,
            opacity: opacity,
            glow: glow,
            sway: sway,
            moves: moves,
            isHeld: isPaused
        )
        .frame(width: width, height: width * aspect)
    }
}

private struct BreathingInk: UIViewRepresentable {
    let name: String
    let opacity: Double
    let glow: Bool
    let sway: Double
    let moves: Bool
    let isHeld: Bool

    private static let period: CFTimeInterval = 4.8

    func makeUIView(context: Context) -> AmbientInkView {
        AmbientInkView()
    }

    func updateUIView(_ view: AmbientInkView, context: Context) {
        // The original drawing, resampled once by the render server on its
        // way to the screen, as SwiftUI did. Shrunk to size first and then
        // turned by the breath, it was resampled twice and the quill lost 42%
        // of its edge detail and the stamp 32%.
        view.content = .fitted(name: name)
        view.ink.opacity = Float(opacity)
        let radians = CGFloat(sway * .pi / 180)
        let rest = CATransform3DRotate(CATransform3DMakeScale(0.995, 0.995, 1), -radians, 0, 0, 1)
        let swell = CATransform3DRotate(CATransform3DMakeScale(1.025, 1.025, 1), radians, 0, 0, 1)
        view.ink.shadowColor = UIColor(BookPalette.lampGold).cgColor
        view.ink.shadowOffset = .zero
        view.ink.shadowOpacity = glow ? 0.22 : 0.12
        view.ink.shadowRadius = glow ? 8 : 3
        view.ink.transform = rest

        guard moves else {
            view.run(nil, isHeld: isHeld)
            return
        }
        var parts: [CAAnimation] = []
        let breath = CABasicAnimation(keyPath: "transform")
        breath.fromValue = NSValue(caTransform3D: rest)
        breath.toValue = NSValue(caTransform3D: swell)
        parts.append(breath)
        if glow {
            let glowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
            glowOpacity.fromValue = 0.22
            glowOpacity.toValue = 0.45
            let glowRadius = CABasicAnimation(keyPath: "shadowRadius")
            glowRadius.fromValue = 8
            glowRadius.toValue = 16
            parts += [glowOpacity, glowRadius]
        }
        let group = CAAnimationGroup()
        group.animations = parts
        group.duration = Self.period
        view.run(
            AmbientInkView.forever(group),
            signature: "breath|\(sway)|\(glow)",
            isHeld: isHeld
        )
    }
}

/// A whisper of Ken Burns: endless slow scale-and-drift breathing for a
/// picture that fills its frame. The minimum scale keeps a few points of
/// overflow in reserve so the picture never pulls away from its clip edges.
///
/// Runs in the render server, like `LivingMarginaliaImage`; the caller clips.
struct AmbientKenBurnsImage: View {
    let name: String
    var minScale: CGFloat = 1.03
    var maxScale: CGFloat = 1.06
    var drift: CGSize = CGSize(width: 4, height: 2)
    var period: Double = 18
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var moves: Bool {
        #if DEBUG
        if PerfProbeSwitches.shared.stillKenBurns { return false }
        #endif
        return !reduceMotion
    }

    var body: some View {
        KenBurnsInk(
            name: name,
            minScale: minScale,
            maxScale: maxScale,
            drift: drift,
            period: period,
            moves: moves,
            isHeld: isPaused
        )
    }
}

private struct KenBurnsInk: UIViewRepresentable {
    let name: String
    let minScale: CGFloat
    let maxScale: CGFloat
    let drift: CGSize
    let period: Double
    let moves: Bool
    let isHeld: Bool

    func makeUIView(context: Context) -> AmbientInkView {
        AmbientInkView()
    }

    func updateUIView(_ view: AmbientInkView, context: Context) {
        view.content = .filling(name: name)
        guard moves else {
            view.ink.transform = CATransform3DIdentity
            view.run(nil, isHeld: isHeld)
            return
        }
        // Scale about the centre, then drift: the order SwiftUI's
        // `scaleEffect` then `offset` applied them in.
        func pose(scale: CGFloat, direction: CGFloat) -> CATransform3D {
            CATransform3DConcat(
                CATransform3DMakeScale(scale, scale, 1),
                CATransform3DMakeTranslation(drift.width * direction, drift.height * direction, 0)
            )
        }
        let from = pose(scale: minScale, direction: -1)
        view.ink.transform = from
        let wander = CABasicAnimation(keyPath: "transform")
        wander.fromValue = NSValue(caTransform3D: from)
        wander.toValue = NSValue(caTransform3D: pose(scale: maxScale, direction: 1))
        wander.duration = period
        view.run(
            AmbientInkView.forever(wander),
            signature: "kenburns|\(minScale)|\(maxScale)|\(drift.width)|\(drift.height)|\(period)",
            isHeld: isHeld
        )
    }
}

/// Ambient motion the render server runs by itself.
///
/// A SwiftUI `repeatForever` animation is recomputed on the main thread every
/// frame for as long as it runs. On an iPhone 15, Book Today sat at about
/// 130 ms of main thread per second with nobody touching it, and spent 3 to
/// 4 ms of every scrolled frame, nearly all of it on its breathing marginalia
/// and drifting banner. As a layer animation the same motion costs the main
/// thread nothing once it has started.
///
/// Holding still freezes the motion where it is. SwiftUI could only snap it
/// back to rest, which on the banner was a jump of up to a tenth of its size.
final class AmbientInkView: UIView {
    enum Content: Equatable {
        /// Fitted to the view.
        case fitted(name: String)
        /// Filling the view, cropped by whoever holds it.
        case filling(name: String)
    }

    /// The layer that moves. The view's own layer belongs to SwiftUI.
    let ink = CALayer()

    var content: Content? {
        didSet {
            guard content != oldValue else { return }
            ink.contents = nil
            setNeedsLayout()
        }
    }

    private var motion: CAAnimation?
    private var signature: String?
    private var isHeld = false
    private static let motionKey = "ambient"

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        // Every property here is set by hand or animated on purpose; none of
        // them should pick up Core Animation's implicit quarter-second fade.
        let still = NSNull()
        ink.actions = [
            "bounds": still, "position": still, "contents": still, "transform": still, "opacity": still,
            "shadowOpacity": still, "shadowRadius": still, "shadowColor": still, "shadowOffset": still
        ]
        layer.addSublayer(ink)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resumeAfterBackground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    static func aspectRatio(of name: String) -> CGFloat {
        guard let size = UIImage(named: name)?.size, size.width > 0 else { return 1 }
        return size.height / size.width
    }

    /// The same motion there and back again, for as long as the layer lives.
    static func forever(_ animation: CAAnimation) -> CAAnimation {
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.autoreverses = true
        animation.repeatCount = .infinity
        // Belt and braces with `resumeAfterBackground`: nothing about a trip
        // to the background or out of the window may leave the ink still.
        animation.isRemovedOnCompletion = false
        return animation
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ink.bounds = CGRect(origin: .zero, size: bounds.size)
        ink.position = CGPoint(x: bounds.midX, y: bounds.midY)
        guard ink.contents == nil, let content else { return }
        switch content {
        case let .fitted(name):
            ink.contentsGravity = .resizeAspect
            ink.contents = UIImage(named: name)?.cgImage
        case let .filling(name):
            ink.contentsGravity = .resizeAspectFill
            ink.contents = UIImage(named: name)?.cgImage
        }
    }

    /// Starts, holds or drops the motion. `signature` names the motion, so a
    /// SwiftUI update that describes the same breath leaves the running one
    /// alone instead of restarting it from rest.
    func run(_ motion: CAAnimation?, signature: String? = nil, isHeld: Bool) {
        guard let motion else {
            ink.removeAnimation(forKey: Self.motionKey)
            self.motion = nil
            self.signature = nil
            ink.speed = 1
            ink.timeOffset = 0
            ink.beginTime = 0
            self.isHeld = isHeld
            return
        }
        if signature != self.signature || ink.animation(forKey: Self.motionKey) == nil {
            self.motion = motion
            self.signature = signature
            ink.speed = 1
            ink.timeOffset = 0
            ink.beginTime = 0
            ink.add(motion, forKey: Self.motionKey)
            // Held from the moment it arrived, it is caught on its first
            // frame, which is its rest pose, until it is let go.
            self.isHeld = false
        }
        hold(isHeld)
    }

    private func hold(_ held: Bool) {
        defer { isHeld = held }
        if held, ink.speed != 0, ink.animation(forKey: Self.motionKey) != nil {
            let now = ink.convertTime(CACurrentMediaTime(), from: nil)
            ink.speed = 0
            ink.timeOffset = now
        } else if !held {
            if ink.animation(forKey: Self.motionKey) == nil, let motion {
                ink.add(motion, forKey: Self.motionKey)
            }
            guard ink.speed == 0 else { return }
            let frozenAt = ink.timeOffset
            ink.speed = 1
            ink.timeOffset = 0
            ink.beginTime = 0
            ink.beginTime = ink.convertTime(CACurrentMediaTime(), from: nil) - frozenAt
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { resumeAfterBackground() }
    }

    @objc private func resumeAfterBackground() {
        guard let motion, ink.animation(forKey: Self.motionKey) == nil, !isHeld else { return }
        ink.add(motion, forKey: Self.motionKey)
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
                .foregroundStyle(authority.isEnabled
                    ? AnyShapeStyle(MaterialInk.gilt)
                    : AnyShapeStyle(MaterialInk.text.opacity(0.48)))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("My Hands")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MaterialInk.text.opacity(0.9))
                Text(statusLine)
                    .font(.caption2)
                    .foregroundStyle(MaterialInk.text.opacity(0.62))
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
                        .stroke(MaterialInk.text.opacity(0.1), lineWidth: 0.7)
                )
        )
    }

    private var statusLine: String {
        guard authority.isEnabled else {
            return "The house keys are outside my covers. Open the pact if you want me meddling in an ordinary hour."
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
                        .bookToggleSound(draft.isEnabled)
                } header: {
                    Text("A standing pact")
                } footer: {
                    Text("You mark the doors and the appetite. I choose the moment, or let one of the cast choose badly. Snatch the keys back whenever you want; I know what a locked door means.")
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
                            .bookToggleSound(draft.allowsCalendarOpenings)
                        Toggle("Use a governed whisper seat", isOn: $draft.allowsNotificationSummons)
                            .tint(BookPalette.lampGold)
                            .bookToggleSound(draft.allowsNotificationSummons)
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
            .navigationTitle("My Hands")
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
/// it: a dog-ear, a guarded ribbon, a sealed leaf, or a pencil correction.
/// That keeps the Book recognizable without turning it into a face or mascot.
struct BookPresenceSilhouette: View {
    let stance: BookStance
    let interior: BookInteriorState
    var greyIsInsideCover = false
    var isPaused = false
    let onKnock: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didArrive = false
    @State private var isKnocking = false

    private var mark: BookMaterialMark {
        .current(in: interior, greyIsInsideCover: greyIsInsideCover)
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
        case .curious: disposition = "listening with my cover slightly raised"
        case .protective: disposition = "keeping my covers close"
        case .mischievous: disposition = "sitting crooked and hiding something"
        case .hushed: disposition = "resting quietly"
        case .contrite: disposition = "holding a correction in pencil"
        case .intent: disposition = "holding my place with care"
        case .pleased: disposition = "settled and quietly pleased"
        }

        let evidence: String
        switch mark {
        case .greyScar: evidence = " One of my edges has gone pale where familiarity got in."
        case .sealedLeaf: evidence = " A sealed leaf is showing."
        case .dogEar: evidence = " One of my corners is dog-eared."
        case .keepingWatch: evidence = " My ribbon's keeping an unfinished promise."
        case .revision: evidence = " A pencil correction crosses my cover."
        case .mischief: evidence = " A crooked pencil mark has escaped across my cover."
        case .longGame: evidence = " My ribbon marks a longer piece of business."
        case .unmarked: evidence = ""
        }
        return "I'm \(disposition).\(evidence)"
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
        case .greyScar:
            ZStack {
                Rectangle()
                    .fill(BookPalette.paper.opacity(0.82))
                    .frame(width: 7, height: 58)
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
                    .foregroundStyle(BookPalette.ink.opacity(0.45))
                    .frame(width: 4, height: 52)
            }
            .rotationEffect(.degrees(2))
            .offset(x: 2, y: 4)
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
        case .mischief:
            Image(systemName: "scribble.variable")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(BookPalette.paper.opacity(0.86))
                .rotationEffect(.degrees(-12))
                .offset(x: -9, y: 16)
        case .longGame:
            Image(systemName: "map.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(BookPalette.lampGold)
                .padding(4)
                .background(BookPalette.nightPanel.opacity(0.94), in: Circle())
                .overlay { Circle().stroke(BookPalette.lampGold.opacity(0.58), lineWidth: 0.8) }
                .offset(x: -11, y: 41)
        case .unmarked:
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

struct BookDogEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// A literal folded corner, large enough to read as something the Book did
/// rather than as a bookmark icon describing the idea of a dog-ear.
struct BookInterjectionDogEarMark: View {
    var tint: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BookDogEar()
                .fill(BookPalette.paper)
                .shadow(color: BookPalette.ink.opacity(0.28), radius: 2, x: -2, y: 2)
            BookDogEar()
                .stroke(tint.opacity(0.78), lineWidth: 1.2)
            Path { path in
                path.move(to: CGPoint(x: 2, y: 2))
                path.addLine(to: CGPoint(x: 48, y: 48))
            }
            .stroke(tint.opacity(0.46), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
        .allowsHitTesting(false)
    }
}

/// Ink transferred by a paw or thumb. It intentionally has no label: the mark
/// is the interjection.
struct BookInterjectionSmudgeMark: View {
    var tint: Color

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(tint.opacity(0.055 + Double(index % 3) * 0.025))
                    .frame(width: CGFloat(18 + index * 3), height: CGFloat(5 + index % 2))
                    .rotationEffect(.degrees(Double(index * 11 - 28)))
                    .offset(
                        x: CGFloat((index % 3) * 7 - 7),
                        y: CGFloat(index * 8 - 24)
                    )
            }
        }
        .blur(radius: 0.55)
    }
}

/// Two leaves refusing to close flush: a returned Page made physical.
struct BookInterjectionOpenLeafMark: View {
    var tint: Color

    var body: some View {
        HStack(spacing: -5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(BookPalette.paper)
                .overlay { RoundedRectangle(cornerRadius: 2).stroke(tint.opacity(0.52), lineWidth: 0.8) }
                .rotationEffect(.degrees(-7), anchor: .bottomTrailing)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(BookPalette.paper)
                .overlay { RoundedRectangle(cornerRadius: 2).stroke(tint.opacity(0.52), lineWidth: 0.8) }
                .rotationEffect(.degrees(7), anchor: .bottomLeading)
        }
        .shadow(color: BookPalette.ink.opacity(0.22), radius: 2, y: 1)
    }
}

/// The same physical book carries onboarding and everyday launch. The wrappers
/// own their timing; this view owns the cover, hinge, lit inner page, and sparks
/// so the two transitions cannot quietly drift into different visual languages.
private struct FallingBookArtwork: View {
    let width: CGFloat
    let height: CGFloat
    let monthlyCover: PagesRisingMonthlyCover?
    let coverTitleLines: [String]
    let coverReaderName: String?
    let insideTitle: String
    let titleWrite: Double
    let open: Double
    let idleTime: TimeInterval

    init(
        width: CGFloat,
        height: CGFloat,
        monthlyCover: PagesRisingMonthlyCover? = nil,
        coverTitleLines: [String],
        coverReaderName: String? = nil,
        insideTitle: String,
        titleWrite: Double,
        open: Double,
        idleTime: TimeInterval
    ) {
        self.width = width
        self.height = height
        self.monthlyCover = monthlyCover
        self.coverTitleLines = coverTitleLines
        self.coverReaderName = coverReaderName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.insideTitle = insideTitle
        self.titleWrite = titleWrite
        self.open = open
        self.idleTime = idleTime
    }

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
            if let monthlyCover {
                // Everyday launch is the same physical Book as Pages Rising.
                // Reuse its actual cover face so the monthly selector has one
                // downstream rendering path, including all cover copy.
                FolioMonthlyCoverView(cover: monthlyCover)
            } else {
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

                    if let coverReaderName {
                        Text("FOR \(coverReaderName.uppercased())")
                            .font(.system(size: min(width * 0.052, 12), weight: .bold, design: .serif))
                            .tracking(1.15)
                            .foregroundStyle(BookPalette.lampGold.opacity(0.88))
                            .lineLimit(2)
                            .minimumScaleFactor(0.66)
                            .frame(maxWidth: max(1, width - 58))
                            .opacity(faceOpacity * titleWrite)
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
    let cover: PagesRisingMonthlyCover
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
                    monthlyCover: cover,
                    coverTitleLines: ["ReEnchanted"],
                    insideTitle: "I REMEMBERED",
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
    let cover: PagesRisingMonthlyCover
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
                cover: cover,
                phase: phase,
                showsLoadingCue: didReachHold && revealStartElapsed == nil
            )
            .contentShape(Rectangle())
            .onTapGesture {
                fastForwardToHold()
            }
            .onChange(of: isReadyToReveal) { _, ready in
                guard ready else { return }
                beginRevealIfPossible()
            }
        }
        .ignoresSafeArea()
        .task {
            // Thresholding a TimelineView's continuously changing Double in
            // `onChange` can feed state back into the same render frame. SwiftUI
            // correctly reports that as an invalid update loop. The clock still
            // paints every intermediate frame; these two tasks only ring the
            // hold and finish bells once.
            BookSoundBank.overture(.appear)
            try? await Task.sleep(for: .seconds(leadInDuration))
            guard !Task.isCancelled else { return }
            reachHold()
        }
        .task(id: revealStartElapsed) {
            guard revealStartElapsed != nil, !didFinish else { return }
            try? await Task.sleep(for: .seconds(revealDuration))
            guard !Task.isCancelled else { return }
            finish()
        }
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
        BookSoundBank.overture(.open)
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
    let readerName: String?
    let onFinished: () -> Void

    init(readerName: String? = nil, onFinished: @escaping () -> Void) {
        self.readerName = readerName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.onFinished = onFinished
    }

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
                        coverReaderName: readerName,
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
        .accessibilityLabel("I open beneath you. Cold ink crosses your fingers. Stories rush past in salt, heat, snow, and sound. There is no down, only chapters. Stone catches you inside the library.")
        .accessibilityHint("Double-tap to skip the fall through the Book.")
        .accessibilityAddTraits(.isButton)
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        BookFeedback.play(.openPage, fill: true)
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

    // A still stage, so it is finished as one picture. Left as layers, its
    // four blended washes were recomposited under every frame of anything that
    // scrolled or moved above it.
    var body: some View {
        stage
            .drawingGroup()
            .ignoresSafeArea()
    }

    private var stage: some View {
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
            // The Book now carries the living motion. Its surrounding room is
            // intentionally a still stage, avoiding a perpetual wallpaper
            // timeline while preserving the same labyrinth and star field.
            driftingBackdrop(at: Date(timeIntervalSinceReferenceDate: 0))
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
    /// The red the plate renderers already use for corner marks and closing
    /// lines. Reserved for things overprinted on a page rather than written
    /// into it: a warning, a stamp, a correction.
    static let rubricRed = Color(red: 0.54, green: 0.12, blue: 0.13)
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
        // The front pages of a book share the binding's own colours.
        case .taleBound, .inventory, .bindery, .frontMatter:
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
            // watermark: the feel of a lesson under way.
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
            // faintest watermark. The unprompted door should not look enchanted
            // before the reader has given the Book anything.
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
        case .bookAside:
            return PageVisualStyle(
                accent: Color(red: 0.55, green: 0.24, blue: 0.27),
                symbolColor: Color(red: 0.55, green: 0.24, blue: 0.27),
                paperTop: Color(red: 0.95, green: 0.86, blue: 0.72),
                paperMiddle: Color(red: 0.84, green: 0.69, blue: 0.57),
                paperBottom: Color(red: 0.57, green: 0.40, blue: 0.40),
                scrapColor: Color(red: 0.87, green: 0.73, blue: 0.61),
                sideMarginalia: "IlluminationScrapS03_21",
                cornerMarginalia: "IlluminationScrapS01_16",
                smallMarginalia: "IlluminationScrapS03_08",
                watermarkMarginalia: "MarginaliaSeal",
                sideMarginaliaWidth: 70,
                cornerMarginaliaWidth: 84,
                sideMarginaliaOpacity: 0.44,
                cornerMarginaliaOpacity: 0.38,
                watermarkOpacity: 0.13,
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
        // Older paper than a feast day, and a colder ink: a Spell is copied out
        // of somebody else's practice rather than announced by the calendar.
        case .spell:
            return PageVisualStyle(
                accent: Color(red: 0.34, green: 0.30, blue: 0.52),
                symbolColor: Color(red: 0.52, green: 0.40, blue: 0.22),
                paperTop: Color(red: 0.94, green: 0.89, blue: 0.76),
                paperMiddle: Color(red: 0.86, green: 0.79, blue: 0.63),
                paperBottom: Color(red: 0.66, green: 0.58, blue: 0.47),
                scrapColor: Color(red: 0.83, green: 0.77, blue: 0.62),
                sideMarginalia: "IlluminationScrapS01_15",
                cornerMarginalia: "IlluminationScrapS03_24",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaSeal"
            )
        case .recipe:
            // A page out of somebody's kitchen: flour, copper, a little grease.
            return PageVisualStyle(
                accent: Color(red: 0.62, green: 0.34, blue: 0.20),
                symbolColor: Color(red: 0.70, green: 0.44, blue: 0.22),
                paperTop: Color(red: 0.97, green: 0.93, blue: 0.84),
                paperMiddle: Color(red: 0.90, green: 0.84, blue: 0.70),
                paperBottom: Color(red: 0.72, green: 0.62, blue: 0.48),
                scrapColor: Color(red: 0.88, green: 0.81, blue: 0.66),
                sideMarginalia: "IlluminationScrapS01_15",
                cornerMarginalia: "IlluminationScrapS03_24",
                smallMarginalia: "MarginaliaStar",
                watermarkMarginalia: "MarginaliaSeal"
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

/// A loose piece of handmade paper. Unlike a bound folio leaf, no edge is a
/// spine, so all four sides wander. Shared by transient scraps and other Book
/// matter that must not fall back into rounded-card geometry.
struct DeckledPaperScrapShape: Shape {
    var seed: Int
    var amplitude: CGFloat = 1.8

    func path(in rect: CGRect) -> Path {
        let inset = amplitude * 1.5
        let steps = 16

        func jitter(_ salt: Int) -> CGFloat {
            let mixed = UInt(bitPattern: seed &* 2_654_435_761 &+ salt &* 40_503)
            return (CGFloat(mixed % 1_001) / 1_000 - 0.5) * 2 * amplitude
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset + jitter(0)))

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.minX + inset + (rect.width - inset * 2) * t,
                y: rect.minY + inset + jitter(step &+ 11)
            ))
        }
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.maxX - inset + jitter(step &+ 101),
                y: rect.minY + inset + (rect.height - inset * 2) * t
            ))
        }
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.maxX - inset - (rect.width - inset * 2) * t,
                y: rect.maxY - inset + jitter(step &+ 211)
            ))
        }
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.minX + inset + jitter(step &+ 307),
                y: rect.maxY - inset - (rect.height - inset * 2) * t
            ))
        }

        path.closeSubpath()
        return path
    }
}

/// How a piece of parchment was cut. The material underneath — colour, fibre
/// map, grain, edge strokes — is the same whichever cut is used, so a Page
/// opened full-height is made of literally the same paper as the leaf it came
/// from rather than of something that resembles it.
enum ParchmentSurfaceCut: Shape {
    case rounded
    case looseDeckle(seed: Int)
    /// A whole leaf lifted out of the Book: a slow hand-cut wander sized for an
    /// edge the height of the screen. See `OpenedLeafEdgeShape`.
    case openedLeaf(seed: Int)

    func path(in rect: CGRect) -> Path {
        switch self {
        case .rounded:
            return RoundedRectangle(cornerRadius: 8, style: .continuous).path(in: rect)
        case .looseDeckle(let seed):
            return DeckledPaperScrapShape(seed: seed).path(in: rect)
        case .openedLeaf(let seed):
            return OpenedLeafEdgeShape(seed: seed).path(in: rect)
        }
    }
}

private struct ParchmentSurface: ViewModifier {
    let accent: Color
    var style: PageVisualStyle?
    var paperStock: LeafPaperStock?
    var textureSeed: Int
    var cut: ParchmentSurfaceCut
    let isActive: Bool
    /// A parchment *card* is a way of making a slip of paper stand out against
    /// the night. Written on a leaf it would be paper laid on paper, so a card
    /// that yields becomes an entry set into the page instead: a rule beneath
    /// it, and a rule down its edge when it is the active one. Leaves themselves
    /// never yield; only the card API sets this.
    var yieldsToPaper = false

    @Environment(\.bookSurfaceMaterial) private var material


    private var resolved: PageVisualStyle {
        style ?? {
            var fallback = PageVisualStyle.default
            fallback.accent = accent
            fallback.symbolColor = accent
            return fallback
        }()
    }

    private var paper: ParchmentMaterial {
        ParchmentMaterial(
            style: resolved,
            paperStock: paperStock,
            textureSeed: textureSeed,
            isActive: isActive
        )
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if yieldsToPaper && material == .paper {
            entry(content)
        } else {
            parchment(content)
        }
    }

    private func entry(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                LeafRule(seed: textureSeed &+ 3, tint: BookPalette.ink, opacity: 0.16)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .leading) {
                if isActive {
                    Rectangle()
                        .fill(MaterialInk.accent(accent).opacity(0.5))
                        .frame(width: 1.5)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
    }

    private func parchment(_ content: Content) -> some View {
        let paper = self.paper
        return content
            .background {
                paper.fill(cut)
                    .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
            }
            .overlay {
                paper.fiber()
                    .clipShape(cut)
            }
            .overlay {
                paper.grain()
                    .clipShape(cut)
            }
            .overlay {
                paper.edgeStroke(cut)
            }
            .overlay {
                paper.accentStroke(cut)
            }
            .overlay {
                paper.moonwriteGlow(cut)
            }
            .shadow(color: paper.glowColor, radius: paper.glowRadius, x: 0, y: 0)
    }
}

/// The parchment itself, layer by layer.
///
/// `parchmentSurface` stacks these layers around a card or a folio leaf. An
/// opened leaf holds a scroll view, so it stacks the very same layers another
/// way, where nothing the reader scrolls is redrawn through them (see
/// `OpenedLeafPaper`). One material, two arrangements: a Page opened out of the
/// Book is still made of literally the same paper as the leaf it came from.
struct ParchmentMaterial {
    let style: PageVisualStyle
    var paperStock: LeafPaperStock?
    var textureSeed: Int
    var isActive: Bool

    /// How strongly the stock's fibre shows: the stock's own weight, scaled by
    /// how fibrous this Page type's paper is meant to be.
    var fiberOpacity: Double {
        let base: Double
        if let paperStock {
            let styleScale = style.fiberOpacity / PageVisualStyle.default.fiberOpacity
            base = min(0.34, paperStock.baseOpacity * styleScale)
        } else {
            base = style.fiberOpacity
        }
        return isActive ? base : max(0.10, base * 0.62)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let mixed = textureSeed &+ salt &* 5_003
        let raw = UInt(bitPattern: mixed.stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }

    /// The Page type's parchment colour, cut to shape.
    func fill(_ cut: ParchmentSurfaceCut) -> some View {
        cut.fill(
            LinearGradient(
                colors: [
                    style.paperTop,
                    style.paperMiddle,
                    style.paperBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    /// The stock's fibre map, multiplied into whatever lies beneath it. It
    /// overhangs its frame a little on purpose; whoever lays it down cuts it.
    /// Unmultiplied, it is the veil the overhang leaves over whatever is not
    /// paper.
    func fiber(multipliesIntoPage: Bool = true) -> some View {
        Image(paperStock?.assetName ?? "ParchmentFiber")
            .resizable()
            .scaledToFill()
            // Material maps stay colourless. The Page type's parchment
            // gradient beneath them remains the source of paper colour.
            .saturation(0)
            .contrast(1.06)
            .scaleEffect(1.055)
            .rotationEffect(.degrees(Double(unit(11) - 0.5) * 1.2))
            .offset(
                x: (unit(13) - 0.5) * 12,
                y: (unit(17) - 0.5) * 12
            )
            .opacity(fiberOpacity)
            .blendMode(.multiply)
    }

    func grain() -> some View {
        ParchmentGrain()
            .fill(BookPalette.ink.opacity(style.grainOpacity))
    }

    func edgeStroke(_ cut: ParchmentSurfaceCut) -> some View {
        cut
            .stroke(BookPalette.parchmentEdge.opacity(0.38), lineWidth: 1)
    }

    func accentStroke(_ cut: ParchmentSurfaceCut) -> some View {
        cut
            .stroke(style.accent.opacity(isActive ? 0.48 : 0.22), lineWidth: 1)
            .padding(2)
    }

    @ViewBuilder
    func moonwriteGlow(_ cut: ParchmentSurfaceCut) -> some View {
        if style.moonwriteGlow {
            MoonwriteParchmentGlow(accent: style.accent, isActive: isActive)
                .clipShape(cut)
                .allowsHitTesting(false)
        }
    }

    /// The moonwrite halo around the whole sheet. Clear on every other paper.
    var glowColor: Color {
        style.moonwriteGlow ? style.accent.opacity(isActive ? 0.46 : 0.26) : .clear
    }

    var glowRadius: CGFloat {
        style.moonwriteGlow ? (isActive ? 22 : 12) : 0
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
        modifier(ParchmentSurface(
            accent: accent,
            style: nil,
            paperStock: nil,
            textureSeed: 0,
            cut: .rounded,
            isActive: isActive,
            yieldsToPaper: true
        ))

    }

    func parchmentSurface(
        style: PageVisualStyle,
        paperStock: LeafPaperStock? = nil,
        textureSeed: Int = 0,
        cut: ParchmentSurfaceCut = .rounded,
        isActive: Bool = false
    ) -> some View {
        modifier(ParchmentSurface(
            accent: style.accent,
            style: style,
            paperStock: paperStock,
            textureSeed: textureSeed,
            cut: cut,
            isActive: isActive
        ))
    }

    func deckledPaperScrapSurface(
        accent: Color = BookPalette.gold,
        paperStock: LeafPaperStock = .ragHandmade,
        textureSeed: Int,
        isActive: Bool = false
    ) -> some View {
        modifier(ParchmentSurface(
            accent: accent,
            style: nil,
            paperStock: paperStock,
            textureSeed: textureSeed,
            cut: .looseDeckle(seed: textureSeed),
            isActive: isActive
        ))
    }

    func sectionRuneLabel() -> some View {
        self
            .font(.system(.caption, design: .serif, weight: .semibold))
            .textCase(.uppercase)
            .kerning(2)
            // Lamp gold against the night, bronze when the label is written
            // on a leaf. Resolved when drawn, from the surface it lands on.
            .foregroundStyle(MaterialInk.gilt)
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

/// Shared with the lifted leaf in `OpenedLeaf.swift`, which paints the same
/// grain over a full-height sheet.
struct ParchmentGrain: Shape {
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
        } else {
            Canvas { context, size in
                AmbientLetterFieldRenderer.draw(in: context, size: size, time: 0, reduceMotion: true)
            }
            .opacity(isPaused ? 0.24 : 0.36)
        }
    }
}

/// The Pixie's ear on the room.
///
/// She lives at the app root and the reader types inside the Book, so there has
/// to be some thread between them: an exclamation point was just written, and
/// whether the reader is still writing. She answers when their hands are free.
///
/// Deliberately not a general event bus. She is interested in one mark, and a
/// this stays specific to her appetite and the reader's writing, rather than
/// becoming a way for any view to make her dance.
@MainActor
@Observable
final class BookPixieSummons {
    static let shared = BookPixieSummons()

    /// Retained until the Book is free to answer, rather than expiring behind
    /// an editor or a sheet before the reader can possibly see her.
    private(set) var exclaimedAt: Date?
    private var writingEditors: Set<UUID> = []
    @ObservationIgnored private var acknowledgedExclamation: Date?

    var isWriting: Bool { !writingEditors.isEmpty }

    private init() {}

    /// Notice the mark during editing; do not interrupt the reader to answer it.
    func readerWroteAnExclamation() {
        exclaimedAt = Date()
    }

    func setWriting(_ writing: Bool, editorID: UUID) {
        if writing { writingEditors.insert(editorID) }
        else { writingEditors.remove(editorID) }
    }

    func takePendingExclamation() -> Bool {
        guard let exclaimedAt, exclaimedAt != acknowledgedExclamation else { return false }
        acknowledgedExclamation = exclaimedAt
        return true
    }

}

/// Where the Book is, sent up to whoever is hosting the room.
///
/// The Pixie lives at the app root so she can cross the tabs, the space below
/// the binding, and the dark around it. She still needs the Book's frame to know
/// where its furniture is, and the Book is the only view that knows that.
struct BookFrameAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// A place on the Book worth sitting on, published upward by whatever drew it.
///
/// The Pixie does not hunt for these; the Book offers them. That keeps her
/// appetite honest — she can only land on things that actually exist on the
/// page, never on a guess about where a word might be.
struct BookPixiePerch: Identifiable, Equatable {
    enum Kind: Int, Equatable {
        /// The word the sentence arrives at. Her favourite thing in the world.
        case accentWord = 3
        /// A stop, a pause, a raised voice: her whole domain.
        case punctuation = 2
        /// A mark someone else left in the margin. Worth investigating.
        case marginalia = 1
    }

    var id: String
    var kind: Kind
    var rect: CGRect
}

/// The Punctuation Pixie, out of the backdrop and into the room.
///
/// She is not decoration and never was: she is a Cast member with a portrait, a
/// scribe who signs marginalia, and a fae with her own bargains. Her domain is
/// rhythm and pause — the comma-place, the exclamation-thing — and she is the
/// one who "turned one of your periods into an ellipsis when you weren't looking,
/// and grinned about it". Everything here follows from that: what she lands on,
/// what she carries, and what she does when a reader has the nerve to touch her.
///
/// Three rules keep her a character rather than a mascot:
///
/// 1. **She ignores you.** A creature that wants attention is Clippy. She has
///    her own business and mostly attends to it.
/// 2. **She respects writing.** Editors and presentations still her; a queued
///    exclamation gets its answer after the reader finishes.
/// 3. **Her gifts are physical.** A deliberate shake or touch makes her bring
///    one readable scrap. She drops it and returns to her own business.
struct BookPixieLayer: View {
    /// Places the Book has offered her.
    var perches: [BookPixiePerch] = []
    /// Where the Book is sitting, in her coordinate space. She ranges over the
    /// whole app — tabs, the space below the binding, the room around it — and
    /// this is only how she knows where the furniture is worth landing on.
    var bookRect: CGRect = .zero
    var isPaused: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var textInputActive = false
    @State private var activeFlight: PippaDeliveryFlight?
    @State private var cardFlight: PippaDeliveryFlight?
    @State private var scrap: PippaScrap?
    @State private var deliveryTask: Task<Void, Never>?
    @State private var lastInteractionAt = Date.distantPast

    private var isUnavailable: Bool {
        isPaused || scenePhase != .active || textInputActive
            || BookPixieSummons.shared.isWriting || bookRect.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Everything her frames need, read here on the main thread once per
            // update: the summons, a startle, what she carries. Her drawing then
            // touches nothing but this value, so it can run off the main thread.
            let flight = PixieFlight(
                perches: perches,
                bookRect: bookRect,
                fleeCorner: CGPoint(x: 0.9, y: 0.12),
                startledAt: activeFlight?.startedAt,
                delivery: activeFlight
            )
            ZStack {
                if isUnavailable || reduceMotion || voiceOver {
                    // Reduced motion still gets her, simply at rest. Removing her
                    // entirely would take a character out of the room rather than
                    // calming her down.
                    Canvas { context, canvasSize in
                        flight.draw(in: context, size: canvasSize, time: 0, startle: 0)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                } else {
                    ZStack {
                        // Drawn from `flight` alone, on the main thread. Drawing her
                        // asynchronously took the surface wait (`RBLayer display →
                        // wait_image_queue`) off the main thread, but on a busy
                        // phone her frames then arrived late and her flight visibly
                        // skipped (bj, 2026-10-18), so she stays synchronous. What
                        // makes her wait is the render server's load beneath her;
                        // cut that instead (see the Glow lamp's breath).
                        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                            let now = PixieFlight.clock(timeline.date)
                            Canvas(rendersAsynchronously: Self.drawsOffMain) { context, canvasSize in
                                flight.draw(
                                    in: context,
                                    size: canvasSize,
                                    time: now,
                                    startle: flight.startleStrength(now: now)
                                )
                            }
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                        // Only she is touchable, only where she is, and only
                        // when she has settled. Its own clock, so the drawing above
                        // never waits on a view that takes touches.
                        //
                        // She ranges over the whole app now — the leaf, the
                        // bookmarks, the charms at the tail — so a target that
                        // followed her in flight would drift across every
                        // control in the Book and occasionally swallow a Keep.
                        // Catching her while she is sitting still is both the
                        // safe rule and the better one: a fae in flight should
                        // not be grabbable.
                        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                            let now = PixieFlight.clock(timeline.date)
                            if activeFlight == nil, flight.perchSettle(time: now) > 0.3 {
                                Circle()
                                    .fill(Color.clear)
                                    .contentShape(Circle())
                                    .frame(width: 48, height: 48)
                                    .position(flight.position(size: size, time: now, startle: flight.startleStrength(now: now)))
                                    .onTapGesture { deliver(kind: .touch, size: size, flight: flight) }
                                    .accessibilityLabel("Pippa Pilcrow")
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { deliver(kind: .touch, size: size, flight: flight) }
                            }
                        }
                    }
                }
                if let scrap, let cardFlight, !isUnavailable {
                    PippaMessageCard(scrap: scrap, flight: cardFlight,
                                     restsImmediately: reduceMotion || voiceOver,
                                     isReleased: activeFlight == nil,
                                     dismiss: putScrapAway)
                        .id(cardFlight.startedAt)
                }
                if (reduceMotion || voiceOver), !isUnavailable {
                    Button {
                        deliver(kind: .touch, size: size, flight: flight)
                    } label: {
                        Color.clear.frame(width: 48, height: 48).contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(flight.position(size: size, time: 0, startle: 0))
                    .accessibilityLabel("Pippa Pilcrow")
                    .accessibilityHint("Ask her for a scrap")
                }
            }
            .background {
                PippaShakeReceiver(isEnabled: !isUnavailable) {
                    deliver(kind: .shake, size: size, flight: flight)
                }
                .frame(width: 0, height: 0)
            }
            .onChange(of: isUnavailable) { _, unavailable in
                if unavailable { putScrapAway() }
                else { answerExclamation(size: size, flight: flight) }
            }
            .onAppear {
                DispatchQueue.main.async { answerExclamation(size: size, flight: flight) }
            }
            .onChange(of: BookPixieSummons.shared.exclaimedAt) { _, _ in
                answerExclamation(size: size, flight: flight)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                textInputActive = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
                textInputActive = false
                DispatchQueue.main.async { answerExclamation(size: size, flight: flight) }
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidBeginEditingNotification)) { _ in
                textInputActive = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
                textInputActive = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidEndEditingNotification)) { _ in
                textInputActive = false
                DispatchQueue.main.async { answerExclamation(size: size, flight: flight) }
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
                textInputActive = false
            }
            .onChange(of: size) { _, _ in putScrapAway() }
            .onChange(of: PippaReadingDesk.shared.reading) { _, reading in
                // A removed/edited Page must not leave an obsolete claim open.
                if let scrap, !scrap.sourcePageIDs.isEmpty,
                   !reading.scraps.contains(scrap),
                   scrap.word.flatMap({ reading.favouriteScrap(for: $0) }) != scrap {
                    putScrapAway()
                }
            }
            .onDisappear { putScrapAway() }
            .accessibilityAction(named: Text("Ask Pippa for a scrap")) {
                deliver(kind: .touch, size: size, flight: flight)
            }
        }
    }

    private func answerExclamation(size: CGSize, flight: PixieFlight) {
        guard !isUnavailable, activeFlight == nil, size.width > 100,
              !UIApplication.shared.reenchantedHasFocusedTextInput(),
              BookPixieSummons.shared.takePendingExclamation() else { return }
        deliver(kind: .exclamation, size: size, flight: flight)
    }

    private func deliver(kind: PippaDeliveryFlight.Kind, size: CGSize, flight: PixieFlight) {
        guard !isUnavailable, activeFlight == nil, size.width > 100,
              !UIApplication.shared.reenchantedHasFocusedTextInput() else { return }
        guard kind == .exclamation || Date().timeIntervalSince(lastInteractionAt) >= 8 else { return }
        deliveryTask?.cancel()
        let now = PixieFlight.clock(Date())
        let delivery = PippaDeliveryFlight(
            kind: kind, startedAt: now,
            origin: flight.position(size: size, time: now, startle: 0),
            landing: CGPoint(x: min(size.width - 25, bookRect.maxX - 18),
                             y: max(40, bookRect.minY + 50)),
            cardCentre: CGPoint(x: size.width / 2,
                                y: max(150, min(size.height - 180, bookRect.midY))),
            room: size, cardWidth: min(310, size.width - 48)
        )
        let message = kind == .exclamation ? PippaScrap.exclamation : PippaReadingDesk.shared.nextScrap()
        scrap = message
        cardFlight = delivery
        activeFlight = reduceMotion || voiceOver ? nil : delivery
        if kind != .exclamation { lastInteractionAt = Date() }
        BookFeedback.play(.tap, sound: false)
        deliveryTask = Task { @MainActor in
            if !reduceMotion && !voiceOver {
                do { try await Task.sleep(for: .seconds(PippaDeliveryFlight.duration)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            activeFlight = nil
            if voiceOver { UIAccessibility.post(notification: .announcement, argument: "Pippa says: \(message.line)") }
            deliveryTask = nil
            answerExclamation(size: size, flight: flight)
        }
    }

    private func putScrapAway() {
        deliveryTask?.cancel()
        deliveryTask = nil
        activeFlight = nil
        cardFlight = nil
        scrap = nil
    }

    /// DEBUG `--perf-pixie-async` draws her off the main thread, to measure
    /// against. Off by default: see the note in `body`.
    private static var drawsOffMain: Bool {
        #if DEBUG
        return PerfProbeSwitches.shared.pixieDrawsOffMain
        #else
        return false
        #endif
    }
}

/// The Pixie's motion and drawing, as a plain value.
///
/// `BookPixieLayer` builds one of these on the main thread each time it updates
/// and her canvas draws from it alone. Nothing in here reads view state, the
/// environment or the summons singleton, which is what lets her frames be drawn
/// off the main thread. The motion and the drawing are unchanged; they moved
/// here from the view on 2026-10-18.
struct PixieFlight {
    var perches: [BookPixiePerch]
    var bookRect: CGRect
    var fleeCorner: CGPoint
    var startledAt: TimeInterval?
    var delivery: PippaDeliveryFlight?

    /// The light she carries.
    private static let lamp = Color(red: 1.0, green: 0.90, blue: 0.68)
    /// The cooler edge of her bloom, so the glow has somewhere to fall off to
    /// instead of ending in a flat gold disc.
    private static let halo = Color(red: 0.78, green: 0.72, blue: 0.52)
    /// Wing membrane: warm and translucent rather than grey, or she reads as an
    /// insect the moment she crosses onto paper.
    private static let wing = Color(red: 1.0, green: 0.94, blue: 0.80)
    /// A thin dark edge on the core. This is the whole trick for staying visible
    /// on cream: a real light seen against paper has a contour.
    private static let contour = Color(red: 0.20, green: 0.14, blue: 0.08)
    /// What she sheds. Deep enough in tone to be seen on cream, where the lamp
    /// simply is not.
    private static let dust = Color(red: 0.68, green: 0.44, blue: 0.13)

    /// Her clock. A DEBUG probe run (`--perf-pixie-replay`) starts it at launch
    /// so every run flies the same path at the same moment.
    static func clock(_ date: Date) -> TimeInterval {
        #if DEBUG
        if let origin = PerfProbeSwitches.shared.pixieReplayOrigin {
            return 600 + date.timeIntervalSince(origin)
        }
        #endif
        return date.timeIntervalSinceReferenceDate
    }

    func startleStrength(now: TimeInterval) -> Double {
        guard let startledAt else { return 0 }
        let elapsed = now - startledAt
        guard elapsed < PippaDeliveryFlight.duration else { return 0 }
        // Bolts, then eases back to her own business.
        return elapsed < 0.22 ? smooth(elapsed / 0.22)
            : smooth((PippaDeliveryFlight.duration - elapsed) / (PippaDeliveryFlight.duration - 0.22))
    }

    // MARK: Where she is

    /// Her resting business: a slow wander, pulled toward whatever perch the
    /// Book is currently offering, and thrown off it entirely when startled.
    /// How hard she is answering a summons, 0...1.
    ///
    /// Exclamation points are her weakness, not her job. Everything else she
    /// does is on her own schedule; this is the one thing that makes her drop it.
    private func eagerness(now: TimeInterval) -> Double {
        guard let delivery, delivery.kind == .exclamation else { return 0 }
        return sin(delivery.progress(at: now) * .pi)
    }

    func position(size: CGSize, time: TimeInterval, startle: Double) -> CGPoint {
        let wander = CGPoint(
            x: size.width * CGFloat(0.5 + sin(time * 0.083) * 0.34 + cos(time * 0.031) * 0.09),
            y: size.height * CGFloat(0.42 + cos(time * 0.067 + 0.6) * 0.26 + sin(time * 0.047) * 0.09)
        )

        var point = wander
        if let perch = currentPerch(time: time, size: size) {
            // Settle onto the perch, sit a while, then lift off again.
            let settle = perchSettle(time: time)
            let target = CGPoint(x: perch.rect.midX, y: perch.rect.minY - 7)
            point.x += (target.x - point.x) * CGFloat(settle)
            point.y += (target.y - point.y) * CGFloat(settle)
        }

        if startle > 0 {
            let away = CGPoint(x: size.width * fleeCorner.x, y: size.height * fleeCorner.y)
            point.x += (away.x - point.x) * CGFloat(startle)
            point.y += (away.y - point.y) * CGFloat(startle)
        }

        if let delivery, time >= delivery.startedAt {
            return delivery.fairy(at: delivery.progress(at: time), returningTo: point)
        }
        return point
    }

    // Keeping her out of the text column was a mistake, and an ugly one: the
    // rule was applied per frame with no memory, so the moment her wander
    // crossed the middle she snapped to the far margin and read as teleporting
    // rather than flying. She goes where she likes now. What protects reading is
    // that she never *settles* on the text — every perch is in a margin — and
    // that she stills entirely while the Book is working.

    /// Somewhere to sit even before the Book starts offering places.
    ///
    /// The real appetite — accent words, punctuation, other people's marginalia —
    /// needs the folio to publish glyph rectangles upward, which it does not do
    /// yet. Meanwhile she lands on the Book's actual furniture, which she can
    /// find from its frame alone: the fore-edge where the bookmarks stand, the
    /// tail where the charms hang, the head corner, and the outer margin of the
    /// open page. Swapping in real targets later changes nothing here but the
    /// contents of `perches`.
    private func furniturePerches() -> [BookPixiePerch] {
        guard !bookRect.isEmpty else { return [] }
        return [
            BookPixiePerch(
                id: "fore-edge",
                kind: .marginalia,
                rect: CGRect(x: bookRect.maxX - 8, y: bookRect.minY + bookRect.height * 0.28, width: 10, height: 10)
            ),
            BookPixiePerch(
                id: "tail",
                kind: .marginalia,
                rect: CGRect(x: bookRect.minX + bookRect.width * 0.36, y: bookRect.maxY + 10, width: 10, height: 10)
            ),
            BookPixiePerch(
                id: "head",
                kind: .marginalia,
                // The folio's measured frame now includes the clear room its
                // ribbon needs above the painted board. The old inset leaves
                // her sitting in that room; this reaches the blue head edge
                // without moving the Book itself.
                rect: CGRect(x: bookRect.minX + 18, y: bookRect.minY + 36, width: 10, height: 10)
            ),
            BookPixiePerch(
                id: "outer-margin",
                kind: .marginalia,
                rect: CGRect(x: bookRect.maxX - bookRect.width * 0.11, y: bookRect.minY + bookRect.height * 0.64, width: 10, height: 10)
            )
        ]
    }

    /// One perch at a time, held for a good while. Better perches win: she will
    /// leave a marginal scribble for an accent word without hesitating.
    private func currentPerch(time: TimeInterval, size: CGSize) -> BookPixiePerch? {
        let available = perches.isEmpty ? furniturePerches() : perches
        guard !available.isEmpty else { return nil }
        let ranked = available.sorted { $0.kind.rawValue > $1.kind.rawValue }
        let slot = Int(floor(time / Self.perchPeriod))
        let best = ranked.prefix(3)
        guard !best.isEmpty else { return nil }
        return best[abs(slot) % best.count]
    }

    private static let perchPeriod: Double = 19

    /// 0 approaching, 1 sitting, back to 0 as she leaves.
    func perchSettle(time: TimeInterval) -> Double {
        let phase = (time.truncatingRemainder(dividingBy: Self.perchPeriod) + Self.perchPeriod)
            .truncatingRemainder(dividingBy: Self.perchPeriod) / Self.perchPeriod
        switch phase {
        case ..<0.22: return smooth(phase / 0.22) * 0.94
        case ..<0.68: return 0.94
        case ..<0.86: return smooth((0.86 - phase) / 0.18) * 0.94
        default: return 0
        }
    }

    private func smooth(_ t: Double) -> Double {
        let clamped = min(1, max(0, t))
        return clamped * clamped * (3 - 2 * clamped)
    }

    // MARK: Drawing

    func draw(in context: GraphicsContext, size: CGSize, time: TimeInterval, startle: Double) {
        guard size.width > 4, size.height > 4 else { return }
        let her = position(size: size, time: time, startle: startle)
        let called = eagerness(now: time)
        // A Pixie who has just found an exclamation point is not settling on
        // anything, however long she had been sitting.
        let settle = perchSettle(time: time) * (1 - startle) * (1 - called)

        // A single tow thread makes the little light's relationship to the
        // readable card clear. It exists only during this brief delivery.
        if let delivery {
            let progress = delivery.progress(at: time)
            if progress >= 0.30, progress < PippaDeliveryFlight.release {
                let card = delivery.card(at: progress)
                var thread = Path()
                thread.move(to: her)
                thread.addLine(to: CGPoint(x: card.x + delivery.cardWidth * 0.38, y: card.y - 65))
                context.stroke(thread, with: .color(Self.contour.opacity(0.55)), lineWidth: 0.8)
            }
        }

        // The trail thins as she settles: a sitting creature leaves no wake.
        for index in (1...10).reversed() {
            let past = time - Double(index) * 0.09
            let point = position(size: size, time: past, startle: startle)
            let fade = Double(11 - index) / 10
            let radius = CGFloat(1.1 + fade * 2.6)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Self.lamp.opacity(fade * 0.30 * (1 - settle * 0.7)))
            )
        }

        var body = context
        body.translateBy(x: her.x, y: her.y)

        // Wings beat fast and wide in flight, slow and shallow at rest, and never
        // stop: a resting creature still fans its wings.
        //
        // The previous version oscillated by only ±0.18 into a 20-degree term,
        // which came out as a seven-degree twitch in flight and about two at
        // rest — a wing that reads as frozen. Rate and reach both ease with
        // `settle` rather than switching on a threshold, so there is no pop when
        // she touches down.
        let beatRate = 15.5 - settle * 13.6 + startle * 9 + called * 11
        let reach = 1.0 - settle * 0.55
        let flap = (sin(time * beatRate) * 0.5 + 0.5) * reach
        // A light with wings, not a body that glows. She reads at a glance on
        // the dark room *and* on cream parchment because the bright core carries
        // a thin dark contour: a real light seen against paper has an edge.
        let pulse = 1 + sin(time * 2.4) * 0.06 + startle * 0.35
            + called * (0.22 + sin(time * 9) * 0.10)
        let halo = CGFloat(22 * pulse + settle * 3)

        // Outer bloom.
        var glow = body
        glow.addFilter(.shadow(color: Self.lamp.opacity(0.55 + startle * 0.25 + called * 0.2), radius: halo * 0.55))
        glow.fill(
            Path(ellipseIn: CGRect(x: -halo, y: -halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Self.lamp.opacity(0.55), location: 0),
                    .init(color: Self.lamp.opacity(0.26), location: 0.34),
                    .init(color: Self.halo.opacity(0.16), location: 0.62),
                    .init(color: .clear, location: 1)
                ]),
                center: .zero,
                startRadius: 0,
                endRadius: halo
            )
        )

        // Wings: long, raked, translucent, and actually visible. They beat hard
        // in flight and fold nearly shut when she settles.
        // Wings sit either side of her and reach outward, angled up a little.
        // Reaching *upward* from the top of the orb — which is where the first
        // pass put them — reads as a pair of ears, not a pair of wings.
        let span = CGFloat(15 + settle * 1.5)
        for side in [-1.0, 1.0] {
            var wing = body
            wing.scaleBy(x: side, y: 1)
            wing.rotate(by: .degrees(-8 - 54 * flap))
            let shape = Path(ellipseIn: CGRect(x: 2.2, y: -span * 0.46, width: span, height: span * 0.62))
            wing.fill(shape, with: .color(Self.wing.opacity(0.32 + startle * 0.14)))
            wing.stroke(shape, with: .color(Self.lamp.opacity(0.38)), lineWidth: 0.6)
            // A single vein, which is most of what makes a translucent shape
            // read as a wing rather than a smear.
            var vein = Path()
            vein.move(to: CGPoint(x: 2.6, y: 0))
            vein.addQuadCurve(
                to: CGPoint(x: 2.2 + span * 0.92, y: -span * 0.06),
                control: CGPoint(x: 2.2 + span * 0.5, y: -span * 0.24)
            )
            wing.stroke(vein, with: .color(Self.lamp.opacity(0.26)), lineWidth: 0.5)
        }

        // The core, and the contour that makes it survive a bright page.
        let core = CGFloat(5.2 * pulse)
        body.fill(
            Path(ellipseIn: CGRect(x: -core - 0.7, y: -core - 0.7, width: (core + 0.7) * 2, height: (core + 0.7) * 2)),
            with: .color(Self.contour.opacity(0.30))
        )
        body.fill(
            Path(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2)),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.95), Self.lamp.opacity(0.92), Self.lamp.opacity(0.4)]),
                center: .zero,
                startRadius: 0,
                endRadius: core
            )
        )

        // Motes she sheds, deep enough in tone to be seen on cream.
        for mote in 0..<4 {
            let drift = time * 1.6 + Double(mote) * 1.7
            let reach = 9.0 + Double(mote) * 3.4 + startle * 14 + called * 9
            let point = CGPoint(x: cos(drift) * reach, y: sin(drift * 0.8) * reach * 0.75 + 3)
            let twinkle = 0.32 + 0.34 * sin(time * 4.5 + Double(mote))
            let radius = CGFloat(0.7 + 0.45 * sin(time * 3 + Double(mote) * 1.3))
            body.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Self.dust.opacity(max(0, twinkle) * (0.8 - settle * 0.3)))
            )
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
            // The Pixie is not drawn here any more. She came forward into the
            // room (see `BookPixieLayer`), and there is only one of her — a
            // second copy shimmering behind the Book would make her scenery
            // again, which is the whole thing this stopped being.
            //
            // Her gathering pull stays in the letter field: the drift still
            // swarms and releases as though something were herding it, which is
            // what the backdrop was always really showing.
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
        // A wider swirl keeps the gathered letters orbiting the pixie: close
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
        // go: a longer plateau so the "gathered up for a little while" reads.
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
    /// Only one authored text field is ever present on an onboarding page. A
    /// shared scroll identity lets focus pin that field to the top of the
    /// reading area, leaving the newly revealed response room to grow below it.
    private static let activeTextFieldScrollID = "onboarding-active-text-field"

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
    /// is never a pure loss: the low band still hands the reader a beginning
    /// (a grudge, an open road, a strange seed) that the rival can carry.
    private enum WickerOutcomeTier: String, Equatable {
        case triumph   // a bright fracture: the margin cracks open in your favor
        case hold      // clean success
        case glance    // just short: frayed but holding
        case cost      // Wicker gets a hook: kept as the first page of something

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
        var pageChangeNoticed: String
        var rutStrongest: String
        var routineMemory: String
        var mostAlive: String
        var awakeMemory: String
        var magicSource: String
        var roleHands: String
        /// Role id the Book named and the reader accepted.
        var roleID: String
        /// Role id the Book named first, if the reader said "that's not me".
        var refusedRoleID: String
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
        /// Whether the reader gave their word before the first move. The Book
        /// holds them to it later, gently, and only ever by keeping its own half.
        var sworePact: Bool
        var inscriptionEdition: MonthlyEdition?
        var inscriptionEditionPDFPath: String
    }

    let onGlowUnlocked: () -> Void
    let onKeepIlluminatedPhoto: (IlluminatedPhotoDraft, URL?) -> Void
    let onPaused: () -> Void
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
    @State private var pageTilt = false
    @State private var didNotifyGlowUnlocked = false
    @State private var castPreviewURL: URL?
    @State private var didWakeFirstInk = false
    @State private var didLivingInkChange = false
    @State private var livingInkChangeTask: Task<Void, Never>?
    @State private var sleeveWord: String?
    @State private var didSteadyFirstPage = false
    @State private var unwrittenWordDrag: CGSize = .zero
    @State private var didTuckUnwrittenWord = false
    @AppStorage("onboardingDraftChapterID") private var drawnChapterID = ""
    @State private var onboardingPhotoItem: PhotosPickerItem?
    @State private var onboardingPhotoImage: UIImage?
    @State private var onboardingPhotoDraft: IlluminatedPhotoDraft?
    @State private var onboardingPhotoPreviewURL: URL?
    @State private var onboardingPhotoMessage = "Your handmade PDF is already waiting. You can also place one of your photos in it."
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
    // Night-one wagers the reader tapped to confirm: the Barnum beat, kept
    // honest by paying off later as receipts in First Reading.
    @State private var confirmedWagers: Set<String> = []
    /// The reader's own commitment, sworn before the first move. It persists as
    /// a draft like everything else so a mid-onboarding relaunch does not quietly
    /// unswear it.
    @AppStorage("onboardingDraftSworePact") private var sworePact = false
    @AppStorage("onboardingDraftFirstPressText") private var firstPressText = ""
    @State private var selectedFirstPressPresetID: String?
    @AppStorage("onboardingDraftDidKeepFirstPage") private var didCompleteFirstPress = false
    @AppStorage("onboardingDraftMomentFate") private var momentFate = ""
    @AppStorage("onboardingDraftHiddenMagicStance") private var hiddenMagicStance = ""
    @AppStorage("onboardingDraftPageChangeNoticed") private var pageChangeNoticed = ""
    @AppStorage("onboardingDraftRutStrongest") private var rutStrongest = ""
    @AppStorage("onboardingDraftRoutineMemory") private var routineMemory = ""
    /// Which ordinary hour the Book picks apart: drove / cooked / walked.
    @AppStorage("onboardingDraftRecallScenario") private var recallScenario = ""
    /// One character per asked question: "1" kept, "0" gone, "" unanswered.
    /// Persisted so backing out mid-interrogation resumes where they were.
    @AppStorage("onboardingDraftRecallAnswers") private var recallAnswersRaw = ""
    @AppStorage("onboardingDraftMostAlive") private var mostAlive = ""
    @AppStorage("onboardingDraftAwakeMemory") private var awakeMemory = ""
    @AppStorage("onboardingDraftMagicSource") private var magicSource = ""
    // The third axis of the reader's role: what the hands do with something
    // good once it has been found. Asked outright because it is the one that
    // changes what the Book should hand over next.
    @AppStorage("onboardingDraftHands") private var roleHands = ""
    // The role the Book named, and, if the reader tapped "that's not me": the
    // one it named first. A refused role is kept: being wrong about somebody in
    // a specific way is worth more later than pretending it never happened.
    @AppStorage("onboardingDraftRoleID") private var chosenRoleID = ""
    @AppStorage("onboardingDraftRoleRefused") private var refusedRoleID = ""
    @AppStorage("onboardingOpeningMiniStep") private var openingMiniStep = 0
    @AppStorage("onboardingFlowVersion") private var onboardingFlowVersion = 0
    @State private var isOpeningOvertureTitleVisible = true
    @State private var openingOvertureTitleFadeTask: Task<Void, Never>?
    // The instant the player arrived, captured once so the loose Page keeps
    // naming the same moment even after a relaunch.
    @AppStorage("onboardingDraftArrivalTimestamp") private var arrivalTimestamp = 0.0
    @State private var didRevealOpeningCard = false
    @State private var onboardingShareItem: OnboardingShareItem?
    @AppStorage("onboardingDraftPagewrightImagePath") private var onboardingPagewrightImagePath = ""
    @AppStorage("onboardingDraftPagewrightTitle") private var onboardingPagewrightTitle = ""
    @AppStorage("onboardingDraftPagewrightTemplate") private var onboardingPagewrightTemplate = ""
    @AppStorage("onboardingDraftPagewrightSourceSignature") private var onboardingPagewrightSourceSignature = ""
    @State private var onboardingPagewrightError = ""
    @State private var bookOfYouPreviewURL: URL?
    @State private var isPressingOpeningRevealVideo = false
    @State private var isBindingFirstEdition = false
    // Plays the book-cover-opening beat over the step 0 → 1 transition.
    @State private var isCoverOpeningVisible = false
    // Ink bursts fired on authored inputs (keep, belief).
    @State private var openingKeepBurst = 0
    @State private var beliefPlantBurst = 0
    // A short "sewing" beat before the finale mini-edition opens in QuickLook.
    @State private var isSewingFirstEdition = false
    @State private var didBindFirstEdition = false
    @State private var boundInscriptionEdition: MonthlyEdition?
    @State private var inscriptionEditionPDFPath = ""
    /// Empty means the dedicated Book-and-thread illustration. A catalogue id means
    /// the reader deliberately chose that Bindery plate for the PDF cover;
    /// `reader-photo` promotes their illuminated photograph to the cover.
    /// Persist it with the other onboarding drafts so a ribbon or relaunch
    /// cannot quietly put the old coat back on.
    @AppStorage("onboardingDraftFirstDoorCoverChoiceID") private var inscriptionCoverChoiceID = ""
    /// A durable local copy of the unilluminated source photograph. The
    /// illuminated composition still appears inside the edition; the cover
    /// receives the reader's photograph itself, with live type in the authored
    /// footer clearing.
    @AppStorage("onboardingDraftFirstDoorCoverPhotoPath") private var inscriptionCoverPhotoPath = ""
    @AppStorage("onboardingDraftFirstDoorCoverFocusX") private var inscriptionCoverFocusX = -1.0
    @AppStorage("onboardingDraftFirstDoorCoverFocusY") private var inscriptionCoverFocusY = -1.0
    @State private var didCloseFirstEditionPreview = false
    @State private var firstEditionBindingError = ""
    // Guards the belief-planting ceremony so its burst can play before advancing.
    @State private var isPlantingBelief = false
    // Drives the gold gild-sweep across the illuminated photograph when it is kept.
    @State private var photoGildSweep: Double = 0

    /// Fourteen screens in all, each bringing at most one new thing, and every
    /// answer used on the screen it was given. Five beats on the loose Page:
    /// the Book makes a claim, proves it twice out of the reader's own life,
    /// delivers the verdict, and only then asks them to catch something. Then
    /// eight story pages inside the Book and the little book at the end.
    static let openingMiniStepCount = 5
    private let stepCount = 10
    private let currentOnboardingFlowVersion = 16
    private let rutChoices = [
        OnboardingChoice(id: "work", title: "Work swallows the day", detail: "", symbol: "briefcase"),
        OnboardingChoice(id: "phone", title: "My phone eats the edges", detail: "", symbol: "iphone"),
        OnboardingChoice(id: "chores", title: "Chores all blur together", detail: "", symbol: "checklist"),
        OnboardingChoice(id: "exhaustion", title: "I'm tired before I begin", detail: "", symbol: "battery.25percent"),
        OnboardingChoice(id: "sameness", title: "My days feel the same", detail: "", symbol: "repeat"),
        OnboardingChoice(id: "later", title: "I keep waiting for later", detail: "", symbol: "hourglass")
    ]
    /// Computed rather than fixed so the first answer can name the word that
    /// actually went. The Book is not scoring anybody: a reader who claims it
    /// and sees they were wrong has learned the same thing either way, and one
    /// who really caught it gets the small thrill of being right.
    private var pageChangeChoices: [OnboardingChoice] {
        [
            // The detail used to name the word ("It was 'afternoon's'"), which
            // handed every reader the answer before they gave it.
            OnboardingChoice(id: "caught", title: "I caught it", detail: "A word went. I saw it go.", symbol: "eye.fill"),
            OnboardingChoice(id: "uncertain", title: "Something shifted", detail: "I saw movement, but I couldn't say what went missing.", symbol: "eye.trianglebadge.exclamationmark"),
            OnboardingChoice(id: "missed", title: "I missed it", detail: "The Page changed before I knew there was anything to catch.", symbol: "eye.slash")
        ]
    }
    private let routineMemoryChoices = [
        OnboardingChoice(id: "full", title: "Most of it", detail: "I can replay the ordinary minutes, not only the ending.", symbol: "film.stack"),
        OnboardingChoice(id: "islands", title: "A few sharp pieces", detail: "I get a few clips, then nothing in between.", symbol: "circle.grid.cross"),
        OnboardingChoice(id: "result", title: "Mostly the result", detail: "I remember getting there and getting done. Not the middle.", symbol: "flag.checkered"),
        OnboardingChoice(id: "blank", title: "Almost nothing", detail: "I know it happened. That's about it.", symbol: "rectangle.dashed")
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
    /// Ordered to match `ReaderRoleRegistry.hands`.
    private let handsChoices = [
        OnboardingChoice(id: "keeping", title: "I keep it", detail: "Somewhere safe, where I can find it again.", symbol: "archivebox"),
        OnboardingChoice(id: "telling", title: "I tell somebody", detail: "I want someone else to hear about it.", symbol: "bubble.left.and.bubble.right"),
        OnboardingChoice(id: "making", title: "I make something of it", detail: "It turns into a thing that didn't exist before.", symbol: "hammer"),
        OnboardingChoice(id: "returning", title: "I go back for more", detail: "I look for another moment like it.", symbol: "arrow.triangle.2.circlepath"),
        OnboardingChoice(id: "still", title: "I sit with it", detail: "I don't do anything. I let it stay a while.", symbol: "leaf")
    ]
    private let sleeveWords = ["GLINT", "MARGIN", "THRESHOLD"]
    private let whisperChoices = [
        OnboardingChoice(id: "morning", title: "Morning", detail: "One small thing to look for, near the start of the day.", symbol: "sunrise"),
        OnboardingChoice(id: "evening", title: "Evening", detail: "One knock before bed, to catch something from today.", symbol: "moon"),
        OnboardingChoice(id: "both", title: "Both", detail: "Something to look for in the morning, a knock at night.", symbol: "sunrise.fill"),
        OnboardingChoice(id: "inside", title: "Only when I open the Book", detail: "No knocking. I wait until you open me.", symbol: "bell.slash")
    ]
    private let wickerChoices = [
        WickerModeChoice(
            id: "slice-of-life",
            title: "Something Small and True",
            detail: "Tell him one exact, unglamorous detail from your actual life.",
            symbol: "mug",
            difficulty: 42,
            triumphLine: "You give him one exact, unglamorous detail. It lands so cleanly the sneer slides off his face. A shelf leans closer. “Beginner's luck,” Wicker says, which is what people say when the beginner has just beaten them.",
            holdLine: "The ordinary detail lands square. Wicker was ready for something grand; he wasn't ready for something specific. He recovers a half-beat late. I write the half-beat down.",
            glanceLine: "The detail comes out smaller than you meant. “That's your evidence?” Wicker asks. Zara doesn't rescue you. She only says, “Truth doesn't need to be large.” Annoyingly, it holds.",
            costLine: "It comes out mumbled. Wicker pockets the mumble like a coin. “Lovely,” he says. “You've brought me almost a thought.” I turn the insult into the opening line of a grudge."
        ),
        WickerModeChoice(
            id: "arc",
            title: "Where This Is Going",
            detail: "Don't answer the insult. Tell him where your story is headed.",
            symbol: "arrow.triangle.turn.up.right.diamond",
            difficulty: 56,
            triumphLine: "You name where this is going before he can name what's wrong with it. A gold arrow draws itself under your sentence and points past him. “Pushy little book,” Wicker mutters. He moves aside anyway.",
            holdLine: "You point at a future and the hall leans that way. Wicker feels it move under his boots. “A direction isn't a destiny,” he says. No, but it is a direction, and he has to step aside.",
            glanceLine: "The promise wobbles. Wicker hears it; he collects wobbles. “Future tense in a heroic little costume.” Still, a wobbling arrow's an arrow. I pin its heading to the wall.",
            costLine: "The direction leaves your mouth as a question. Wicker circles the question mark. “There. The first honest thing you've said.” I file it as an open road, and put his name at the next bend."
        ),
        WickerModeChoice(
            id: "surprise",
            title: "Something He Won't Expect",
            detail: "Refuse the obvious reply and let something odd out instead.",
            symbol: "sparkles",
            difficulty: 64,
            triumphLine: "Your answer arrives so far sideways that Wicker forgets to be superior for one entire second. A shelf laughs in dry, rustling paper. He'll deny this. I've already underlined it twice.",
            holdLine: "You let something odd through the gap. Wicker blinks. “Did you rehearse that, or are you naturally inconvenient?” Odd is the one thing he's never learned to out-sneer.",
            glanceLine: "The surprise half-lands: a spark where you meant a flourish. Wicker slow-claps. “Nearly an event.” Zara murmurs, “Useful data,” which is less satisfying than punching him but more useful.",
            costLine: "The odd thing fizzles at your feet. Wicker applauds with real pleasure. “Courageous,” he says, in the least flattering way possible. I keep the misfire. I want a rematch."
        )
    ]
    private let firstSentenceStarters = [
        "The light on the wall right now is weirdly good.",
        "There's a tiny sound in this room I never noticed before.",
        "Today felt like something, and I still can't say what.",
        "The weather changed the whole room and nobody told me.",
        "My fridge hums one note, and I've ignored it for years."
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
        onPaused: @escaping () -> Void = {},
        onFinished: @escaping (Result) -> Void
    ) {
        self.onGlowUnlocked = onGlowUnlocked
        self.onKeepIlluminatedPhoto = onKeepIlluminatedPhoto
        self.onPaused = onPaused
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

            if isSewingFirstEdition {
                BinderySewingOverlay()
                    .transition(.opacity)
                    .zIndex(41)
            }

            if isCoverOpeningVisible {
                LabyrinthCoverOpeningView(readerName: name) {
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
            if openingMiniStep > Self.openingMiniStepCount - 1 {
                openingMiniStep = Self.openingMiniStepCount - 1
            }
            if step >= stepCount {
                step = stepCount - 1
            }
            scheduleOpeningOvertureTitleFadeIfNeeded()
            // If the player closed the app partway through, offer to resume.
            if !wasOlderFlow, step > 0 || openingMiniStep > 0 {
                showResumePrompt = true
            }
            notifyGlowUnlockedIfNeeded()
            scheduleLivingInkRutProofIfNeeded()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                shimmer = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                pageTilt = true
            }
        }
        .onDisappear {
            openingOvertureTitleFadeTask?.cancel()
            openingOvertureTitleFadeTask = nil
            livingInkChangeTask?.cancel()
            livingInkChangeTask = nil
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
        let scrollMaxHeight: CGFloat = isPortrait
            ? min(640, max(420, size.height - 116))
            : min(540, max(360, size.height - 120))

        return VStack(spacing: 0) {
            Spacer(minLength: isPortrait ? 12 : 18)

            // No banner above the page on a phone. It used to show for two
            // seconds and then collapse, which slid it half-transparent over
            // the card and jumped the content up under the reader's thumb
            // mid-tap. The pill inside the page already names where they are.
            VStack(spacing: 0) {
                onboardingPageScroll(
                    horizontalPadding: 22,
                    readingMaxWidth: nil,
                    showsInlineChrome: true
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

            stepDots
                .padding(.top, isPortrait ? 18 : 16)
                .padding(.horizontal, 22)

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
                showsInlineChrome: !showsFolioRail
            )
            .id(showsFolioRail ? "onboarding-folio-scroll" : "onboarding-portrait-scroll")

            if !showsFolioRail {
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
                        Text("HOW WE MET")
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

                stepDots

                Spacer(minLength: 20)

                VStack(alignment: .leading, spacing: 8) {
                    Label("A living first edition", systemImage: "book.closed")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                    Text("Your answers stay on this device and become the first handwriting in me.")
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
                    .accessibilityLabel("Skip these first questions and open the free Book")
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
                turnOnboardingPage(to: "onboarding-page-top", with: scrollProxy)
                notifyGlowUnlockedIfNeeded()
            }
            .onChange(of: openingMiniStep) { _, _ in
                guard step == 0 else { return }
                scheduleOpeningOvertureTitleFadeIfNeeded()
                scheduleLivingInkRutProofIfNeeded()
                // House rule: moving forward always lands the reader at the
                // top of the next beat. Anything else means a beat can open
                // halfway down itself, and the reader arrives mid-thought.
                turnOnboardingPage(to: "onboarding-page-top", with: scrollProxy)
            }
            .onChange(of: mostAlive) { _, answer in
                awakeMemory = ""
                guard step == 0, openingMiniStep == 2, !answer.isEmpty else { return }
                revealOnboarding("onboarding-alive-detail", with: scrollProxy)
            }
            .onChange(of: isOnboardingFieldFocused) { _, isFocused in
                guard isFocused else { return }
                pinOnboardingTextField(with: scrollProxy)
            }
            .onChange(of: belief) { _, _ in
                notifyGlowUnlockedIfNeeded()
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(
                OnboardingLateRevealScrolling(
                    step: step,
                    openingMiniStep: openingMiniStep,
                    didLivingInkChange: didLivingInkChange,
                    pageChangeNoticed: pageChangeNoticed,
                    recallScenario: recallScenario,
                    recallAnswered: recallAnswered,
                    rutStrongest: rutStrongest,
                    rehearsalChoice: rehearsalChoiceStorage,
                    investedBelief: investedBelief,
                    magicSource: magicSource,
                    roleHands: roleHands,
                    didSteadyFirstPage: didSteadyFirstPage,
                    drawnChapterID: drawnChapterID,
                    wickerThrowID: wickerThrowID,
                    hasWickerOutcome: wickerOutcome != nil,
                    didCloseFirstEditionPreview: didCloseFirstEditionPreview,
                    whisperCadence: whisperCadence,
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

    private func notifyGlowUnlockedIfNeeded() {
        guard !didNotifyGlowUnlocked else { return }
        guard step >= 4 else { return }
        guard !belief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        didNotifyGlowUnlocked = true
        onGlowUnlocked()
    }

    private var onboardingActIndex: Int {
        switch step {
        case 0: return 0
        case 1...5: return 1
        case 6...8: return 2
        default: return 3
        }
    }

    private var onboardingActTitle: String {
        switch onboardingActIndex {
        case 0: return "The Curse Proves Itself"
        case 1: return "A Few Things About You"
        case 2: return "The Story Bites Back"
        default: return "Your First Little Book"
        }
    }

    /// The Inscription is a four-signature little book, not a fourteen-item
    /// setup checklist. Showing every internal page made the opening ritual
    /// look barely begun after it had already delivered its first proof.
    private var stepDots: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(
                            index <= onboardingActIndex
                                ? BookPalette.lampGold
                                : BookPalette.teal.opacity(0.30)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: index == onboardingActIndex ? 6 : 4)
                }
            }

            Text("PART \(onboardingActIndex + 1) OF 4 · \(onboardingActTitle.uppercased())")
                .font(.system(size: 10, weight: .black))
                .tracking(0.9)
                .foregroundStyle(BookPalette.lampGold.opacity(0.82))

            if canPutRibbonHere {
                Button {
                    isOnboardingFieldFocused = false
                    BookFeedback.play(.select)
                    onPaused()
                } label: {
                    Label("Put a ribbon here", systemImage: "bookmark.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.lampGold)
                .accessibilityHint("Opens the Book and saves your place in these first questions")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Part \(onboardingActIndex + 1) of 4, \(onboardingActTitle)")
    }

    /// Only offer the ribbon at sewn seams. Everything needed to resume these
    /// three pages is already persisted; offering it mid-scene could make a
    /// photograph, wager, or freshly bound preview fall out of the Book.
    private var canPutRibbonHere: Bool {
        step == 1 || step == 6 || (step == stepCount - 1 && !didBindFirstEdition)
    }

    private var firstPressTrimmedText: String {
        firstPressText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Everything that names the time of day reads the frozen arrival moment.
    // Reading the clock made the Page say "10:42 AM" and "afternoon" in the
    // same sentence after a pause.
    private var firstPressTimeName: String {
        let hour = Calendar.current.component(.hour, from: arrivalMoment)
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "late night"
        }
    }

    private var firstPressTimeTexture: String {
        let hour = Calendar.current.component(.hour, from: arrivalMoment)
        switch hour {
        case 5..<8: return "the day's still deciding what kind of page it'll be"
        case 8..<12: return "the morning's already left fingerprints on the room"
        case 12..<17: return "the afternoon's warm with unfinished errands"
        case 17..<22: return "the evening's gathering the day back into its sleeves"
        default: return "the late hour makes even small things sound like secrets"
        }
    }

    private var firstPressSeasonTexture: String {
        let month = Calendar.current.component(.month, from: arrivalMoment)
        switch month {
        case 3...5: return "spring light"
        case 6...8: return "summer heat"
        case 9...11: return "autumn edge"
        default: return "winter quiet"
        }
    }

    /// Answers to the mission the Book just set: what is the nearest ordinary
    /// thing *doing* that gives away its opinion about being there.
    ///
    /// Every one obeys one of the two house rules: Give the World the Pen
    /// (the object takes the verb and acts on the reader) or Cross the Wires
    /// (one sense answers for another). A preset that reads "I noticed the
    /// cup" teaches the reader that the correct answer is a flat report, and
    /// then every page they write afterwards is a flat report.
    private var firstPressPresets: [FirstPressPreset] {
        let hour = Calendar.current.component(.hour, from: arrivalMoment)
        let skySentence: String
        let roomSentence: String
        let bodySentence: String
        let objectSentence: String
        switch hour {
        case 5..<12:
            skySentence = "The morning light's leaning on the wall like it owns it."
            roomSentence = "Someone's moving about in another room, very quietly."
            bodySentence = "My feet have gone cold and they want me to know."
            objectSentence = "My mug's empty and still warm."
        case 12..<17:
            skySentence = "The sun's drawn one bright stripe across the wall."
            roomSentence = "Something in this room hums one note and won't stop."
            bodySentence = "My shoulders have crept up to my ears again."
            objectSentence = "A pen's rolled under the table to hide from me."
        case 17..<22:
            skySentence = "The sky's changing colour and nobody asked it to."
            roomSentence = "The lamp's making this room look warmer than it is."
            bodySentence = "I'm tired, but my head's still wide awake."
            objectSentence = "The kettle's ticking as it cools, like it's counting."
        default:
            skySentence = "The dark window's showing me my own face."
            roomSentence = "It's so quiet I can hear the fridge thinking."
            bodySentence = "My bed's calling and I'm pretending not to hear."
            objectSentence = "My charging cable's tied itself in a knot again."
        }
        return [
            FirstPressPreset(id: "sky", title: "The sky", detail: firstPressTimeName, symbol: "cloud.moon", sentence: skySentence),
            FirstPressPreset(id: "room", title: "This room", detail: firstPressSeasonTexture, symbol: "book.pages", sentence: roomSentence),
            FirstPressPreset(id: "body", title: "My mood", detail: "right now", symbol: "heart.text.square", sentence: bodySentence),
            FirstPressPreset(id: "object", title: "One object", detail: "nearby", symbol: "cup.and.saucer", sentence: objectSentence)
        ]
    }

    private let firstPressNarrativeChoices = [
        FirstPressNarrativeChoice(
            id: "slice-of-life",
            title: "Small and Everyday",
            detail: "Stay with the little thing you noticed.",
            symbol: "mug",
            outcomeLine: "A tiny ink creature curled up beside it and decided to guard it. Nothing else happened. I liked that."
        ),
        FirstPressNarrativeChoice(
            id: "arc",
            title: "A Little Adventure",
            detail: "Your real thing starts a made-up adventure.",
            symbol: "arrow.triangle.turn.up.right.diamond",
            outcomeLine: "Then an ink creature stole the full stop off the end and ran. So it isn't finished yet."
        ),
        FirstPressNarrativeChoice(
            id: "surprise",
            title: "Surprise",
            detail: "Let me put something odd in.",
            symbol: "sparkles",
            outcomeLine: "Then a very small wolf walked out of my margin, sniffed it, and fell asleep on top of it. I had other plans. The wolf didn't."
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
        return place == "Night" ? "The \(anchor.capitalized) at Night" : "The \(anchor.capitalized) in the \(place)"
    }

    private var firstPressPreviewExcerpt: String {
        let text = firstPressTrimmedText
        guard let detail = firstPressPreviewDetail(from: text).nonEmpty else {
            return "\(openingArrivalExcerpt) \(firstPressNarrativeResultLine)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "\(openingArrivalExcerpt) You gave me this: \u{2018}\(detail).\u{2019} \(firstPressNarrativeResultLine)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
    }

    /// The Book answers a kept sentence with one small story of its own. The
    /// reader used to pick the kind of story; now the sentence picks, so the
    /// card still answers back without another question.
    private var bookReplyToFirstPress: FirstPressNarrativeChoice? {
        guard rehearsalChoice == .keep, !firstPressTrimmedText.isEmpty else { return nil }
        let index = abs(firstPressTrimmedText.stableHash) % firstPressNarrativeChoices.count
        return firstPressNarrativeChoices[index]
    }

    private var firstPressNarrativeResultLine: String {
        bookReplyToFirstPress?.outcomeLine ?? ""
    }

    private var firstPressSouvenirLine: String {
        if let detail = firstPressPreviewDetail(from: firstPressTrimmedText).nonEmpty {
            return "\(openingArrivalExcerpt) You gave me this: \u{2018}\(detail).\u{2019} \(firstPressNarrativeResultLine)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return openingArrivalExcerpt
    }

    private var livingInkProofLine: String {
        firstPressPreviewDetail(from: firstPressTrimmedText).nonEmpty
            ?? firstPressSouvenirLine
    }

    private var livingInkProofParts: (before: String, word: String, after: String) {
        let tokens = livingInkProofLine.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return ("", "word", "") }
        let stopWords: Set<String> = [
            "a", "an", "and", "at", "but", "for", "from", "i", "in", "is",
            "it", "my", "of", "on", "the", "this", "to", "was", "with", "you"
        ]
        let chosenIndex = tokens.indices
            .filter { index in
                let cleaned = tokens[index]
                    .lowercased()
                    .trimmingCharacters(in: .punctuationCharacters)
                return cleaned.count >= 4 && !stopWords.contains(cleaned)
            }
            .max { left, right in
                tokens[left].count < tokens[right].count
            }
            ?? max(0, tokens.count / 2)
        let beforeWords = tokens[..<chosenIndex]
        let afterWords = tokens[(chosenIndex + 1)...]
        return (
            beforeWords.isEmpty ? "" : beforeWords.joined(separator: " ") + " ",
            tokens[chosenIndex],
            afterWords.isEmpty ? "" : " " + afterWords.joined(separator: " ")
        )
    }

    /// The iPad's banner above the page. Phones don't show it: there it
    /// collapsed mid-read and jumped the page under the reader's thumb.
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
                Text("HOW WE MET")
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
    /// their own tap produced. The delay lets the inserted view lay out first:
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

    /// Focus changes the scroll view's visible height while the keyboard rises.
    /// Pin once immediately, then again after that inset has settled so the
    /// field itself (not the page heading or the response) owns the top edge.
    private func pinOnboardingTextField(with proxy: ScrollViewProxy) {
        proxy.scrollTo(Self.activeTextFieldScrollID, anchor: .top)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            guard isOnboardingFieldFocused else { return }
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.22)) {
                proxy.scrollTo(Self.activeTextFieldScrollID, anchor: .top)
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
            Label(onboardingStageName, systemImage: onboardingSymbol)
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
                .accessibilityLabel("Skip these first questions and open the free Book")
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

    /// Each story page sits behind a type-erased boundary for the same reason
    /// the opening beats do: one combined result-builder switch over every
    /// page is deep enough to exhaust the main-thread stack on device.
    @ViewBuilder
    private var stepContent: some View {
        if step == 0 {
            onboardingOpeningPage
        } else {
            switch step - 1 {
            case 0: AnyView(onboardingArrivalStep)
            case 1: AnyView(onboardingSnackStep)
            case 2: AnyView(onboardingBeliefStep)
            case 3: AnyView(onboardingMagicStep)
            case 4: AnyView(onboardingRoleRevealStep)
            case 5: AnyView(onboardingChapterStep)
            case 6: AnyView(onboardingWickerArrivesStep)
            case 7: AnyView(onboardingInkbonesStep)
            default: AnyView(onboardingLittleBookStep)
            }
        }
    }

    /// Zara, and the one thing people ask when they meet: what do we call you?
    private var onboardingArrivalStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingTitle("Through the Page")
            onboardingProse(inscriptionFallThroughProse)
            guidePortrait(mood: "Zara Finch has already noticed what you did with the Page.")
            onboardingProse("""
            "Don't stand up too fast," she says. "Everyone does. I'm Zara. I live in here."

            Ink scribbles itself across the floor by her shoe: "She's nice. She knows where everything is. Mostly."
            """)
            onboardingTakeZarasHandAction

            if didSteadyFirstPage {
                VStack(alignment: .leading, spacing: 18) {
                    onboardingProse("""
                    Zara pulls you up. Your Page is still in your hand.

                    "You're from outside," she says, like it's the most interesting thing that's happened all week. "Nobody gets in from outside. What do we call you? Your real name, a nickname, or one just for in here. Write it below."
                    """)
                    onboardingField("What should I call you?", text: $name)
                    if let answer = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                        onboardingNameSignature(answer)
                            .id("onboarding-name-signature")
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        onboardingPreviewCard(
                            symbol: "person.crop.circle.badge.checkmark",
                            title: "\"\(answer),\" Zara tries.",
                            body: "\"Yes. That'll do it.\""
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    continueButton("That's my name", disabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .id("onboarding-arrival-standing")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var onboardingSnackStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            guidePortrait(mood: "Zara has an urgent question. It isn't a serious one.")
            onboardingTitle("What Do You Snack On?")
            onboardingProse("""
            "Right, \(readerFirstName). The important question," Zara says. "What do you snack on while you read? Mine's green apples. The crunch annoys the librarian."

            "Write it below. \u{201C}Nothing\u{201D} counts. I just want something small and true about you."
            """)
            onboardingField("I snack on...", text: $snack)
            if let answer = snackInSentence {
                onboardingPreviewCard(
                    symbol: "takeoutbag.and.cup.and.straw",
                    title: "Noted, very seriously",
                    body: "Zara writes \u{201C}\(answer)\u{201D} in the margin in tiny careful letters. A small ink creature draws a plate under it and sits on the plate."
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
        }
    }

    /// One belief, one meaning of the word, and a visible answer: the word
    /// the Curse was eating on the reader's Page comes back dark.
    private var onboardingBeliefStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingTitle("One Thing You Believe")
            onboardingProse("""
            A word on the edge of your Page goes grey and starts to fade.

            "The Curse again," Zara says. "It can't stand things people actually believe. So tell it one. Something you'd say out loud and stick up for."

            "Mine's \u{201C}people can change\u{201D}. Yours can be small. \u{201C}A walk usually helps.\u{201D} \u{201C}Dogs know things.\u{201D} Write it below."
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
                        symbol: "checkmark.seal.fill",
                        title: "The grey word's back",
                        body: "The fading word on your Page goes dark again, and \u{201C}\(answer)\u{201D} is written right beside it in ink that won't come off. \"It'll turn up again,\" Zara says. \"In your Pages, in the stories. Whenever something agrees with it.\""
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    continueButton("Good")
                } else {
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
        }
    }

    private var onboardingMagicStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingTitle("What Makes a Day Feel Special?")
            onboardingProse("""
            "What makes an ordinary day feel a bit magic to you?" Zara asks. "A song at exactly the right moment? Wild weather? Making someone laugh?"

            "Tap the one that's most you. First answer. Don't think about it."
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

                onboardingTitle("What Do You Do When You Notice It?")
                onboardingProse("""
                "Last one before the Book has a go at you," Zara says. "When you find something good, a song, a light, a strange minute, what do you do with it? Pick the one most like you."
                """)
                onboardingChoiceList(choices: handsChoices, selection: $roleHands)
            }
            continueButton(
                "That's me",
                disabled: magicSource.isEmpty || roleHands.isEmpty
            )
            .id("onboarding-hands-continue")
        }
    }

    private var onboardingRoleRevealStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingRoleReveal
        }
    }

    private var onboardingChapterStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            // They are places with banners, not people.
            onboardingTitle("Choose Your First Chapter")
            onboardingProse("""
            Zara stops under five banners. "These are the Chapters. These aren't teams, and they're definitely not houses with nicer robes. Each one's an argument about what makes an ordinary life worth anything. They don't agree. They never have."

            "Tap one to hear what it thinks of your Page. Pick the one you like best. It's where your story starts."
            """)
            onboardingChapterAffinityPicker
            continueButton("Choose this Chapter", disabled: drawnChapterID.isEmpty)
                .id("onboarding-chapter-continue")
            if drawnChapterID.isEmpty {
                secondaryOnboardingButton("You pick for me", systemImage: "sparkles") {
                    drawnChapterID = bookChosenChapterID
                    advance()
                }
            }
        }
    }

    /// He has taken the Page out of the reader's hand and is walking backwards
    /// reading it. Everything he taunts them with is something they gave.
    private var onboardingWickerArrivesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingTitle("Wicker Takes the Page")
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
                    .accessibilityLabel("Wicker, reading your Page")
                Text("A boy in a green-black coat, reading your Page backwards while he walks.")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            onboardingProse(inscriptionWickerIntroduction)
            continueButton("Answer him")
        }
    }

    private var onboardingInkbonesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingTitle("Throw the Inkbones")
            onboardingProse("""
            Zara presses a handful of little bones into your palm. They're warm, and they click like teeth.

            "Inkbones," she says. "When something could go either way in here, they decide."
            """)
            onboardingWickerChoice
            continueButton("Get your Page back", disabled: wickerOutcome == nil)
        }
    }

    /// Wicker flips the Page back, and everything the reader gave becomes a
    /// little book they can keep. One decision at a time: the cover, the book,
    /// then when the Book should knock.
    private var onboardingLittleBookStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingSystemStrip([
                ("signature", name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"),
                ("flag.2.crossed", drawnChapter?.name ?? "No Chapter yet"),
                ("rectangle.stack", "Your little book")
            ])
            onboardingTitle("Your First Little Book")
            onboardingProse("""
            Wicker holds the Page a moment longer than he needs to. Then he flips it back at you, and you catch it.

            "Go on then," he says. "See what it made of you."

            "You gave it a lot of true things," Zara says. "It wants to give you something back."
            """)

            onboardingPhotoBindingChoice
                .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.04))

            onboardingInscriptionCoverChoice
                .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.05))

            onboardingFirstBindingInvite
                .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.06))

            if didBindFirstEdition {
                onboardingPreviewCard(
                    symbol: "checkmark.seal.fill",
                    title: "Your first little book's yours.",
                    body: didCloseFirstEditionPreview
                        ? "It's saved in my files. Read it, share it, print it. It's yours whatever you do next."
                        : "Open it. Everything I remembered, your Chapter, Wicker, and Zara's letter are inside."
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else if !firstEditionBindingError.isEmpty {
                onboardingPreviewCard(
                    symbol: "exclamationmark.triangle",
                    title: "The thread snapped.",
                    body: firstEditionBindingError
                )
                // The answers are already in `onboardingResult`; the edition is
                // the only thing missing, and it can be bound later from the
                // Bindery. A repeating failure must still have a way forward.
                secondaryOnboardingButton("Carry on, bind it later", systemImage: "arrow.right") {
                    withAnimation(reduceMotion ? .none : .easeOut(duration: 0.32)) {
                        didCloseFirstEditionPreview = true
                    }
                }
            }

            if didCloseFirstEditionPreview {
                onboardingThirtyDayPromise
                    .id("onboarding-knock")
                    .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.06))
                continueButton("Open the Book", disabled: whisperCadence.isEmpty)
            }
        }
    }

    private var onboardingSymbol: String {
        guard step > 0 else { return "book.pages" }
        switch step - 1 {
        case 0: return "signature"
        case 1: return "takeoutbag.and.cup.and.straw"
        case 2: return "leaf.fill"
        case 3: return "sparkles"
        case 4: return "seal"
        case 5: return "flag.2.crossed"
        case 6: return "theatermasks"
        case 7: return "die.face.4"
        default: return "rectangle.stack"
        }
    }

    private var onboardingStageName: String {
        guard step > 0 else { return "First Page" }
        switch step - 1 {
        case 0: return "Through the Page"
        case 1: return "Snacks"
        case 2: return "What You Believe"
        case 3: return "Your Kind of Magic"
        case 4: return "Your Story Name"
        case 5: return "Your First Chapter"
        case 6: return "Wicker"
        case 7: return "The Inkbones"
        default: return "Your Little Book"
        }
    }

    private var onboardingHeaderLine: String {
        guard step > 0 else { return "An ordinary day, turned into something you can hold." }
        switch step - 1 {
        case 0: return "You fall in, and somebody asks your name."
        case 1: return "Zara asks the important question."
        case 2: return "One thing you believe."
        case 3: return "What makes a day feel special."
        case 4: return "I say what you are."
        case 5: return "Five banners, five arguments. Pick one."
        case 6: return "Somebody takes your Page."
        case 7: return "Answer him, and let the bones decide."
        default: return "Your answers become a little book you can keep."
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
                .accessibilityLabel("Skip these first questions and open the free Book")
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
        case 1: return "An Ordinary Hour"
        case 2: return "A Good Moment"
        case 3: return "The Curse"
        default: return "Catch One Now"
        }
    }

    private var openingMiniSymbol: String {
        switch openingMiniStep {
        case 0: return "doc.text.fill"
        case 1: return "cloud.fog"
        case 2: return "arrow.uturn.backward.circle"
        case 3: return "exclamationmark.triangle.fill"
        default: return "sparkle.magnifyingglass"
        }
    }


    /// Three questions the reader was present for and cannot answer. "Gone" is
    /// exactly as easy to tap as "I remember it": the beat only works if the out
    /// is effortless and the Book sounds pleased rather than sorry about it.
    @ViewBuilder
    private var onboardingRecallProbes: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(recallQuestions.enumerated()), id: \.offset) { index, question in
                let state = recallState(index: index)
                VStack(alignment: .leading, spacing: 8) {
                    Text(question)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        recallAnswerButton("I remember it", index: index, remembered: true, selected: state == true)
                        recallAnswerButton("I don't remember", index: index, remembered: false, selected: state == false)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.paper.opacity(0.46), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(BookPalette.ink.opacity(state == nil ? 0.12 : 0.24), lineWidth: 1)
                }
                .modifier(OnboardingSectionArrivalModifier(kind: .section, delay: 0.05 + Double(index) * 0.07))
            }
        }
    }

    private func recallAnswerButton(_ title: String, index: Int, remembered: Bool, selected: Bool) -> some View {
        Button {
            answerRecall(index: index, remembered: remembered)
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    (selected ? (remembered ? BookPalette.teal : BookPalette.ink) : BookPalette.paper)
                        .opacity(selected ? 0.22 : 0.5),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            (selected ? (remembered ? BookPalette.teal : BookPalette.ink) : BookPalette.ink).opacity(selected ? 0.5 : 0.14),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.bookPress())
        .foregroundStyle(selected ? BookPalette.ink : BookPalette.ink.opacity(0.7))
    }

    /// The "I caught it" answer is the dangerous one: a reader who beat the
    /// trick can decide the whole premise is a party game and stop listening.
    /// So the Book doesn't congratulate them: it demonstrates the same
    /// machinery a second time, on them, using the sentence they are currently
    /// reading. Prediction is why the word vanished unnoticed, and it is also
    /// why nobody reads letters. Naming the mechanism turns a trick into an
    /// argument.
    private var livingInkPredictionProse: String {
        let word = livingInkProofParts.word.trimmingCharacters(in: .punctuationCharacters)
        let opener = pageChangeNoticed == "caught"
            ? "You saw it go. It was “\(word)”. Good eyes. Most people don't."
            : "It was “\(word)”. I took it while you were looking right at it."
        return """
        "\(opener)"

        "Things go missing like that all day long, and nobody notices. Not words. Bits of your actual life."
        """
    }

    private var openingVerdictTitle: String {
        recallRemembered >= 3 ? "You've Made This Awkward" : "That's the Curse"
    }

    /// Names both halves of the contrast outright. Saying "one of them" and
    /// "the other" made the reader do the bookkeeping at the exact moment the
    /// argument lands, and an argument the reader has to reconstruct is one
    /// they can decline.
    private var openingVerdictProse: String {
        let activity = RoutineRecallProbe.scenario(id: recallScenario)?.noun ?? "ordinary activity"
        let detail = awakeMemory.trimmingCharacters(in: .whitespacesAndNewlines)
        if recallRemembered >= 3 {
            return """
            "You remembered all three things from that \(activity). Then you gave me “\(detail)” without even stopping."

            "I came here to catch you out and you've spoiled it. Fine. I don't mind."

            "The Curse is real. It just hasn't got as much of you yet."
            """
        }
        return """
        "You were there for the whole \(activity), and \(recallMissedPhrase) already gone. Then I asked about a good moment, and you gave me “\(detail)” straight away."

        "Same week. Same head. One of them stuck to you. The other one slid off while you were still in it."

        "That's the Curse. Its proper name is the Rut of Routine. It's on everybody, and it isn't your fault."
        """
    }

    /// "two of the three small things are" — counted, never rounded down to
    /// something gentler. Zero kept is said plainly too.
    private var recallMissedPhrase: String {
        switch RoutineRecallProbe.askedCount - recallRemembered {
        case ...1: return "one of the three small things is"
        case 2: return "two of the three small things are"
        default: return "all three small things are"
        }
    }

    private var openingOfferProse: String {
        """
        "I've been fighting the Curse for a long time. But I haven't got hands. I haven't got feet. I've never stood in the rain. You have."

        "So here's how we fight it. You catch one real thing from your day before it blurs. A bird arguing with your fence. Something your mum said. You bring it to me, and I keep it. I make stories out of it. Every month I hand back what you kept, in writing, and you can check I'm not lying."

        "Let's catch one now. Before you go anywhere."
        """
    }

    // MARK: The interrogation

    /// Seeded off the arrival moment so the same reader is always asked the
    /// same three. Being asked different questions on a second look would show
    /// the machinery and cost the beat its authority.
    private var recallQuestions: [String] {
        RoutineRecallProbe.questions(
            scenarioID: recallScenario,
            seed: "\(Int(arrivalTimestamp))-\(recallScenario)"
        )
    }

    private var recallAnswers: [Character] { Array(recallAnswersRaw) }

    private var recallAnswered: Bool {
        !recallScenario.isEmpty && recallAnswersRaw.count == recallQuestions.count
    }

    private var recallRemembered: Int {
        recallAnswers.filter { $0 == "1" }.count
    }

    private func answerRecall(index: Int, remembered: Bool) {
        var chars = Array(recallAnswersRaw)
        while chars.count <= index { chars.append("-") }
        chars[index] = remembered ? "1" : "0"
        BookFeedback.play(.select)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            recallAnswersRaw = String(chars.prefix(recallQuestions.count))
        }
    }

    private func recallState(index: Int) -> Bool? {
        guard index < recallAnswers.count else { return nil }
        switch recallAnswers[index] {
        case "1": return true
        case "0": return false
        default: return nil
        }
    }

    /// The tally, stored as the routine-memory baseline the rest of the app
    /// already reads. A count of concrete misses is harder evidence than the
    /// old self-assessment, which people flattered themselves answering.
    private var recallBaselineID: String {
        switch recallRemembered {
        case 0: return "blank"
        case 1: return "result"
        case 2: return "islands"
        default: return "full"
        }
    }

    private var onboardingOpeningPage: some View {
        onboardingOpeningMiniStepContent
            .animation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.84), value: didCompleteFirstPress)
            .animation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.84), value: openingMiniStep)
    }

    /// Keep each opening beat behind a type-erased boundary. The combined
    /// result-builder switch grew deep enough that the Swift runtime exhausted
    /// Rabbit's main-thread stack while resolving its concrete generic type,
    /// before the first onboarding beat could appear.
    private var onboardingOpeningMiniStepContent: AnyView {
        switch openingMiniStep {
        case 0: return AnyView(onboardingOpeningFindsYouStep)
        case 1: return AnyView(onboardingOpeningRecallStep)
        case 2: return AnyView(onboardingOpeningAwakeStep)
        case 3: return AnyView(onboardingOpeningVerdictStep)
        default: return AnyView(onboardingOpeningCatchStep)
        }
    }

    /// The claim and the first proof on one Page. The word goes missing from
    /// the very card that says "I can prove it", while the reader is holding
    /// it, so there's no second copy of the sentence to compare against.
    private var onboardingOpeningFindsYouStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingOpeningOverture
            onboardingOpeningCard

            if didLivingInkChange {
                onboardingProse("""
                "I just rubbed out a word. While you were holding me. Did you see it go?"
                """)
                .id("onboarding-opening-bite")
                .transition(.opacity.combined(with: .move(edge: .top)))
                onboardingChoiceList(choices: pageChangeChoices, selection: $pageChangeNoticed)
            }

            if !pageChangeNoticed.isEmpty {
                onboardingProse(livingInkPredictionProse)
                    .id("onboarding-opening-prediction")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                onboardingRoutineReceiptCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
                openingMiniContinueButton("Test me") {
                    advanceOpeningMiniStep()
                }
            }
        }
    }

    private var onboardingOpeningRecallStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingTitle("One Ordinary Hour")
                .id("onboarding-opening-recall")
            onboardingProse("""
            "Let's test it. Which of these did you do most recently? Cooking, a walk you always take, or a drive you know by heart. Tap one."

            "Then I'll ask about three small things from it. Just tap whether you remember each one. No typing. Don't think too hard."
            """)
            onboardingChipChoices(
                choices: RoutineRecallProbe.scenarios.map {
                    OnboardingChoice(id: $0.id, title: $0.label, detail: "", symbol: "clock.arrow.circlepath")
                },
                selection: $recallScenario
            )
            if let scenario = RoutineRecallProbe.scenario(id: recallScenario) {
                onboardingProse("\"\(scenario.setup)\"")
                    .id("onboarding-recall-setup")
                onboardingRecallProbes
                if recallAnswered {
                    onboardingPreviewCard(
                        symbol: recallRemembered >= 3 ? "eye.fill" : "cloud.fog",
                        title: recallRemembered >= 3 ? "Well then" : "There it is",
                        body: RoutineRecallProbe.verdict(remembered: recallRemembered, scenario: scenario),
                        largeText: true
                    )
                    .id("onboarding-recall-verdict")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            openingMiniContinueButton(
                "Next question",
                disabled: !recallAnswered
            ) {
                routineMemory = recallBaselineID
                advanceOpeningMiniStep()
            }
        }
    }

    private var onboardingOpeningAwakeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingTitle("A Good Moment, Lately")
                .id("onboarding-opening-control")
            // The chips answer "what were you doing", so the question has to
            // ask that. "The last time, not your favourite time" blocks the
            // idealised holiday answer: the verdict needs something from this
            // month, not the best week of their life.
            onboardingProse("""
            "Now the other kind. Think of the last time you felt properly awake. Not your best day ever. Just the most recent good bit. What were you doing? Tap the closest."
            """)
            onboardingChipChoices(choices: aliveChoices, selection: $mostAlive)
            if !mostAlive.isEmpty {
                onboardingProse("""
                "Now write one thing you can still see, hear or feel from it. A sound. A colour. What your hands were doing. \u{201C}My friend's ridiculous laugh\u{201D} is plenty."
                """)
                .id("onboarding-alive-detail")
                onboardingField("A sound, a sight, or something you felt...", text: $awakeMemory)
            }
            openingMiniContinueButton(
                "Hand it over",
                disabled: mostAlive.isEmpty
                    || awakeMemory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                advanceOpeningMiniStep()
            }
        }
    }

    /// The verdict, then the one question it makes obvious: where does it get
    /// you worst? The answer is used on the spot and again in the reader's
    /// name, so it sits with the Curse it's about rather than a screen later.
    private var onboardingOpeningVerdictStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingTitle(openingVerdictTitle)
                .id("onboarding-opening-verdict")
            onboardingProse(openingVerdictProse)
            onboardingNotYourFaultCard
                .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.10))
            onboardingTitle("Where Does It Get You Worst?")
                .id("onboarding-opening-rut")
            onboardingProse("""
            "Tap the closest. That's where I'll start looking."
            """)
            onboardingChipChoices(choices: rutChoices, selection: $rutStrongest)
            if !rutStrongest.isEmpty {
                onboardingPreviewCard(
                    symbol: "scope",
                    title: "Noted",
                    body: rutReflection
                )
                .id("onboarding-opening-rut-reflection")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            openingMiniContinueButton(
                "So what do we do?",
                disabled: rutStrongest.isEmpty
            ) {
                advanceOpeningMiniStep()
            }
        }
    }

    /// The offer and the first catch, together, because the button on the
    /// verdict asks "so what do we do?" and this is the answer: you catch one,
    /// I keep it. The story card presses the reader's own sentence in front of
    /// them the moment they decide.
    private var onboardingOpeningCatchStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingTitle("Catch One Now")
                .id("onboarding-opening-offer")
            onboardingProse(openingOfferProse)
            onboardingOpeningPress
                .id("onboarding-opening-press")
            if firstPressTrimmedText.isEmpty {
                onboardingFirstPressLocalPreview
            } else {
                onboardingNoticedLine
                    .transition(.opacity.combined(with: .move(edge: .top)))
                onboardingOpeningKeepDecision
                    .transition(.opacity.combined(with: .move(edge: .top)))
                // The Curse's entrance branches on the keep-or-wait choice made
                // in the card directly above, so it has to render after it.
                if rehearsalChoice != nil {
                    onboardingProse(firstPressRutArrivalProse)
                        .id("onboarding-opening-grey-bite")
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                onboardingFirstPressLocalPreview
                if rehearsalChoice != nil {
                    onboardingProse(firstPressTransitionProse)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    onboardingStoryCardShareButton
                    onboardingOpenBookTab
                }
            }
        }
    }

    // The Book is direct, curious, and occasionally feral. Give every question
    // a concrete subject, name changing speakers, and explain the next action.
    // A surprise belongs in what happens, not in instructions readers must decode.
    static let openingFirstWords = "You pick up the book you just found. Nobody saw you take it."

    /// Overprinted across the loose Page. This is where the curse warning
    /// lives now: the Page arrives already carrying it, so the claim is a thing
    /// the reader finds rather than a thing the app declares at them.
    static let openingPageStamp = "STOP. You're under a curse. I can prove it."

    /// The very first words of the whole app: the reader opens the app, finds
    /// the Book, and sees a loose page slip out before the Book itself opens.
    private var onboardingOpeningOverture: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isOpeningOvertureTitleVisible || isPadOnboardingDevice {
                Text(Self.openingFirstWords)
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

            Text("A loose Page falls out. I'm writing on it. I want to talk to you.")
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
                ? "The Page slipped out the moment you found me: \(arrivalClockTime), \(arrivalWeekdayName) \(firstPressTimeName). I noticed you arrive."
                : "That was happening before I asked. The Curse had it filed as scenery. You just made it something.")
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
            Text("Your first move")
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

                Text("Look up from me. Find one thing near you: a sound, the light, your mug, your own cold feet. What's it doing right now? Write one sentence about it.")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .modifier(OnboardingGhostInModifier(delay: 0.10))

            onboardingEmbeddedDetailField

            Text("Write your own, or tap one of mine and change it until it's true.")
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

    private var onboardingEmbeddedDetailField: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "The light's sitting on the chair like it's waiting for someone.",
                text: firstPressTextBinding,
                axis: .vertical
            )
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .focused($isOnboardingFieldFocused)
                .inkFeedback(text: firstPressTextBinding.wrappedValue)
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
        .id(Self.activeTextFieldScrollID)
    }

    private var onboardingFirstPressLocalPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.teal)
                Text("YOUR STORY PREVIEW")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(BookPalette.teal)
                Spacer(minLength: 0)
                Text(rehearsalChoice == .keep ? "KEPT" : (rehearsalChoice == .wait ? "WAITING" : "FORMING"))
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
            Text("NOW YOU DECIDE.")
                .font(.system(size: 10, weight: .black))
                .tracking(1.1)
                .foregroundStyle(BookPalette.ink.opacity(0.46))

            Text("Keep it and it's mine to read. Tonight, and after. It'll come back in stories and letters, weeks from now, when you've forgotten you told me.\n\nLet it wait and nothing's lost. I'll just notice you didn't.")
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
                Text("The Page folds the sentence inward and says nothing about it.")
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

    private var onboardingOpenBookTab: some View {
        Button {
            openBookFromLivingPage()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16, weight: .black))
                Text(rehearsalChoice == nil ? "Keep it or let it wait" : "Open the Book")
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
        .disabled(rehearsalChoice == nil)
        .opacity(rehearsalChoice != nil ? 1 : 0.62)
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
        guard rehearsalChoice != nil else {
            BookFeedback.play(.error)
            return
        }
        BookFeedback.play(.openPage, fill: true)
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

    /// While the reader is still on the first beat, the word the Book took is
    /// missing from the opening card itself.
    private var openingArrivalExcerptAsShown: String {
        guard step == 0, openingMiniStep == 0, didLivingInkChange else { return openingArrivalExcerpt }
        let parts = livingInkProofParts
        return "\(parts.before)_____\(parts.after)"
    }

    private var onboardingOpeningArtifact: BookOfYouShareArtifact {
        let hasPageDecision = !firstPressTrimmedText.isEmpty
        return BookOfYouShareArtifact(
            title: firstPressTrimmedText.isEmpty ? openingArrivalTitle : firstPressPreviewTitle,
            excerpt: hasPageDecision ? firstPressPreviewExcerpt : openingArrivalExcerptAsShown,
            dateLine: arrivalMoment.formatted(date: .abbreviated, time: .omitted),
            themeName: "Ordinary life",
            chapterName: didCompleteFirstPress
                ? "First kept Page"
                : (rehearsalChoice == .wait ? "Allowed to wait" : (hasPageDecision ? "Forming now" : "Written at your arrival")),
            seed: openingArtifactSeed,
            // The warning stays when the reader writes their own first line and
            // the rest of the Page re-forms around it. The Page becomes theirs;
            // what it came to tell them does not get overwritten by them.
            stamp: Self.openingPageStamp
        )
    }

    private var onboardingInscriptionBookOfYouArtifact: BookOfYouShareArtifact {
        let reader = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"
        let decision = rehearsalChoice == .keep
            ? "kept one true Page"
            : "let the first Page wait"
        let chapter = drawnChapter?.name ?? "five arguing banners"
        let thresholdActs = onboardingPagewrightIsReady
            ? "\(decision), handed me a pile of true answers, and watched \(chapter) change what happened next"
            : "\(decision), and watched \(chapter) change what happened next"
        let excerpt = "\(reader) \(thresholdActs). These first answers and choices became a little book to keep."
        return BookOfYouShareArtifact(
            title: "What I Made of Your Answers",
            excerpt: excerpt,
            dateLine: arrivalMoment.formatted(date: .abbreviated, time: .omitted),
            themeName: "Inscription",
            chapterName: "The Book of You",
            seed: "first-door-book-of-you".stableHash
                ^ reader.stableHash
                ^ firstPressTrimmedText.stableHash
                ^ drawnChapterID.stableHash
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

    /// A lightweight facsimile of the monthly bound edition: the "remember"
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
                Text("\(arrivalMonthName)'s kept Pages are already shoving at the press. When you want the edition, I'll bind them into a PDF to keep, print at home, or later order as a physical book from the Bindery.")
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

    /// The opening's entire argument, closed at the end: they could not
    /// retrieve three ordinary things from an hour they lived through, and then
    /// handed over one exact thing without pausing. Quoting their own words
    /// back is the proof: anything the Book asserts here it has already shown.
    private var recallContrastLine: String {
        let detail = awakeMemory.trimmingCharacters(in: .whitespacesAndNewlines)
        return recallRemembered >= RoutineRecallProbe.askedCount
            ? "You remembered all three small things from an ordinary hour. Then you gave me “\(detail)” without even stopping. The Curse hasn't got much of you yet. I'll keep an eye on it."
            : "You lost \(RoutineRecallProbe.askedCount - recallRemembered) of three small things from an hour you were awake for. Then you gave me “\(detail)” straight away. Same week, same head. You were only really there for one of them."
    }

    private func onboardingJourneyRow(symbol: String, title: String, detail: String) -> some View {
        // This panel is the payoff for the whole Inscription: it is where the
        // reader finds out the Book was listening. Caption-sized type made the
        // evidence look like a receipt footer.
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 32, height: 32)
                .background(BookPalette.nightPanel.opacity(0.92), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                Text(detail)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.74))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The last ask, and the only one about the future. No research panel,
    /// no thirty-day badge, and no reassurance about missing days: the Book
    /// asks when to knock and the reader's answer triggers the prompt it
    /// promised.
    private var onboardingThirtyDayPromise: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("BEFORE I LET YOU GO")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(BookPalette.gold)
                Text("When should I knock?")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(BookPalette.ink)
            }

            Text("\"Here's the whole game. Notice one true thing. Keep it, or let it wait. See what comes back. I'll knock once to remind you. When?\"")
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            onboardingChipChoices(
                choices: whisperChoices,
                selection: $whisperCadence,
                largeText: true
            )
            if !whisperCadence.isEmpty {
                onboardingPreviewCard(
                    symbol: "bell.badge.fill",
                    title: "\(whisperTitle) it is.",
                    body: whisperCueReflection,
                    largeText: true
                )
                .id("onboarding-whisper-hinge")
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Pick one to carry on. Want me quiet? That's the last one.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(BookPalette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
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
                            ? "Your photograph's going in your first little book."
                            : "Everything you told me is already in it. You can add one ordinary photograph too."
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
                        Text("It'll sit next to the words you made, decorated, full size.")
                            .font(.system(.caption, design: .serif).weight(.semibold))
                            .foregroundStyle(BookPalette.ink.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(BookPalette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Text("A room, a coffee cup, someone you love, the light right now. Boring's fine. Boring's usually the honest one. I decorate it right here on your phone. It doesn't go anywhere.")
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
                Text("You don't have to. You can make the book without one.")
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

    private var onboardingInscriptionCoverChoice: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(BookPalette.nightText)
                    .frame(width: 34, height: 34)
                    .background(BookPalette.violet.opacity(0.92), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("CHOOSE YOUR COVER")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.05)
                        .foregroundStyle(BookPalette.gold)
                    Text("\"Pick my face. I can't see it while I'm open.\"")
                        .font(.system(.callout, design: .serif).weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.80))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Pick a cover for your first little book. One of these pictures, or your own photograph if you added one.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    inscriptionCoverChoiceButton(id: "", title: "How We Met", plate: nil)
                    #if canImport(UIKit)
                    if didKeepOnboardingPhoto,
                       !inscriptionCoverPhotoPath.isEmpty,
                       let image = UIImage(contentsOfFile: inscriptionCoverPhotoPath) {
                        inscriptionCoverChoiceButton(
                            id: "reader-photo",
                            title: "Your Photograph",
                            plate: nil,
                            readerImage: image
                        )
                    }
                    #endif
                    ForEach(PublicationCoverCatalogue.rotating) { plate in
                        inscriptionCoverChoiceButton(id: plate.id, title: plate.title, plate: plate)
                    }
                }
                .padding(.vertical, 2)
            }

            #if canImport(UIKit)
            if let proof = inscriptionSelectedCoverProofImage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WITH ITS REAL WORDS ON")
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.9)
                        .foregroundStyle(BookPalette.gold)
                    Image(uiImage: proof)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 230)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
                    Text("This is exactly how the cover will print.")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(BookPalette.nightPanel.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
            }
            #endif

            Text(
                inscriptionCoverChoiceID.isEmpty
                    ? "\"That one. It suits me.\""
                    : "\"That coat. Hold still while I get ink on it.\""
            )
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(BookPalette.violet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    BookPalette.page.opacity(0.78),
                    BookPalette.violet.opacity(0.08),
                    BookPalette.page.opacity(0.58)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.violet.opacity(0.30), lineWidth: 1)
        }
    }

    private func inscriptionCoverChoiceButton(
        id: String,
        title: String,
        plate: PublicationCoverPlate?,
        readerImage: UIImage? = nil
    ) -> some View {
        let isSelected = inscriptionCoverChoiceID == id
        return Button {
            selectInscriptionCover(id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                inscriptionCoverChoiceArtwork(id: id, plate: plate, readerImage: readerImage)
                    .frame(width: 104, height: 142)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isSelected ? BookPalette.lampGold.opacity(0.92) : BookPalette.ink.opacity(0.14),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(BookPalette.nightText)
                                .padding(6)
                                .background(BookPalette.lampGold.opacity(0.94), in: Circle())
                                .padding(6)
                        }
                    }

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                    .lineLimit(2)
                    .frame(width: 104, alignment: .leading)
            }
            .padding(7)
            .background(
                isSelected ? BookPalette.lampGold.opacity(0.13) : BookPalette.page.opacity(0.58),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Chooses the cover for your first PDF book")
    }

    #if canImport(UIKit)
    private var inscriptionSelectedCoverProofImage: UIImage? {
        let artwork: MonthlyEditionPDFWriter.VolumeCoverArtwork
        if inscriptionCoverChoiceID == "reader-photo" {
            guard !inscriptionCoverPhotoPath.isEmpty,
                  let image = UIImage(contentsOfFile: inscriptionCoverPhotoPath) else { return nil }
            artwork = .init(
                image: image,
                titleLayout: .photographFooter,
                id: "first-door-reader-photo-proof",
                focusPoint: (0...1).contains(inscriptionCoverFocusX)
                    && (0...1).contains(inscriptionCoverFocusY)
                    ? CGPoint(x: CGFloat(inscriptionCoverFocusX), y: CGFloat(inscriptionCoverFocusY))
                    : nil
            )
        } else {
            guard let plate = PublicationCoverCatalogue.plate(id: inscriptionCoverChoiceID),
                  let image = UIImage(named: plate.assetName) else { return nil }
            artwork = .init(
                image: image,
                titleLayout: plate.titleLayout,
                id: plate.id
            )
        }
        let copy = MonthlyEditionPDFWriter.VolumeCoverCopy(
            readerName: name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader",
            coverLine: "HOW WE MET",
            coverSubline: namedRole.fullName
        )
        return MonthlyEditionPDFWriter.volumeCoverFrontProof(
            copy: copy,
            artwork: artwork,
            size: CGSize(width: 360, height: 540)
        )
    }
    #endif

    @ViewBuilder
    private func inscriptionCoverChoiceArtwork(
        id: String,
        plate: PublicationCoverPlate?,
        readerImage: UIImage?
    ) -> some View {
        if id == "reader-photo", let readerImage {
            Image(uiImage: readerImage)
                .resizable()
                .scaledToFill()
        } else if let plate {
            #if canImport(UIKit)
            if let image = UIImage(named: plate.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                inscriptionMissingCoverArtwork
            }
            #else
            inscriptionMissingCoverArtwork
            #endif
        } else {
            ZStack {
                LinearGradient(
                    colors: [BookPalette.nightPanel, BookPalette.violet.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(spacing: 8) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(BookPalette.lampGold)
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(BookPalette.lampGold)
                                .frame(width: 5, height: 5)
                        }
                    }
                    Text("HOW WE\nMET")
                        .font(.system(size: 10, weight: .black, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BookPalette.nightText)
                }
                .padding(10)
            }
        }
    }

    private var inscriptionMissingCoverArtwork: some View {
        ZStack {
            BookPalette.paper
            Image(systemName: "photo.artframe")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(BookPalette.ink.opacity(0.38))
        }
    }

    private func selectInscriptionCover(_ choiceID: String) {
        guard inscriptionCoverChoiceID != choiceID else { return }
        inscriptionCoverChoiceID = choiceID
        if didBindFirstEdition {
            didBindFirstEdition = false
            boundInscriptionEdition = nil
            inscriptionEditionPDFPath = ""
            didCloseFirstEditionPreview = false
            firstEditionBindingError = ""
            castPreviewURL = nil
        }
        BookFeedback.play(.select)
    }

    /// The finale payoff: the Bindery presses a real mini Monthly Edition:
    /// cover, star chart, foreword, Zara's letter, and the pages the player
    /// authored during onboarding: through the same PDF pipeline as the
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
                    // Not "already working": nothing is sewn until the reader
                    // taps below.
                    Text("THE BINDERY")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(BookPalette.gold)
                    Text(didBindFirstEdition ? "Your first little book is done." : "Let's make your first little book.")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(
                        didKeepOnboardingPhoto
                            ? "A real book you can keep, as a PDF. Your cover, your photograph, a page of your scraps, what your Chapter thinks, what Wicker did, everything I remembered, and a letter from Zara. Keep it, share it, print it."
                            : "A real book you can keep, as a PDF. Your cover, a page of your scraps, what your Chapter thinks, what Wicker did, everything I remembered, and a letter from Zara. Keep it, share it, print it."
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                bindInscriptionEdition()
            } label: {
                Label(
                    isBindingFirstEdition
                        ? "The Bindery's sewing…"
                        : (didBindFirstEdition ? "Open my little book again" : "Make my little book"),
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
                    shareBoundInscriptionEdition()
                } label: {
                    Label("Share my little book", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.teal)
                .accessibilityHint("Opens the Apple share sheet for your first PDF book")
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
    private func bindInscriptionEdition() {
        isOnboardingFieldFocused = false
        guard !isBindingFirstEdition else { return }
        isBindingFirstEdition = true
        didCloseFirstEditionPreview = false
        firstEditionBindingError = ""
        if !onboardingPagewrightIsReady {
            arrangeOnboardingPagewrightLeaf()
        }
        let sampleBookOfYouPageURL = BookOfYouShareCardRenderer.render(artifact: onboardingInscriptionBookOfYouArtifact)
        let edition = inscriptionEdition(sampleBookOfYouPageURL: sampleBookOfYouPageURL)
        BookFeedback.play(.braidStart)
        withAnimation(.easeIn(duration: 0.3)) { isSewingFirstEdition = true }
        Task { @MainActor in
            do {
                let url = try inscriptionEditionArchiveURL()
                try MonthlyEditionPDFWriter.write(edition, to: url)
                // Let the sewing beat play through before the book opens.
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 320 : 1200))
                BookFeedback.play(.braidComplete, fill: true)
                withAnimation(.easeOut(duration: 0.35)) { isSewingFirstEdition = false }
                isBindingFirstEdition = false
                didBindFirstEdition = true
                boundInscriptionEdition = edition
                inscriptionEditionPDFPath = url.path
                castPreviewURL = url
            } catch {
                withAnimation(.easeOut(duration: 0.3)) { isSewingFirstEdition = false }
                isBindingFirstEdition = false
                firstEditionBindingError = "The thread snapped before the book was done. Tap Make my little book to try again."
                BookFeedback.play(.error)
            }
        }
    }

    @MainActor
    private func shareBoundInscriptionEdition() {
        isOnboardingFieldFocused = false
        let path = inscriptionEditionPDFPath.trimmingCharacters(in: .whitespacesAndNewlines)
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
    private func inscriptionEditionArchiveURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        let directory = base
            .appendingPathComponent(bundle, isDirectory: true)
            .appendingPathComponent("FirstDoorEditions", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ReEnchanted-How-We-Met.pdf")
    }

    /// Synthesizes a real special edition from the onboarding answers. Genuine
    /// `BookPage`s still pass through the shared curator so no kept material is
    /// fabricated or dropped; the final editorial order and four-signature
    /// matter belong specifically to the threshold instead of borrowing a
    /// one-day monthly report's foreword and theme furniture.
    private func inscriptionEdition(sampleBookOfYouPageURL: URL? = nil) -> MonthlyEdition {
        let calendar = Calendar.current
        let now = arrivalMoment
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)
        let readerName = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"
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
            promptText: "What the test showed",
            userInput: """
            \(curseTestLine)
            Still sharp: \u{201C}\(awakeMemory.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "a good moment")\u{201D}
            Where it gets you worst: \(rutTitle.lowercased())

            \(rutReflection)
            """,
            tags: ["onboarding", "reflection", "rut-proof"],
            sourceID: "first-door"
        ))

        pages.append(BookPage(
            type: .souvenir,
            createdAt: now.addingTimeInterval(150),
            promptText: "I learn my manners",
            userInput: """
            Margin ration: \(snackInSentence.map { "\u{201C}\($0)\u{201D}" } ?? "nothing")
            First belief: \(belief.trimmingCharacters(in: .whitespacesAndNewlines))
            \(investedBelief ? "It's in the story now. It'll turn up again." : "It's resting in the margin.")
            """,
            tags: ["onboarding", "reader-texture", "belief"],
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
                userInput: "When Wicker interrupted, you answered with \(mode.title.lowercased()). \(wickerConsequence(for: mode, tier: outcome.tier))",
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
                    caption: "A sample story Page made from your first answers.",
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
            promptText: "What I Made of Your Answers",
            userInput: inscriptionMiniStory,
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

            You fell out of the Unwritten this \(firstPressTimeName) and, before anyone could give you a tour, you'd already shown me two things: how you like a moment told, and whether it was worth keeping.

            Bring more of the small stuff. The Academy will argue about it, loudly. I'll remember what you actually picked.

            Zara Finch, who found you in the sentence-dust
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
                latestLine: "You chose \(chapter.name) for your first story.",
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
            readerRole: BoundReaderRole(namedRole),
            startDate: monthStart,
            endDate: now,
            generatedAt: now,
            calendar: calendar
        )
        edition.dayBook = nil  // the threshold chapbook has its own press form
        edition.title = "Book of You: The Inscription"
        edition.subtitle = "\(readerName): your first little book"
        edition.publicationKind = .special
        edition.publicationRecipeID = "first-door"
        edition.publicationCoverPlateID = PublicationCoverCatalogue
            .plate(id: inscriptionCoverChoiceID)?
            .id

        // The threshold volume reads like a short commissioned book, not like
        // an unusually thin calendar report. Preserve every authored Page, but
        // put the sample story first, then its evidence, image plate, and Zara's
        // letter. The dedicated PDF path supplies the ownership and proof leaves.
        let inscriptionOrder = ["daily-braids", "souvenirs", "images", "letters"]
        edition.sections = edition.sections
            .compactMap { section -> MonthlyEditionSection? in
                guard inscriptionOrder.contains(section.id) else { return nil }
                var section = section
                switch section.id {
                case "daily-braids":
                    section.title = "What I Made of Your Answers"
                    section.note = "Your first detail, the Chapter you chose, and what happened with Wicker."
                case "souvenirs":
                    section.title = "Your Answers and Choices"
                    section.note = "The answers, choices, and small human facts that made this copy yours."
                case "images":
                    section.title = "One Piece of Your World"
                    section.note = "A real thing from outside me, pressed into the binding."
                case "letters":
                    section.title = "A Letter from the Sentence-Dust"
                    section.note = "Zara Finch writes to you from the Academy."
                default:
                    break
                }
                return section
            }
            .sorted { left, right in
                (inscriptionOrder.firstIndex(of: left.id) ?? .max)
                    < (inscriptionOrder.firstIndex(of: right.id) ?? .max)
            }

        let forgotten = max(0, RoutineRecallProbe.askedCount - recallRemembered)
        let curseTitle: String
        let curseEvidence: String
        let curseMeaning: String
        if recallAnswered, forgotten == 0 {
            curseTitle = "The Curse Meets Its Exception"
            curseEvidence = "You kept all three small details from the \(RoutineRecallProbe.scenario(id: recallScenario)?.noun ?? "ordinary hour")."
            curseMeaning = "The Rut didn't get that minute. Good. I love being proved wrong about this."
        } else if recallAnswered {
            curseTitle = "The Details That Slipped Past"
            curseEvidence = "\(forgotten == 1 ? "One" : (forgotten == 2 ? "Two" : "All three")) of the three small details were gone from the \(RoutineRecallProbe.scenario(id: recallScenario)?.noun ?? "ordinary hour")."
            curseMeaning = "You were awake for that whole hour, and that's all that stuck. That's the Curse. We're taking some back."
        } else {
            curseTitle = "The Claim Stays Blank"
            curseEvidence = "You didn't finish the three memory questions."
            curseMeaning = "I'd rather leave it blank than pretend I caught you."
        }

        let role = BoundReaderRole(namedRole)
        let chapterName = drawnChapter?.name ?? "The Five Chapters"
        let chapterBody = drawnChapter.map { chapterReading(for: $0) }
            ?? "The banners argued over the Page and declined to become a tidy personality test."
        let wickerLine: String = {
            guard let outcome = wickerOutcome,
                  let choice = wickerChoices.first(where: { $0.id == outcome.choiceID }) else {
                return "Wicker left the margin unbitten. For now."
            }
            return "When Wicker interrupted, you answered with \(choice.title.lowercased()). \(wickerConsequence(for: choice, tier: outcome.tier))"
        }()
        let firstDetailRaw = rehearsalChoice == .keep
            ? (firstSouvenir.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? inscriptionChapterSubject)
            : "the choice to let the first offered Page wait"
        let firstDetailWords = firstDetailRaw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let firstDetail = firstDetailWords.count > 180
            ? String(firstDetailWords.prefix(177)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
            : firstDetailWords
        let thresholdChoiceLine: String = {
            switch rehearsalChoice {
            case .keep:
                return "You told me to keep it. So I did. It's still here."
            case .wait:
                return "You let the Page wait. I wrote that down as a no, and a no counts."
            case nil:
                return "You never said keep or wait. So it's still waiting."
            }
        }()
        let pagewrightReturn = onboardingPagewrightIsReady
            ? "Your scraps are in here too, stuck down crooked on purpose."
            : "The Bindery pressed the Page, the argument, and the bite mark into this copy."
        let bookNote = """
        \(readerName),

        I was blank when you got here. Then you gave me \(firstDetail), and look what it did to my pages.

        This is the first thing we made while watching each other: one detail, one choice, one argument, one bite mark, all of it yours.

        I've only caught you once. I kept it anyway.

        - me
        """
        let wickerAtTableLine: String = {
            guard let outcome = wickerOutcome,
                  let choice = wickerChoices.first(where: { $0.id == outcome.choiceID }) else {
                return "I opened it. The margin's suspiciously unbitten, so I've left room for trouble."
            }
            return "I opened it. I bit the margin. \(readerName) answered with \(choice.title.lowercased()), and the page had the decency to change afterward."
        }()
        let bindingConversation = BoundVolumeCastConversation(
            title: "The Copy on the Binding Table",
            setting: "Zara and Wicker get the finished copy, still warm from the press. They're only allowed to argue about what's actually on the pages.",
            lines: [
                .init(
                    id: "first-door-zara-hinge",
                    speakerID: "zara-finch",
                    speakerName: "Zara Finch",
                    glyph: nil,
                    words: "Open it at the seam. \(firstDetail) is doing the real work. Small enough to be missed, specific enough to hold."
                ),
                .init(
                    id: "first-door-wicker-bite",
                    speakerID: "wicker-eddies",
                    speakerName: "Wicker Eddies",
                    glyph: nil,
                    words: wickerAtTableLine
                ),
                .init(
                    id: "first-door-zara-record",
                    speakerID: "zara-finch",
                    speakerName: "Zara Finch",
                    glyph: nil,
                    words: "Good. Leave the fighting in the binding. This copy remembers what actually happened."
                ),
                .init(
                    id: "first-door-wicker-verdict",
                    speakerID: "wicker-eddies",
                    speakerName: "Wicker Eddies",
                    glyph: nil,
                    words: "Fine. \(readerName) brought one real thing, and I kept it. I've checked. Annoyingly, it's still there."
                )
            ],
            evidenceIDs: [
                "first-door-detail",
                "chapter:\(drawnChapter?.id ?? "undrawn")",
                "wicker:\(wickerOutcome?.choiceID ?? "unanswered")",
                onboardingPagewrightIsReady ? "pagewright:\(onboardingPagewrightTemplate)" : "pagewright:not-made"
            ]
        )
        let readerCoverArtwork: InscriptionPublicationMatter.ReaderCoverArtwork? = {
            guard inscriptionCoverChoiceID == "reader-photo",
                  didKeepOnboardingPhoto,
                  !inscriptionCoverPhotoPath.isEmpty,
                  FileManager.default.fileExists(atPath: inscriptionCoverPhotoPath) else {
                return nil
            }
            let hasFocus = (0...1).contains(inscriptionCoverFocusX)
                && (0...1).contains(inscriptionCoverFocusY)
            return .init(
                imagePath: inscriptionCoverPhotoPath,
                titleLayout: .photographFooter,
                focusX: hasFocus ? inscriptionCoverFocusX : nil,
                focusY: hasFocus ? inscriptionCoverFocusY : nil
            )
        }()
        let specialClosing = """
        \(readerName), this copy keeps the things you told me, the choices you made, and what happened when you met Wicker.

        You came through as \(role?.markedName ?? "a reader still being named"). Bring me another small thing. Let's see if it grows teeth.

        - me
        """
        edition.inscriptionPublication = InscriptionPublicationMatter(
            arrivalLine: "Bound on \(now.formatted(.dateTime.weekday(.wide).month(.wide).day().year())) at \(arrivalClockTime).",
            signatures: [
                .init(
                    id: "curse",
                    title: curseTitle,
                    evidence: curseEvidence,
                    meaning: curseMeaning
                ),
                .init(
                    id: "learning",
                    title: "A Few Things About You",
                    evidence: "You light up \(mostAliveInYourWords). \(magicSourceInYourWords.capitalizedFirst) feels like magic to you. So I named you \(namedRole.fullName).",
                    meaning: "It's how I know what to bring you."
                ),
                .init(
                    id: "consequence",
                    title: "The Story Bites Back",
                    evidence: "\(chapterName) read your Page. \(wickerLine)",
                    meaning: "What you chose changed what happened next. The story's still sore about it."
                ),
                .init(
                    id: "return",
                    title: "Your First PDF Book",
                    evidence: onboardingPagewrightIsReady
                        ? "\(firstDetail) turned into a page of scraps, an argument, a consequence, and this book."
                        : "\(firstDetail) turned into a Page, an argument, a consequence, and this book.",
                    meaning: "Something from your real life went into me and came out different. That's the deal."
                )
            ],
            firstArgumentTitle: chapterName,
            firstArgumentBody: "\(chapterBody)\n\n\(wickerLine)",
            closing: specialClosing,
            pagewrightLeaf: onboardingPagewrightIsReady
                ? .init(
                    title: onboardingPagewrightTitle.nonEmpty ?? "My First Scrapbook Page",
                    imagePath: onboardingPagewrightImagePath,
                    templateID: onboardingPagewrightTemplate.nonEmpty ?? PagewrightTemplate.polaroidScatter.rawValue
                )
                : nil,
            bookNote: bookNote,
            thresholdThread: [
                .init(id: "noticed", stage: "YOU NOTICED", detail: firstDetail),
                .init(id: "kept", stage: "THE BOOK KEPT", detail: thresholdChoiceLine),
                .init(id: "argued", stage: "THE ACADEMY ARGUED", detail: "\(chapterName) took the first reading and refused to call it a verdict."),
                .init(id: "bit", stage: "WICKER BIT THE MARGIN", detail: wickerLine),
                .init(id: "returned", stage: "THE PRESS RETURNED", detail: pagewrightReturn)
            ],
            bindingConversation: bindingConversation,
            readerCoverArtwork: readerCoverArtwork
        )
        edition.foreword = ""
        edition.bindingStory = nil
        edition.closing = specialClosing
        edition.pageCount = edition.sections.reduce(0) { partial, section in
            partial + section.items.count
        }
        return edition
    }

    private var firstPressTransitionProse: String {
        let answer = rehearsalChoice == .keep
            ? "Got it. Now come and see what happens to it in there."
            : "Fine. It can wait. Come inside anyway."
        return "\"\(answer)\"\n\nThe loose Page slides back between the covers. Tap Open the Book to follow it."
    }

    private var firstPressRutArrivalProse: String {
        switch rehearsalChoice {
        case .keep:
            return """
            You keep the Page. Something grey starts eating at its edge.

            "That's the Curse. It's always hungry. Leave it. It can't have what you kept."
            """
        case .wait:
            return """
            You let the Page wait. As it folds, something grey nibbles its edge.

            "That's the Curse. Nobody invited it."
            """
        case nil:
            return """
            The Page waits for your decision. Something grey waits with it.
            """
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

	            Text("I'll gild it right here on your phone and tuck it into the PDF of your story. Nothing gets uploaded anywhere.")
	                .font(.system(.footnote, design: .serif))
	                .foregroundStyle(BookPalette.ink.opacity(0.58))
	                .lineSpacing(2)
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
	                        Text(isOnboardingPhotoLoading ? "The illumination's settling." : "Hand me one picture.")
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

	            // "You can't lose this" and "he walks off with something of
	            // yours" were withdrawing each other one clause apart. Both
	            // facts are true; only the reassurance had to go.
	            Text("Tap what you say back. That throws the Inkbones. A high throw and you win. A low throw and Wicker gets something to hold over you later.")
	                .font(.system(.callout, design: .serif))
	                .foregroundStyle(BookPalette.ink.opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(wickerChoices) { choice in
                    let selected = wickerOutcome?.choiceID == choice.id
                    let spent = wickerOutcome != nil && !selected
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

    /// The Glow-waking act break: plant the belief, burst gold ink from the
    /// sigil, let Zara's margin note land, and give the new Glow a beat to wake
    /// before the page turns.
    private func plantBeliefWithCeremony() {
        guard !isPlantingBelief else { return }
        isPlantingBelief = true
        investedBelief = true
        BookFeedback.play(.braidStart)
        beliefPlantBurst += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 600))
            isPlantingBelief = false
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
        // remains persisted for this Inscription, so reopening it cannot reroll.
        Int.random(in: 1...100)
    }

    private func wickerChoice(for id: String) -> WickerModeChoice? {
        wickerChoices.first { $0.id == id }
    }

    private var didCompleteInscriptionArrival: Bool {
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

    private func keepFirstPressPage() {
        isOnboardingFieldFocused = false
        guard !firstPressTrimmedText.isEmpty else {
            BookFeedback.play(.error)
            return
        }
        let alreadyKept = didCompleteFirstPress
        rehearsalChoice = .keep
        didCompleteFirstPress = true
        // Written after the choice, so the Book's reply is part of what's kept.
        firstSouvenir = firstPressSouvenirLine
        BookFeedback.play(.braidComplete, fill: true)
        // Celebrate authorship, not navigation: fire the burst + character echo
        // only on the first keep, and let the ink land before the note (the
        // live desk's sequencing rule).
        guard !alreadyKept else { return }
        openingKeepBurst += 1
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

    private func scheduleLivingInkRutProofIfNeeded() {
        livingInkChangeTask?.cancel()
        livingInkChangeTask = nil
        guard step == 0, openingMiniStep == 0 else { return }
        guard pageChangeNoticed.isEmpty else {
            didLivingInkChange = true
            return
        }

        didLivingInkChange = false
        // Long enough to read the stamp and the sentence under it once.
        livingInkChangeTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 4_200_000_000)
            } catch {
                return
            }
            guard step == 0, openingMiniStep == 0 else { return }
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.24)) {
                didLivingInkChange = true
            }
            BookFeedback.play(.tap)
        }
    }

    /// Minutes of today already spent at the moment the reader arrived.
    ///
    /// The Book took the *name of the day* off the opening Page, so the only
    /// honest receipt it can hand back is the one already on the clock. No
    /// estimate, no claim about the reader's history: a number they can check
    /// against their own watch.
    private var openingSpentMinutesToday: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: arrivalMoment)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Pays out the claim the reveal button makes. This used to promise "a
    /// number" and "a receipt" and then render neither, on the one screen whose
    /// whole job is proving the Book's claims can be checked.
    private var onboardingRoutineReceiptCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("\(openingSpentMinutesToday) minutes of today are already gone.")
                .font(.system(.title3, design: .serif).weight(.black))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(pageChangeNoticed == "caught"
                 ? "\"You caught one word, and you were staring straight at it. Today's had \(openingSpentMinutesToday) minutes so far. How many of those did you catch?\""
                 : "\"One word went while you were staring straight at it. Today's had \(openingSpentMinutesToday) minutes so far. How many of those did you actually see?\"")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.78))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.page.opacity(0.66), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(BookPalette.teal.opacity(0.88))
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
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
                         ? "Up you come."
                         : "Tap to let Zara help you stand up.")
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

    // MARK: Two beats that ask for nothing
    //
    // Snack, name, belief, magic and hands is five asks in a row, and the
    // reader can feel the form underneath the prose. These sit inside that run
    // and take no answer at all: one is the cast having opinions about
    // something the reader already told them, the other is a physical object
    // that clatters. Both exist to make the middle stop being a questionnaire.

    /// The name moment: the Book writes the reader's chosen name once, in gold,
    /// as a nibbed signature that draws itself on: the small ceremony of being
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
                    Text("\"\(belief)\"")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(BookPalette.ink.opacity(0.78))
                    Text(investedBelief ? "It's in the story now." : "Put it in the story and it comes alive in here.")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    /// The three wagers for this reader: stable per install so the payoff can
    /// name exactly what was guessed.
    private var onboardingWagers: [FirstWagers.Wager] {
        FirstWagers.three(seed: name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "reader")
    }

    /// A few concrete guesses. The reader chooses what is true; later pages
    /// can recall that answer without treating a shared word as proof.
    private var onboardingWagerBeat: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 26, height: 26)
                    .background(BookPalette.nightPanel.opacity(0.88), in: Circle())
                Text("Three guesses")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BookPalette.ink.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            Text("I want to guess. Tap any I get right.")
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
                 ? "None of these? I’ll have to get to know you."
                 : "I’ll remember \(confirmedWagers.count == 1 ? "that one" : "those").")
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
        // The prose above this picker already says these are five
        // arguments and already says to tap one. These two headers said
        // both again, which meant the reader was told to tap four separate
        // times on one screen.
        VStack(alignment: .leading, spacing: 12) {
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
	                                    Text(selected ? "CHOSEN" : "READ MORE")
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
                        Text("\(chapter.name) it is.")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(BookPalette.ink.opacity(0.84))
                        Text("That's where your story starts. The other four will still talk to you. Loudly.")
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
        case "emberheart": return "Life's a story you write yourself."
        case "mossbloom": return "Life's written by something bigger. Your job's to listen."
        case "tidecrest": return "Life isn't a story at all. Each good moment's whole on its own."
        case "riddlewind": return "Life's a story we write together."
        case "duskthorn": return "There's no story without trouble. A bit of friction keeps a life from going blank."
        default: return chapter.philosophy
        }
    }

    private func chapterReading(for chapter: AcademyChapter) -> String {
        let subject = inscriptionChapterSubject
        switch chapter.id {
        case "emberheart": return "Emberheart says you made \(subject) happen. You decided it was worth a sentence."
        case "mossbloom": return "Mossbloom says \(subject) was there waiting. You just finally noticed."
        case "tidecrest": return "Tidecrest won't make \(subject) mean anything. It happened. That's plenty."
        case "riddlewind": return "Riddlewind says you and the world wrote \(subject) together. You noticed. The world did the rest."
        case "duskthorn": return "Duskthorn sees a fight in \(subject). You, refusing to let it disappear."
        default: return "\(chapter.name) begins with this idea: \(chapter.philosophy)"
        }
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
            return "\(chapter.talismanName) changes what I reach for first."
        }
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
        onboardingPhotoMessage = "I'm gilding the edges. Won't be a moment."
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
            assetLocalIdentifier: "onboarding-local:\(UUID().uuidString)",
            sourceImageSize: CodableSize(width: image.size.width, height: image.size.height)
        )
        let renderedURL = IlluminatedPageRenderer.renderPreview(draft: draft, sourceImage: image)
        let coverPhotoURL = archiveInscriptionCoverPhoto(image)
        let coverFocus = MonthlyEditionPDFWriter.readerPhotoFocus(for: image)
        onboardingPhotoImage = image
        onboardingPhotoDraft = draft
        onboardingPhotoPreviewURL = renderedURL
        inscriptionCoverPhotoPath = coverPhotoURL?.path ?? ""
        inscriptionCoverFocusX = coverFocus?.x ?? -1
        inscriptionCoverFocusY = coverFocus?.y ?? -1
        if inscriptionCoverChoiceID == "reader-photo" {
            inscriptionCoverChoiceID = ""
        }
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
    private func archiveInscriptionCoverPhoto(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.94) else { return nil }
        do {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let bundle = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
            let directory = base
                .appendingPathComponent(bundle, isDirectory: true)
                .appendingPathComponent("FirstDoorEditions", isDirectory: true)
                .appendingPathComponent("CoverPhotographs", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("First-Door-Reader-Photograph.jpg")
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            appLog.error("Inscription cover photograph archive failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    private func onboardingPhotoDemoAnalysis(for image: UIImage, seed: Int) -> PhotoAnalysis {
        let size = image.size
        let orientation = size.width > size.height ? "landscape" : (size.height > size.width ? "portrait" : "square")

        func choose(_ options: [String], salt: Int) -> String {
            guard !options.isEmpty else { return "" }
            let scrambled = UInt(bitPattern: (seed &+ salt &* 7_919).stableScramble)
            return options[Int(scrambled % UInt(options.count))]
        }

        let fieldNote = choose([
            "You were really there for this one.",
            "Somebody stopped to take this. Hi, somebody.",
            "A Tuesday, up close. Look at it.",
            "Look at that. Caught completely off guard.",
            "Proof this day happened. I'm keeping it.",
            "Nobody posed for this. I can tell."
        ], salt: 11)
        let stampLabel = choose([
            "CAUGHT IT",
            "NOT BAD, YOU",
            "THIS HAPPENED",
            "STILL HERE",
            "REAL ONE",
            "GOOD EYE",
            "KEPT",
            "YOURS"
        ], salt: 23)
        let openingObservation = choose([
            "You looked, so it counts",
            "It held still for you",
            "This one didn't blur past",
            "Nobody else saw it like this",
            "You noticed. That's the trick",
            "A real thing, in real light"
        ], salt: 37)
        let materialObservation = choose([
            "\(orientation.capitalized), and no filter",
            "Stays on your phone, always",
            "Nobody else has seen this",
            "Picked from your actual day",
            "Those colors were free",
            "Gilded here, nowhere else"
        ], salt: 41)
        let closingLine = choose([
            "I kept it. It's a good one.",
            "I kept it. Look what you found.",
            "I kept it. Ordinary, and I love it.",
            "I kept it. That day happened.",
            "I kept it. Mine now. Sorry.",
            "I kept it. You were here."
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
            scene: "A private \(orientation) photo chosen at the Inscription.",
            motifs: motifs,
            mood: choose(["fresh proof", "private wonder", "good light", "small magic"], salt: 67),
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
                    "A photo of a day you were actually in.",
                    "An ordinary moment, now with gold edges.",
                    "Your own world, on my first page.",
                    "A day that would've blurred, caught instead."
                ], salt: 79),
                choose([
                    "The picture never left your phone.",
                    "You decided what it means. I only framed it.",
                    "A photo from real life, now in the story.",
                    "The day made the light. I made room."
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
        case "making": return "You made something. Look at you"
        case "outside": return "Outside is where you light up"
        case "people": return "Better with company, you said"
        case "movement": return "You come alive moving, you said"
        case "learning": return "Curious. It shows"
        case "solitude": return "Quiet is where you recharge"
        case "helping": return "You'd help. It shows"
        case "story": return "You're a story person. Noted"
        default: return "Still working out what wakes you"
        }
    }

    private var onboardingPhotoMagicObservation: String {
        switch magicSource {
        case "music": return "Music is your magic. Noted"
        case "weather": return "Weather is your magic. Noted"
        case "places": return "Certain places hum for you"
        case "coincidence": return "You love a good coincidence"
        case "details": return "You spot the tiny stuff"
        case "laughter": return "A good laugh is your magic"
        case "imagination": return "Your imagination runs the show"
        case "love": return "Love is your magic. Aw"
        default: return "Your magic is still a mystery"
        }
    }

    private var onboardingPhotoRutObservation: String {
        switch rutStrongest {
        case "work": return "Work didn't get this one"
        case "phone": return "Your phone didn't get this one"
        case "chores": return "The chores didn't get this one"
        case "exhaustion": return "Noticed it even while tired"
        case "sameness": return "Today was different right here"
        case "later": return "You didn't put this off"
        default: return "The Rut missed this one"
        }
    }
    #endif

    @MainActor
    private func keepOnboardingIlluminatedPhoto() {
        guard let draft = onboardingPhotoDraft else { return }
        let firstKeep = !didKeepOnboardingPhoto
        let renderedURL = onboardingPhotoPreviewURL
        didKeepOnboardingPhoto = true
        onboardingPhotoMessage = "Kept. The illuminated photograph is inside your First Edition and Today's Margins."
        BookFeedback.play(.keepPage)
        guard firstKeep else { return }
        // A single gold gild-sweep across the photograph as it "develops".
        photoGildSweep = 0
        if reduceMotion {
            photoGildSweep = 1
        } else {
            withAnimation(.easeInOut(duration: 0.9)) { photoGildSweep = 1 }
        }

        // The parent persistence path changes the entire Book. Start it after
        // this already-deep onboarding action has returned so the root cannot
        // re-enter while the photo step is still handling its button press.
        DispatchQueue.main.async {
            onKeepIlluminatedPhoto(draft, renderedURL)
        }
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
            BookFeedback.play(.braidComplete)
        } catch {
            onboardingPhotoMessage = "Photos wouldn't take the illuminated photograph yet. Check photo permissions, then try again."
            BookFeedback.play(.error)
        }
        #else
        onboardingPhotoMessage = "This build can't save to Photos, but the illuminated photograph is ready to share."
        #endif
    }

    private var comfortPreviewSymbol: String {
        switch comfortBoundary {
        case "gentle": return "leaf.fill"
        case "strange": return "eye.fill"
        default: return "hand.point.up.left.fill"
        }
    }

    private var comfortPreviewAccent: Color {
        switch comfortBoundary {
        case "gentle": return BookPalette.teal
        case "strange": return BookPalette.violet
        default: return BookPalette.lampGold
        }
    }

    private var comfortBookReaction: String {
        switch comfortBoundary {
        case "gentle": return "“Asking nicely. Fine. I can whisper through keyholes.”"
        case "strange": return "“Oh, good. I was trying very hard not to bite the furniture.”"
        default: return "“A nudge. Good. I've got one finger and excellent aim.”"
        }
    }

    private var comfortPreviewLine: String {
        switch comfortBoundary {
        case "gentle": return "Found one small thing near you yet? Write it down if you want to keep it."
        case "strange": return "Find something you walk past every single day. Look at it properly. Bring me one thing about it you've never noticed. I'll wait. I'm very good at waiting."
        default: return "Look around. Find one thing you nearly missed today, and give me a sentence about it."
        }
    }

    private var comfortBoundaryLine: String {
        "“If you say no, I stop. Even if it was a very good idea. I might sulk.”"
    }

    private var whisperTitle: String {
        whisperChoices.first { $0.id == whisperCadence }?.title ?? "Only when I open the Book"
    }

    private var whisperCueReflection: String {
        switch whisperCadence {
        case "morning": return "Something to look for, before the day starts running."
        case "evening": return "One knock before bed, to catch something before today folds itself up."
        case "both": return "One in the morning, one at night. You can change the times whenever you like."
        default: return "No knocking. I'll be in here when you open me."
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
            return "something you imagined"
        case "love":
            return "a small, specific sign that somebody loves you"
        default:
            return "something you can't quite explain yet"
        }
    }

    private var drawnChapter: AcademyChapter? {
        AcademyChapterRegistry.chapter(id: drawnChapterID)
    }

    // MARK: The naming

    /// The three answers the role is read from. Chip ids, not prose, so the
    /// reader-facing copy can change without renaming anybody.
    private var readerRoleAxes: RoleAxes {
        RoleAxes(
            rut: rutStrongest.nonEmpty,
            alive: mostAlive.nonEmpty,
            magic: magicSource.nonEmpty,
            hands: roleHands.nonEmpty,
            // Everything below happened while the Book was watching. Wicker is
            // deliberately absent: he arrives after the naming, so his Mark
            // stays available for the reader to earn later.
            recallKept: recallAnswered ? recallRemembered : nil,
            caughtTheWord: pageChangeNoticed.nonEmpty.map { $0 == "caught" },
            keptFirstPage: rehearsalChoice.map { $0 == .keep },
            backedTheirBelief: belief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : investedBelief
        )
    }

    /// What the Book calls the reader. A role they swapped to wins over a fresh
    /// reading, so the naming does not quietly undo itself on redraw.
    private var namedRole: ComposedRole {
        if let chosen = ReaderRoleRegistry.role(named: chosenRoleID) {
            return ReaderRoleRegistry.compose(role: chosen, axes: readerRoleAxes)
        }
        return ReaderRoleRegistry.compose(axes: readerRoleAxes)
    }

    /// One swap, offered once. Cycling through twelve would turn a reading into
    /// a menu, and a role you shopped for is not a role that read you.
    private var mayRefuseRole: Bool { refusedRoleID.isEmpty }

    private func refuseNamedRole() {
        let ranking = ReaderRoleRegistry.ranked(axes: readerRoleAxes)
        let current = namedRole.role
        guard let index = ranking.firstIndex(where: { $0.id == current.id }) else { return }
        let next = ranking[(index + 1) % ranking.count]
        BookFeedback.play(.select)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            refusedRoleID = current.id
            chosenRoleID = next.id
        }
    }

    /// The Book shows its working. Every line here is something the reader
    /// typed or tapped in the last three steps: the specificity has to be
    /// earned or the whole beat reads as a horoscope.
    /// What the Book is standing on. The measured lines come first, because
    /// they are the ones the reader cannot argue with: they watched themselves
    /// do these. A dossier resting only on chips invites an audit it fails.
    private var roleReceiptLines: [(String, String)] {
        var lines: [(String, String)] = []
        if recallAnswered {
            let scenario = RoutineRecallProbe.scenario(id: recallScenario)?.noun ?? "an ordinary hour"
            lines.append((
                recallRemembered >= 3 ? "eye.fill" : "cloud.fog",
                recallRemembered >= 3
                    ? "You remembered all three small things from the \(scenario). Almost nobody does."
                    : "\((RoutineRecallProbe.askedCount - recallRemembered) == 1 ? "One" : ((RoutineRecallProbe.askedCount - recallRemembered) == 2 ? "Two" : "All three")) of three small things were gone from the \(scenario)."
            ))
        }
        if pageChangeNoticed == "caught" {
            lines.append(("bolt.fill", "You caught the word I took while you were holding the Page."))
        }
        if rehearsalChoice == .keep {
            lines.append(("bookmark.fill", "You kept your first Page instead of letting it wait."))
        }
        if !mostAlive.isEmpty {
            lines.append(("waveform.path.ecg", "You light up \(mostAliveInYourWords)."))
        }
        if let detail = awakeMemory.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            lines.append(("quote.opening", "\u{201C}\(detail)\u{201D}: you fetched that from memory, intact."))
        }
        if !magicSource.isEmpty {
            lines.append(("sparkles", "\(magicSourceInYourWords.capitalizedFirst) puts a charge through you."))
        }
        if let hands = namedRole.hands {
            lines.append(("hand.raised", hands.gloss))
        }
        // The Mark is shown as what the Book saw, not as another label to learn.
        if let mark = namedRole.mark {
            lines.append(("seal.fill", mark.evidence))
        }
        return lines
    }

    private var curseTestLine: String {
        guard recallAnswered else { return "The ordinary hour went untested." }
        let scenario = RoutineRecallProbe.scenario(id: recallScenario)?.noun ?? "an ordinary hour"
        return "Gone from the \(scenario): \(RoutineRecallProbe.askedCount - recallRemembered) of three small things."
    }

    private var rutTitle: String {
        rutChoices.first { $0.id == rutStrongest }?.title ?? "an unnamed part of the day"
    }

    private var mostAliveTitle: String {
        aliveChoices.first { $0.id == mostAlive }?.title ?? "a place I haven't learned yet"
    }

    private var magicSourceTitle: String {
        magicSourceChoices.first { $0.id == magicSource }?.title ?? "a kind of magic still waiting to be noticed"
    }

    /// The chip titles are written in the reader's voice ("Moving my body").
    /// Repeated in the Book's mouth they need turning round, or the Book ends
    /// up talking about a body it hasn't got.
    private var mostAliveInYourWords: String {
        switch mostAlive {
        case "making": return "making something"
        case "outside": return "outside somewhere"
        case "people": return "with people you love"
        case "movement": return "moving your body"
        case "learning": return "learning something"
        case "solitude": return "alone and unhurried"
        case "helping": return "helping someone"
        case "story": return "lost in a story"
        default: return "somewhere I haven't learned yet"
        }
    }

    private var magicSourceInYourWords: String {
        switch magicSource {
        case "music": return "music landing just right"
        case "weather": return "wild weather"
        case "places": return "places with a charge"
        case "coincidence": return "strange coincidences"
        case "details": return "tiny beautiful details"
        case "laughter": return "making someone laugh"
        case "imagination": return "dreams and imagination"
        case "love": return "the people you love"
        default: return "something you can't name yet"
        }
    }

    /// What Zara calls the reader once she knows: the first word of the name
    /// they gave.
    private var readerFirstName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").first.map(String.init) ?? "then"
    }

    /// The snack as the reader wrote it, minus a trailing full stop. Always
    /// quoted where it's used, so the keyboard's automatic capital reads as
    /// their handwriting rather than a typo in the middle of a sentence.
    private var snackInSentence: String? {
        snack.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
            .nonEmpty
    }

    private var namedOnboardingBelief: String {
        belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "the thing you believe in"
    }

    private var rutReflection: String {
        switch rutStrongest {
        case "work":
            return "“Then I won't ask work to be magical. I'll hunt for the minutes it forgot to eat.”"
        case "phone":
            return "“Then I won't nag you about the phone. I'll just point at whatever's happening right next to it.”"
        case "chores":
            return "“Then the dishes get hunted too. No two Tuesdays are actually the same, and I'll prove it.”"
        case "exhaustion":
            return "“Then I won't ask for effort. I'll look for the kind of wonder you can spot half asleep.”"
        case "sameness":
            return "“Then I'll watch for the tiny differences. Every Tuesday has one. It hides.”"
        case "later":
            return "“Then I'll stop letting later have everything. Today gets a turn.”"
        default:
            return "I leave the seam unmarked. I won't guess."
        }
    }

    private var magicSourceReflection: String {
        if magicSource == "unsure" {
            return "“Honest answer. I won't make something up. I'll show you small things and you decide what counts.”"
        }
        return "“\(magicSourceInYourWords.capitalizedFirst). Good. I'll start there, and leave room for surprises.”"
    }

    private var inscriptionChapterSubject: String {
        if rehearsalChoice == .keep,
           let detail = firstPressPreviewDetail(from: firstPressTrimmedText).nonEmpty {
            return "“\(detail)”"
        }
        return "the choice to let the first offered Page wait"
    }

    private var inscriptionFallThroughProse: String {
        let decisionLine = rehearsalChoice == .keep
            ? "Your kept Page catches on your thumb."
            : "The Page you let wait unfolds beside your hand."
        return """
        \(decisionLine) You pull it closer. It pulls back. Harder.

        The floor goes. You fall between lines of ink, past a wolf asleep on a sentence and a train rattling along a footnote. It smells like rain on old paper.

        Then your knees hit stone. Shelves go up and up all around you. You're inside me now. In my story.

        A girl with quick grey eyes is looking down at you. Your Page has landed by her shoe.
        """
    }

    private var bookChosenChapterID: String {
        let chapters = AcademyChapterRegistry.publicChapters
        guard !chapters.isEmpty else { return "emberheart" }
        let seed = [
            firstPressTrimmedText,
            name.trimmingCharacters(in: .whitespacesAndNewlines),
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
                carriedThread = "Wicker has to admit that was specific. He hates admitting things."
            case .hold:
                carriedThread = "Next time your day starts to blur, bring back another one like that. He won't see it coming."
            case .glance:
                carriedThread = "Wicker dares you to bring back one more real detail tomorrow. He says he'll be harder to impress."
            case .cost:
                carriedThread = "Wicker writes “Rematch?” in your margin. Bring back something surprising and you can win your piece back."
            }
        case "arc":
            switch tier {
            case .triumph:
                carriedThread = "“\(mostAliveInYourWords.capitalizedFirst)” writes itself beside the arrow. Your next adventure starts with something you actually like."
            case .hold:
                carriedThread = "The arrow points at the part of your life where you're \(mostAliveInYourWords). That's where your next little adventure starts."
            case .glance:
                carriedThread = "Wicker wants you to go and do something you enjoy, then tell him what really happened. “Details,” he says. “I'll be checking.”"
            case .cost:
                carriedThread = "Wicker writes his name beside your next adventure. He means to heckle the whole way. Someone's already drawn a rude little picture of him next to it."
            }
        default:
            let surpriseSubject = investedBelief
                ? "“\(namedOnboardingBelief)”"
                : magicSourceInYourWords
            switch tier {
            case .triumph:
                carriedThread = "\(surpriseSubject) flicks a gold speck into Wicker's cuff. His face is now on record."
            case .hold:
                carriedThread = "\(surpriseSubject) is allowed to barge into a future Page, right when Wicker thinks he's won."
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
            return "Wicker never got his answer."
        }
        return "When Wicker grabbed your Page, you answered with \(choice.title.lowercased()). \(wickerConsequence(for: choice, tier: outcome.tier))"
    }

    private var inscriptionWickerIntroduction: String {
        let chapterLine = drawnChapter.map {
            "“And you've already picked a side. \($0.name).” He says it like a diagnosis."
        } ?? "“You haven't even picked a side yet.”"
        let namedBelief = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "an unnamed belief"
        let beliefLine = investedBelief
            ? "He finds “\(namedBelief)” written dark in your margin. “You've already put weight behind it. Before it's done a day's work.”"
            : "He finds “\(namedBelief)” pencilled faintly in your margin. “Nothing behind it. A slogan in a nice coat.”"
        let roleLine = "“\(namedRole.fullName),” he reads, and snorts. “It's flattering you. It does that.” I bite his cuff."
        return """
        He steps out from behind a shelf at the worst possible moment, and the Page is out of your hand before you see him move.

        “So you're the impossible reader.” He looks you up and down. “I expected taller.”

        Zara's jaw goes tight. “That's Wicker. He collects the beginnings of other people's stories. Don't hand him one for free.”

        \(roleLine)

        \(beliefLine) \(chapterLine)

        He's waiting for an answer.
        """
    }

    private var inscriptionMiniStory: String {
        let reader = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Reader"
        let ration = snackInSentence ?? "nothing"
        let namedBelief = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "a belief still to be written"
        let decision = rehearsalChoice == .keep
            ? "You kept \(inscriptionChapterSubject). That sentence lives in me now."
            : "You let your first Page wait. I wrote down that you did."
        let chapterLine = drawnChapter.map { "You picked \($0.name). \(chapterReading(for: $0))" }
            ?? "You didn't pick a Chapter yet. They're still arguing about it."
        return """
        \(reader). Here's what I remember from the day we met.

        \(decision)

        You told Zara your reading snack was “\(ration)”. She wrote it down very seriously.

        You believe “\(namedBelief)”. \(investedBelief ? "You put it in the story, so it'll keep turning up." : "You kept it to yourself for now. That's allowed.")

        You light up \(mostAliveInYourWords). \(magicSourceInYourWords.capitalizedFirst) feels like magic to you.

        \(chapterLine)

        \(wickerBraidLine)

        That's you, in ink. The Curse can try. I'll be very annoying about it.

        Zara reads it over your shoulder. “It was listening,” she says. “Let's make you a copy.”
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

    /// Scroll handling for later beats that reveal content after the reader
    /// toggles something. Text fields keep their own top anchor above.
    /// Extracted from the scroll view's own modifier
    /// chain purely so the type-checker can cope: the chain had grown past what
    /// it would solve in reasonable time.
    private struct OnboardingLateRevealScrolling: ViewModifier {
        let step: Int
        let openingMiniStep: Int
        let didLivingInkChange: Bool
        let pageChangeNoticed: String
        let recallScenario: String
        let recallAnswered: Bool
        let rutStrongest: String
        let rehearsalChoice: String
        let investedBelief: Bool
        let magicSource: String
        let roleHands: String
        let didSteadyFirstPage: Bool
        let drawnChapterID: String
        let wickerThrowID: UUID
        let hasWickerOutcome: Bool
        let didCloseFirstEditionPreview: Bool
        let whisperCadence: String
        let reveal: (String, Double) -> Void

        private func onOpening(_ beat: Int) -> Bool { step == 0 && openingMiniStep == beat }

        // Every answer that reveals something below the fold brings it up, so
        // the reader never has to go looking for what their tap did. These
        // were once keyed to step numbers from an older order of screens, and
        // quietly stopped firing.
        func body(content: Content) -> some View {
            content
                .onChange(of: didLivingInkChange) { _, changed in
                    guard changed, onOpening(0) else { return }
                    // Late enough that the scroll doesn't point at the bite.
                    reveal("onboarding-opening-bite", 1.6)
                }
                .onChange(of: pageChangeNoticed) { _, answer in
                    guard !answer.isEmpty, onOpening(0) else { return }
                    reveal("onboarding-opening-prediction", 0.08)
                }
                .onChange(of: recallScenario) { _, answer in
                    guard !answer.isEmpty, onOpening(1) else { return }
                    reveal("onboarding-recall-setup", 0.08)
                }
                .onChange(of: recallAnswered) { _, answered in
                    guard answered, onOpening(1) else { return }
                    reveal("onboarding-recall-verdict", 0.12)
                }
                .onChange(of: rutStrongest) { _, answer in
                    guard !answer.isEmpty, onOpening(3) else { return }
                    reveal("onboarding-opening-rut-reflection", 0.08)
                }
                .onChange(of: rehearsalChoice) { _, answer in
                    guard !answer.isEmpty, onOpening(4) else { return }
                    reveal("onboarding-opening-grey-bite", 0.2)
                }
                .onChange(of: didSteadyFirstPage) { _, stood in
                    guard stood, step == 1 else { return }
                    reveal("onboarding-arrival-standing", 0.08)
                }
                .onChange(of: investedBelief) { _, invested in
                    guard invested else { return }
                    reveal("onboarding-belief-sigil", 0.08)
                }
                .onChange(of: magicSource) { _, answer in
                    guard !answer.isEmpty, step == 4 else { return }
                    reveal("onboarding-magic-source-reflection", 0.08)
                }
                .onChange(of: roleHands) { _, answer in
                    guard !answer.isEmpty, step == 4 else { return }
                    reveal("onboarding-hands-continue", 0.08)
                }
                .onChange(of: drawnChapterID) { _, answer in
                    guard !answer.isEmpty, step == 6 else { return }
                    reveal("onboarding-chapter-continue", 0.16)
                }
                .onChange(of: wickerThrowID) { _, _ in
                    guard hasWickerOutcome else { return }
                    reveal("onboarding-wicker-inkbones", 0.12)
                }
                .onChange(of: didCloseFirstEditionPreview) { _, closed in
                    guard closed else { return }
                    reveal("onboarding-knock", 0.2)
                }
                .onChange(of: whisperCadence) { _, cadence in
                    guard !cadence.isEmpty else { return }
                    reveal("onboarding-whisper-hinge", 0.08)
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
            .inkFeedback(text: text.wrappedValue)
            .dictationInput(text: text)
            .padding(12)
            .background(BookPalette.paper.opacity(0.8), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
            }
            .id(Self.activeTextFieldScrollID)
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

    private var onboardingPagewrightIsReady: Bool {
        let path = onboardingPagewrightImagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return !path.isEmpty
            && onboardingPagewrightSourceSignature == currentOnboardingPagewrightSourceSignature
            && FileManager.default.fileExists(atPath: path)
    }

    private var currentOnboardingPagewrightSourceSignature: String {
        [
            firstPressTrimmedText,
            firstSouvenir,
            name,
            snack,
            belief,
            mostAlive,
            magicSource,
            roleHands
        ].joined(separator: "\u{241E}")
    }

    /// The scraps on the Pagewright's leaf, written the way the Book would
    /// say them. They used to read like form labels ("Most alive: Moving my
    /// body"), and the reader's snack arrived mid-sentence with its capital.
    private var onboardingPagewrightScraps: [BookPage] {
        let now = arrivalMoment
        let reader = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "You"
        let ration = snackInSentence.map { "\u{201C}\($0)\u{201D}" } ?? "nothing to eat"
        let believed = belief.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            .map { "\u{201C}\($0)\u{201D}" } ?? "nothing yet, which is allowed"
        let handsLine = ReaderRoleRegistry.hands(id: roleHands)?.gloss ?? ""
        return [
            BookPage(
                id: "first-door-pagewright-true-thing",
                type: .souvenir,
                createdAt: now,
                promptText: "The first true thing",
                userInput: firstPressTrimmedText.nonEmpty ?? (firstSouvenir.nonEmpty ?? openingArrivalExcerpt),
                tags: ["onboarding", "pagewright-source", "first-door"],
                sourceID: "first-door"
            ),
            BookPage(
                id: "first-door-pagewright-belief",
                type: .aboutYou,
                createdAt: now.addingTimeInterval(1),
                promptText: "Your name, snack, and belief",
                userInput: "\(reader) brought \(ration) and believes \(believed).",
                tags: ["onboarding", "pagewright-source", "belief"],
                sourceID: "first-door"
            ),
            BookPage(
                id: "first-door-pagewright-magic",
                type: .souvenir,
                createdAt: now.addingTimeInterval(2),
                promptText: "What you enjoy noticing",
                userInput: "Lights up \(mostAliveInYourWords). Finds magic in \(magicSourceInYourWords). \(handsLine)"
                    .trimmingCharacters(in: .whitespaces),
                tags: ["onboarding", "pagewright-source", "magic"],
                sourceID: "first-door"
            )
        ]
    }

    /// The photograph the reader chose for their little book, if they chose
    /// one. Onboarding never reaches into the photo library on its own.
    private var onboardingPagewrightFallbackPhoto: PagewrightPersonalPhoto? {
        #if canImport(UIKit)
        guard let image = onboardingPhotoImage,
              let data = image.jpegData(compressionQuality: 0.88) else { return nil }
        return PagewrightPersonalPhoto(
            data: data,
            aspectRatio: image.size.height > 0 ? image.size.width / image.size.height : 1
        )
        #else
        return nil
        #endif
    }

    /// The Pagewright moved to the desk, so onboarding no longer opens the
    /// worktable. The little book still gets a leaf: the Pagewright arranges
    /// the reader's scraps itself, badly on purpose, at binding time. It uses
    /// the reader's own photograph only if they chose one on the last page,
    /// and never asks for the library.
    private func arrangeOnboardingPagewrightLeaf() {
        let template = PagewrightTemplate.softChaos
        let photo = onboardingPagewrightFallbackPhoto
        let scraps = onboardingPagewrightScraps
        let pages = photo == nil ? scraps : Array(scraps.dropLast())
        let pullQuotes = Dictionary(
            uniqueKeysWithValues: pages.map { ($0.id, PagewrightText.pullQuote(for: $0)) }
        )
        let pinnedNote = PagewrightPinnedNote(
            text: "The scraps voted against neatness.",
            style: .sticky
        )
        var elements = pages.enumerated().map { index, page in
            let placement = template.placement(for: index, kind: .page)
            return PagewrightCanvasElement(
                kind: .page,
                sourceID: page.id,
                x: placement.x,
                y: placement.y,
                width: placement.width,
                rotation: placement.rotation,
                z: index
            )
        }
        let notePlacement = template.placement(for: 0, kind: .note)
        elements.append(
            PagewrightCanvasElement(
                kind: .note,
                sourceID: pinnedNote.id,
                x: notePlacement.x,
                y: notePlacement.y,
                width: notePlacement.width,
                rotation: notePlacement.rotation,
                z: elements.count
            )
        )

        var photos: [PagewrightPersonalPhoto] = []
        if let photo {
            photos.append(photo)
            elements.append(
                PagewrightCanvasElement(
                    kind: .personalPhoto,
                    sourceID: photo.id,
                    x: 0.54,
                    y: 0.52,
                    width: min(0.48, max(0.22, photo.aspectRatio * 0.42)),
                    rotation: -5,
                    z: elements.count
                )
            )
        }

        let draft = PagewrightDraft(
            title: "A Page We Made Together",
            note: "The loose answers refused to remain an intake form.",
            format: template.format,
            template: template,
            pages: pages,
            pullQuotes: pullQuotes,
            pinnedNotes: [pinnedNote],
            personalPhotos: photos,
            elements: elements,
            background: template.background,
            paperTint: template.background.defaultTint,
            marginalia: template.marginalia,
            marginaliaPackID: CoreMarginsPack.id
        )
        let renderedURL = renderOnboardingPagewright(draft)
        keepOnboardingPagewright(draft, renderedURL: renderedURL)
    }

    private func renderOnboardingPagewright(_ draft: PagewrightDraft) -> URL? {
        #if canImport(UIKit)
        do {
            let url = try onboardingPagewrightArchiveURL()
            try PagewrightPDFWriter.writePNG(draft: draft, to: url)
            onboardingPagewrightError = ""
            return url
        } catch {
            onboardingPagewrightError = "The Pagewright couldn't press the image this time. Your words and pictures are still on this phone."
            BookFeedback.play(.error)
            return nil
        }
        #else
        return nil
        #endif
    }

    private func keepOnboardingPagewright(_ draft: PagewrightDraft, renderedURL: URL?) {
        let url = renderedURL ?? renderOnboardingPagewright(draft)
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        onboardingPagewrightTitle = draft.title
        onboardingPagewrightTemplate = draft.template.rawValue
        onboardingPagewrightImagePath = url.path
        onboardingPagewrightSourceSignature = currentOnboardingPagewrightSourceSignature
        onboardingPagewrightError = ""
        BookFeedback.play(.braidComplete)
    }

    private func onboardingPagewrightArchiveURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        let directory = base
            .appendingPathComponent(bundle, isDirectory: true)
            .appendingPathComponent("FirstDoorEditions", isDirectory: true)
            .appendingPathComponent("Pagewright", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("First-Door-Pagewright.png")
    }

    @ViewBuilder
    private var onboardingRoleReveal: some View {
        let composed = namedRole
        let role = composed.role

        guidePortrait(mood: "Zara has stopped writing. She is reading back what she wrote.")
        onboardingProse("""
        "Oh," Zara says, and turns the Page round so you can see it. "It's decided what you are already. Usually it waits a month."

        "It watched what you did more than what you said. Whether you caught the word it took. Whether you kept your first Page. What you did with your belief."
        """)

        VStack(alignment: .leading, spacing: 14) {
            Text("THE BOOK NAMES YOU")
                .font(.system(size: 10, weight: .black))
                .tracking(1.4)
                .foregroundStyle(BookPalette.lampGold)

            Text(composed.fullName)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: BookPalette.lampGold.opacity(0.24), radius: 10, x: 0, y: 3)

            if let hands = composed.hands {
                Text(hands.name)
                    .font(.system(size: 13, weight: .black))
                    .tracking(0.6)
                    .foregroundStyle(BookPalette.teal)
            }

            Text(role.dossier)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.page.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1.5)
        }
        .id("onboarding-role-\(role.id)")
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .modifier(OnboardingSectionArrivalModifier(kind: .artifact, delay: 0.06))

        if let epithet = composed.epithet {
            onboardingPreviewCard(
                symbol: "cloud.fog",
                title: "And I know where the grey gets in",
                body: epithet.cost
            )
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("HOW I KNEW")
                .font(.system(size: 10, weight: .black))
                .tracking(1.2)
                .foregroundStyle(BookPalette.ink.opacity(0.52))

            ForEach(roleReceiptLines.indices, id: \.self) { index in
                let line = roleReceiptLines[index]
                Label(line.1, systemImage: line.0)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(0.52), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .modifier(OnboardingSectionArrivalModifier(kind: .section, delay: 0.14))

        if mayRefuseRole {
            Button {
                refuseNamedRole()
            } label: {
                Text("That's not me")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.54))
                    .underline()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
        } else {
            Text("You turned the first name down. I'm keeping that too.")
                .font(.footnote)
                .foregroundStyle(BookPalette.ink.opacity(0.46))
                .frame(maxWidth: .infinity, alignment: .center)
        }

        continueButton("Continue with this name")
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

    /// The Curse, evidenced: two real studies and one extrapolation the Book
    /// owns out loud. Spliced from the landing page's "Who we're up against"
    /// chapter, which bj preferred, so the app and the site make the same
    /// argument in the same words.
    ///
    /// The line between what the researchers found and what the Book infers
    /// is drawn exactly once, and the inference then stands at full strength.
    /// The reader's own recall contrast is not repeated here: the verdict
    /// prose directly above has already said it.
    private var onboardingNotYourFaultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EVEN SCIENCE HAS CAUGHT IT")
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.teal)

            onboardingProse("""
            "Your home has a smell. You notice it when you've been away. A few days later, it's gone again."

            "You bought your mug because you loved it. Now you drink from it every morning without looking at it."

            "They're still there. The smell. The mug. The Curse doesn't take them away. It just makes you stop noticing them. Even Science has caught it doing three things."
            """)
            onboardingBenefitCard(
                symbol: "cloud",
                title: "It takes your mind somewhere else.",
                body: "Researchers pinged people's phones at random moments and asked what they were doing and what they were thinking about. Almost half the time, they were thinking about something else. You drive home making all the right turns, thinking about work."
            )
            Link("Killingsworth & Gilbert · Science (2010)", destination: URL(string: "https://dtg.sites.fas.harvard.edu/KILLINGSWORTH%20%26%20GILBERT%20%282010%29.pdf")!)
            onboardingBenefitCard(
                symbol: "eye",
                title: "It hides things right in front of you.",
                body: "People counted basketball passes in a video. A person in a gorilla suit walked right through the game and stayed a bit. About half of them didn't report seeing it. A whole gorilla. They were busy counting."
            )
            Link("Simons & Chabris · Perception (1999)", destination: URL(string: "https://www.chabris.com/Simons1999.pdf")!)
            onboardingBenefitCard(
                symbol: "calendar",
                title: "It squashes your days.",
                body: "Time spent doing the same things gets remembered as shorter. Same breakfast, same journey, dinner, telly, bed. A week goes by and you can't tell Tuesday from Thursday. Then your birthday comes round again. Already?"
            )
            Link("Avni-Babad & Ritov (2003)", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/14640847/")!)
            onboardingProse("""
            "That's what the science says. Here's the truth."

            "The Curse is old. Older than clocks. It's been on everyone who ever had a street and a breakfast. It doesn't take your days all at once. It makes them easy to miss, until they're gone."
            """)
        }
        .font(.footnote)
        .tint(BookPalette.teal)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 10))
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
        sworePact = false
        selectedFirstPressPresetID = nil
        didCompleteFirstPress = false
        momentFate = ""
        hiddenMagicStance = ""
        pageChangeNoticed = ""
        rutStrongest = ""
        routineMemory = ""
        mostAlive = ""
        awakeMemory = ""
        magicSource = ""
        roleHands = ""
        chosenRoleID = ""
        refusedRoleID = ""
        whisperCadence = ""
        openingMiniStep = 0
        sleeveWord = nil
        drawnChapterID = ""
        didWakeFirstInk = false
        didLivingInkChange = false
        livingInkChangeTask?.cancel()
        livingInkChangeTask = nil
        didSteadyFirstPage = false
        unwrittenWordDrag = .zero
        didTuckUnwrittenWord = false
        wickerOutcome = nil
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
        onboardingPagewrightImagePath = ""
        onboardingPagewrightTitle = ""
        onboardingPagewrightTemplate = ""
        onboardingPagewrightSourceSignature = ""
        onboardingPagewrightError = ""
        didBindFirstEdition = false
        boundInscriptionEdition = nil
        inscriptionEditionPDFPath = ""
        inscriptionCoverChoiceID = ""
        inscriptionCoverPhotoPath = ""
        inscriptionCoverFocusX = -1
        inscriptionCoverFocusY = -1
        didCloseFirstEditionPreview = false
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
        guard openingMiniStep < Self.openingMiniStepCount - 1 else { return }
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
        // `firstSouvenir` is the rendered Page: my arrival line, the reader's
        // sentence, and my reply. Only the text they actually entered may cross
        // the archive boundary as their first true sentence.
        let trimmedSouvenir = rehearsalChoice == .keep
            ? firstPressTrimmedText
            : ""
        let trimmedSleeveWord = (sleeveWord ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChapter = drawnChapterID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTaste = tastePreference.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComfort = comfortBoundary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWhisper = whisperCadence.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAwakeMemory = awakeMemory.trimmingCharacters(in: .whitespacesAndNewlines)

        return Result(
            skipped: useDefaults,
            momentFate: momentFate,
            hiddenMagicStance: hiddenMagicStance,
            pageChangeNoticed: pageChangeNoticed,
            rutStrongest: rutStrongest,
            routineMemory: routineMemory,
            mostAlive: mostAlive,
            awakeMemory: trimmedAwakeMemory,
            magicSource: magicSource,
            roleHands: roleHands,
            roleID: useDefaults ? "" : namedRole.role.id,
            refusedRoleID: useDefaults ? "" : refusedRoleID,
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
            sworePact: useDefaults ? false : sworePact,
            inscriptionEdition: useDefaults ? nil : boundInscriptionEdition,
            inscriptionEditionPDFPath: useDefaults ? "" : inscriptionEditionPDFPath
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
                        Text(isEnteringBook ? "I make room." : "Look before it becomes a page.")
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
                            didEnterBook ? "Inside the First Edition" : "Becoming part of me…",
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
struct BinderySewingOverlay: View {
    /// Real progress, 0…1. Nil means the overlay drives itself on a timer,
    /// which is right for the onboarding beat: there is no work behind that
    /// one, it is a flourish and says so.
    ///
    /// When a value is supplied the stitches follow *it* and nothing else, so a
    /// press that stalls leaves the spine half-sewn. A ceremony that finishes
    /// while the work has failed is the animation lying, and a ceremony that
    /// lies once is never trusted again.
    var progress: Double? = nil
    var caption: String = "Sewing your first edition…"

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
                    Text(caption)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(BookPalette.nightText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(pulse ? 1 : 0.7)
            }
            .padding(40)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            guard let progress else {
                guard !reduceMotion else { stitched = 1; return }
                withAnimation(.easeInOut(duration: 1.1)) { stitched = 1 }
                return
            }
            stitched = progress
        }
        .onChange(of: progress) { _, newValue in
            guard let newValue else { return }
            guard !reduceMotion else { stitched = newValue; return }
            withAnimation(.easeInOut(duration: 0.55)) { stitched = newValue }
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
                    Text("You throw")
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(BookPalette.lampGold)
                    Text(revealed ? badge : "Throwing…")
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
                        Text("You threw \(roll), needed \(difficulty)")
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
        .accessibilityLabel("\(badge). You threw \(roll), needed \(difficulty). \(consequence)")
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

            Text("Zara says it once, carefully, and I darken the letters so future pages can find you.")
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
        .accessibilityLabel("I write your name: \(name)")
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
/// appears (e.g. the snack "margin ration"): the lightest celebration in the
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
///
/// It is a scrap she tore off and taped in, not a panel: a deckled edge, a
/// second scrap showing behind it, and a strip of tape holding it to the page.
struct MarginTutorNoteCard: View {
    let note: MarginTutorNote
    let onDismiss: () -> Void

    private var seed: Int { note.id.stableHash }
    private var scrap: DeckledPaperScrapShape { DeckledPaperScrapShape(seed: seed, amplitude: 2.1) }
    /// A hand tears paper crooked. The angle is the note's own, so the same
    /// note lands the same way every time it is shown.
    private var tilt: Double { (Double(UInt(bitPattern: seed) % 7) - 3) * 0.42 - 0.6 }

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
        .padding(.horizontal, 15)
        .padding(.top, 15)
        .padding(.bottom, 13)
        // A torn scrap is only as big as what is written on it.
        .frame(maxWidth: 460, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            ZStack {
                // A second scrap caught under the first, so the note reads as
                // loose paper rather than one flat plate.
                DeckledPaperScrapShape(seed: seed &+ 31, amplitude: 1.6)
                    .fill(BookPalette.paper.opacity(0.92))
                    .rotationEffect(.degrees(1.1))
                    .offset(x: 4, y: 5)

                scrap.fill(
                    LinearGradient(
                        colors: [
                            BookPalette.page.opacity(0.99),
                            BookPalette.paper.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                scrap
                    .fill(ImagePaint(image: Image("ParchmentFiber"), scale: 0.32))
                    .opacity(0.16)
                    .blendMode(.multiply)

                // Faint ruling, cut off by the tear like real lined paper.
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(BookPalette.ink.opacity(0.055))
                            .frame(height: 0.6)
                    }
                }
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 11)
                .mask(scrap)
            }
        }
        .overlay {
            scrap.stroke(BookPalette.parchmentEdge.opacity(0.32), lineWidth: 0.8)
        }
        .overlay(alignment: .topLeading) {
            marginTape
                .rotationEffect(.degrees(-6))
                .offset(x: 22, y: -7)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .shadow(color: .black.opacity(0.34), radius: 13, x: 1, y: 7)
        .rotationEffect(.degrees(tilt))
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

    /// The strip holding the scrap to whatever it landed on: cloudy, waxy, and
    /// slightly wider than it needs to be, the way tape torn by hand is.
    private var marginTape: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BookPalette.paper.opacity(0.50),
                        BookPalette.page.opacity(0.30),
                        BookPalette.paper.opacity(0.46)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 54, height: 15)
            .overlay {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .stroke(BookPalette.parchmentEdge.opacity(0.24), lineWidth: 0.6)
            }
            .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)
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
            if let uiImage = BookRenderedImageCache.shared.image(for: customAsset.reference) { return Image(uiImage: uiImage) }
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


/// Pack art is decoded once off the main actor, bounded to a display-sized
/// image. Bundled assets keep SwiftUI's normal asset-catalog cache.
struct BookMarginaliaImage: View {
    let assetName: String
    @State private var fileImage: UIImage?
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1_024 * 1_024
        return cache
    }()
    /// Stands in for a file-backed mark until it decodes. The view must always
    /// have something to draw: while it was an empty `if let`, SwiftUI never
    /// ran `.task` on it (a modifier on an empty view has nothing to attach to,
    /// including a task hung off a background), so downloaded monthly marks
    /// waited for a load nothing had asked for and stayed blank forever.
    private static let clearPlaceholder = UIImage()

    init(assetName: String) {
        self.assetName = assetName
        if assetName.hasPrefix("/") {
            _fileImage = State(initialValue: Self.images.object(forKey: assetName as NSString))
        }
    }

    var body: some View {
        Group {
            if assetName.hasPrefix("/") {
                Image(uiImage: fileImage ?? Self.clearPlaceholder).resizable()
            } else {
                Image(assetName).resizable()
            }
        }
        .task(id: assetName) { await loadFileImage() }
    }

    private func loadFileImage() async {
        guard assetName.hasPrefix("/") else { return }
        if let cached = Self.images.object(forKey: assetName as NSString) {
            fileImage = cached
            return
        }
        fileImage = nil
        let path = assetName
        let decoded = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1_536,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
        guard !Task.isCancelled, let decoded else { return }
        Self.images.setObject(decoded, forKey: path as NSString,
            cost: (decoded.cgImage?.bytesPerRow ?? 0) * (decoded.cgImage?.height ?? 0))
        fileImage = decoded
    }
}

private extension String {
    /// Upper-cases only the first character, for a reader's answer that has
    /// moved to the front of one of the Book's sentences.
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
