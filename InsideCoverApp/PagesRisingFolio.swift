import SwiftUI
import UIKit
import CoreMotion
import Photos

/// The light cover matter Pages Rising needs. A completed monthly binding can
/// supply its real title and commissioned plate; a month still in progress
/// wears the same cover language without pretending it has already been bound.
struct PagesRisingMonthlyCover: Equatable {
    var imprint: String
    var monthLine: String
    var title: String
    var subtitle: String
    var dateLine: String
    var footerLine: String
    var artworkAssetName: String?
    var isBound: Bool
}

/// The desk's old wax shortcuts, recut as fore-edge bookmarks. The action is
/// still owned by `ContentView`; the folio only gives it a physical home.
struct PagesRisingSealTab: Identifiable {
    var id: String
    var title: String
    var shortTitle: String
    var wax: Color
    var seed: Int
    var isBusy: Bool
    /// The Book is handing this tab to the reader for the first time. Onboarding
    /// used to stage that moment on the Glow pill in the navigation bar; the bar
    /// is gone, so the bookmark has to carry the reveal itself.
    var isRevealing: Bool = false
    var action: () -> Void
}

/// A small tool that hangs from the Book rather than from the app chrome.
/// Only journeys used from anywhere earn a permanent tail here; everything
/// else belongs in the printed contents or a particular leaf.
struct PagesRisingBookCharm: Identifiable {
    var id: String
    var title: String
    var metal: Color
    var seed: Int
    var action: () -> Void
}

/// One stable destination printed into the Book's own contents leaf. The
/// action remains owned by `ContentView`, so this page never invents a second
/// archive, router, or settings system.
struct PagesRisingContentsEntry: Identifiable {
    var id: String
    var title: String
    var detail: String
    var systemImage: String
    var action: () -> Void
}

private struct FolioResponseDraft: Equatable {
    var text = ""
    var selectedOption: String?
}

/// Draft ink belongs to the logical Page, not to a particular hosting
/// controller. UIPageViewController may discard and recreate a leaf during a
/// curl; keeping the draft here means the reader's sentence survives the turn.
private final class FolioInteractionStore: ObservableObject {
    @Published private var drafts: [String: FolioResponseDraft] = [:]

    func binding(for documentID: String) -> Binding<FolioResponseDraft> {
        Binding(
            get: { [weak self] in self?.drafts[documentID] ?? FolioResponseDraft() },
            set: { [weak self] draft in self?.drafts[documentID] = draft }
        )
    }

    func draft(for documentID: String) -> FolioResponseDraft {
        drafts[documentID] ?? FolioResponseDraft()
    }
}

private enum FolioInteractionLeafKind: Equatable {
    case response
    case generationRequest
}

/// The compact desk's living book. A `SurfacePage` remains the unit the
/// Curator publishes and the reader can open, keep, or pass; leaves are only a
/// transient reading layout. Turning one therefore never mutates the desk.
struct PagesRisingFolio: View {
    let surfaces: [SurfacePage]
    let cover: PagesRisingMonthlyCover
    let sealTabs: [PagesRisingSealTab]
    let charms: [PagesRisingBookCharm]
    let contentsEntries: [PagesRisingContentsEntry]
    @Binding var isContentsOpen: Bool
    let glowScore: Int
    let showsGlow: Bool
    var isGlowRevealing: Bool = false
    let isBusy: (SurfacePage) -> Bool
    let isRetiring: (SurfacePage) -> Bool
    let animatesArrival: (SurfacePage) -> Bool
    let selectedSurfaceID: String?
    let onOpen: (SurfacePage) -> Void
    let onKeep: (SurfacePage, String) -> Void
    let onDismiss: (SurfacePage) -> Void
    let onOpenGlow: () -> Void
    let onExploreDeeper: () -> String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.sizeCategory) private var sizeCategory

    @AppStorage("pagesRisingBookIsClosed") private var isBookClosed = false
    @State private var currentLeafID: String?
    @State private var readingPosition: FolioReadingPosition?
    @State private var preferredDocumentIndex = 0
    @State private var coverTurn: CGFloat = 1
    @State private var isBookTransitioning = false
    @State private var riffleProgress: CGFloat = 0
    @State private var isRiffling = false
    @State private var riffleIsReversed = false
    @State private var requestedDocumentID: String?
    @State private var interactionStore = FolioInteractionStore()

    private var pageHeight: CGFloat {
        if sizeCategory.isFolioAccessibilityCategory {
            if horizontalSizeClass == .compact {
                return min(700, max(600, UIScreen.main.bounds.height - 152))
            }
            return 680
        }
        if horizontalSizeClass == .compact {
            // The old 510-point leaf left almost a quarter of a tall phone as
            // loose wallpaper. Let the Book grow with the reading window, but
            // keep a little room for the two tools hanging from its tail.
            return min(650, max(510, UIScreen.main.bounds.height - 202))
        }
        return 600
    }

    var body: some View {
        GeometryReader { proxy in
            // The tabs live mostly in the old outer margin. Only a narrow strip
            // is reserved from the leaf, so moving the seals does not turn the
            // reading column into a phone-sized receipt.
            let reservedForeEdge: CGFloat = sizeCategory.isFolioAccessibilityCategory ? 54 : 48
            let leafWidth = max(260, proxy.size.width - reservedForeEdge)
            let metrics = FolioLayoutMetrics(
                pageWidth: leafWidth,
                pageHeight: pageHeight,
                contentSizeCategory: sizeCategory.uiContentSizeCategory
            )
            let leaves = PagesRisingFolioPaginator.paginate(surfaces, metrics: metrics)

            VStack(spacing: 8) {
                ZStack(alignment: .topLeading) {
                    FolioBookBoard(cover: cover)
                        .frame(width: leafWidth + 12, height: pageHeight + 12)
                        .clipped()
                        .offset(x: -4, y: -6)
                        .accessibilityHidden(true)
                        .zIndex(0)

                    // These are inserted deeper than the current leaf. Their
                    // long inner ends continue beneath the paper (and beneath
                    // the front board when closed); only the handled ends are
                    // allowed to escape at the fore-edge.
                    FolioSealBookmarkRail(tabs: bindingTabs)
                        .frame(width: 66, alignment: .topLeading)
                        .offset(x: leafWidth - 18, y: 54)
                        .zIndex(0.45)

                    FolioLeafBlock()
                        .frame(width: leafWidth + 4, height: pageHeight + 3)
                        .offset(x: 0, y: 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .zIndex(0.7)

                    Group {
                        if isContentsOpen || leaves.isEmpty {
                            FolioContentsLeaf(
                                entries: contentsEntries,
                                showsBack: !leaves.isEmpty,
                                onClose: closeContents
                            )
                            .transition(.opacity)
                        } else if reduceMotion {
                            FolioStillPager(
                                leaves: leaves,
                                currentLeafID: $currentLeafID,
                                interactionStore: interactionStore,
                                isBusy: isBusy,
                                isRetiring: isRetiring,
                                animatesArrival: animatesArrival,
                                selectedSurfaceID: selectedSurfaceID,
                                glowScore: glowScore,
                                showsGlow: showsGlow,
                                onOpenGlow: onOpenGlow,
                                onOpen: onOpen,
                                onKeep: onKeep,
                                onDismiss: onDismiss,
                                onExploreDeeper: exploreDeeper,
                                onReturnToStart: { returnToFirstLeaf(in: leaves) }
                            )
                        } else {
                            FolioCurlPager(
                                leaves: leaves,
                                pageSize: CGSize(width: leafWidth, height: pageHeight),
                                currentLeafID: $currentLeafID,
                                interactionStore: interactionStore,
                                isBusy: isBusy,
                                isRetiring: isRetiring,
                                animatesArrival: animatesArrival,
                                selectedSurfaceID: selectedSurfaceID,
                                glowScore: glowScore,
                                showsGlow: showsGlow,
                                onOpenGlow: onOpenGlow,
                                onOpen: onOpen,
                                onKeep: onKeep,
                                onDismiss: onDismiss,
                                onExploreDeeper: exploreDeeper,
                                onReturnToStart: { returnToFirstLeaf(in: leaves) }
                            )
                        }
                    }
                    .frame(width: leafWidth, height: pageHeight)
                    .clipShape(FolioDeckleEdgeShape())
                    // A greedy leaf (the contents leaf asks for infinite width)
                    // otherwise takes hits out past its own clip and swallows
                    // the fore-edge tabs standing beside it. The hit shape has
                    // to be the cut edge too, or the paper is grabbable a couple
                    // of points past where it visibly ends.
                    .contentShape(FolioDeckleEdgeShape())
                    .shadow(color: .black.opacity(0.34), radius: 14, x: 0, y: 9)
                    .opacity(reduceMotion ? (isBookClosed ? 0 : 1) : min(1, coverTurn * 1.8))
                    .scaleEffect(
                        reduceMotion ? (isBookClosed ? 0.985 : 1) : 0.985 + (0.015 * coverTurn),
                        anchor: .leading
                    )
                    .allowsHitTesting(!isBookClosed && !isBookTransitioning)
                    .accessibilityHidden(isBookClosed)
                    .zIndex(1)

                    // Above the leaf and the illumination, but under the
                    // cover: the leaves fly inside the Book, not over it.
                    FolioRiffle(progress: riffleProgress, isReversed: riffleIsReversed)
                        .frame(width: leafWidth, height: pageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .zIndex(1.55)

                    if !reduceMotion {
                        FolioCoverPassingShadow(progress: coverTurn)
                            .frame(width: leafWidth, height: pageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .zIndex(1.6)
                    }

                    Button(action: openBook) {
                        FolioMonthlyCoverView(cover: cover)
                            .frame(width: leafWidth + 12, height: pageHeight + 12)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .frame(width: leafWidth + 12, height: pageHeight + 12)
                    .offset(x: -4, y: -6)
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : -118 * coverTurn),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.62
                    )
                    .offset(x: reduceMotion ? 0 : -3 * coverTurn)
                    .scaleEffect(
                        x: 1,
                        y: reduceMotion ? 1 : 1 - (0.012 * sin(.pi * coverTurn)),
                        anchor: .leading
                    )
                    .opacity(
                        reduceMotion
                            ? (isBookClosed ? 1 : 0)
                            : max(0, 1 - (coverTurn * 1.08))
                    )
                    .shadow(
                        color: .black.opacity(
                            reduceMotion
                                ? 0.58
                                : Double(0.20 + (0.42 * (1 - coverTurn)))
                        ),
                        radius: reduceMotion ? 22 : 10 + (12 * (1 - coverTurn)),
                        x: reduceMotion ? 4 : 4 + (10 * coverTurn),
                        y: 14
                    )
                    .allowsHitTesting(isBookClosed && !isBookTransitioning)
                    .accessibilityLabel("Open \(cover.title), \(cover.dateLine)")
                    .accessibilityHint("Opens Pages Rising")
                    .zIndex(2)

                    if !charms.isEmpty {
                        FolioBookCharmRail(charms: charms)
                            .offset(x: 34, y: pageHeight - 20)
                            .zIndex(0.82)
                    }

                    if !isBookClosed {
                        Button(action: closeBook) {
                            FolioBookClasp()
                        }
                        .buttonStyle(.plain)
                        .offset(x: 9, y: pageHeight - 39)
                        .accessibilityLabel("Close the Book")
                        .zIndex(1.45)
                    }
                }
                .frame(width: proxy.size.width, height: pageHeight + 72, alignment: .topLeading)
            }
            .task(id: synchronizationKey(for: leaves, metrics: metrics)) {
                #if DEBUG
                let smokeTarget = requestedSmokeLeaf(in: leaves)
                #else
                let smokeTarget: FolioLeaf? = nil
                #endif

                if let smokeTarget {
                    currentLeafID = smokeTarget.id
                    rememberPosition(for: smokeTarget.id, in: leaves)
                } else if let requestedDocumentID,
                   let target = leaves.first(where: {
                       !$0.isEnding && $0.documentID == requestedDocumentID
                   }) {
                    currentLeafID = target.id
                    rememberPosition(for: target.id, in: leaves)
                    self.requestedDocumentID = nil
                } else {
                    synchronizeCurrentLeaf(in: leaves)
                }
                if leaves.isEmpty {
                    isContentsOpen = true
                }
            }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--smoke-folio-cover") {
                    isBookClosed = true
                }
                #endif
                coverTurn = isBookClosed ? 0 : 1
            }
            .onChange(of: currentLeafID) { _, nextID in
                rememberPosition(for: nextID, in: leaves)
            }
        }
        .frame(height: pageHeight + 72)
    }

    /// Glow and Contents lead the fore-edge. They are handles for the Book's
    /// own light and divisions; the four seals below are what the reader hands
    /// the Book from the outside world.
    private var bindingTabs: [PagesRisingSealTab] {
        (showsGlow ? [glowTab] : []) + [contentsTab] + sealTabs
    }

    /// Glow keeps its full illuminated command menu. This bookmark is merely
    /// the physical handle that calls it from the Book's binding; the small
    /// illumination printed on every leaf remains a second, quieter entrance.
    private var glowTab: PagesRisingSealTab {
        PagesRisingSealTab(
            id: "glow",
            title: "Glow",
            shortTitle: "Glow",
            wax: Color(red: 0.72, green: 0.49, blue: 0.16),
            seed: 47,
            isBusy: false,
            isRevealing: isGlowRevealing,
            action: onOpenGlow
        )
    }

    private var contentsTab: PagesRisingSealTab {
        PagesRisingSealTab(
            id: "contents",
            title: isContentsOpen ? "Back to the leaf" : "Contents",
            shortTitle: "Contents",
            wax: Color(red: 0.40, green: 0.29, blue: 0.17),
            seed: 41,
            isBusy: false,
            action: { isContentsOpen ? closeContents() : openContents() }
        )
    }

    /// Turning back to the beginning is travel too, so it riffles in reverse
    /// rather than teleporting the reader to leaf one.
    private func returnToFirstLeaf(in leaves: [FolioLeaf]) {
        guard let first = leaves.first else { return }
        riffle(reversed: true) { currentLeafID = first.id }
    }

    /// Long enough to read as travel, short enough that a reader who just
    /// wants the destination is not made to wait for the performance.
    private static let riffleDuration: Double = 0.66

    private func openContents() {
        riffle(reversed: false) { isContentsOpen = true }
    }

    private func closeContents() {
        riffle(reversed: true) { isContentsOpen = false }
    }

    /// The last leaf deepens the current binding. The new Pages arrive beneath
    /// the thickest part of a riffle, and the Book settles on the first of them.
    private func exploreDeeper() {
        riffle(reversed: false) {
            requestedDocumentID = onExploreDeeper()
        }
    }

    /// Going somewhere else in the Book should look like the Book going there.
    /// Leaves turn past the reader, the destination changes while they are
    /// covered, and the Book settles on it — so the new leaf is revealed by
    /// the riffle rather than swapped behind it.
    private func riffle(reversed: Bool, changeDestination: @escaping () -> Void) {
        guard !isRiffling, !isBookTransitioning else { return }

        guard !reduceMotion else {
            BookFeedback.play(.openPage)
            withAnimation(BookMotion.pageTurn(true)) { changeDestination() }
            return
        }

        BookFeedback.play(.openPage)
        riffleIsReversed = reversed
        riffleProgress = 0
        isRiffling = true

        withAnimation(.timingCurve(0.28, 0.02, 0.16, 1, duration: Self.riffleDuration)) {
            riffleProgress = 1
        }

        Task { @MainActor in
            // Swap under the thickest part of the flight, so the reader never
            // sees the destination arrive — only the Book arriving at it.
            try? await Task.sleep(for: .seconds(Self.riffleDuration * 0.41))
            changeDestination()
            try? await Task.sleep(for: .seconds(Self.riffleDuration * 0.64))
            isRiffling = false
        }
    }

    private func openBook() {
        guard !isBookTransitioning else { return }
        BookFeedback.play(.openPage)
        if reduceMotion {
            isBookClosed = false
            coverTurn = 1
            return
        }

        isBookTransitioning = true
        isBookClosed = false
        withAnimation(.timingCurve(0.20, 0.72, 0.18, 1, duration: 0.82)) {
            coverTurn = 1
        }
        finishBookTransition(after: 0.82)
    }

    private func closeBook() {
        guard !isBookTransitioning else { return }
        BookFeedback.play(.tap)
        if reduceMotion {
            isBookClosed = true
            coverTurn = 0
            return
        }

        isBookTransitioning = true
        isBookClosed = true
        withAnimation(.timingCurve(0.54, 0.02, 0.22, 1, duration: 0.74)) {
            coverTurn = 0
        }
        finishBookTransition(after: 0.74)
    }

    private func finishBookTransition(after duration: Double) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            isBookTransitioning = false
        }
    }

    private func synchronizationKey(
        for leaves: [FolioLeaf],
        metrics: FolioLayoutMetrics
    ) -> String {
        let leafKey = leaves.map(\.id).joined(separator: "|")
        return "\(Int(metrics.pageWidth)):\(Int(metrics.pageHeight)):\(metrics.contentSizeCategory.rawValue):\(leafKey)"
    }

    #if DEBUG
    /// Launch-only visual routes. They do not change reader state; they let a
    /// locked Simulator settle directly on otherwise hard-to-reach specimens.
    private func requestedSmokeLeaf(in leaves: [FolioLeaf]) -> FolioLeaf? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--smoke-folio-decoration-plate") {
            return leaves.first(where: \.isDecorationPlate)
        }
        if arguments.contains("--smoke-folio-ending") {
            return leaves.first(where: \.isEnding)
        }
        return nil
    }
    #endif

    /// Repagination can move a word to a differently numbered leaf. Restore by
    /// the logical Page and text offset rather than by a brittle leaf number.
    private func synchronizeCurrentLeaf(in leaves: [FolioLeaf]) {
        guard !leaves.isEmpty else {
            currentLeafID = nil
            readingPosition = nil
            preferredDocumentIndex = 0
            return
        }

        if let currentLeafID, leaves.contains(where: { $0.id == currentLeafID }) {
            rememberPosition(for: currentLeafID, in: leaves)
            return
        }

        if let position = readingPosition,
           let restored = leaves.first(where: {
               $0.documentID == position.documentID
                   && $0.textRange.contains(position.textOffset)
           }) ?? leaves
               .filter({ $0.documentID == position.documentID })
               .min(by: {
                   abs($0.textRange.lowerBound - position.textOffset)
                       < abs($1.textRange.lowerBound - position.textOffset)
               }) {
            currentLeafID = restored.id
            rememberPosition(for: restored.id, in: leaves)
            return
        }

        let documentIDs = leaves.reduce(into: [String]()) { result, leaf in
            if !result.contains(leaf.documentID) { result.append(leaf.documentID) }
        }
        let documentIndex = min(preferredDocumentIndex, max(0, documentIDs.count - 1))
        let targetID = documentIDs[documentIndex]
        let target = leaves.first(where: { $0.documentID == targetID }) ?? leaves[0]
        currentLeafID = target.id
        rememberPosition(for: target.id, in: leaves)
    }

    private func rememberPosition(for leafID: String?, in leaves: [FolioLeaf]) {
        guard let leafID, let leaf = leaves.first(where: { $0.id == leafID }) else { return }
        readingPosition = FolioReadingPosition(
            documentID: leaf.documentID,
            textOffset: leaf.textRange.lowerBound
        )

        let documentIDs = leaves.reduce(into: [String]()) { result, candidate in
            if !result.contains(candidate.documentID) { result.append(candidate.documentID) }
        }
        preferredDocumentIndex = documentIDs.firstIndex(of: leaf.documentID) ?? 0
    }
}

// MARK: - The physical Book

/// What remains visible beneath an open leaf: leather at the fore-edge, a
/// stitched hinge, page-block lines, and the monthly coat waiting underneath.
private struct FolioBookBoard: View {
    let cover: PagesRisingMonthlyCover

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.17, blue: 0.13),
                            Color(red: 0.16, green: 0.10, blue: 0.18),
                            Color(red: 0.055, green: 0.045, blue: 0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let artwork = cover.artworkAssetName {
                Image(artwork)
                    .resizable()
                    .scaledToFill()
                    .saturation(0.58)
                    .contrast(1.08)
                    .opacity(0.24)
                    .blendMode(.screen)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }

            Image("ParchmentFiber")
                .resizable()
                .scaledToFill()
                .opacity(0.10)
                .blendMode(.softLight)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    BookPalette.lampGold.opacity(0.30),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 5])
                )
                .padding(9)

            HStack(spacing: 1.5) {
                ForEach(0..<6, id: \.self) { index in
                    Rectangle()
                        .fill(BookPalette.page.opacity(0.22 - Double(index) * 0.022))
                        .frame(width: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 4)
        }
        .overlay(alignment: .leading) {
            FolioLeatherHinge()
                .frame(width: 22)
        }
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.34, green: 0.07, blue: 0.08), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 12, height: 78)
                .offset(x: -25, y: 24)
                .rotationEffect(.degrees(3))
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 18, x: 5, y: 12)
    }
}

/// The leaves beneath the one being read. Their uneven fore-edge and bottom
/// signatures make the page sit on a book block instead of floating over a
/// cover illustration.
private struct FolioLeafBlock: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Array((0..<5).reversed()), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.89, green: 0.81, blue: 0.64),
                                    Color(red: 0.72, green: 0.62, blue: 0.46)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(BookPalette.ink.opacity(0.09), lineWidth: 0.6)
                        }
                        .frame(
                            width: proxy.size.width - CGFloat(4 - index) * 0.7,
                            height: proxy.size.height - CGFloat(4 - index) * 0.55
                        )
                        .offset(
                            x: CGFloat(index) * 0.75,
                            y: CGFloat(index) * 0.65
                        )
                }

                Image("ParchmentFiber")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.11)
                    .blendMode(.multiply)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Canvas { context, size in
                    var foreEdge = Path()
                    for y in stride(from: CGFloat(5), through: size.height - 5, by: 4.5) {
                        let inset = Int(y / 4.5).isMultiple(of: 3) ? CGFloat(1.5) : 0
                        foreEdge.move(to: CGPoint(x: inset, y: y))
                        foreEdge.addLine(to: CGPoint(x: size.width, y: y + 0.25))
                    }
                    context.stroke(
                        foreEdge,
                        with: .color(BookPalette.ink.opacity(0.14)),
                        lineWidth: 0.45
                    )
                }
                .frame(width: 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.vertical, 7)

                Canvas { context, size in
                    var signatures = Path()
                    for x in stride(from: CGFloat(8), through: size.width - 8, by: 14) {
                        signatures.move(to: CGPoint(x: x, y: 0))
                        signatures.addLine(to: CGPoint(x: x + 1, y: size.height))
                    }
                    context.stroke(
                        signatures,
                        with: .color(BookPalette.ink.opacity(0.10)),
                        lineWidth: 0.5
                    )
                }
                .frame(height: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 10)
            }
            .shadow(color: .black.opacity(0.24), radius: 5, x: 2, y: 4)
        }
    }
}

private struct FolioLeatherHinge: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.58), .black.opacity(0.12), .black.opacity(0.46)],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(spacing: 16) {
                ForEach(0..<18, id: \.self) { _ in
                    Circle()
                        .fill(BookPalette.lampGold.opacity(0.34))
                        .frame(width: 2.5, height: 2.5)
                }
            }
        }
    }
}

/// The cover drags a soft pool of darkness across the first leaf while it
/// turns. Its opacity is zero at both resting positions; making the progress
/// animatable preserves the shadow in the middle of the journey.
private struct FolioCoverPassingShadow: View, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let passage = max(0, sin(.pi * progress))
            let shadowWidth = proxy.size.width * 0.72

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(Double(0.34 * passage)),
                    .black.opacity(Double(0.16 * passage)),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: shadowWidth)
            .offset(x: (-shadowWidth * 0.62) + (proxy.size.width * 0.72 * progress))
            .blendMode(.multiply)
        }
    }
}

/// The closed state deliberately uses the same title hierarchy as the monthly
/// website proof, but gives it a handled field-journal body: leather, stitches,
/// brass guards, a pressed sprig, and one grimoire sigil that has no business
/// being embossed on ordinary stationery.
private struct FolioMonthlyCoverView: View {
    let cover: PagesRisingMonthlyCover

    private var usesWeatherCabinet: Bool {
        cover.artworkAssetName == "BoundVolumeCoverWeatherCabinet"
    }

    private var titleInk: Color {
        usesWeatherCabinet
            ? Color(red: 0.12, green: 0.10, blue: 0.08)
            : Color(red: 0.98, green: 0.93, blue: 0.82)
    }

    private var secondaryInk: Color {
        usesWeatherCabinet
            ? Color(red: 0.22, green: 0.17, blue: 0.12)
            : Color(red: 0.96, green: 0.89, blue: 0.76)
    }

    private var coverGold: Color {
        usesWeatherCabinet
            ? Color(red: 0.43, green: 0.28, blue: 0.10)
            : BookPalette.lampGold
    }

    private var displayTitle: String {
        if usesWeatherCabinet, cover.title == "The Labyrinth of Stories" {
            return "The Labyrinth\nof Stories"
        }
        if usesWeatherCabinet, cover.title == "Pages Still Rising" {
            return "Pages Still\nRising"
        }
        return cover.title
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.23, blue: 0.17),
                            Color(red: 0.075, green: 0.09, blue: 0.075),
                            Color(red: 0.18, green: 0.08, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let artwork = cover.artworkAssetName {
                if usesWeatherCabinet {
                    // The cabinet plate is 1875 x 2775 while the phone folio is
                    // deliberately narrower. Fill-cropping removed both doors
                    // and made the cover look accidentally enlarged. Preserve
                    // the whole commissioned plate and let the leather beneath
                    // it act as a dark mounting mat where the ratios differ.
                    Image(artwork)
                        .resizable()
                        .scaledToFit()
                        .saturation(0.94)
                        .contrast(1.02)
                        .overlay {
                            LinearGradient(
                                colors: [.black.opacity(0.02), .black.opacity(0.14)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .opacity(0.98)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                } else {
                    Image(artwork)
                        .resizable()
                        .scaledToFill()
                        .saturation(0.76)
                        .contrast(1.10)
                        .overlay {
                            LinearGradient(
                                colors: [.black.opacity(0.12), .black.opacity(0.48)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .opacity(0.80)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }

            Image("ParchmentFiber")
                .resizable()
                .scaledToFill()
                .opacity(0.16)
                .blendMode(.softLight)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.58), lineWidth: 1)
                .padding(12)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    BookPalette.lampGold.opacity(0.32),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 5])
                )
                .padding(18)

            VStack(spacing: 9) {
                Text(cover.imprint.uppercased())
                    .font(.system(size: 10, weight: .black, design: .serif))
                    .tracking(2.0)
                    .foregroundStyle(titleInk)

                Text(cover.monthLine.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(coverGold)

                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(coverGold.opacity(0.92))
                    .padding(.vertical, 2)

                Text(displayTitle)
                    .font(.system(size: usesWeatherCabinet ? 23 : 30, weight: .bold, design: .serif))
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.62)
                    .lineLimit(3)
                    .lineSpacing(usesWeatherCabinet ? -1 : -2)
                    .foregroundStyle(titleInk)
                    .shadow(
                        color: usesWeatherCabinet ? .white.opacity(0.40) : .black.opacity(0.62),
                        radius: usesWeatherCabinet ? 1 : 3,
                        y: usesWeatherCabinet ? 0 : 2
                    )
                    .padding(.horizontal, usesWeatherCabinet ? 54 : 38)

                Text(cover.subtitle)
                    .font(.system(.caption, design: .serif).italic().weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(secondaryInk.opacity(0.90))
                    .padding(.horizontal, 46)

                Text(cover.dateLine.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.45)
                    .foregroundStyle(coverGold)

                Text(cover.footerLine)
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundStyle(secondaryInk.opacity(usesWeatherCabinet ? 0.76 : 0.68))
            }
            .padding(.vertical, 46)

            if !usesWeatherCabinet {
                MarginaliaImage(name: "MarginaliaLavender", width: 82, opacity: 0.30)
                    .rotationEffect(.degrees(-13))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 20)
                    .padding(.bottom, 28)
                    .accessibilityHidden(true)

                MarginaliaImage(name: "MarginaliaCompass", width: 90, opacity: 0.20)
                    .rotationEffect(.degrees(8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 24)
                    .padding(.trailing, 20)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .leading) {
            FolioLeatherHinge()
                .frame(width: 24)
                .opacity(0.92)
        }
        .overlay(alignment: .topLeading) { FolioBrassCorner().frame(width: 48, height: 48) }
        .overlay(alignment: .topTrailing) { FolioBrassCorner().frame(width: 48, height: 48).rotationEffect(.degrees(90)) }
        .overlay(alignment: .bottomTrailing) { FolioBrassCorner().frame(width: 48, height: 48).rotationEffect(.degrees(180)) }
        .overlay(alignment: .bottomLeading) { FolioBrassCorner().frame(width: 48, height: 48).rotationEffect(.degrees(270)) }
        .overlay(alignment: .trailing) {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.08, blue: 0.10), Color.black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 22, height: 70)
                .overlay { Capsule().stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1) }
                .offset(x: 9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.black.opacity(0.52), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.58), radius: 22, x: 4, y: 14)
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

/// The Book going to find something in another part of itself.
///
/// Not a transition between screens: a burst of leaves turns past the reader,
/// the destination changes while they are covered, and the Book settles on
/// what was asked for. Animatable, so the whole flight interpolates from one
/// `progress` value instead of re-evaluating the folio's body per frame.
private struct FolioRiffle: View, Animatable {
    var progress: CGFloat
    var isReversed: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Enough leaves to read as travel, few enough to stay cheap. Each one is
    /// a plain shape; the only text is the ghost ruling drawn into it.
    private static let leafCount = 9

    /// How much of the whole flight a single leaf occupies. The leftover time
    /// is what staggers them, so leaves overlap rather than march in file.
    private static let leafSpan: Double = 0.42

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                ForEach(0..<Self.leafCount, id: \.self) { index in
                    let stagger = Double(index) / Double(Self.leafCount)
                    let started = stagger * (1 - Self.leafSpan)
                    let raw = (Double(progress) - started) / Self.leafSpan
                    let local = min(1, max(0, raw))
                    // A leaf that has not lifted yet, or has already fallen,
                    // must not paint: otherwise the stack reads as a smear.
                    let isFlying = raw > 0.05 && raw < 0.98
                    let turn = isReversed ? (1 - local) : local

                    riffleLeaf(size: proxy.size, turn: turn, index: index)
                        .rotation3DEffect(
                            .degrees(-172 * turn),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.58
                        )
                        // Real paper bows as it passes overhead.
                        .scaleEffect(
                            x: 1,
                            y: 1 - (0.020 * sin(.pi * turn)),
                            anchor: .leading
                        )
                        .opacity(isFlying ? 1 : 0)
                        .zIndex(turn)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func riffleLeaf(size: CGSize, turn: Double, index: Int) -> some View {
        // A page catches the lamp as it comes up, then falls into its own
        // shadow on the way down.
        let lift = sin(.pi * turn)

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.87, blue: 0.72),
                            Color(red: 0.84, green: 0.75, blue: 0.58)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Image("ParchmentFiber")
                .resizable()
                .scaledToFill()
                .opacity(0.16)
                .blendMode(.multiply)

            // Faint ruling, so the leaves read as pages with writing on them
            // rather than blank card stock.
            Canvas { context, canvasSize in
                var ruling = Path()
                let inset = canvasSize.width * 0.16
                for y in stride(from: canvasSize.height * 0.22, to: canvasSize.height * 0.86, by: 13) {
                    let ragged = (Int(y) % 3 == 0) ? canvasSize.width * 0.22 : 0
                    ruling.move(to: CGPoint(x: inset, y: y))
                    ruling.addLine(to: CGPoint(x: canvasSize.width - inset - ragged, y: y))
                }
                context.stroke(
                    ruling,
                    with: .color(BookPalette.ink.opacity(0.13)),
                    lineWidth: 1.1
                )
            }

            // The lamp catch, brightest as the leaf stands upright.
            LinearGradient(
                colors: [
                    .white.opacity(0.20 * lift),
                    .clear,
                    .black.opacity(0.30 * lift)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.overlay)

            // Its own shadow deepens as it turns away from the reader.
            Color.black.opacity(0.34 * turn)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.16), lineWidth: 0.7)
        }
        .frame(
            width: size.width - CGFloat(index % 3) * 1.1,
            height: size.height - CGFloat(index % 2) * 1.4
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.42 * lift), radius: 12 * lift, x: 10 * lift, y: 5)
    }
}

/// The Book's own contents leaf: printed matter, not a menu. Every entry is a
/// destination `ContentView` already owns, so this leaf never invents a second
/// router — it only gives the Book somewhere to print its own divisions.
private struct FolioContentsLeaf: View {
    let entries: [PagesRisingContentsEntry]
    let showsBack: Bool
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entries) { entry in
                        FolioContentsRow(entry: entry)

                        if entry.id != entries.last?.id {
                            Rectangle()
                                .fill(BookPalette.ink.opacity(0.10))
                                .frame(height: 0.7)
                                .padding(.leading, 34)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            footer
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .parchmentSurface(accent: BookPalette.lampGold, isActive: true)
        .overlay(alignment: .leading) {
            FolioOpenLeafBinding(tint: BookPalette.lampGold)
                .frame(width: 31)
                .padding(.vertical, 8)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("CONTENTS")
                .font(.system(size: 12, weight: .black, design: .serif))
                .tracking(3.2)
                .foregroundStyle(BookPalette.lampGold)

            Text("What this Book is currently made of.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(BookPalette.ink.opacity(0.56))
        }
        .padding(.leading, 34)
        .padding(.bottom, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(BookPalette.lampGold.opacity(0.34))
                .frame(height: 1)
                .padding(.leading, 34)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var footer: some View {
        Group {
            if showsBack {
                Button(action: onClose) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back to the open leaf")
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close the contents and return to the open leaf")
            } else {
                Text("No loose Page is tapping tonight. The rest of me is still here.")
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.ink.opacity(0.52))
            }
        }
        .padding(.top, 10)
        .padding(.leading, 34)
    }
}

/// A contents line, set the way a printed one is: the entry on the left, a
/// dotted leader carrying the eye across, and its mark at the fore-edge.
private struct FolioContentsRow: View {
    let entry: PagesRisingContentsEntry

    @State private var isPressed = false

    var body: some View {
        Button(action: entry.action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: entry.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BookPalette.lampGold.opacity(0.86))
                    .frame(width: 24, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)

                    if !entry.detail.isEmpty {
                        Text(entry.detail)
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(BookPalette.ink.opacity(0.54))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                FolioLeaderDots()
                    .frame(height: 9)
                    .layoutPriority(-1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(BookPalette.ink.opacity(0.34))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(
                BookPalette.lampGold.opacity(isPressed ? 0.10 : 0),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.16)) { isPressed = pressing }
        }, perform: {})
        .accessibilityLabel(entry.detail.isEmpty ? entry.title : "\(entry.title). \(entry.detail)")
        .accessibilityHint("Turns the Book to this part of itself")
    }
}

private struct FolioLeaderDots: View {
    var body: some View {
        Canvas { context, size in
            var dots = Path()
            let y = size.height * 0.5
            var x: CGFloat = 2
            while x < size.width - 2 {
                dots.addEllipse(in: CGRect(x: x, y: y, width: 1.3, height: 1.3))
                x += 5
            }
            context.fill(dots, with: .color(BookPalette.ink.opacity(0.30)))
        }
        .frame(minWidth: 18)
        .accessibilityHidden(true)
    }
}

private struct FolioBrassCorner: View {
    var body: some View {
        FolioCornerGuardShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.74, blue: 0.36),
                        Color(red: 0.43, green: 0.28, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                FolioCornerGuardShape()
                    .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.38), radius: 2, y: 1)
    }
}

private struct FolioCornerGuardShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A little illumination painted into every open leaf. It is navigation, but
/// it behaves like a recurring piece of the Book's art rather than toolbar
/// chrome: touch the bright centre and the Glow opens.
private struct FolioGlowIllumination: View {
    let score: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    private var strength: Double {
        0.34 + (Double(max(0, min(100, score))) / 100 * 0.48)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(BookPalette.lampGold.opacity(0.035 + strength * 0.06))
                    .blur(radius: 1.4)

                Canvas { context, size in
                    let gold = BookPalette.lampGold
                    let centre = CGPoint(x: size.width * 0.52, y: size.height * 0.47)

                    var leftVine = Path()
                    leftVine.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.70))
                    leftVine.addCurve(
                        to: CGPoint(x: size.width * 0.46, y: size.height * 0.50),
                        control1: CGPoint(x: size.width * 0.18, y: size.height * 0.38),
                        control2: CGPoint(x: size.width * 0.34, y: size.height * 0.82)
                    )
                    context.stroke(leftVine, with: .color(gold.opacity(strength * 0.64)), lineWidth: 1)

                    var rightVine = Path()
                    rightVine.move(to: CGPoint(x: size.width * 0.92, y: size.height * 0.24))
                    rightVine.addCurve(
                        to: CGPoint(x: size.width * 0.58, y: size.height * 0.45),
                        control1: CGPoint(x: size.width * 0.82, y: size.height * 0.58),
                        control2: CGPoint(x: size.width * 0.68, y: size.height * 0.16)
                    )
                    context.stroke(rightVine, with: .color(gold.opacity(strength * 0.56)), lineWidth: 0.9)

                    let flecks: [(CGFloat, CGFloat, CGFloat)] = [
                        (0.18, 0.34, 1.5), (0.26, 0.69, 1.1),
                        (0.76, 0.30, 1.3), (0.84, 0.61, 0.9)
                    ]
                    for (x, y, radius) in flecks {
                        let dot = CGRect(
                            x: size.width * x - radius,
                            y: size.height * y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.fill(Path(ellipseIn: dot), with: .color(gold.opacity(strength * 0.72)))
                    }

                    let ring = CGRect(
                        x: centre.x - size.width * 0.20,
                        y: centre.y - size.height * 0.20,
                        width: size.width * 0.40,
                        height: size.height * 0.40
                    )
                    context.stroke(
                        Path(ellipseIn: ring),
                        with: .color(gold.opacity(strength * 0.38)),
                        style: StrokeStyle(lineWidth: 0.8, dash: [1.8, 2.6])
                    )
                }

                Image(systemName: "sparkle")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(BookPalette.lampGold.opacity(strength))
                    .shadow(
                        color: BookPalette.lampGold.opacity(isBreathing ? 0.52 : 0.20),
                        radius: isBreathing ? 8 : 3
                    )
                    .scaleEffect(isBreathing ? 1.06 : 0.96)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Glow. \(BeliefLexicon.glowName(for: score)).")
        .accessibilityHint("Opens the illuminated Glow menu")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

private struct FolioBookClasp: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.10, blue: 0.065),
                            Color(red: 0.35, green: 0.19, blue: 0.085),
                            .black.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(BookPalette.lampGold.opacity(0.60))
                .frame(width: 7, height: 7)
                .overlay {
                    Circle().stroke(.black.opacity(0.45), lineWidth: 0.7)
                }
        }
        .frame(width: 29, height: 21)
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.30), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.40), radius: 3, x: 1, y: 2)
    }
}

private struct FolioBookCharmRail: View {
    let charms: [PagesRisingBookCharm]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = FolioCharmMotionModel()

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ForEach(charms) { charm in
                FolioBookCharmButton(
                    charm: charm,
                    motionAngle: charm.id == "search"
                        ? motion.lightCharmAngle
                        : motion.heavyCharmAngle
                )
            }
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tools hanging from the Book")
        .onAppear { motion.start(reduceMotion: reduceMotion) }
        .onDisappear { motion.stop() }
        .onChange(of: reduceMotion) { _, next in
            motion.start(reduceMotion: next)
        }
    }
}

private struct FolioBookCharmButton: View {
    let charm: PagesRisingBookCharm
    let motionAngle: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    private var lean: Double {
        charm.id == "search" ? -5.5 : 4.0
    }

    private var cordLength: CGFloat {
        charm.id == "search" ? 30 : 39
    }

    var body: some View {
        Button(action: charm.action) {
            VStack(spacing: -1) {
                FolioCharmCord(
                    metal: charm.metal,
                    length: cordLength,
                    seed: charm.seed
                )

                Group {
                    if charm.id == "search" {
                        FolioMagnifyingGlassCharm(metal: charm.metal, seed: charm.seed)
                    } else {
                        FolioAlmanacCharm(metal: charm.metal, seed: charm.seed)
                    }
                }
            }
            .rotationEffect(
                .degrees(lean + (reduceMotion ? 0 : motionAngle) + (isPressed && !reduceMotion ? -2 : 0)),
                anchor: .top
            )
            .scaleEffect(isPressed ? 0.96 : 1, anchor: .top)
            .frame(width: 54, height: 94, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.68)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityLabel("Open \(charm.title)")
        .accessibilityHint("A charm hanging from the Book")
    }
}

/// The two tools are pendulums, not a single gyroscope decoration. The glass
/// is light and follows the hand quickly; the almanac plate carries farther
/// and settles later. Gravity supplies the resting angle and brief device
/// acceleration gives each spring a small, physically legible kick.
@MainActor
private final class FolioCharmMotionModel: ObservableObject {
    @Published private(set) var lightCharmAngle: Double = 0
    @Published private(set) var heavyCharmAngle: Double = 0

    private let manager = CMMotionManager()
    private var lastTimestamp: TimeInterval?
    private var lightVelocity: Double = 0
    private var heavyVelocity: Double = 0

    func start(reduceMotion: Bool) {
        stop(reset: reduceMotion)
        guard !reduceMotion, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let self, let sample else { return }
            self.consume(sample)
        }
    }

    func stop() {
        stop(reset: false)
    }

    private func stop(reset: Bool) {
        manager.stopDeviceMotionUpdates()
        lastTimestamp = nil
        lightVelocity = 0
        heavyVelocity = 0
        if reset {
            lightCharmAngle = 0
            heavyCharmAngle = 0
        }
    }

    private func consume(_ sample: CMDeviceMotion) {
        let previous = lastTimestamp ?? sample.timestamp - manager.deviceMotionUpdateInterval
        let dt = min(1.0 / 15.0, max(1.0 / 60.0, sample.timestamp - previous))
        lastTimestamp = sample.timestamp

        let gravityTarget = max(-12, min(12, sample.gravity.x * 17))
        let impulse = max(-1.4, min(1.4, sample.userAcceleration.x))
        integrate(
            angle: &lightCharmAngle,
            velocity: &lightVelocity,
            target: gravityTarget,
            impulse: impulse * 8.0,
            stiffness: 19.0,
            dampingPerFrame: 0.82,
            dt: dt
        )
        integrate(
            angle: &heavyCharmAngle,
            velocity: &heavyVelocity,
            target: gravityTarget * 0.72,
            impulse: impulse * 4.2,
            stiffness: 10.5,
            dampingPerFrame: 0.90,
            dt: dt
        )
    }

    private func integrate(
        angle: inout Double,
        velocity: inout Double,
        target: Double,
        impulse: Double,
        stiffness: Double,
        dampingPerFrame: Double,
        dt: Double
    ) {
        velocity += ((target - angle) * stiffness + impulse) * dt
        velocity *= pow(dampingPerFrame, dt * 60)
        angle = max(-15, min(15, angle + velocity * dt))
    }
}

private struct FolioCharmCord: View {
    let metal: Color
    let length: CGFloat
    let seed: Int

    var body: some View {
        Canvas { context, size in
            let linkHeight: CGFloat = 7
            let count = max(2, Int(size.height / 5.5))
            for index in 0..<count {
                let y = CGFloat(index) * 5.5
                let x = size.width / 2 + (index.isMultiple(of: 2) ? -0.8 : 0.8)
                let rect = CGRect(x: x - 2.7, y: y, width: 5.4, height: linkHeight)
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color((index.isMultiple(of: 2) ? metal : BookPalette.lampGold).opacity(0.62)),
                    lineWidth: 1.15
                )
            }
        }
        .frame(width: 14, height: length)
        .shadow(color: .black.opacity(0.38), radius: 1, x: 1, y: 1)
        .accessibilityHidden(true)
    }
}

private struct FolioMagnifyingGlassCharm: View {
    let metal: Color
    let seed: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.50, green: 0.69, blue: 0.70).opacity(0.36),
                            Color(red: 0.07, green: 0.10, blue: 0.12).opacity(0.82)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 22
                    )
                )
                .frame(width: 36, height: 36)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [metal.opacity(0.92), BookPalette.lampGold.opacity(0.62), .black.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4.5
                )
                .frame(width: 40, height: 40)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [metal.opacity(0.84), Color(red: 0.18, green: 0.10, blue: 0.06), .black.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 8, height: 28)
                .rotationEffect(.degrees(-42))
                .offset(x: 17, y: 20)

            FolioCharmWear(seed: seed)
                .frame(width: 40, height: 40)
        }
        .frame(width: 54, height: 58, alignment: .topLeading)
        .shadow(color: .black.opacity(0.56), radius: 5, x: 2, y: 4)
    }
}

private struct FolioAlmanacCharm: View {
    let metal: Color
    let seed: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            metal.opacity(0.88),
                            Color(red: 0.43, green: 0.25, blue: 0.08),
                            Color(red: 0.12, green: 0.075, blue: 0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 6) {
                HStack(spacing: 3) {
                    Circle().fill(.black.opacity(0.42))
                    Circle().stroke(BookPalette.page.opacity(0.62), lineWidth: 1)
                    Circle().fill(BookPalette.page.opacity(0.62))
                }
                .frame(width: 25, height: 7)

                ZStack {
                    Circle()
                        .stroke(BookPalette.page.opacity(0.42), lineWidth: 1)
                    Path { path in
                        path.move(to: CGPoint(x: 4, y: 13))
                        path.addCurve(
                            to: CGPoint(x: 18, y: 4),
                            control1: CGPoint(x: 11, y: 13),
                            control2: CGPoint(x: 17, y: 9)
                        )
                    }
                    .stroke(BookPalette.page.opacity(0.60), lineWidth: 1)
                }
                .frame(width: 22, height: 22)
            }

            FolioCharmWear(seed: seed)
        }
        .frame(width: 39, height: 49)
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.62), lineWidth: 1.1)
        }
        .overlay(alignment: .top) {
            Circle()
                .stroke(metal.opacity(0.72), lineWidth: 2)
                .frame(width: 11, height: 11)
                .offset(y: -7)
        }
        .shadow(color: .black.opacity(0.56), radius: 5, x: 2, y: 4)
    }
}

private struct FolioCharmWear: View {
    let seed: Int

    var body: some View {
        Canvas { context, size in
            let mixed = abs(seed * 37)
            for index in 0..<4 {
                let x = CGFloat((mixed + index * 19) % 31) + 6
                let y = CGFloat((mixed + index * 13) % 29) + 7
                var scratch = Path()
                scratch.move(to: CGPoint(x: x, y: y))
                scratch.addLine(to: CGPoint(x: x + CGFloat(4 + index), y: y - CGFloat(2 + index % 2)))
                context.stroke(
                    scratch,
                    with: .color(.black.opacity(0.18)),
                    lineWidth: 0.7
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FolioSealBookmarkRail: View {
    let tabs: [PagesRisingSealTab]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(tabs) { tab in
                FolioSealBookmarkButton(tab: tab)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FolioSealBookmarkButton: View {
    let tab: PagesRisingSealTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var revealBloom = false

    private var wearIndex: Int { abs(tab.seed) }
    private var tabWidth: CGFloat { 54 + CGFloat(wearIndex % 4) }
    private var tabHeight: CGFloat { 67 + CGFloat((wearIndex / 2) % 5) }
    private var restingX: CGFloat { CGFloat((wearIndex / 3) % 4) - 1.5 }
    private var restingY: CGFloat { CGFloat((wearIndex / 5) % 3) - 1 }
    private var restingRotation: Double { Double((wearIndex % 9) - 4) * 0.16 }
    private var wornShape: FolioWornBookmarkShape {
        FolioWornBookmarkShape(seed: tab.seed)
    }

    var body: some View {
        Button {
            guard !tab.isBusy else { return }
            tab.action()
        } label: {
            ZStack(alignment: .trailing) {
                wornShape
                    .fill(
                        LinearGradient(
                            colors: [
                                .black.opacity(0.76),
                                Color(red: 0.24, green: 0.16, blue: 0.10).opacity(0.86),
                                tab.wax.opacity(0.58),
                                tab.wax.opacity(0.68)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                wornShape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.11, blue: 0.055).opacity(0.30),
                                .clear,
                                .black.opacity(0.18)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )

                Image("ParchmentFiber")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.24)
                    .blendMode(.multiply)

                Rectangle()
                    .fill(.black.opacity(0.27))
                    .frame(width: 28)
                    .frame(maxWidth: .infinity, alignment: .leading)

                FolioBookmarkWear(seed: tab.seed)
                FolioBookmarkStitches(seed: tab.seed)

                Text(tab.shortTitle.uppercased())
                    .font(.system(size: 8.2, weight: .black, design: .serif))
                    .tracking(0.75)
                    .foregroundStyle(Color(red: 0.94, green: 0.87, blue: 0.73).opacity(0.92))
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(90))
                    .frame(width: 34, height: tabHeight - 8)
                    .padding(.trailing, 1)

                if tab.isBusy {
                    wornShape
                        .fill(.black.opacity(0.23))
                    ProgressView()
                        .tint(Color(red: 0.90, green: 0.82, blue: 0.67))
                        .scaleEffect(0.66)
                        .frame(width: 34)
                }

                if tab.isRevealing {
                    wornShape
                        .fill(BookPalette.lampGold.opacity(revealBloom ? 0.10 : 0.40))
                    wornShape
                        .stroke(BookPalette.lampGold.opacity(revealBloom ? 0.0 : 0.92), lineWidth: 1.5)
                        .shadow(color: BookPalette.lampGold.opacity(0.85), radius: revealBloom ? 15 : 4)
                }

                wornShape
                    .stroke(.black.opacity(0.48), lineWidth: 0.9)
            }
            .frame(width: tabWidth, height: tabHeight)
            .clipShape(wornShape)
            .compositingGroup()
            .frame(width: 62, height: 72, alignment: .leading)
            .offset(
                x: restingX + (isPressed ? (reduceMotion ? -1 : -3) : 0),
                y: restingY
            )
            .rotationEffect(.degrees(restingRotation), anchor: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(tab.isBusy)
        .shadow(color: .black.opacity(0.50), radius: 4, x: 2, y: 3)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.26, dampingFraction: 0.68)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityLabel("\(tab.title) bookmark")
        .accessibilityHint(tab.isBusy ? "Working" : "Press to open")
        // The bookmark eases out of the binding while the Book is offering it,
        // so the reveal is legible as "here, this is yours now" even with the
        // bloom suppressed for reduced motion.
        .offset(x: tab.isRevealing ? 7 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: tab.isRevealing)
        .onChange(of: tab.isRevealing) { _, revealing in
            guard revealing, !reduceMotion else {
                revealBloom = false
                return
            }
            revealBloom = false
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                revealBloom = true
            }
        }
    }
}

/// A leaf cut by hand rather than guillotined. Deckle is the untrimmed edge
/// left when paper is made in a mould: it wanders by a point or two and never
/// repeats. A `RoundedRectangle` reads as a card, and no amount of decoration
/// laid on top of a card makes it read as paper.
///
/// The spine edge stays true. Only the three outer edges wander, which is how a
/// real bound leaf behaves — the fold is cut straight and the fore-edge is not.
struct FolioDeckleEdgeShape: Shape {
    var seed: Int = 7
    /// Kept small on purpose. Deckle is felt at a glance and examined rarely;
    /// past two points or so it stops reading as paper and starts reading as
    /// damage.
    var amplitude: CGFloat = 1.6

    func path(in rect: CGRect) -> Path {
        func jitter(_ salt: Int) -> CGFloat {
            let mixed = UInt(bitPattern: seed &* 2_654_435_761 &+ salt &* 40_503)
            return (CGFloat(mixed % 1_001) / 1_000 - 0.5) * 2 * amplitude
        }

        let corner: CGFloat = 2.5
        // Enough steps to read as a wander, few enough to stay cheap: this
        // shape is rebuilt on every leaf turn.
        let steps = 14
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + corner))

        // Head, wandering.
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * t,
                y: rect.minY + jitter(step) + amplitude
            ))
        }

        // Fore-edge, the most worried of the three.
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.maxX - amplitude + jitter(step &+ 97) * 1.25,
                y: rect.minY + rect.height * t
            ))
        }

        // Tail, wandering back.
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.maxX - rect.width * t,
                y: rect.maxY - amplitude + jitter(step &+ 211)
            ))
        }

        // The spine edge is cut straight, so it closes plainly.
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.closeSubpath()
        return path
    }
}

/// Rectangular, but cut by a hand and worried at the outer edge. The hidden
/// left edge stays long so the flag still reads as inserted beneath the leaves.
private struct FolioWornBookmarkShape: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        func jitter(_ salt: Int, amplitude: CGFloat) -> CGFloat {
            let mixed = UInt(bitPattern: seed &* 31 &+ salt &* 73)
            let unit = CGFloat(mixed % 101) / 100
            return (unit - 0.5) * 2 * amplitude
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 1.1 + jitter(0, amplitude: 0.7)))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + 0.8 + jitter(1, amplitude: 0.8)))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + 1.2 + jitter(2, amplitude: 0.9)))
        path.addLine(to: CGPoint(x: rect.maxX - 1.4, y: rect.minY + 1.1 + jitter(3, amplitude: 0.8)))
        path.addLine(to: CGPoint(x: rect.maxX - 0.5 + jitter(4, amplitude: 0.45), y: rect.minY + rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.maxX - 2.1, y: rect.minY + rect.height * 0.36))
        path.addLine(to: CGPoint(x: rect.maxX - 0.7, y: rect.minY + rect.height * 0.43))
        path.addLine(to: CGPoint(x: rect.maxX - 1.5 + jitter(5, amplitude: 0.55), y: rect.minY + rect.height * 0.72))
        path.addLine(to: CGPoint(x: rect.maxX - 0.8, y: rect.maxY - 1.7 + jitter(6, amplitude: 0.7)))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.maxY - 0.8 + jitter(7, amplitude: 0.8)))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.maxY - 1.3 + jitter(8, amplitude: 0.7)))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 0.7 + jitter(9, amplitude: 0.65)))
        path.closeSubpath()
        return path
    }
}

/// Uneven handling marks: thumb-darkened patches, a partial ring, scratches,
/// and little pale scuffs where the dye has gone thin.
private struct FolioBookmarkWear: View {
    let seed: Int

    private func unit(_ salt: Int) -> CGFloat {
        let mixed = UInt(bitPattern: seed &* 97 &+ salt &* 131)
        return CGFloat(mixed % 997) / 996
    }

    var body: some View {
        Canvas { context, size in
            let dirt = Color(red: 0.14, green: 0.075, blue: 0.035)
            for index in 0..<6 {
                let width = 6 + unit(index * 4 + 1) * 14
                let height = 4 + unit(index * 4 + 2) * 10
                let x = size.width * (0.18 + unit(index * 4 + 3) * 0.70) - width / 2
                let y = size.height * (0.10 + unit(index * 4 + 4) * 0.82) - height / 2
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height)),
                    with: .color(dirt.opacity(0.07 + Double(unit(index + 40)) * 0.09))
                )
            }

            let ringSize = 14 + unit(61) * 8
            let ringRect = CGRect(
                x: size.width * (0.44 + unit(62) * 0.26) - ringSize / 2,
                y: size.height * (0.24 + unit(63) * 0.34) - ringSize / 2,
                width: ringSize,
                height: ringSize * 0.72
            )
            context.stroke(
                Path(ellipseIn: ringRect),
                with: .color(dirt.opacity(0.11)),
                style: StrokeStyle(lineWidth: 1.1, dash: [ringSize * 0.72, ringSize * 0.35])
            )

            for index in 0..<4 {
                let y = size.height * (0.18 + unit(index + 70) * 0.65)
                let startX = size.width * (0.44 + unit(index + 80) * 0.34)
                var scratch = Path()
                scratch.move(to: CGPoint(x: startX, y: y))
                scratch.addLine(to: CGPoint(x: min(size.width - 2, startX + 5 + unit(index + 90) * 9), y: y + unit(index + 100) * 1.5 - 0.75))
                context.stroke(
                    scratch,
                    with: .color(Color(red: 0.94, green: 0.84, blue: 0.66).opacity(0.13)),
                    lineWidth: 0.65
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// The seam is intentionally incomplete. A few stitches have pulled loose and
/// no two flags have exactly the same surviving rhythm.
private struct FolioBookmarkStitches: View {
    let seed: Int

    var body: some View {
        Canvas { context, size in
            let thread = Color(red: 0.82, green: 0.70, blue: 0.50).opacity(0.28)
            let darkThread = Color.black.opacity(0.20)

            for index in 0..<8 where (index + seed).isMultiple(of: 4) == false {
                let x = 27 + CGFloat(index) * max(3.4, (size.width - 32) / 8)
                let slant: CGFloat = (index + seed).isMultiple(of: 2) ? 0.55 : -0.45
                var top = Path()
                top.move(to: CGPoint(x: x, y: 3.4))
                top.addLine(to: CGPoint(x: x + 2.0, y: 3.4 + slant))
                context.stroke(top, with: .color(thread), lineWidth: 0.7)

                var bottom = Path()
                bottom.move(to: CGPoint(x: x + 0.5, y: size.height - 3.5))
                bottom.addLine(to: CGPoint(x: x + 2.2, y: size.height - 3.5 - slant))
                context.stroke(bottom, with: .color(thread), lineWidth: 0.7)
            }

            for index in 0..<5 where (index + seed).isMultiple(of: 3) == false {
                let y = 6 + CGFloat(index) * max(5.2, (size.height - 12) / 5)
                var edge = Path()
                edge.move(to: CGPoint(x: size.width - 3.5, y: y))
                edge.addLine(to: CGPoint(x: size.width - 3.1, y: y + 2.2))
                context.stroke(edge, with: .color(thread), lineWidth: 0.7)
            }

            var buriedSeam = Path()
            buriedSeam.move(to: CGPoint(x: 27.5, y: 4))
            buriedSeam.addLine(to: CGPoint(x: 27.1, y: size.height - 4))
            context.stroke(
                buriedSeam,
                with: .color(darkThread),
                style: StrokeStyle(lineWidth: 0.6, dash: [3, 2, 1, 4])
            )
        }
        .allowsHitTesting(false)
    }
}

/// The open leaf is sewn to something, not floating in a card stack. The
/// punctures and uneven thread are intentionally quieter than the ink.
private struct FolioOpenLeafBinding: View {
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [
                        .black.opacity(0.18),
                        tint.opacity(0.055),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                Canvas { context, size in
                    var thread = Path()
                    thread.move(to: CGPoint(x: 10, y: 15))
                    thread.addCurve(
                        to: CGPoint(x: 11, y: size.height - 15),
                        control1: CGPoint(x: 8, y: size.height * 0.30),
                        control2: CGPoint(x: 14, y: size.height * 0.70)
                    )
                    context.stroke(
                        thread,
                        with: .color(BookPalette.lampGold.opacity(0.23)),
                        style: StrokeStyle(lineWidth: 0.9, dash: [2, 8])
                    )

                    for index in 0..<8 {
                        let y = 25 + (size.height - 50) * CGFloat(index) / 7
                        let hole = CGRect(x: 7.5, y: y - 2, width: 5, height: 4)
                        context.fill(Path(ellipseIn: hole), with: .color(.black.opacity(0.14)))
                        context.stroke(
                            Path(ellipseIn: hole.insetBy(dx: 0.7, dy: 0.6)),
                            with: .color(BookPalette.page.opacity(0.42)),
                            lineWidth: 0.5
                        )
                    }
                }
            }
            .frame(width: 31, height: proxy.size.height)
        }
        .blendMode(.multiply)
    }
}

// MARK: - Transient folio model

private struct FolioReadingPosition: Equatable {
    var documentID: String
    var textOffset: Int
}

/// One horizontal-measure contract shared by semantic pagination and rendered
/// ink. Page families may change type, alignment, ruling, and marginalia, but
/// none of them may quietly claim paper outside these insets.
private enum FolioLeafMeasure {
    static let paperPadding: CGFloat = 18
    static let paperVerticalPadding: CGFloat = 14
    static let inkPadding: CGFloat = 14
    /// TextKit and SwiftUI occasionally disagree by a fraction of a glyph at a
    /// line end. Measure a little narrower so the rendered leaf wraps early.
    static let typesettingSafetyInset: CGFloat = 9
    /// UILabel can round a multi-line run one or two points taller than
    /// NSAttributedString.boundingRect. Reserve real paper for that rounding
    /// so the final baseline of a fragment is never shaved in half.
    static let textBoxVerticalSafetyInset: CGFloat = 6

    static func typesettingWidth(pageWidth: CGFloat) -> CGFloat {
        typesettingWidth(
            fieldWidth: paperFieldWidth(pageWidth: pageWidth)
        )
    }

    static func paperFieldWidth(pageWidth: CGFloat) -> CGFloat {
        max(1, pageWidth - (paperPadding * 2))
    }

    static func paperFieldHeight(pageHeight: CGFloat) -> CGFloat {
        max(1, pageHeight - (paperVerticalPadding * 2))
    }

    /// The field is the exact width left inside the paper padding. Keeping this
    /// overload beside the page-width calculation lets the renderer and
    /// paginator consume the same equation instead of growing two almost-equal
    /// notions of where a line ends.
    static func typesettingWidth(fieldWidth: CGFloat) -> CGFloat {
        max(
            1,
            fieldWidth
                - (inkPadding * 2)
                - (typesettingSafetyInset * 2)
        )
    }
}

private struct FolioLayoutMetrics: Equatable {
    var pageWidth: CGFloat
    var pageHeight: CGFloat
    var contentSizeCategory: UIContentSizeCategory

    /// The leaf reserves a real gutter for marginalia plus fixed header and
    /// final-leaf disposition furniture. Every leaf uses the same conservative
    /// measure so turning to the last one never makes its ink jump or clip.
    var contentWidth: CGFloat { FolioLeafMeasure.typesettingWidth(pageWidth: pageWidth) }
    var contentHeight: CGFloat {
        let furnitureHeight: CGFloat = contentSizeCategory.isAccessibilityCategory ? 250 : 214
        return max(214, pageHeight - furnitureHeight)
    }
}

private enum FolioTitleDevice: String, Equatable {
    case heraldic
    case specimenLabel
    case letterhead
    case cabinetPlate
    case constellation
    case illuminatedInitial
    case quietRule
    case chapterMark
    case continuation
}

private enum FolioTextFlow: String, Equatable {
    case leading
    case centered
    case offset
}

/// Horizontal intent belongs to an individual block, not the whole leaf.
/// SwiftUI's TextAlignment has no justified case, so the compositor stores
/// its own value and hands the exact NSTextAlignment to TextKit.
private enum FolioParagraphAlignment: String, Equatable {
    case leading
    case centered
    case trailing
    case justified

    var frameAlignment: Alignment {
        switch self {
        case .leading, .justified: return .leading
        case .centered: return .center
        case .trailing: return .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading, .justified: return .leading
        case .centered: return .center
        case .trailing: return .trailing
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .centered: return .center
        case .trailing: return .right
        case .justified: return .justified
        }
    }
}

private enum FolioMarginSide: String, Equatable {
    case leading
    case trailing
    case none
}

private enum FolioRulingStyle: String, Equatable {
    case none
    case field
    case ledger
    case correspondence
    case constellation
}

private enum FolioTypeface: String, Equatable {
    case literary
    case field
    case archival
    case dispatch
    case luminous
}

/// The broad spatial behavior of a leaf. This is deliberately smaller than a
/// template catalog: Page dialect supplies the family resemblance, while the
/// stable document seed chooses one of a few editorial arrangements.
private enum FolioSpatialStyle: String, Equatable {
    case heroPlate
    case fieldRail
    case cabinetRail
    case letterMargin
    case quietColumn
}

/// A resolved composition, not a skin. Pagination and rendering both consume
/// this exact value, so a wide title, narrow field-note measure, or tall
/// letterhead owns real paper instead of colliding with it after layout.
private struct FolioLeafComposition: Equatable {
    var seed: Int
    var dialect: LeafVisualDialectID
    var titleDevice: FolioTitleDevice
    var textFlow: FolioTextFlow
    var rulingStyle: FolioRulingStyle
    var typeface: FolioTypeface
    var spatialStyle: FolioSpatialStyle
    var regionPattern: LeafRegionPatternID
    var headerHeight: CGFloat
    var titleScale: CGFloat
    var deckScale: CGFloat
    var bodyScale: CGFloat
    var lineSpacingScale: CGFloat
    var leadingInset: CGFloat
    var trailingInset: CGFloat
    var topInset: CGFloat
    var decorationBudget: Int
    var marginaliaSide: FolioMarginSide
    var marginaliaReserve: CGFloat
    var ghostOpacity: Double
    var inkBleedOpacity: Double
    var titleUsesAccent: Bool
    var usesAccessibleAlignment: Bool
    /// Let one word in the opening sentence take the accent ink. Reserved for
    /// Pages set at display size — a short Page is a held-up sentence, and the
    /// landing word carries it. On a full leaf of prose the same trick reads as
    /// a stray highlighter.
    var accentsOpeningPhrase: Bool = false

    func contentWidth(for role: FolioInkRole, metrics: FolioLayoutMetrics) -> CGFloat {
        contentWidth(for: role, baseContentWidth: metrics.contentWidth)
    }

    func contentWidth(for role: FolioInkRole, baseContentWidth: CGFloat) -> CGFloat {
        let titleNarrowing: CGFloat
        switch titleDevice {
        case .heraldic, .quietRule, .constellation:
            titleNarrowing = role == .title ? 18 : 0
        case .specimenLabel, .cabinetPlate:
            titleNarrowing = role == .title ? 10 : 0
        default:
            titleNarrowing = 0
        }
        return max(1, baseContentWidth - leadingInset - trailingInset - titleNarrowing)
    }

    /// Printed privacy copy shares its row with a shield. Pagination must
    /// reserve that same shield gutter or the label gains an unmeasured line
    /// when it reaches the real leaf.
    func textWidth(for role: FolioInkRole, metrics: FolioLayoutMetrics) -> CGFloat {
        let width = contentWidth(for: role, metrics: metrics)
        return role == .privacy ? max(1, width - 22) : width
    }

    func contentHeight(metrics: FolioLayoutMetrics) -> CGFloat {
        max(180, metrics.contentHeight - max(0, headerHeight - 32) - topInset)
    }

    func pointScale(for role: FolioInkRole) -> CGFloat {
        switch role {
        case .title: return titleScale
        case .deck: return deckScale
        case .body: return bodyScale
        case .handwritten, .underlined: return min(1.08, bodyScale + 0.03)
        case .provenance, .privacy: return min(1.02, bodyScale)
        }
    }

    func lineSpacing(for role: FolioInkRole) -> CGFloat {
        role.lineSpacing * lineSpacingScale
    }

    func spacingAfter(for role: FolioInkRole) -> CGFloat {
        let titleBreath: CGFloat = titleDevice == .heraldic || titleDevice == .constellation ? 6 : 0
        return role.spacingAfter * min(1.12, lineSpacingScale) + (role == .title ? titleBreath : 0)
    }

    func alignment(
        for role: FolioInkRole,
        text: String,
        blockID: String
    ) -> FolioParagraphAlignment {
        if usesAccessibleAlignment { return .leading }
        if role == .privacy { return .leading }
        let choice = Int(UInt(bitPattern: "\(seed)|\(blockID)".stableHash) % 100)
        switch role {
        case .title:
            if [.heraldic, .cabinetPlate, .constellation, .quietRule, .chapterMark].contains(titleDevice) {
                return .centered
            }
            return textFlow == .centered ? .centered : .leading
        case .deck:
            if textFlow == .centered { return .centered }
            return choice < 18 && text.count < 150 ? .trailing : .leading
        case .body:
            if text.count >= 190,
               [.literary, .dispatch, .luminous].contains(typeface),
               choice < 46 {
                return .justified
            }
            if text.count < 120, textFlow == .offset, choice < 22 {
                return .trailing
            }
            return textFlow == .centered && text.count < 180 ? .centered : .leading
        case .handwritten, .underlined:
            if choice < 28 { return .trailing }
            if choice < 43 { return .centered }
            return .leading
        case .provenance:
            return choice < 38 ? .trailing : .leading
        case .privacy:
            return .leading
        }
    }

    func tracking(for role: FolioInkRole) -> CGFloat {
        switch (typeface, role) {
        case (.archival, .title): return 1.1
        case (.dispatch, .title): return 0.7
        case (_, .provenance), (_, .privacy): return 0.25
        default: return 0
        }
    }
}

private enum FolioLeafCompositor {
    private struct Grammar {
        var dialect: LeafVisualDialectID
        var titleDevices: [FolioTitleDevice]
        var textFlows: [FolioTextFlow]
        var rulingStyles: [FolioRulingStyle]
        var typeface: FolioTypeface
        var titleScale: ClosedRange<CGFloat>
        var bodyScale: ClosedRange<CGFloat>
        var decorationBudget: ClosedRange<Int>
        var ghostOpacity: ClosedRange<Double>
        var inkBleedOpacity: ClosedRange<Double>
        var titleUsesAccent: Bool
    }

    static func plan(
        for surface: SurfacePage,
        documentID: String,
        leafIndex: Int,
        metrics: FolioLayoutMetrics
    ) -> FolioLeafComposition {
        let grammar = grammar(for: surface)
        let seed = "\(documentID)|\(leafIndex)|leaf-composition-v1".stableHash
        let isContinuation = leafIndex > 0
        let displayAmplification = displayTypeAmplification(
            for: surface,
            isContinuation: isContinuation
        )
        let spatialStyle = resolvedSpatialStyle(
            dialect: grammar.dialect,
            isContinuation: isContinuation,
            seed: seed
        )
        var regionPattern = resolvedRegionPattern(
            for: surface,
            dialect: grammar.dialect,
            leafIndex: leafIndex,
            seed: seed,
            metrics: metrics
        )
        if leafIndex > 0, regionPattern != .continuous {
            let previousSeed = "\(documentID)|\(leafIndex - 1)|leaf-composition-v1".stableHash
            let previousPattern = resolvedRegionPattern(
                for: surface,
                dialect: grammar.dialect,
                leafIndex: leafIndex - 1,
                seed: previousSeed,
                metrics: metrics
            )
            if previousPattern == regionPattern {
                regionPattern = [97, 193, 389]
                    .lazy
                    .map { salt in
                        resolvedRegionPattern(
                            for: surface,
                            dialect: grammar.dialect,
                            leafIndex: leafIndex,
                            seed: seed &+ salt,
                            metrics: metrics
                        )
                    }
                    .first(where: { $0 != previousPattern })
                    ?? .continuous
            }
        }
        let titleDevice = isContinuation
            ? .continuation
            : pick(grammar.titleDevices, seed: seed, salt: 3)
        var textFlow = pick(grammar.textFlows, seed: seed, salt: 5)
        if spatialStyle == .heroPlate || regionPattern == .heroPlate {
            textFlow = .centered
        }
        if metrics.contentSizeCategory.isAccessibilityCategory { textFlow = .leading }
        let ruling = pick(grammar.rulingStyles, seed: seed, salt: 7)
        let variation = unit(seed, salt: 11)
        let bodyVariation = unit(seed, salt: 13)
        let headerHeight = resolvedHeaderHeight(titleDevice, accessibility: metrics.contentSizeCategory.isAccessibilityCategory)
        var insets = resolvedInsets(flow: textFlow, seed: seed, accessibility: metrics.contentSizeCategory.isAccessibilityCategory)
        let decorationBudget = integer(in: grammar.decorationBudget, seed: seed, salt: 19)
        let marginaliaSide: FolioMarginSide
        let marginaliaReserve: CGFloat
        if decorationBudget == 0 || metrics.contentSizeCategory.isAccessibilityCategory {
            marginaliaSide = .none
            marginaliaReserve = 0
        } else if unit(seed, salt: 43) < 0.5 {
            marginaliaSide = .leading
            marginaliaReserve = resolvedMarginaliaReserve(
                style: spatialStyle,
                metrics: metrics,
                currentInsets: insets.leading + insets.trailing
            )
            insets.leading += marginaliaReserve
        } else {
            marginaliaSide = .trailing
            marginaliaReserve = resolvedMarginaliaReserve(
                style: spatialStyle,
                metrics: metrics,
                currentInsets: insets.leading + insets.trailing
            )
            insets.trailing += marginaliaReserve
        }

        return FolioLeafComposition(
            seed: seed,
            dialect: grammar.dialect,
            titleDevice: titleDevice,
            textFlow: textFlow,
            rulingStyle: ruling,
            typeface: grammar.typeface,
            spatialStyle: spatialStyle,
            regionPattern: regionPattern,
            headerHeight: headerHeight,
            titleScale: interpolate(grammar.titleScale, unit: variation),
            deckScale: (0.97 + bodyVariation * 0.08) * displayAmplification,
            bodyScale: interpolate(grammar.bodyScale, unit: bodyVariation) * displayAmplification,
            lineSpacingScale: 0.94 + unit(seed, salt: 17) * 0.14,
            leadingInset: insets.leading,
            trailingInset: insets.trailing,
            topInset: isContinuation ? 0 : (titleDevice == .illuminatedInitial ? 5 : 0),
            decorationBudget: decorationBudget,
            marginaliaSide: marginaliaSide,
            marginaliaReserve: marginaliaReserve,
            ghostOpacity: interpolate(grammar.ghostOpacity, unit: Double(unit(seed, salt: 23))),
            inkBleedOpacity: interpolate(grammar.inkBleedOpacity, unit: Double(unit(seed, salt: 29))),
            titleUsesAccent: grammar.titleUsesAccent,
            usesAccessibleAlignment: metrics.contentSizeCategory.isAccessibilityCategory,
            accentsOpeningPhrase: displayAmplification > 1.2
        )
    }

    /// Set a short Page like a short Page.
    ///
    /// Type scale was chosen entirely by dialect and a seeded variation, so a
    /// Page holding twelve words was set at the same size as one holding three
    /// hundred — and twelve words at reading size leaves most of the leaf empty
    /// while saying nothing about how much they matter. A book does the
    /// opposite: a page with one line on it sets that line large.
    ///
    /// This runs inside `plan`, before any text is measured, so the paginator
    /// sizes the leaf against the type it will actually draw. An amplified Page
    /// may therefore need a second leaf, which is correct — it is genuinely
    /// bigger now.
    ///
    /// Continuations are left alone. They are the middle of a Page already in
    /// flow, and re-sizing mid-thought would read as a mistake rather than as
    /// emphasis.
    static func displayTypeAmplification(
        for surface: SurfacePage,
        isContinuation: Bool
    ) -> CGFloat {
        guard !isContinuation else { return 1 }

        let prose = surface.payload.headline.count + surface.payload.body.count
        switch prose {
        case ..<70: return 1.50
        case 70..<130: return 1.30
        case 130..<220: return 1.14
        default: return 1
        }
    }

    private static func grammar(for surface: SurfacePage) -> Grammar {
        let dialect = resolvedDialect(for: surface)
        switch dialect {
        case .fieldJournal:
            return Grammar(dialect: dialect, titleDevices: [.heraldic, .specimenLabel, .quietRule], textFlows: [.centered, .leading, .offset], rulingStyles: [.field, .none], typeface: .field, titleScale: 1.03...1.22, bodyScale: 0.98...1.08, decorationBudget: 1...3, ghostOpacity: 0.025...0.055, inkBleedOpacity: 0.55...0.90, titleUsesAccent: false)
        case .correspondence:
            return Grammar(dialect: dialect, titleDevices: [.letterhead, .quietRule, .specimenLabel], textFlows: [.leading, .offset], rulingStyles: [.correspondence, .none], typeface: .dispatch, titleScale: 0.94...1.08, bodyScale: 0.98...1.04, decorationBudget: 1...3, ghostOpacity: 0.018...0.042, inkBleedOpacity: 0.32...0.62, titleUsesAccent: true)
        case .weatherCabinet:
            return Grammar(dialect: dialect, titleDevices: [.cabinetPlate, .specimenLabel, .constellation], textFlows: [.leading, .offset], rulingStyles: [.ledger, .constellation, .none], typeface: .archival, titleScale: 0.96...1.12, bodyScale: 0.96...1.03, decorationBudget: 1...3, ghostOpacity: 0.018...0.045, inkBleedOpacity: 0.28...0.54, titleUsesAccent: true)
        case .archive:
            return Grammar(dialect: dialect, titleDevices: [.specimenLabel, .chapterMark, .quietRule], textFlows: [.leading, .offset], rulingStyles: [.ledger, .none], typeface: .archival, titleScale: 0.94...1.10, bodyScale: 0.97...1.04, decorationBudget: 0...2, ghostOpacity: 0.045...0.082, inkBleedOpacity: 0.22...0.48, titleUsesAccent: true)
        case .grimoire:
            return Grammar(dialect: dialect, titleDevices: [.constellation, .chapterMark, .illuminatedInitial], textFlows: [.leading, .centered], rulingStyles: [.constellation, .none], typeface: .luminous, titleScale: 1.02...1.18, bodyScale: 0.98...1.06, decorationBudget: 1...3, ghostOpacity: 0.045...0.075, inkBleedOpacity: 0.58...0.92, titleUsesAccent: true)
        case .quotation:
            return Grammar(dialect: dialect, titleDevices: [.quietRule, .illuminatedInitial], textFlows: [.centered, .leading], rulingStyles: [.none], typeface: .literary, titleScale: 1.05...1.26, bodyScale: 1.00...1.08, decorationBudget: 0...2, ghostOpacity: 0.012...0.032, inkBleedOpacity: 0.18...0.36, titleUsesAccent: false)
        case .atlas:
            return Grammar(dialect: dialect, titleDevices: [.specimenLabel, .cabinetPlate, .chapterMark], textFlows: [.leading, .offset], rulingStyles: [.ledger, .field], typeface: .field, titleScale: 0.96...1.12, bodyScale: 0.96...1.04, decorationBudget: 1...3, ghostOpacity: 0.025...0.052, inkBleedOpacity: 0.35...0.68, titleUsesAccent: true)
        case .illuminatedPlate:
            return Grammar(dialect: dialect, titleDevices: [.illuminatedInitial, .quietRule, .chapterMark], textFlows: [.centered, .leading], rulingStyles: [.none], typeface: .literary, titleScale: 0.98...1.14, bodyScale: 0.96...1.02, decorationBudget: 1...3, ghostOpacity: 0.010...0.025, inkBleedOpacity: 0.16...0.32, titleUsesAccent: false)
        case .storybook:
            return Grammar(dialect: dialect, titleDevices: [.chapterMark, .constellation, .heraldic], textFlows: [.leading, .centered], rulingStyles: [.none, .constellation], typeface: .literary, titleScale: 1.02...1.20, bodyScale: 0.99...1.07, decorationBudget: 1...3, ghostOpacity: 0.035...0.065, inkBleedOpacity: 0.42...0.76, titleUsesAccent: false)
        case .plainLeaf:
            return Grammar(dialect: dialect, titleDevices: [.quietRule, .specimenLabel], textFlows: [.leading, .offset], rulingStyles: [.field, .none], typeface: .literary, titleScale: 0.98...1.12, bodyScale: 0.98...1.05, decorationBudget: 0...2, ghostOpacity: 0.025...0.048, inkBleedOpacity: 0.28...0.58, titleUsesAccent: false)
        }
    }

    private static func resolvedDialect(for surface: SurfacePage) -> LeafVisualDialectID {
        if let raw = surface.payload.metadata["leafVisualDialect"],
           let explicit = LeafVisualDialectID(rawValue: raw) {
            return explicit
        }
        let tags = Set((surface.payload.metadata["tags"] ?? "")
            .components(separatedBy: CharacterSet(charactersIn: ",|;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        if !tags.isDisjoint(with: Set(["play", "playful", "mission", "field", "dare"])) { return .fieldJournal }
        if !tags.isDisjoint(with: Set(["letter", "dispatch", "postage"])) { return .correspondence }
        if !tags.isDisjoint(with: Set(["weather", "sky", "forecast"])) { return .weatherCabinet }
        if !tags.isDisjoint(with: Set(["map", "compass", "place", "location"])) { return .atlas }

        switch surface.type {
        case .diary, .souvenir, .body, .fuel, .wickerDare, .gamePage, .plainPage:
            return .fieldJournal
        case .letter, .note, .gossip, .pactDispatch, .facultyResearch,
             .supportGuild, .inkrestOfficeHours:
            return .correspondence
        case .mood, .weather, .todaysSky:
            return .weatherCabinet
        case .aboutYou, .patreon, .bookOfYou, .bookRemembered,
             .bookConnections, .bookNotices, .inventory, .bindery,
             .bookPocket, .packPage, .calendar, .helpTips, .radio,
             .frontMatter:
            return .archive
        case .lore, .bookFae, .faeBargain, .tarot, .wordNegotiation,
             .theBleed, .askTheBook, .twoReadings, .enchantment,
             .glowInvitation:
            return .grimoire
        case .quotes, .affirmations, .rest, .quip, .bookAside:
            return .quotation
        case .location, .anchor, .wonderCompass, .marginsAtlas, .bookJump:
            return .atlas
        case .illuminatedPhoto, .illustration:
            return .illuminatedPlate
        case .narrativeOS, .taleBound, .academyClass, .elective,
             .festival, .welcome, .castBond, .pactVerdict, .pactErrand:
            return .storybook
        }
    }

    private static func resolvedHeaderHeight(_ device: FolioTitleDevice, accessibility: Bool) -> CGFloat {
        let base: CGFloat
        switch device {
        case .heraldic, .constellation: base = 58
        case .cabinetPlate, .chapterMark: base = 48
        case .letterhead, .illuminatedInitial: base = 44
        case .specimenLabel, .quietRule: base = 38
        case .continuation: base = 30
        }
        return accessibility ? min(base, 44) : base
    }

    private static func resolvedSpatialStyle(
        dialect: LeafVisualDialectID,
        isContinuation: Bool,
        seed: Int
    ) -> FolioSpatialStyle {
        switch dialect {
        case .fieldJournal, .atlas:
            return .fieldRail
        case .correspondence:
            return .letterMargin
        case .weatherCabinet, .archive:
            return .cabinetRail
        case .grimoire, .storybook:
            return !isContinuation && unit(seed, salt: 61) < 0.62
                ? .heroPlate
                : .fieldRail
        case .quotation, .illuminatedPlate:
            return .quietColumn
        case .plainLeaf:
            return unit(seed, salt: 67) < 0.44 ? .fieldRail : .quietColumn
        }
    }

    /// Selects a measured flow grammar, not a painted template. Page families
    /// keep a recognizable editorial rhythm, while content length and leaf
    /// number decide when the Book can afford a more theatrical arrangement.
    /// Pack art direction is honored, but accessibility always returns to one
    /// uninterrupted reading column.
    private static func resolvedRegionPattern(
        for surface: SurfacePage,
        dialect: LeafVisualDialectID,
        leafIndex: Int,
        seed: Int,
        metrics: FolioLayoutMetrics
    ) -> LeafRegionPatternID {
        guard !metrics.contentSizeCategory.isAccessibilityCategory else {
            return .continuous
        }

        if leafIndex == 0,
           let raw = surface.payload.metadata["leafRegionPattern"],
           let explicit = LeafRegionPatternID(rawValue: raw) {
            return explicit
        }

        let characterCount = [
            surface.prompt,
            surface.payload.headline,
            surface.detail,
            surface.pagesRisingReadingBody,
            surface.reason
        ].reduce(0) { $0 + $1.count }
        let shortEnoughForPlate = characterCount <= 520
        let mediumLength = characterCount <= 1_050
        let chance = unit(seed, salt: 71)

        if leafIndex > 0 {
            // Continuation leaves should feel quieter, but not mechanically
            // identical. Roughly one in three capable families breaks the
            // prose into two related fields; the rest remain generous text.
            switch dialect {
            case .fieldJournal, .grimoire, .storybook, .atlas, .plainLeaf:
                return chance < 0.34 ? .staggeredField : .continuous
            case .correspondence:
                return chance < 0.28 ? .letterWithPostscript : .continuous
            case .weatherCabinet, .archive:
                return chance < 0.30 ? .sectionedCabinet : .continuous
            case .quotation, .illuminatedPlate:
                return .continuous
            }
        }

        switch dialect {
        case .fieldJournal:
            if shortEnoughForPlate, chance < 0.58 { return .heroPlate }
            return mediumLength && chance < 0.80 ? .staggeredField : .continuous
        case .correspondence:
            return mediumLength ? .letterWithPostscript : .continuous
        case .weatherCabinet, .archive:
            return mediumLength ? .sectionedCabinet : .continuous
        case .grimoire, .storybook:
            if shortEnoughForPlate, chance < 0.66 { return .heroPlate }
            return mediumLength && chance < 0.82 ? .staggeredField : .continuous
        case .quotation:
            return shortEnoughForPlate ? .heroPlate : .continuous
        case .atlas:
            return mediumLength && chance < 0.72 ? .staggeredField : .continuous
        case .illuminatedPlate:
            return .sectionedCabinet
        case .plainLeaf:
            if shortEnoughForPlate, chance < 0.26 { return .heroPlate }
            return mediumLength && chance < 0.54 ? .staggeredField : .continuous
        }
    }

    /// Marginalia owns paper before the paginator runs. On a narrow phone this
    /// intentionally creates another leaf instead of drawing a moth over a
    /// sentence. Always leave a viable reading column, even on compact Books.
    private static func resolvedMarginaliaReserve(
        style: FolioSpatialStyle,
        metrics: FolioLayoutMetrics,
        currentInsets: CGFloat
    ) -> CGFloat {
        // On a phone, prose is still the main object on the leaf. Marginalia
        // may borrow a narrow rail, but it must never turn the reading measure
        // into a receipt. Larger marks can fall into the lower blank field (or
        // decline to print) instead of taking another forty points from every
        // line of ink.
        let desired: CGFloat
        switch style {
        case .heroPlate: desired = 18
        case .fieldRail: desired = 28
        case .cabinetRail: desired = 26
        case .letterMargin: desired = 24
        case .quietColumn: desired = 18
        }
        // Preserve roughly four fifths of the typesetting field, with a
        // comfortable literary floor on ordinary phones. Very small Books use
        // the available measure rather than manufacturing width off-paper.
        let minimumReadingMeasure = min(
            220,
            max(176, metrics.contentWidth * 0.82)
        )
        let available = max(
            0,
            metrics.contentWidth - currentInsets - minimumReadingMeasure
        )
        return min(desired, available)
    }

    private static func resolvedInsets(
        flow: FolioTextFlow,
        seed: Int,
        accessibility: Bool
    ) -> (leading: CGFloat, trailing: CGFloat) {
        guard !accessibility else { return (0, 0) }
        switch flow {
        case .leading: return (0, 0)
        // Alignment already centers the type. These are only a little breath,
        // not a second pair of page margins.
        case .centered: return (4 + unit(seed, salt: 31) * 4, 4 + unit(seed, salt: 37) * 4)
        case .offset:
            return unit(seed, salt: 41) < 0.5 ? (8, 0) : (0, 8)
        }
    }

    private static func pick<T>(_ values: [T], seed: Int, salt: Int) -> T {
        values[Int(UInt(bitPattern: (seed &+ salt &* 7_919).stableScramble) % UInt(values.count))]
    }

    private static func unit(_ seed: Int, salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 4_049).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }

    private static func interpolate(_ range: ClosedRange<CGFloat>, unit: CGFloat) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    private static func interpolate(_ range: ClosedRange<Double>, unit: Double) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    private static func integer(in range: ClosedRange<Int>, seed: Int, salt: Int) -> Int {
        let count = max(1, range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(UInt(bitPattern: (seed &+ salt &* 2_977).stableScramble) % UInt(count))
    }
}

private enum FolioTextRegionKind: String, Equatable {
    case primary
    case secondary
    case margin
    case provenance
    case media
}

/// A real measured rectangle in the printable field. Regions carry semantic
/// permissions and reading order; they are not arbitrary decorations. A
/// fragment can only enter a compatible region, and overflow walks the
/// region chain before asking the paginator for another leaf.
private struct FolioTextRegion: Identifiable, Equatable {
    var id: String
    var kind: FolioTextRegionKind
    var frame: CGRect
    var allowedRoles: [FolioInkRole]
    var maximumBlocks: Int? = nil

    func accepts(_ role: FolioInkRole) -> Bool {
        allowedRoles.contains(role)
    }
}

private struct FolioLeaf: Identifiable, Equatable {
    var id: String
    var documentID: String
    /// The visible paper this leaf was paginated against. A page-curl
    /// controller owns a wider transition canvas, so asking the host for its
    /// proposed size can silently typeset beyond the actual fore-edge.
    var pageSize: CGSize
    var surface: SurfacePage
    var fragments: [FolioFragment]
    var inkRegions: [FolioTextRegion] = []
    var textRange: ClosedRange<Int>
    var documentLeafIndex: Int
    var documentLeafCount: Int
    var globalLeafIndex: Int
    var globalLeafCount: Int
    var ghostText: String?
    var composition: FolioLeafComposition
    var decorationRecipe: LeafDecorationRecipe
    var inkUsedHeight: CGFloat
    var interactionKind: FolioInteractionLeafKind? = nil
    /// Interaction is another measured block. When there is honest room it
    /// shares the final reading leaf; otherwise it receives a leaf of its own.
    var interactionPlacement: CGRect? = nil
    /// A deliberate breath in the document: paper, marks, perhaps one line of
    /// handwriting, but no required prose block. It remains a normal turnable
    /// leaf and keeps the Page family's material dialect.
    var isDecorationPlate: Bool = false
    /// The Book running out of what it set for tonight. Carried as a real leaf
    /// so both pagers reach it with their ordinary index arithmetic, instead of
    /// each growing a special case at the end of the block.
    var isEnding: Bool = false

    var isFirstDocumentLeaf: Bool { documentLeafIndex == 0 }
    var isLastDocumentLeaf: Bool { documentLeafIndex == documentLeafCount - 1 }

    var decorativeMarginNote: String? {
        if interactionKind == .generationRequest { return "Psst. Tell me to start." }
        if interactionKind == .response { return "Your ink goes here." }
        guard documentLeafCount > 1 else { return nil }
        if isFirstDocumentLeaf { return "It would not all sit still. Turn me." }
        if isLastDocumentLeaf { return "I caught the last loose lines here." }
        return documentLeafIndex.isMultiple(of: 2)
            ? "It ran over. I put it here."
            : "More ink hiding under the leaf."
    }
}

private struct FolioFragment: Identifiable, Equatable {
    enum Content: Equatable {
        case text(String)
        case image(FolioMedia)
    }

    var id: String
    var content: Content
    var role: FolioInkRole
    var textRange: ClosedRange<Int>
    var measuredHeight: CGFloat
    var pointSize: CGFloat
    var spacingAfter: CGFloat
    var alignment: FolioParagraphAlignment = .leading
    /// Exact paper-field coordinates resolved by the paginator. Rendering does
    /// not infer a new width or stack order from UIKit's page-curl canvas.
    var placement: CGRect = .zero

    var plainText: String? {
        guard case .text(let text) = content else { return nil }
        return text
    }
}

private enum FolioMedia: Equatable {
    case asset(name: String, label: String)
    case file(path: String, label: String)
    case photoLibrary(identifier: String, label: String)
    case illuminated(draft: IlluminatedPhotoDraft, label: String)

    var label: String {
        switch self {
        case .asset(_, let label), .file(_, let label),
             .photoLibrary(_, let label), .illuminated(_, let label):
            return label
        }
    }
}

private enum FolioInkRole: Equatable {
    case title
    case deck
    case body
    case handwritten
    case underlined
    case provenance
    case privacy

    var textStyle: UIFont.TextStyle {
        switch self {
        case .title: return .title2
        case .deck: return .body
        case .body: return .body
        case .handwritten, .underlined: return .callout
        case .provenance, .privacy: return .footnote
        }
    }

    var basePointSize: CGFloat {
        switch self {
        case .title: return 25
        case .deck: return 17
        case .body: return 17.5
        case .handwritten, .underlined: return 16
        case .provenance, .privacy: return 13
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .title: return 2
        case .deck: return 3
        case .body: return 4
        case .handwritten, .underlined: return 3
        case .provenance, .privacy: return 2
        }
    }

    var spacingAfter: CGFloat {
        switch self {
        case .title: return 14
        case .deck: return 12
        case .body: return 11
        case .handwritten: return 13
        case .underlined: return 10
        case .provenance, .privacy: return 8
        }
    }

    func uiFont(category: UIContentSizeCategory, composition: FolioLeafComposition) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let resolvedPointSize = basePointSize * composition.pointScale(for: self)
        let base = uiFont(pointSize: resolvedPointSize, composition: composition)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base, compatibleWith: traits)
    }

    /// Rebuilds the exact face used during TextKit pagination after its scaled
    /// point size has been stored on a fragment. SwiftUI's `Text` can adopt the
    /// page-curl transition canvas as an ideal single-line width; UILabel stays
    /// pinned to the paper measure and uses the same wrapping engine as the
    /// paginator.
    func uiFont(pointSize: CGFloat, composition: FolioLeafComposition) -> UIFont {
        let base: UIFont
        switch self {
        case .title:
            base = FolioTypography.titleFont(
                size: pointSize,
                typeface: composition.typeface,
                device: composition.titleDevice
            )
        case .deck:
            base = FolioTypography.deckFont(size: pointSize, typeface: composition.typeface)
        case .body:
            base = FolioTypography.bodyFont(size: pointSize, typeface: composition.typeface)
        case .handwritten:
            base = UIFont(name: "Noteworthy-Light", size: pointSize)
                ?? FolioTypography.serifItalicFont(size: pointSize)
        case .underlined:
            base = FolioTypography.serifFont(size: pointSize, weight: .semibold)
        case .provenance, .privacy:
            base = composition.typeface == .archival
                ? .monospacedSystemFont(ofSize: pointSize, weight: .medium)
                : .systemFont(ofSize: pointSize, weight: .semibold)
        }
        return base
    }

    func swiftUIFont(pointSize: CGFloat, composition: FolioLeafComposition? = nil) -> Font {
        let typeface = composition?.typeface ?? .literary
        let device = composition?.titleDevice ?? .quietRule
        switch self {
        case .title:
            return FolioTypography.swiftTitleFont(size: pointSize, typeface: typeface, device: device)
        case .deck:
            return FolioTypography.swiftDeckFont(size: pointSize, typeface: typeface)
        case .body:
            return FolioTypography.swiftBodyFont(size: pointSize, typeface: typeface)
        case .handwritten:
            if UIFont(name: "Noteworthy-Light", size: pointSize) != nil {
                return .custom("Noteworthy-Light", fixedSize: pointSize)
            }
            return .system(size: pointSize, weight: .regular, design: .serif).italic()
        case .underlined:
            return .system(size: pointSize, weight: .semibold, design: .serif)
        case .provenance, .privacy:
            return .system(
                size: pointSize,
                weight: typeface == .archival ? .medium : .semibold,
                design: typeface == .archival ? .monospaced : .default
            )
        }
    }
}

private enum FolioTypography {
    static func titleFont(size: CGFloat, typeface: FolioTypeface, device: FolioTitleDevice) -> UIFont {
        switch (typeface, device) {
        case (.dispatch, _):
            return serifItalicFont(size: size)
        case (.archival, .specimenLabel), (.archival, .cabinetPlate):
            return .monospacedSystemFont(ofSize: size, weight: .semibold)
        case (.field, .specimenLabel):
            return .systemFont(ofSize: size, weight: .semibold)
        default:
            return serifFont(size: size, weight: .semibold)
        }
    }

    static func deckFont(size: CGFloat, typeface: FolioTypeface) -> UIFont {
        switch typeface {
        case .dispatch, .luminous: return serifItalicFont(size: size)
        case .archival: return .monospacedSystemFont(ofSize: size, weight: .regular)
        default: return serifFont(size: size, weight: .regular)
        }
    }

    static func bodyFont(size: CGFloat, typeface: FolioTypeface) -> UIFont {
        switch typeface {
        case .field, .literary, .dispatch, .luminous: return serifFont(size: size, weight: .regular)
        case .archival: return serifFont(size: size, weight: .regular)
        }
    }

    static func swiftTitleFont(size: CGFloat, typeface: FolioTypeface, device: FolioTitleDevice) -> Font {
        switch (typeface, device) {
        case (.dispatch, _):
            return .system(size: size, weight: .medium, design: .serif).italic()
        case (.archival, .specimenLabel), (.archival, .cabinetPlate):
            return .system(size: size, weight: .semibold, design: .monospaced)
        case (.field, .specimenLabel):
            return .system(size: size, weight: .semibold, design: .rounded)
        default:
            return .system(size: size, weight: .semibold, design: .serif)
        }
    }

    static func swiftDeckFont(size: CGFloat, typeface: FolioTypeface) -> Font {
        switch typeface {
        case .dispatch, .luminous:
            return .system(size: size, weight: .regular, design: .serif).italic()
        case .archival:
            return .system(size: size, weight: .regular, design: .monospaced)
        default:
            return .system(size: size, weight: .regular, design: .serif)
        }
    }

    static func swiftBodyFont(size: CGFloat, typeface: FolioTypeface) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func serifItalicFont(size: CGFloat) -> UIFont {
        let base = serifFont(size: size, weight: .regular)
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) else {
            return .italicSystemFont(ofSize: size)
        }
        return UIFont(descriptor: descriptor, size: size)
    }
}

/// Builds the printable rectangles consumed by both TextKit pagination and
/// SwiftUI rendering. Exact offsets vary gently from the stable composition
/// seed, but every region remains inside the same measured paper contract.
private enum FolioLeafRegionPlanner {
    static func regions(
        for composition: FolioLeafComposition,
        metrics: FolioLayoutMetrics
    ) -> [FolioTextRegion] {
        let top = 14 + composition.topInset
        let contentHeight = composition.contentHeight(metrics: metrics)
        let baseX = FolioLeafMeasure.inkPadding + FolioLeafMeasure.typesettingSafetyInset
        let mainX = baseX + composition.leadingInset
        let mainWidth = composition.contentWidth(for: .body, metrics: metrics)
        let bottom = top + contentHeight

        func frame(
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            height: CGFloat
        ) -> CGRect {
            CGRect(
                x: max(baseX, x),
                y: max(top, y),
                width: max(1, min(width, mainX + mainWidth - max(baseX, x))),
                height: max(1, min(height, bottom - max(top, y)))
            )
        }

        func region(
            _ id: String,
            _ kind: FolioTextRegionKind,
            _ rect: CGRect,
            _ roles: [FolioInkRole],
            maximumBlocks: Int? = nil
        ) -> FolioTextRegion {
            FolioTextRegion(
                id: id,
                kind: kind,
                frame: rect,
                allowedRoles: roles,
                maximumBlocks: maximumBlocks
            )
        }

        let allRoles: [FolioInkRole] = [
            .title, .deck, .body, .handwritten, .underlined, .provenance, .privacy
        ]
        let proseRoles: [FolioInkRole] = [.title, .deck, .body]
        let noteRoles: [FolioInkRole] = [.handwritten, .underlined]
        let filingRoles: [FolioInkRole] = [.provenance, .privacy]
        let horizontalJitter = (unit(composition.seed, salt: 5) - 0.5) * 8
        let verticalJitter = (unit(composition.seed, salt: 7) - 0.5) * 10

        switch composition.regionPattern {
        case .continuous:
            return [
                region(
                    "continuous",
                    .primary,
                    frame(x: mainX, y: top, width: mainWidth, height: contentHeight),
                    allRoles
                )
            ]

        case .heroPlate:
            let heroY = top + 12 + max(0, verticalJitter)
            let heroHeight = contentHeight * 0.59
            let noteWidth = min(112, mainWidth * 0.48)
            let noteX: CGFloat = composition.marginaliaSide == .trailing
                ? mainX + mainWidth - noteWidth
                : mainX
            return [
                region(
                    "hero",
                    .primary,
                    frame(
                        x: mainX + 2,
                        y: heroY,
                        width: mainWidth - 4,
                        height: heroHeight
                    ),
                    proseRoles,
                    maximumBlocks: 3
                ),
                region(
                    "hero-margin",
                    .margin,
                    frame(
                        x: noteX,
                        y: top + contentHeight * 0.64,
                        width: noteWidth,
                        height: contentHeight * 0.20
                    ),
                    noteRoles,
                    maximumBlocks: 2
                ),
                region(
                    "hero-filing",
                    .provenance,
                    frame(
                        x: mainX + mainWidth * 0.10,
                        y: top + contentHeight * 0.87,
                        width: mainWidth * 0.80,
                        height: contentHeight * 0.13
                    ),
                    filingRoles,
                    maximumBlocks: 2
                )
            ]

        case .staggeredField:
            let inset: CGFloat = 8
            let upperLeads = unit(composition.seed, salt: 13) < 0.5
            let upperX = mainX + (upperLeads ? 0 : inset) + horizontalJitter * 0.25
            let lowerX = mainX + (upperLeads ? inset : 0) - horizontalJitter * 0.25
            return [
                region(
                    "field-upper",
                    .primary,
                    frame(
                        x: upperX,
                        y: top,
                        width: mainWidth - inset,
                        height: contentHeight * 0.34
                    ),
                    proseRoles + noteRoles,
                    maximumBlocks: 3
                ),
                region(
                    "field-lower",
                    .secondary,
                    frame(
                        x: lowerX,
                        y: top + contentHeight * 0.40 + verticalJitter * 0.18,
                        width: mainWidth - inset,
                        height: contentHeight * 0.47
                    ),
                    [.deck, .body, .handwritten, .underlined]
                ),
                region(
                    "field-filing",
                    .provenance,
                    frame(
                        x: mainX,
                        y: top + contentHeight * 0.90,
                        width: mainWidth,
                        height: contentHeight * 0.10
                    ),
                    filingRoles,
                    maximumBlocks: 2
                )
            ]

        case .sectionedCabinet:
            return [
                region(
                    "cabinet-heading",
                    .primary,
                    frame(
                        x: mainX + 4,
                        y: top,
                        width: mainWidth - 8,
                        height: contentHeight * 0.32
                    ),
                    [.title, .deck],
                    maximumBlocks: 3
                ),
                region(
                    "cabinet-body",
                    .secondary,
                    frame(
                        x: mainX + horizontalJitter * 0.35,
                        y: top + contentHeight * 0.38,
                        width: mainWidth - abs(horizontalJitter * 0.35),
                        height: contentHeight * 0.41
                    ),
                    [.deck, .body, .handwritten, .underlined]
                ),
                region(
                    "cabinet-filing",
                    .provenance,
                    frame(
                        x: mainX + 7,
                        y: top + contentHeight * 0.83,
                        width: mainWidth - 14,
                        height: contentHeight * 0.17
                    ),
                    filingRoles + noteRoles,
                    maximumBlocks: 3
                )
            ]

        case .letterWithPostscript:
            return [
                region(
                    "letter-body",
                    .primary,
                    frame(
                        x: mainX,
                        y: top,
                        width: mainWidth,
                        height: contentHeight * 0.62
                    ),
                    proseRoles,
                    maximumBlocks: 5
                ),
                region(
                    "letter-postscript",
                    .secondary,
                    frame(
                        x: mainX + 12 + max(0, horizontalJitter * 0.35),
                        y: top + contentHeight * 0.68,
                        width: mainWidth - 18,
                        height: contentHeight * 0.17
                    ),
                    [.body, .handwritten, .underlined],
                    maximumBlocks: 3
                ),
                region(
                    "letter-filing",
                    .provenance,
                    frame(
                        x: mainX,
                        y: top + contentHeight * 0.89,
                        width: mainWidth,
                        height: contentHeight * 0.11
                    ),
                    filingRoles,
                    maximumBlocks: 2
                )
            ]
        }
    }

    private static func unit(_ seed: Int, salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 6_131).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

// MARK: - Semantic pagination

private struct FolioDraftBlock {
    var id: String
    var role: FolioInkRole
    var text: String?
    var media: FolioMedia?
    var startOffset: Int
    var preferredAlignment: FolioParagraphAlignment? = nil
    var minimumFragmentLines: Int = 1
}

/// Identifies a paginated document. The Page's own identifier is not enough:
/// generated prose arrives into the same `SurfacePage` id, so the key has to
/// close over every field `draftBlocks` actually reads, plus the metrics that
/// decide where a line breaks.
private struct FolioDocumentCacheKey: Hashable {
    let documentID: String
    let contentHash: Int
    let pageWidth: Int
    let pageHeight: Int
    let contentSizeCategory: String

    init(surface: SurfacePage, metrics: FolioLayoutMetrics) {
        documentID = surface.payload.metadata["pagesRisingFolioDocumentID"]?.nonEmpty
            ?? surface.id
        var hasher = Hasher()
        hasher.combine(surface.id)
        hasher.combine(surface.type)
        hasher.combine(surface.prompt)
        hasher.combine(surface.detail)
        hasher.combine(surface.payload.headline)
        hasher.combine(surface.payload.body)
        hasher.combine(surface.pagesRisingReadingBody)
        // Dictionary iteration order is not stable, so sort before hashing or
        // the key changes between two identical Pages and never hits.
        for pair in surface.payload.metadata.sorted(by: { $0.key < $1.key }) {
            hasher.combine(pair.key)
            hasher.combine(pair.value)
        }
        contentHash = hasher.finalize()
        pageWidth = Int(metrics.pageWidth.rounded())
        pageHeight = Int(metrics.pageHeight.rounded())
        contentSizeCategory = metrics.contentSizeCategory.rawValue
    }
}

private enum PagesRisingFolioPaginator {
    /// Laying out a leaf costs real TextKit measurement: a binary search per
    /// block, each candidate measured over an O(n) prefix. A three-Page desk
    /// carrying a nightly braid measures out around 22ms, and `paginate` is
    /// called from a view body that re-evaluates on unrelated desk state. The
    /// result is a pure function of (Page content, metrics), so memoise it and
    /// let ordinary redraws cost nothing.
    ///
    /// Cached per document rather than per desk: one Page finishing its prose
    /// must not throw away the pagination of the two beside it.
    @MainActor private static var documentCache: [FolioDocumentCacheKey: [FolioLeaf]] = [:]
    @MainActor private static var documentCacheOrder: [FolioDocumentCacheKey] = []
    private static let documentCacheLimit = 24

    private struct FolioRegionCursor {
        var region: FolioTextRegion
        var usedHeight: CGFloat = 0
        var blockIDs: [String] = []

        var remainingHeight: CGFloat {
            max(0, region.frame.height - usedHeight)
        }

        func canAccept(
            role: FolioInkRole,
            blockID: String,
            minimumHeight: CGFloat
        ) -> Bool {
            guard region.accepts(role), remainingHeight >= minimumHeight else {
                return false
            }
            guard let maximumBlocks = region.maximumBlocks,
                  !blockIDs.contains(blockID) else { return true }
            return blockIDs.count < maximumBlocks
        }

        mutating func consume(height: CGFloat, blockID: String) {
            usedHeight = min(region.frame.height, usedHeight + max(0, height))
            if !blockIDs.contains(blockID) { blockIDs.append(blockID) }
        }
    }

    private static func nextRegionIndex(
        for role: FolioInkRole,
        blockID: String,
        cursors: [FolioRegionCursor],
        minimumHeight: CGFloat
    ) -> Int? {
        cursors.indices.first { index in
            cursors[index].canAccept(
                role: role,
                blockID: blockID,
                minimumHeight: minimumHeight
            )
        }
    }

    /// A region owns its gross width; title apparatus may narrow inside it and
    /// privacy furniture reserves a shield gutter only during text measurement.
    private static func fragmentWidth(
        for role: FolioInkRole,
        region: FolioTextRegion,
        composition: FolioLeafComposition,
        metrics: FolioLayoutMetrics
    ) -> CGFloat {
        let bodyWidth = composition.contentWidth(for: .body, metrics: metrics)
        let roleWidth = composition.contentWidth(for: role, metrics: metrics)
        let roleNarrowing = max(0, bodyWidth - roleWidth)
        return max(1, region.frame.width - roleNarrowing)
    }

    private static func fragmentPlacement(
        role: FolioInkRole,
        displayWidth: CGFloat,
        measuredHeight: CGFloat,
        cursor: FolioRegionCursor,
        alignment: FolioParagraphAlignment
    ) -> CGRect {
        let horizontalRoom = max(0, cursor.region.frame.width - displayWidth)
        let x: CGFloat
        switch alignment {
        case .centered:
            x = cursor.region.frame.minX + horizontalRoom / 2
        case .trailing:
            x = cursor.region.frame.maxX - displayWidth
        case .leading, .justified:
            x = cursor.region.frame.minX
        }
        return CGRect(
            x: x,
            y: cursor.region.frame.minY + cursor.usedHeight,
            width: displayWidth,
            height: measuredHeight
        )
    }

    private static func placeMedia(
        _ media: FolioMedia,
        block: FolioDraftBlock,
        height: CGFloat,
        spacingAfter: CGFloat,
        regionIndex: Int,
        cursors: inout [FolioRegionCursor],
        fragments: inout [FolioFragment]
    ) {
        let region = cursors[regionIndex].region
        let placement = CGRect(
            x: region.frame.minX,
            y: region.frame.minY + cursors[regionIndex].usedHeight,
            width: region.frame.width,
            height: max(1, height)
        )
        let offset = block.startOffset
        fragments.append(FolioFragment(
            id: "\(block.id)-image",
            content: .image(media),
            role: block.role,
            textRange: offset...offset,
            measuredHeight: max(1, height),
            pointSize: 0,
            spacingAfter: spacingAfter,
            alignment: .centered,
            placement: placement
        ))
        cursors[regionIndex].consume(
            height: height + spacingAfter,
            blockID: block.id
        )
    }

    @MainActor
    private static func cachedPaginate(
        _ surface: SurfacePage,
        metrics: FolioLayoutMetrics
    ) -> [FolioLeaf] {
        let key = FolioDocumentCacheKey(surface: surface, metrics: metrics)
        if let hit = documentCache[key] { return hit }

        let leaves = paginate(surface, metrics: metrics)
        #if DEBUG
        let audit = layoutAuditMessages(
            for: leaves,
            surface: surface,
            metrics: metrics
        )
        if !audit.isEmpty {
            debugPrint("[PagesRisingFolio] \(surface.id): \(audit.joined(separator: "; "))")
        }
        #endif
        documentCache[key] = leaves
        documentCacheOrder.append(key)
        if documentCacheOrder.count > documentCacheLimit {
            let evicted = documentCacheOrder.removeFirst()
            documentCache.removeValue(forKey: evicted)
        }
        return leaves
    }

    private static func layoutAuditMessages(
        for leaves: [FolioLeaf],
        surface: SurfacePage,
        metrics: FolioLayoutMetrics
    ) -> [String] {
        var messages: [String] = []
        let expectedMediaCount = preferredMedia(for: surface).count
        let placedMediaCount = leaves
            .flatMap(\.fragments)
            .filter {
                if case .image = $0.content { return true }
                return false
            }
            .count
        if placedMediaCount != expectedMediaCount {
            messages.append("media \(placedMediaCount)/\(expectedMediaCount)")
        }

        for (index, leaf) in leaves.enumerated() {
            let fieldBounds = CGRect(
                x: 0,
                y: 0,
                width: FolioLeafMeasure.paperFieldWidth(pageWidth: metrics.pageWidth),
                height: leaf.composition.contentHeight(metrics: metrics) + 18
            )
            for fragment in leaf.fragments {
                let rect = fragment.placement
                if !rect.minX.isFinite || !rect.minY.isFinite
                    || !rect.width.isFinite || !rect.height.isFinite {
                    messages.append("leaf \(index + 1) has non-finite ink")
                } else if !fieldBounds.insetBy(dx: -1, dy: -1).contains(rect) {
                    messages.append("leaf \(index + 1) has ink outside paper")
                }
                if case .image(.file(let path, _)) = fragment.content,
                   !FileManager.default.fileExists(atPath: path) {
                    messages.append("leaf \(index + 1) has a missing plate")
                }
            }
            if let interaction = leaf.interactionPlacement {
                if !fieldBounds.insetBy(dx: -1, dy: -1).contains(interaction) {
                    messages.append("leaf \(index + 1) has interaction outside paper")
                }
                if leaf.fragments.contains(where: {
                    interaction.intersects($0.placement.insetBy(dx: -4, dy: -4))
                }) {
                    messages.append("leaf \(index + 1) overlaps interaction and ink")
                }
            }
        }
        return messages
    }

    @MainActor
    static func paginate(
        _ surfaces: [SurfacePage],
        metrics: FolioLayoutMetrics
    ) -> [FolioLeaf] {
        var documents: [[FolioLeaf]] = surfaces.enumerated().map { ordinal, surface in
            insertingDecorationPlateIfAppropriate(
                into: cachedPaginate(surface, metrics: metrics),
                for: surface,
                documentOrdinal: ordinal,
                metrics: metrics
            )
        }
        let totalLeafCount = documents.reduce(0) { $0 + $1.count }
        var globalIndex = 0

        for documentIndex in documents.indices {
            let count = documents[documentIndex].count
            for leafIndex in documents[documentIndex].indices {
                documents[documentIndex][leafIndex].documentLeafIndex = leafIndex
                documents[documentIndex][leafIndex].documentLeafCount = count
                documents[documentIndex][leafIndex].globalLeafIndex = globalIndex
                documents[documentIndex][leafIndex].globalLeafCount = totalLeafCount
                globalIndex += 1
            }

        }

        var flattened = documents.flatMap { $0 }
        for leafIndex in flattened.indices {
            let neighborIndex = flattened.indices.contains(leafIndex + 1)
                ? leafIndex + 1
                : leafIndex - 1
            guard flattened.indices.contains(neighborIndex) else { continue }
            flattened[leafIndex].ghostText = flattened[neighborIndex]
                .fragments
                .compactMap(\.plainText)
                .first
                .map { ghostExcerpt(from: $0) }
        }

        // Turning past the last leaf used to hit a wall with no signal. Give
        // the block a closing leaf instead: the Book says it has reached the
        // end of tonight's setting, and offers somewhere deeper to go. It is
        // appended after numbering so "leaf 2 of 2" stays truthful.
        if var closing = flattened.last {
            closing.id = "\(closing.documentID)::ending"
            closing.isEnding = true
            closing.fragments = []
            closing.ghostText = nil
            closing.globalLeafIndex = totalLeafCount
            flattened.append(closing)
        }

        return flattened
    }

    /// Roughly two Pages in every nine receive a wordless or near-wordless
    /// plate, with an extra chance for long documents that need a visual breath.
    /// It is deterministic for a given reading order and never interrupts a
    /// Page that is waiting for the reader's answer or a Gemma generation.
    private static func insertingDecorationPlateIfAppropriate(
        into leaves: [FolioLeaf],
        for surface: SurfacePage,
        documentOrdinal: Int,
        metrics: FolioLayoutMetrics
    ) -> [FolioLeaf] {
        guard !leaves.isEmpty,
              !metrics.contentSizeCategory.isAccessibilityCategory,
              !surface.pagesRisingNeedsUserInitiatedGeneration,
              !surface.isReaderFacingAsk,
              !surface.pageCapabilities.asksReader else { return leaves }

        let seed = "\(surface.id)|\(documentOrdinal)|decoration-plate-v1".stableHash
        let scheduledBreath = documentOrdinal % 4 == 2
        let longDocumentBreath = leaves.count >= 3
            && UInt(bitPattern: seed.stableScramble) % 100 < 42
        guard scheduledBreath || longDocumentBreath else { return leaves }

        let documentID = surface.payload.metadata["pagesRisingFolioDocumentID"]?.nonEmpty
            ?? surface.id
        let insertionIndex = leaves.count >= 3 ? min(2, leaves.count) : leaves.count
        var composition = FolioLeafCompositor.plan(
            for: surface,
            documentID: documentID,
            leafIndex: insertionIndex,
            metrics: metrics
        )
        composition.titleDevice = .continuation
        composition.textFlow = .centered
        composition.spatialStyle = .heroPlate
        composition.regionPattern = .heroPlate
        composition.headerHeight = min(composition.headerHeight, 32)
        composition.leadingInset = 0
        composition.trailingInset = 0
        composition.topInset = 0
        composition.decorationBudget = 3
        composition.marginaliaSide = .none
        composition.marginaliaReserve = 0
        let regions = FolioLeafRegionPlanner.regions(
            for: composition,
            metrics: metrics
        )
        let recipe = LeafDecorationLibrary.recipe(
            pageType: surface.type,
            metadata: surface.payload.metadata,
            documentID: documentID,
            leafIndex: insertionIndex,
            decorationPlate: true
        )
        let plate = FolioLeaf(
            id: "\(documentID)::decoration-plate::\(documentOrdinal)",
            documentID: documentID,
            pageSize: CGSize(width: metrics.pageWidth, height: metrics.pageHeight),
            surface: surface,
            fragments: [],
            inkRegions: regions,
            textRange: -1...(-1),
            documentLeafIndex: insertionIndex,
            documentLeafCount: 1,
            globalLeafIndex: 0,
            globalLeafCount: 1,
            ghostText: nil,
            composition: composition,
            decorationRecipe: recipe,
            inkUsedHeight: 0,
            isDecorationPlate: true
        )

        var expanded = leaves
        expanded.insert(plate, at: insertionIndex)
        return expanded
    }

    private static func paginate(
        _ surface: SurfacePage,
        metrics: FolioLayoutMetrics
    ) -> [FolioLeaf] {
        let documentID = surface.payload.metadata["pagesRisingFolioDocumentID"]?.nonEmpty
            ?? surface.id
        let blocks = draftBlocks(for: surface)
        var leaves: [FolioLeaf] = []
        var fragments: [FolioFragment] = []
        var composition = FolioLeafCompositor.plan(
            for: surface,
            documentID: documentID,
            leafIndex: 0,
            metrics: metrics
        )
        var regions = FolioLeafRegionPlanner.regions(for: composition, metrics: metrics)
        var cursors = regions.map { FolioRegionCursor(region: $0) }

        func finishLeaf() {
            guard !fragments.isEmpty else { return }
            let lower = fragments.map(\.textRange.lowerBound).min() ?? 0
            let upper = fragments.map(\.textRange.upperBound).max() ?? lower
            let ordinal = leaves.count
            let usedHeight = fragments.map { $0.placement.maxY }.max() ?? 0
            let decorationRecipe = LeafDecorationLibrary.recipe(
                pageType: surface.type,
                metadata: surface.payload.metadata,
                documentID: documentID,
                leafIndex: ordinal
            )
            leaves.append(FolioLeaf(
                id: "\(documentID)::\(lower)::\(ordinal)",
                documentID: documentID,
                pageSize: CGSize(width: metrics.pageWidth, height: metrics.pageHeight),
                surface: surface,
                fragments: fragments,
                inkRegions: regions,
                textRange: lower...upper,
                documentLeafIndex: ordinal,
                documentLeafCount: 1,
                globalLeafIndex: 0,
                globalLeafCount: 1,
                ghostText: nil,
                composition: composition,
                decorationRecipe: decorationRecipe,
                inkUsedHeight: usedHeight
            ))
            fragments = []
            composition = FolioLeafCompositor.plan(
                for: surface,
                documentID: documentID,
                leafIndex: leaves.count,
                metrics: metrics
            )
            regions = FolioLeafRegionPlanner.regions(for: composition, metrics: metrics)
            cursors = regions.map { FolioRegionCursor(region: $0) }
        }

        for (blockPosition, block) in blocks.enumerated() {
            if let media = block.media {
                var placed = false
                while !placed {
                    let spacingAfter = composition.spacingAfter(for: block.role)
                    let desiredHeight = mediaHeight(for: composition, metrics: metrics)
                    guard let regionIndex = nextRegionIndex(
                        for: block.role,
                        blockID: block.id,
                        cursors: cursors,
                        minimumHeight: min(72, desiredHeight + spacingAfter)
                    ) else {
                        if !fragments.isEmpty {
                            finishLeaf()
                            continue
                        }
                        if composition.regionPattern != .continuous {
                            composition.regionPattern = .continuous
                            regions = FolioLeafRegionPlanner.regions(
                                for: composition,
                                metrics: metrics
                            )
                            cursors = regions.map { FolioRegionCursor(region: $0) }
                            continue
                        }
                        // Every production blueprint includes a body-capable
                        // region. This defensive path keeps malformed pack art
                        // direction from trapping pagination in an empty loop.
                        guard let fallbackIndex = cursors.firstIndex(where: {
                            $0.region.accepts(block.role)
                        }) ?? cursors.indices.first else { break }
                        let available = max(1, cursors[fallbackIndex].remainingHeight - spacingAfter)
                        placeMedia(
                            media,
                            block: block,
                            height: min(desiredHeight, available),
                            spacingAfter: spacingAfter,
                            regionIndex: fallbackIndex,
                            cursors: &cursors,
                            fragments: &fragments
                        )
                        placed = true
                        continue
                    }

                    let available = max(1, cursors[regionIndex].remainingHeight - spacingAfter)
                    placeMedia(
                        media,
                        block: block,
                        height: min(desiredHeight, available),
                        spacingAfter: spacingAfter,
                        regionIndex: regionIndex,
                        cursors: &cursors,
                        fragments: &fragments
                    )
                    placed = true
                }
                continue
            }

            guard let text = block.text else { continue }
            let characters = Array(text)
            guard !characters.isEmpty else { continue }
            var consumed = 0

            while consumed < characters.count {
                while consumed < characters.count, characters[consumed].isWhitespace {
                    consumed += 1
                }
                guard consumed < characters.count else { break }

                var font = block.role.uiFont(
                    category: metrics.contentSizeCategory,
                    composition: composition
                )
                let spacingAfter = composition.spacingAfter(for: block.role)
                let minimumFragmentHeight = CGFloat(max(1, block.minimumFragmentLines))
                    * (font.lineHeight + composition.lineSpacing(for: block.role))
                    + spacingAfter
                guard let regionIndex = nextRegionIndex(
                    for: block.role,
                    blockID: block.id,
                    cursors: cursors,
                    minimumHeight: minimumFragmentHeight
                ) else {
                    if !fragments.isEmpty {
                        finishLeaf()
                        continue
                    }
                    if composition.regionPattern != .continuous {
                        composition.regionPattern = .continuous
                        regions = FolioLeafRegionPlanner.regions(
                            for: composition,
                            metrics: metrics
                        )
                        cursors = regions.map { FolioRegionCursor(region: $0) }
                        continue
                    }
                    // See the corresponding media fallback above. Exhausting
                    // an incompatible empty blueprint should still advance the
                    // document rather than hang the Book.
                    guard let fallbackIndex = cursors.firstIndex(where: {
                        $0.region.accepts(block.role)
                    }) ?? cursors.indices.first else { break }
                    cursors[fallbackIndex].usedHeight = 0
                    continue
                }

                let displayWidth = fragmentWidth(
                    for: block.role,
                    region: cursors[regionIndex].region,
                    composition: composition,
                    metrics: metrics
                )
                let width = block.role == .privacy
                    ? max(1, displayWidth - 22)
                    : displayWidth
                let available = max(0, cursors[regionIndex].remainingHeight - spacingAfter)
                let remainingText = String(characters[consumed...])
                let alignment = block.preferredAlignment
                    ?? composition.alignment(
                        for: block.role,
                        text: remainingText,
                        blockID: block.id
                    )
                if block.role == .title, consumed == 0 {
                    font = titleFontFittingWholeBlock(
                        String(characters),
                        baseFont: font,
                        width: width,
                        height: available,
                        composition: composition,
                        alignment: alignment
                    )
                    if fragments.isEmpty,
                       composition.regionPattern != .continuous,
                       let nextTextBlock = blocks.dropFirst(blockPosition + 1).first(where: {
                           $0.text?.nonEmpty != nil
                       }) {
                        let titleHeight = measuredTextHeight(
                            remainingText,
                            role: block.role,
                            font: font,
                            width: width,
                            composition: composition,
                            alignment: alignment
                        )
                        let nextFont = nextTextBlock.role.uiFont(
                            category: metrics.contentSizeCategory,
                            composition: composition
                        )
                        let nextMinimum = CGFloat(max(1, nextTextBlock.minimumFragmentLines))
                            * (nextFont.lineHeight + composition.lineSpacing(for: nextTextBlock.role))
                            + composition.spacingAfter(for: nextTextBlock.role)
                        if available - titleHeight < nextMinimum {
                            composition.regionPattern = .continuous
                            regions = FolioLeafRegionPlanner.regions(
                                for: composition,
                                metrics: metrics
                            )
                            cursors = regions.map { FolioRegionCursor(region: $0) }
                            continue
                        }
                    }
                }
                var fittingCount = largestFittingPrefix(
                    characters: Array(characters[consumed...]),
                    role: block.role,
                    font: font,
                    width: width,
                    height: available,
                    composition: composition,
                    alignment: alignment
                )
                fittingCount = balancedFittingPrefix(
                    characters: Array(characters[consumed...]),
                    initialCount: fittingCount,
                    role: block.role,
                    font: font,
                    width: width,
                    composition: composition,
                    alignment: alignment,
                    minimumLines: block.minimumFragmentLines
                )

                if block.role == .title,
                   fittingCount < characters.count - consumed,
                   fragments.isEmpty,
                   composition.regionPattern != .continuous {
                    // A display title may shrink within its editorial range,
                    // but it may not be amputated by a decorative opening
                    // box. Fall back to the full reading field and measure it
                    // again before allowing the title to continue.
                    composition.regionPattern = .continuous
                    regions = FolioLeafRegionPlanner.regions(
                        for: composition,
                        metrics: metrics
                    )
                    cursors = regions.map { FolioRegionCursor(region: $0) }
                    continue
                }

                if fittingCount == 0 {
                    if fragments.isEmpty,
                       composition.regionPattern == .continuous {
                        // The continuous fallback is deliberately taller than
                        // one line in production. If an extreme font metric
                        // still disagrees, advance one grapheme rather than
                        // entering a pagination loop; the outer paper clip is
                        // the final safety boundary.
                        fittingCount = 1
                    } else {
                    // This box has no honest baseline left. Exhaust it and let
                    // the same paragraph try the next compatible region on
                    // this leaf before creating another leaf.
                        cursors[regionIndex].usedHeight = cursors[regionIndex].region.frame.height
                        continue
                    }
                }

                let end = min(characters.count, consumed + fittingCount)
                let fragmentText = String(characters[consumed..<end])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let measuredHeight = measuredTextHeight(
                    fragmentText,
                    role: block.role,
                    font: font,
                    width: width,
                    composition: composition,
                    alignment: alignment
                )
                let placement = fragmentPlacement(
                    role: block.role,
                    displayWidth: displayWidth,
                    measuredHeight: measuredHeight,
                    cursor: cursors[regionIndex],
                    alignment: alignment
                )
                let lower = block.startOffset + consumed
                let upper = block.startOffset + end - 1
                fragments.append(FolioFragment(
                    id: "\(block.id)-\(lower)",
                    content: .text(fragmentText),
                    role: block.role,
                    textRange: lower...upper,
                    measuredHeight: measuredHeight,
                    pointSize: font.pointSize,
                    spacingAfter: spacingAfter,
                    alignment: alignment,
                    placement: placement
                ))
                cursors[regionIndex].consume(
                    height: measuredHeight + spacingAfter,
                    blockID: block.id
                )
                consumed = end
            }
        }

        finishLeaf()

        if leaves.isEmpty {
            let fallbackComposition = FolioLeafCompositor.plan(
                for: surface,
                documentID: documentID,
                leafIndex: 0,
                metrics: metrics
            )
            let fallbackRecipe = LeafDecorationLibrary.recipe(
                pageType: surface.type,
                metadata: surface.payload.metadata,
                documentID: documentID,
                leafIndex: 0
            )
            let fallbackRegions = FolioLeafRegionPlanner.regions(
                for: fallbackComposition,
                metrics: metrics
            )
            let fallback = FolioFragment(
                id: "fallback",
                content: .text(surface.prompt),
                role: .title,
                textRange: 0...0,
                measuredHeight: 44,
                pointSize: FolioInkRole.title.basePointSize,
                spacingAfter: 0,
                alignment: fallbackComposition.alignment(
                    for: .title,
                    text: surface.prompt,
                    blockID: "fallback"
                ),
                placement: fallbackRegions.first.map {
                    CGRect(
                        x: $0.frame.minX,
                        y: $0.frame.minY,
                        width: $0.frame.width,
                        height: min(44, $0.frame.height)
                    )
                } ?? CGRect(x: 24, y: 18, width: max(1, metrics.contentWidth), height: 44)
            )
            leaves = [FolioLeaf(
                id: "\(documentID)::0::0",
                documentID: documentID,
                pageSize: CGSize(width: metrics.pageWidth, height: metrics.pageHeight),
                surface: surface,
                fragments: [fallback],
                inkRegions: fallbackRegions,
                textRange: 0...0,
                documentLeafIndex: 0,
                documentLeafCount: 1,
                globalLeafIndex: 0,
                globalLeafCount: 1,
                ghostText: nil,
                composition: fallbackComposition,
                decorationRecipe: fallbackRecipe,
                inkUsedHeight: fallback.placement.maxY
            )]
        }

        leaves = rebalancedSparseLeaves(leaves, metrics: metrics)

        let isKeptReadback = surface.payload.metadata["keptPageID"]?.nonEmpty != nil
            || surface.payload.metadata["keptPage"] == "true"
        if !isKeptReadback {
            let kind: FolioInteractionLeafKind = surface.pagesRisingNeedsUserInitiatedGeneration
                ? .generationRequest
                : .response
            let desiredHeight = interactionHeight(for: surface, kind: kind)
            if let lastIndex = leaves.indices.last,
               let placement = interactionPlacement(
                    after: leaves[lastIndex].fragments,
                    composition: leaves[lastIndex].composition,
                    desiredHeight: desiredHeight,
                    metrics: metrics
               ) {
                leaves[lastIndex].interactionKind = kind
                leaves[lastIndex].interactionPlacement = placement
                leaves[lastIndex].inkUsedHeight = max(
                    leaves[lastIndex].inkUsedHeight,
                    placement.maxY
                )
            } else {
                let ordinal = leaves.count
                let interactionComposition = FolioLeafCompositor.plan(
                    for: surface,
                    documentID: documentID,
                    leafIndex: ordinal,
                    metrics: metrics
                )
                let interactionRecipe = LeafDecorationLibrary.recipe(
                    pageType: surface.type,
                    metadata: surface.payload.metadata,
                    documentID: documentID,
                    leafIndex: ordinal
                )
                let offset = (leaves.last?.textRange.upperBound ?? 0) + 1
                leaves.append(FolioLeaf(
                    id: "\(documentID)::interaction::\(ordinal)",
                    documentID: documentID,
                    pageSize: CGSize(width: metrics.pageWidth, height: metrics.pageHeight),
                    surface: surface,
                    fragments: [],
                    inkRegions: FolioLeafRegionPlanner.regions(
                        for: interactionComposition,
                        metrics: metrics
                    ),
                    textRange: offset...offset,
                    documentLeafIndex: ordinal,
                    documentLeafCount: 1,
                    globalLeafIndex: 0,
                    globalLeafCount: 1,
                    ghostText: nil,
                    composition: interactionComposition,
                    decorationRecipe: interactionRecipe,
                    inkUsedHeight: desiredHeight,
                    interactionKind: kind
                ))
            }
        }

        return leaves
    }

    private static func interactionHeight(
        for surface: SurfacePage,
        kind: FolioInteractionLeafKind
    ) -> CGFloat {
        switch kind {
        case .generationRequest:
            return 174
        case .response:
            let hasOptions = surface.type == .mood
                || surface.type == .affirmations
                || surface.type == .aboutYou
                || surface.payload.metadata["leafResponseOptions"]?.nonEmpty != nil
            return hasOptions ? 302 : 238
        }
    }

    private static func interactionPlacement(
        after fragments: [FolioFragment],
        composition: FolioLeafComposition,
        desiredHeight: CGFloat,
        metrics: FolioLayoutMetrics
    ) -> CGRect? {
        let contentHeight = composition.contentHeight(metrics: metrics)
        let inkBottom = fragments.map { $0.placement.maxY + $0.spacingAfter }.max()
            ?? composition.topInset
        let top = inkBottom + (fragments.isEmpty ? 0 : 14)
        let bottomBreath: CGFloat = 8
        guard top + desiredHeight + bottomBreath <= contentHeight else { return nil }
        return CGRect(
            x: FolioLeafMeasure.inkPadding
                + FolioLeafMeasure.typesettingSafetyInset
                + composition.leadingInset,
            y: top,
            width: composition.contentWidth(for: .body, metrics: metrics),
            height: desiredHeight
        )
    }

    private struct LayoutQuality {
        var sparseLeafCount = 0
        var orphanFragmentCount = 0
        var score: Int { sparseLeafCount * 45 + orphanFragmentCount * 30 }
    }

    /// Regional recipes sometimes leave a single continuation line on fresh
    /// paper even though the preceding continuous leaf has room. Try one
    /// bounded, deterministic reflow candidate and keep it only when its
    /// editorial score improves. This is deliberately not a render-time
    /// search: the winning document is cached with the rest of pagination.
    private static func rebalancedSparseLeaves(
        _ source: [FolioLeaf],
        metrics: FolioLayoutMetrics
    ) -> [FolioLeaf] {
        guard source.count > 1 else { return source }
        var candidate = source
        var index = 1
        while index < candidate.count {
            guard isAccidentallySparse(candidate[index]),
                  let merged = mergingSparseLeaf(
                    candidate[index],
                    into: candidate[index - 1],
                    metrics: metrics
                  ) else {
                index += 1
                continue
            }
            candidate[index - 1] = merged
            candidate.remove(at: index)
        }
        return quality(of: candidate).score < quality(of: source).score
            ? candidate
            : source
    }

    private static func isAccidentallySparse(_ leaf: FolioLeaf) -> Bool {
        guard !leaf.isDecorationPlate,
              leaf.interactionKind == nil,
              !leaf.fragments.isEmpty,
              leaf.fragments.allSatisfy({
                  if case .text = $0.content { return true }
                  return false
              }) else { return false }
        let inkHeight = leaf.fragments.reduce(CGFloat.zero) {
            $0 + $1.measuredHeight + $1.spacingAfter
        }
        let characterCount = leaf.fragments.compactMap(\.plainText).reduce(0) { $0 + $1.count }
        return inkHeight < 92 || characterCount < 150
    }

    private static func mergingSparseLeaf(
        _ sparse: FolioLeaf,
        into previous: FolioLeaf,
        metrics: FolioLayoutMetrics
    ) -> FolioLeaf? {
        guard previous.composition.regionPattern == .continuous,
              let region = previous.inkRegions.first else { return nil }
        var merged = previous
        var y = max(
            region.frame.minY,
            previous.fragments.map { $0.placement.maxY + $0.spacingAfter }.max()
                ?? region.frame.minY
        ) + 8
        var moved: [FolioFragment] = []

        for fragment in sparse.fragments {
            guard case .text(let text) = fragment.content else { return nil }
            let displayWidth = fragmentWidth(
                for: fragment.role,
                region: region,
                composition: previous.composition,
                metrics: metrics
            )
            let textWidth = fragment.role == .privacy
                ? max(1, displayWidth - 22)
                : displayWidth
            let font = fragment.role.uiFont(
                pointSize: fragment.pointSize,
                composition: previous.composition
            )
            let height = measuredTextHeight(
                text,
                role: fragment.role,
                font: font,
                width: textWidth,
                composition: previous.composition,
                alignment: fragment.alignment
            )
            guard y + height + fragment.spacingAfter <= region.frame.maxY else {
                return nil
            }
            let horizontalRoom = max(0, region.frame.width - displayWidth)
            let x: CGFloat
            switch fragment.alignment {
            case .centered: x = region.frame.minX + horizontalRoom / 2
            case .trailing: x = region.frame.maxX - displayWidth
            case .leading, .justified: x = region.frame.minX
            }
            var updated = fragment
            updated.measuredHeight = height
            updated.placement = CGRect(x: x, y: y, width: displayWidth, height: height)
            moved.append(updated)
            y += height + fragment.spacingAfter
        }

        merged.fragments.append(contentsOf: moved)
        let lower = min(previous.textRange.lowerBound, sparse.textRange.lowerBound)
        let upper = max(previous.textRange.upperBound, sparse.textRange.upperBound)
        merged.textRange = lower...upper
        merged.inkUsedHeight = max(previous.inkUsedHeight, y)
        return merged
    }

    private static func quality(of leaves: [FolioLeaf]) -> LayoutQuality {
        var quality = LayoutQuality()
        for leaf in leaves {
            if isAccidentallySparse(leaf) { quality.sparseLeafCount += 1 }
            for fragment in leaf.fragments {
                guard let text = fragment.plainText,
                      [.body, .deck].contains(fragment.role) else { continue }
                let font = fragment.role.uiFont(
                    pointSize: fragment.pointSize,
                    composition: leaf.composition
                )
                let width = fragment.role == .privacy
                    ? max(1, fragment.placement.width - 22)
                    : fragment.placement.width
                if measuredLineCount(
                    text,
                    role: fragment.role,
                    font: font,
                    width: width,
                    composition: leaf.composition,
                    alignment: fragment.alignment
                ) == 1,
                   text.count < 120 {
                    quality.orphanFragmentCount += 1
                }
            }
        }
        return quality
    }

    private static func draftBlocks(for surface: SurfacePage) -> [FolioDraftBlock] {
        var blocks: [FolioDraftBlock] = []
        var textCursor = 0
        var blockIndex = 0
        var seenParagraphs = Set<String>()

        func appendText(_ rawText: String, role: FolioInkRole, key: String) {
            let paragraphs = rawText
                .removingLegacyRenderedPlateReceipts()
                .replacingOccurrences(of: "\r\n", with: "\n")
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for paragraph in paragraphs {
                let fingerprint = normalized(paragraph)
                guard !fingerprint.isEmpty,
                      seenParagraphs.insert(fingerprint).inserted else { continue }
                let count = max(1, paragraph.count)
                blocks.append(FolioDraftBlock(
                    id: "\(key)-\(blockIndex)",
                    role: role,
                    text: paragraph,
                    media: nil,
                    startOffset: textCursor,
                    minimumFragmentLines: [.body, .deck].contains(role) ? 2 : 1
                ))
                textCursor += count + 1
                blockIndex += 1
            }
        }

        func appendMedia(_ media: FolioMedia) {
            blocks.append(FolioDraftBlock(
                id: "media-\(blockIndex)",
                role: .body,
                text: nil,
                media: media,
                startOffset: textCursor
            ))
            textCursor += 2
            blockIndex += 1
        }

        let prompt = surface.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = surface.payload.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = surface.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = surface.pagesRisingReadingBody
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isEnchantmentPreview = surface.type == .enchantment
            && surface.pagesRisingNeedsUserInitiatedGeneration
        let readingBody = droppingLeadingEditorialCopy(
            body,
            matching: isEnchantmentPreview
                ? [detail, prompt, headline]
                : [prompt, headline, detail]
        )

        appendText(prompt, role: .title, key: "title")
        if !isEnchantmentPreview,
           !headline.isEmpty,
           !equivalent(headline, prompt),
           !equivalent(headline, detail) {
            appendText(headline, role: .deck, key: "headline")
        }

        // An Enchantment title is already the incantation. Its old card deck
        // repeated the title and teaser before finally telling the reader what
        // to do. Put the actual spell instruction directly under the title.
        if !isEnchantmentPreview {
            appendText(detail, role: .deck, key: "detail")
        }

        if let margin = surface.payload.metadata["bookActedMargin"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !margin.isEmpty {
            let title = surface.payload.metadata["bookActedMarginTitle"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let heading = title.flatMap { $0.isEmpty ? nil : "\($0): " } ?? ""
            if surface.payload.metadata["bookInterjectionPhysicalAct"] == "underline",
               let excerpt = surface.payload.metadata["bookInterjectionTargetExcerpt"]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !excerpt.isEmpty {
                appendText("“\(excerpt)”", role: .underlined, key: "underlined-excerpt")
            }
            appendText("\(heading)\(margin)", role: .handwritten, key: "acted-margin")
        }

        let media = preferredMedia(for: surface)
        if revealsReadingBody(surface) || isEnchantmentPreview,
           !readingBody.isEmpty,
           !equivalent(readingBody, prompt),
           !equivalent(readingBody, detail) {
            let bodyParagraphs = readingBody
                .replacingOccurrences(of: "\r\n", with: "\n")
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            var mediaAfterParagraph: [Int: [FolioMedia]] = [:]
            for (mediaIndex, item) in media.enumerated() {
                let target = max(
                    0,
                    min(
                        max(0, bodyParagraphs.count - 1),
                        ((mediaIndex + 1) * max(1, bodyParagraphs.count)) / (media.count + 1) - 1
                    )
                )
                mediaAfterParagraph[target, default: []].append(item)
            }
            for (paragraphIndex, paragraph) in bodyParagraphs.enumerated() {
                appendText(paragraph, role: .body, key: "body-\(paragraphIndex)")
                for item in mediaAfterParagraph[paragraphIndex] ?? [] {
                    appendMedia(item)
                }
            }
        } else {
            for item in media { appendMedia(item) }
        }

        if surface.pagesRisingHasWrittenProse,
           (surface.type == .narrativeOS || surface.type == .academyClass) {
            let choicePrefixes = [
                "storyChoiceSliceOfLife",
                "storyChoiceProgressArc",
                "storyChoiceSurprise"
            ]
            let choices = choicePrefixes.compactMap { prefix -> String? in
                guard let title = surface.payload.metadata["\(prefix)Title"]?.nonEmpty else {
                    return nil
                }
                let prompt = surface.payload.metadata["\(prefix)Prompt"]?.nonEmpty
                return prompt.map { "\(title) — \($0)" } ?? title
            }
            if !choices.isEmpty {
                appendText("The paths scratching at the next leaf:", role: .handwritten, key: "story-paths")
                for (index, choice) in choices.enumerated() {
                    appendText(choice, role: .underlined, key: "story-choice-\(index)")
                }
            }
        }

        let reason = surface.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let alreadyPrintedReason = blocks.contains { block in
            guard let text = block.text else { return false }
            let printed = normalized(text)
            let target = normalized(reason)
            return printed == target
                || (!target.isEmpty && printed.contains(target))
        }
        if !reason.isEmpty, !alreadyPrintedReason {
            appendText(reason, role: .provenance, key: "reason")
        }

        if let privacy = surface.payload.metadata["privacy"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !privacy.isEmpty {
            appendText(privacy.capitalized, role: .privacy, key: "privacy")
        }

        return blocks
    }

    private static func droppingLeadingEditorialCopy(
        _ text: String,
        matching candidates: [String]
    ) -> String {
        var paragraphs = text
            .removingLegacyRenderedPlateReceipts()
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let fingerprints = Set(candidates.map(normalized).filter { !$0.isEmpty })
        while let first = paragraphs.first,
              fingerprints.contains(normalized(first)) {
            paragraphs.removeFirst()
        }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func largestFittingPrefix(
        characters: [Character],
        role: FolioInkRole,
        font: UIFont,
        width: CGFloat,
        height: CGFloat,
        composition: FolioLeafComposition,
        alignment: FolioParagraphAlignment
    ) -> Int {
        guard !characters.isEmpty, height > 0 else { return 0 }
        var low = 1
        var high = characters.count
        var best = 0

        while low <= high {
            let middle = (low + high) / 2
            let candidate = String(characters.prefix(middle))
            if measuredTextHeight(
                candidate,
                role: role,
                font: font,
                width: width,
                composition: composition,
                alignment: alignment
            ) <= height {
                best = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }

        guard best > 0, best < characters.count else { return best }
        if let breakIndex = characters[..<best].lastIndex(where: { $0.isWhitespace }),
           breakIndex > 0 {
            return breakIndex + 1
        }
        return best
    }

    /// A line stranded by itself is usually a pagination accident, not an
    /// editorial decision. Retreat to an earlier word boundary when a split
    /// would leave only one line on either side. Deliberately short complete
    /// blocks remain allowed.
    private static func balancedFittingPrefix(
        characters: [Character],
        initialCount: Int,
        role: FolioInkRole,
        font: UIFont,
        width: CGFloat,
        composition: FolioLeafComposition,
        alignment: FolioParagraphAlignment,
        minimumLines: Int
    ) -> Int {
        guard minimumLines > 1,
              initialCount > 0,
              initialCount < characters.count else { return initialCount }

        let fullText = String(characters)
        let fullLines = measuredLineCount(
            fullText,
            role: role,
            font: font,
            width: width,
            composition: composition,
            alignment: alignment
        )
        guard fullLines >= minimumLines * 2 else { return initialCount }

        var boundaries: [Int] = []
        var index = initialCount
        while index > 0 {
            index -= 1
            if characters[index].isWhitespace { boundaries.append(index + 1) }
        }
        for boundary in boundaries {
            let first = String(characters[..<boundary])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let remainder = String(characters[boundary...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !first.isEmpty, !remainder.isEmpty else { continue }
            let firstLines = measuredLineCount(
                first,
                role: role,
                font: font,
                width: width,
                composition: composition,
                alignment: alignment
            )
            let remainingLines = measuredLineCount(
                remainder,
                role: role,
                font: font,
                width: width,
                composition: composition,
                alignment: alignment
            )
            if firstLines >= minimumLines, remainingLines >= minimumLines {
                return boundary
            }
        }
        return initialCount
    }

    private static func titleFontFittingWholeBlock(
        _ text: String,
        baseFont: UIFont,
        width: CGFloat,
        height: CGFloat,
        composition: FolioLeafComposition,
        alignment: FolioParagraphAlignment
    ) -> UIFont {
        guard width > 0, height > 0 else { return baseFont }
        let minimumPointSize = max(20, baseFont.pointSize * 0.64)
        var pointSize = baseFont.pointSize

        while pointSize >= minimumPointSize {
            let candidate = UIFont(
                descriptor: baseFont.fontDescriptor,
                size: pointSize
            )
            if measuredTextHeight(
                text,
                role: .title,
                font: candidate,
                width: width,
                composition: composition,
                alignment: alignment
            ) <= height {
                return candidate
            }
            pointSize -= 1
        }

        return UIFont(
            descriptor: baseFont.fontDescriptor,
            size: minimumPointSize
        )
    }

    private static func measuredTextHeight(
        _ text: String,
        role: FolioInkRole,
        font: UIFont,
        width: CGFloat,
        composition: FolioLeafComposition,
        alignment: FolioParagraphAlignment
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = composition.lineSpacing(for: role)
        paragraph.alignment = alignment.nsTextAlignment
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph,
            .kern: composition.tracking(for: role)
        ])
        return ceil(attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height) + FolioLeafMeasure.textBoxVerticalSafetyInset
    }

    private static func measuredLineCount(
        _ text: String,
        role: FolioInkRole,
        font: UIFont,
        width: CGFloat,
        composition: FolioLeafComposition,
        alignment: FolioParagraphAlignment
    ) -> Int {
        let height = max(
            0,
            measuredTextHeight(
                text,
                role: role,
                font: font,
                width: width,
                composition: composition,
                alignment: alignment
            ) - FolioLeafMeasure.textBoxVerticalSafetyInset
        )
        let lineHeight = max(1, font.lineHeight + composition.lineSpacing(for: role))
        return max(1, Int(ceil(height / lineHeight)))
    }

    private static func mediaHeight(
        for composition: FolioLeafComposition,
        metrics: FolioLayoutMetrics
    ) -> CGFloat {
        let proportion: CGFloat
        switch composition.dialect {
        case .illuminatedPlate: proportion = 0.58
        case .archive, .weatherCabinet, .atlas: proportion = 0.46
        default: proportion = 0.42
        }
        return min(
            composition.dialect == .illuminatedPlate ? 230 : 196,
            composition.contentHeight(metrics: metrics) * min(0.78, proportion)
        )
    }

    private static func equivalent(_ lhs: String, _ rhs: String) -> Bool {
        normalized(lhs) == normalized(rhs)
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Only a local-writer request remains a preview. Quotes, missions, dares,
    /// notices, and the rest are already Pages: their body belongs on paper now,
    /// not behind a second generic Open action.
    private static func revealsReadingBody(_ surface: SurfacePage) -> Bool {
        !surface.pagesRisingNeedsUserInitiatedGeneration
    }

    private static func preferredMedia(for surface: SurfacePage) -> [FolioMedia] {
        let label = surface.payload.headline.isEmpty ? surface.prompt : surface.payload.headline
        var resolved: [FolioMedia] = []
        var seen = Set<String>()

        func append(_ media: FolioMedia, key: String) {
            guard seen.insert(key).inserted else { return }
            resolved.append(media)
        }

        let typedAssets = surface.mediaAssets.filter { !$0.isPagewrightPDF }
        let isCurrentIllumination = surface.type == .illuminatedPhoto
            || surface.type == .enchantment
        if isCurrentIllumination,
           let finished = typedAssets.first(where: { $0.kind == .renderedImageFile }) {
            append(
                .file(path: finished.reference, label: finished.caption.nonEmpty ?? label),
                key: "file:\(finished.reference)"
            )
            return resolved
        }

        if isCurrentIllumination,
           let sourceAssetName = surface.payload.metadata["sourceAssetName"]?.nonEmpty {
            let fallback = FakePhotoIlluminationAnalyzer.analyze(assetName: sourceAssetName)
            let analysis = PhotoAnalysis.fromSurfaceMetadata(
                surface.payload.metadata,
                fallback: fallback
            )
            let draft = IlluminatedPageComposer.compose(
                analysis: analysis,
                sourceAssetName: sourceAssetName,
                seed: abs(surface.id.stableHash),
                assetLocalIdentifier: surface.payload.metadata["assetLocalIdentifier"]
            )
            append(
                .illuminated(draft: draft, label: label),
                key: "illuminated:\(sourceAssetName)"
            )
            return resolved
        }

        for asset in typedAssets {
            let mediaLabel = asset.caption.nonEmpty ?? label
            switch asset.kind {
            case .bundledImage:
                append(
                    .asset(name: asset.reference, label: mediaLabel),
                    key: "asset:\(asset.reference)"
                )
            case .renderedImageFile:
                append(
                    .file(path: asset.reference, label: mediaLabel),
                    key: "file:\(asset.reference)"
                )
            case .photoLibraryAsset:
                append(
                    .photoLibrary(identifier: asset.reference, label: mediaLabel),
                    key: "photo:\(asset.reference)"
                )
            case .audioFile:
                break
            }
        }

        // Older/generated surfaces may predate SurfacePage's media projection.
        // Keep these fallbacks at the edge and deduplicate them against the
        // typed assets above.
        if let assetName = surface.payload.metadata["assetName"]?.nonEmpty {
            append(.asset(name: assetName, label: label), key: "asset:\(assetName)")
        }
        for key in ["renderedPreviewPath", "proofImagePath"] {
            if let path = surface.payload.metadata[key]?.nonEmpty {
                append(.file(path: path, label: label), key: "file:\(path)")
            }
        }
        return resolved
    }

    private static func ghostExcerpt(from text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        return words.prefix(12).joined(separator: " ")
    }
}

// MARK: - Leaf rendering

private struct FolioLeafPage: View {
    let leaf: FolioLeaf
    @ObservedObject var interactionStore: FolioInteractionStore
    let canGoBackward: Bool
    let canGoForward: Bool
    let isBusy: Bool
    let isRetiring: Bool
    let animatesArrival: Bool
    let isSelected: Bool
    let glowScore: Int
    let showsGlow: Bool
    let onOpenGlow: () -> Void
    let onOpen: () -> Void
    let onKeep: (String) -> Void
    let onDismiss: () -> Void
    let onNavigate: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var hasArrived = false

    private var visualStyle: PageVisualStyle {
        if leaf.surface.type == .festival {
            return PageVisualStyle.festivalStyle(
                accent: leaf.surface.payload.metadata["accent"] ?? ""
            )
        }
        return PageVisualStyle.style(for: leaf.surface.type)
    }

    private var surfaceLabel: String {
        leaf.surface.payload.metadata["surfaceLabel"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? leaf.surface.type.shortTitle
    }

    private var symbolName: String {
        leaf.surface.payload.metadata["symbol"] ?? leaf.surface.type.symbolName
    }

    private var isGenerationPreview: Bool {
        leaf.surface.pagesRisingNeedsUserInitiatedGeneration
    }

    private var isAlreadyKept: Bool {
        leaf.surface.payload.metadata["keptPageID"]?.nonEmpty != nil
    }

    private var bookInterjectionPhysicalAct: String? {
        leaf.surface.payload.metadata["bookInterjectionPhysicalAct"]
    }

    private var isShadowWonderVariant: Bool {
        leaf.surface.payload.metadata["variant"] == "shadow-wonder"
    }

    private var arrivalIsVisible: Bool {
        reduceMotion || !animatesArrival || hasArrived
    }

    private var responseDraft: FolioResponseDraft {
        interactionStore.draft(for: leaf.documentID)
    }

    private var preparedResponse: String {
        let note = responseDraft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard leaf.surface.type == .mood,
              let weather = responseDraft.selectedOption?.nonEmpty else {
            return note
        }
        return note.isEmpty ? weather : "\(weather): \(note)"
    }

    private var requiresReaderResponse: Bool {
        guard leaf.interactionKind == .response else { return false }
        return leaf.surface.origin == .userAuthored
            || leaf.surface.isReaderFacingAsk
            || leaf.surface.pageCapabilities.asksReader
    }

    var body: some View {
        let decorationRecipe = leaf.decorationRecipe
        let wornLeafShape = FolioWornLeafShape(seed: decorationRecipe.seed)

        return ZStack {
            if let texture = decorationRecipe.textureOverlay {
                Image(texture.assetName)
                    .resizable()
                    .scaledToFill()
                    .opacity(min(0.10, texture.defaultOpacity * 0.48))
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            FolioLeafPatina(
                recipe: decorationRecipe,
                composition: leaf.composition,
                inkUsedHeight: leaf.inkUsedHeight,
                tint: visualStyle.accent
            )

            VStack(spacing: 0) {
                leafHeader
                inkField
                leafFooter
            }
            // A UIKit label is allowed to report an ideal width larger than
            // its proposal. Without a fixed paper field, one long first-leaf
            // title can therefore widen this entire VStack behind the curl
            // and leave only its middle visible. The physical leaf, not any
            // child, owns the coordinate space.
            .frame(
                width: FolioLeafMeasure.paperFieldWidth(pageWidth: leaf.pageSize.width),
                height: FolioLeafMeasure.paperFieldHeight(pageHeight: leaf.pageSize.height),
                alignment: .top
            )
            .padding(.horizontal, FolioLeafMeasure.paperPadding)
            .padding(.vertical, FolioLeafMeasure.paperVerticalPadding)

            if isRetiring {
                retirementVeil
            }
        }
        // UIPageViewController's transition view is wider than the leaf while
        // curling. Stay the size semantic pagination used; hidden transition
        // paper must never become readable or tappable paper.
        .frame(width: leaf.pageSize.width, height: leaf.pageSize.height)
        .parchmentSurface(style: visualStyle, isActive: true)
        .clipShape(wornLeafShape)
        .overlay(alignment: .leading) {
            FolioOpenLeafBinding(tint: visualStyle.accent)
                .frame(width: 31)
                .padding(.vertical, 8)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay {
            FolioLeafMarginaliaMarks(
                leaf: leaf,
                accent: visualStyle.accent,
                handwrittenNote: leaf.decorativeMarginNote
            )
        }
        .overlay(alignment: .topTrailing) {
            if bookInterjectionPhysicalAct == "dog-ear" {
                BookInterjectionDogEarMark(tint: visualStyle.accent)
                    .frame(width: 52, height: 52)
                    .allowsHitTesting(false)
                    .accessibilityLabel("The Book dog-eared this Page")
            }
        }
        .overlay(alignment: .trailing) {
            if bookInterjectionPhysicalAct == "smudge" {
                BookInterjectionSmudgeMark(tint: visualStyle.accent)
                    .frame(width: 58, height: 86)
                    .offset(x: 8, y: 20)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // The tail-outer corner, where a printed leaf carries its number.
            Text("\(leaf.documentLeafIndex + 1)/\(leaf.documentLeafCount)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.42))
                .padding(.trailing, 16)
                .padding(.bottom, 9)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomTrailing) {
            if bookInterjectionPhysicalAct == "left-open" {
                BookInterjectionOpenLeafMark(tint: visualStyle.accent)
                    .frame(width: 72, height: 42)
                    .offset(x: 7, y: 12)
                    .allowsHitTesting(false)
                    .accessibilityLabel("The Book left an older Page open here")
            }
        }
        .clipShape(wornLeafShape)
        .overlay {
            wornLeafShape
                .stroke(
                    isSelected ? BookPalette.lampGold.opacity(0.88) : visualStyle.accent.opacity(0.26),
                    lineWidth: isSelected ? 2 : 1
                )
                .padding(2)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.26), radius: 10, x: 1, y: 7)
        .opacity(isRetiring ? 1 : (arrivalIsVisible ? 1 : 0))
        .offset(y: reduceMotion || arrivalIsVisible ? 0 : 18)
        .scaleEffect(reduceMotion || arrivalIsVisible ? 1 : 0.985, anchor: .bottom)
        .allowsHitTesting(!isRetiring)
        .contextMenu {
            if leaf.isLastDocumentLeaf {
                if isGenerationPreview {
                    Button(action: onOpen) {
                        Label("Let Me Write", systemImage: "pencil.and.scribble")
                    }
                } else if !isAlreadyKept {
                    Button { onKeep(preparedResponse) } label: {
                        Label("Keep", systemImage: "bookmark.fill")
                    }
                }
                Button(action: onDismiss) {
                    Label("Let It Go", systemImage: "wind")
                }
            }
        }
        .accessibilityValue(
            "\(surfaceLabel), leaf \(leaf.documentLeafIndex + 1) of \(leaf.documentLeafCount); folio leaf \(leaf.globalLeafIndex + 1) of \(leaf.globalLeafCount)"
        )
        .accessibilityHint(reduceMotion ? "Use the previous and next leaf buttons." : "Curl an edge, or use the previous and next leaf buttons.")
        .accessibilityAction(named: Text("Previous leaf")) {
            if canGoBackward { onNavigate(-1) }
        }
        .accessibilityAction(named: Text("Next leaf")) {
            if canGoForward { onNavigate(1) }
        }
        .onAppear(perform: synchronizeArrival)
        .onChange(of: animatesArrival) { _, _ in synchronizeArrival() }
        .onChange(of: reduceMotion) { _, _ in synchronizeArrival() }
    }

    private var leafHeader: some View {
        ZStack(alignment: .trailing) {
            FolioComposedLeafHeader(
                label: surfaceLabel,
                symbolName: symbolName,
                composition: leaf.composition,
                accent: visualStyle.accent,
                leafNumber: leaf.documentLeafIndex + 1
            )

            // The flags ride at the trailing edge beside the illumination. They
            // used to sit at the leading edge, where they were drawn on top of
            // the composed header's own label — `specimenLabel` and `letterhead`
            // both start their title there, so "NEW PAGE" landed across it.
            // Only the trailing side is reserved across every title device.
            HStack(spacing: 5) {
                Spacer(minLength: 0)

                if leaf.isFirstDocumentLeaf,
                   animatesArrival || leaf.globalLeafIndex > 0 {
                    Text(animatesArrival ? "NEW" : "NEW PAGE")
                        .font(.system(size: 7.5, weight: .black))
                        .tracking(0.7)
                        .foregroundStyle(visualStyle.accent)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 5)
                        .background(BookPalette.page.opacity(0.72), in: Capsule())
                        .overlay { Capsule().stroke(visualStyle.accent.opacity(0.28), lineWidth: 1) }
                }

                if isShadowWonderVariant {
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(BookPalette.violet)
                        .accessibilityLabel("Shadow Wonder variant")
                }

                if showsGlow {
                    FolioGlowIllumination(score: glowScore, action: onOpenGlow)
                        .frame(width: 32, height: 32)
                        .padding(.trailing, bookInterjectionPhysicalAct == "dog-ear" ? 42 : 0)
                }
            }
        }
        .frame(height: leaf.composition.headerHeight)
        .padding(.bottom, 7)
    }

    @ViewBuilder
    private var inkField: some View {
        if let kind = leaf.interactionKind,
           let placement = leaf.interactionPlacement {
            GeometryReader { _ in
                ZStack(alignment: .topLeading) {
                    printedInkField
                    interactionPanel(kind, compact: true)
                        .frame(width: placement.width, height: placement.height)
                        .background(
                            BookPalette.page.opacity(0.30),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(visualStyle.accent.opacity(0.20), lineWidth: 1)
                        }
                        .position(x: placement.midX, y: placement.midY)
                }
            }
        } else if let kind = leaf.interactionKind {
            interactionPanel(kind, compact: false)
        } else {
            printedInkField
        }
    }

    @ViewBuilder
    private func interactionPanel(
        _ kind: FolioInteractionLeafKind,
        compact: Bool
    ) -> some View {
        switch kind {
        case .response:
            FolioResponseLeafPanel(
                surface: leaf.surface,
                accent: visualStyle.accent,
                draft: interactionStore.binding(for: leaf.documentID),
                compact: compact
            )
        case .generationRequest:
            FolioGenerationRequestLeaf(
                surface: leaf.surface,
                accent: visualStyle.accent,
                isBusy: isBusy,
                compact: compact
            )
        }
    }

    private var printedInkField: some View {
        GeometryReader { fieldProxy in
            // UIPageViewController may offer its hosted SwiftUI tree the full
            // transition canvas even though only the narrower paper rectangle
            // is visible. `maxWidth: .infinity` then typesets against invisible
            // paper and the curl clips both ends of every line. Resolve the ink
            // measure from the leaf we can actually see and give the stack that
            // exact width. This is the safety contract for every Page type.
            // Never use `fieldProxy.size.width` for typesetting. During a curl
            // UIPageViewController can briefly propose its wider transition
            // canvas here, especially to the first controller in a document.
            // Pagination already stored the real paper size on the leaf.
            let paperFieldWidth = FolioLeafMeasure.paperFieldWidth(
                pageWidth: leaf.pageSize.width
            )
            ZStack(alignment: .topLeading) {
                FolioDynamicRuling(
                    style: leaf.composition.rulingStyle,
                    tint: visualStyle.accent,
                    seed: leaf.composition.seed
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                if let ghostText = leaf.ghostText {
                    Text(ghostText)
                        .font(.system(size: 20, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(leaf.composition.ghostOpacity))
                        .lineSpacing(7)
                        .frame(width: max(1, paperFieldWidth - 48), alignment: .leading)
                        .scaleEffect(x: -1, y: 1)
                        .rotationEffect(.degrees(2))
                        .offset(x: 24, y: 52)
                        .blur(radius: 0.35)
                        .clipped()
                        .accessibilityHidden(true)
                }

                LinearGradient(
                    colors: [
                        visualStyle.accent.opacity(0.00),
                        visualStyle.accent.opacity(0.025),
                        BookPalette.ink.opacity(0.045)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                FolioRegionFurniture(
                    regions: leaf.inkRegions,
                    pattern: leaf.composition.regionPattern,
                    tint: visualStyle.accent,
                    seed: leaf.composition.seed
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                ForEach(leaf.fragments) { fragment in
                    fragmentView(fragment, width: fragment.placement.width)
                        .frame(
                            width: fragment.placement.width,
                            height: fragment.placement.height,
                            alignment: fragment.alignment.frameAlignment
                        )
                        .position(
                            x: fragment.placement.midX,
                            y: fragment.placement.midY
                        )
                }
            }
            .frame(width: paperFieldWidth, height: fieldProxy.size.height, alignment: .topLeading)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                FolioInkBleed(tint: visualStyle.accent, seed: leaf.id)
                    .frame(height: 20)
                    .padding(.horizontal, 28)
                    .opacity(leaf.composition.inkBleedOpacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func fragmentView(_ fragment: FolioFragment, width: CGFloat) -> some View {
        switch fragment.content {
        case .text(let text):
            if fragment.role == .title {
                FolioComposedTitleText(
                    text: text,
                    pointSize: fragment.pointSize,
                    composition: leaf.composition,
                    accent: visualStyle.accent,
                    width: width,
                    measuredHeight: fragment.measuredHeight,
                    alignment: fragment.alignment
                )
                .accessibilityLabel(text)
            } else if fragment.role == .privacy {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: max(10, fragment.pointSize * 0.84), weight: .semibold))
                        .foregroundStyle(color(for: fragment.role))
                    FolioWrappedText(
                        text: text,
                        role: fragment.role,
                        pointSize: fragment.pointSize,
                        composition: leaf.composition,
                        color: color(for: fragment.role),
                        width: max(1, width - 22),
                        measuredHeight: fragment.measuredHeight,
                        alignment: .leading
                    )
                    .frame(
                        width: max(1, width - 22),
                        height: fragment.measuredHeight,
                        alignment: .leading
                    )
                }
                    .frame(width: width, alignment: .leading)
                    .accessibilityLabel(accessibilityLabel(for: text, role: fragment.role))
            } else {
                FolioWrappedText(
                    text: text,
                    role: fragment.role,
                    pointSize: fragment.pointSize,
                    composition: leaf.composition,
                    color: color(for: fragment.role),
                    width: width,
                    measuredHeight: fragment.measuredHeight,
                    alignment: fragment.alignment,
                    accent: visualStyle.accent,
                    // Only the fragment that opens the block may spend the
                    // accent, so a Page split across several fragments cannot
                    // colour a word in each of them.
                    isOpeningFragment: fragment.textRange.lowerBound == 0
                )
                    .frame(
                        width: width,
                        height: fragment.measuredHeight,
                        alignment: fragment.alignment.frameAlignment
                    )
                    .accessibilityLabel(accessibilityLabel(for: text, role: fragment.role))
            }
        case .image(let media):
            FolioMediaView(media: media, accent: visualStyle.accent)
                .frame(width: width)
                .frame(height: fragment.measuredHeight)
        }
    }

    private func color(for role: FolioInkRole) -> Color {
        switch role {
        case .title:
            return leaf.composition.titleUsesAccent ? visualStyle.accent : BookPalette.ink
        case .deck: return BookPalette.ink.opacity(0.84)
        case .body: return BookPalette.ink.opacity(0.94)
        case .handwritten, .underlined: return visualStyle.accent.opacity(0.92)
        case .provenance: return BookPalette.ink.opacity(0.68)
        case .privacy: return visualStyle.accent
        }
    }

    private func accessibilityLabel(for text: String, role: FolioInkRole) -> String {
        switch role {
        case .handwritten: return "Written in the margin: \(text)"
        case .underlined: return "The Book underlined: \(text)"
        case .privacy: return "Privacy: \(text)"
        default: return text
        }
    }

    private var leafFooter: some View {
        VStack(spacing: 8) {
            if leaf.isLastDocumentLeaf {
                finalLeafActions
            }
            navigationStrip
        }
        .foregroundStyle(visualStyle.accent)
        .frame(
            height: sizeCategory.isFolioAccessibilityCategory ? 128 : 104,
            alignment: .bottom
        )
        .padding(.top, 7)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(visualStyle.accent.opacity(0.22))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var finalLeafActions: some View {
        HStack(spacing: 9) {
            if isGenerationPreview {
                Button(action: onOpen) {
                    Label(
                        isBusy ? "I'm writing…" : "Let me write",
                        systemImage: isBusy ? "circle.dotted" : "pencil.and.scribble"
                    )
                    .symbolEffect(
                        .pulse,
                        options: .speed(0.58),
                        isActive: isBusy && !reduceMotion
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.black))
                .foregroundStyle(BookPalette.page)
                .background(visualStyle.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(isBusy)
            } else {
                Button { onKeep(preparedResponse) } label: {
                    Label(isAlreadyKept ? "Kept" : "Keep", systemImage: "bookmark.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.black))
                .foregroundStyle(BookPalette.page)
                .background(visualStyle.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(isAlreadyKept || isBusy || (requiresReaderResponse && preparedResponse.isEmpty))
                .opacity(
                    isAlreadyKept || (requiresReaderResponse && preparedResponse.isEmpty)
                        ? 0.48
                        : 1
                )
            }

            Button(action: onDismiss) {
                Text("Let it go")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.bold))
            .foregroundStyle(visualStyle.accent)
            .background(
                BookPalette.page.opacity(0.34),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(visualStyle.accent.opacity(0.48), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var navigationStrip: some View {
        HStack(spacing: 9) {
            Spacer(minLength: 0)

            Button { onNavigate(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 25, height: 25)
            }
            .buttonStyle(.bookPress())
            .disabled(!canGoBackward)
            .opacity(canGoBackward ? 1 : 0.24)
            .accessibilityLabel("Previous leaf")

            Text("\(leaf.globalLeafIndex + 1) of \(leaf.globalLeafCount)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.54))
                .frame(minWidth: 42)

            Button { onNavigate(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 25, height: 25)
            }
            .buttonStyle(.bookPress())
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.24)
            .accessibilityLabel("Next leaf")

            Spacer(minLength: 0)
        }
        .frame(height: 34)
    }

    private var retirementVeil: some View {
        ZStack {
            Rectangle()
                .fill(BookPalette.paper.opacity(0.90))
                .blendMode(.normal)
            VStack(spacing: 9) {
                Image(systemName: "bookmark.fill")
                    .font(.title2)
                Text("Tucking this Page away…")
                    .font(.system(.callout, design: .serif, weight: .semibold))
            }
            .foregroundStyle(visualStyle.accent)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    private func synchronizeArrival() {
        guard animatesArrival, !reduceMotion else {
            hasArrived = true
            return
        }
        hasArrived = false
        DispatchQueue.main.async {
            withAnimation(BookMotion.deal(reduceMotion: false)) {
                hasArrived = true
            }
        }
    }
}

private struct FolioComposedLeafHeader: View {
    let label: String
    let symbolName: String
    let composition: FolioLeafComposition
    let accent: Color
    let leafNumber: Int

    var body: some View {
        Group {
            switch composition.titleDevice {
            case .heraldic:
                VStack(spacing: 3) {
                    ZStack {
                        FolioHeaderRays(seed: composition.seed, tint: accent)
                            .frame(width: 48, height: 23)
                        Image(systemName: symbolName)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack(spacing: 7) {
                        rule
                        Image(systemName: "sparkle")
                            .font(.system(size: 7, weight: .bold))
                        headerLabel
                        Image(systemName: "sparkle")
                            .font(.system(size: 7, weight: .bold))
                        rule
                    }
                }
            case .specimenLabel:
                HStack(spacing: 7) {
                    Image(systemName: symbolName)
                        .font(.system(size: 11, weight: .bold))
                    headerLabel
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accent.opacity(0.075), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(accent.opacity(0.36), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
                }
                .frame(maxWidth: .infinity, alignment: composition.textFlow == .offset ? .leading : .center)
                .padding(.horizontal, 24)
            case .letterhead:
                VStack(spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        headerLabel
                        Spacer(minLength: 8)
                        Image(systemName: symbolName)
                            .font(.system(size: 13, weight: .regular))
                            .padding(5)
                            .overlay(Circle().stroke(accent.opacity(0.38), lineWidth: 0.8))
                    }
                    HStack(spacing: 3) {
                        Rectangle().frame(height: 1)
                        Rectangle().frame(width: 18, height: 2)
                    }
                    .opacity(0.30)
                }
            case .cabinetPlate:
                HStack(spacing: 8) {
                    Image(systemName: symbolName)
                        .font(.system(size: 11, weight: .semibold))
                    headerLabel
                    Text(String(format: "%02d", leafNumber))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .opacity(0.56)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(accent.opacity(0.42), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(accent.opacity(0.14), lineWidth: 1)
                        .padding(3)
                }
            case .constellation:
                ZStack {
                    FolioHeaderConstellation(seed: composition.seed, tint: accent)
                    HStack(spacing: 8) {
                        Image(systemName: symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(6)
                            .background(BookPalette.page.opacity(0.58), in: Circle())
                        headerLabel
                    }
                }
            case .illuminatedInitial:
                HStack(spacing: 9) {
                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(accent.opacity(0.10), in: Circle())
                        .overlay(Circle().stroke(accent.opacity(0.34), lineWidth: 1))
                    headerLabel
                    rule
                }
            case .quietRule:
                HStack(spacing: 9) {
                    rule
                    headerLabel
                    rule
                }
            case .chapterMark:
                VStack(spacing: 3) {
                    headerLabel
                    HStack(spacing: 5) {
                        Rectangle().frame(width: 44, height: 0.7)
                        Image(systemName: symbolName)
                            .font(.system(size: 8, weight: .semibold))
                        Rectangle().frame(width: 44, height: 0.7)
                    }
                    .opacity(0.36)
                }
            case .continuation:
                HStack(spacing: 7) {
                    Image(systemName: symbolName)
                        .font(.system(size: 9, weight: .semibold))
                    Text(label.uppercased())
                        .lineLimit(1)
                    // The tail-outer folio number already carries this leaf's
                    // position, and carries it as "3/3" — both halves. Printing
                    // "LEAF 3" here as well gave one leaf three position labels
                    // in three corners. This device's real news is that the Page
                    // is still going, so say that instead.
                    Text("• CONTINUED")
                        .opacity(0.58)
                    rule
                }
                .font(.system(size: 8.5, weight: .bold, design: .serif))
                .tracking(0.8)
            }
        }
        .foregroundStyle(accent.opacity(0.90))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), leaf \(leafNumber)")
    }

    private var headerLabel: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .black, design: composition.typeface == .archival ? .monospaced : .serif))
            .tracking(composition.typeface == .archival ? 1.2 : 1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
    }

    private var rule: some View {
        Rectangle()
            .fill(accent.opacity(0.34))
            .frame(maxWidth: .infinity)
            .frame(height: 0.8)
    }
}

private struct FolioHeaderRays: View {
    let seed: Int
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.72)
            for index in 0..<7 {
                let angle = CGFloat(-0.86 + Double(index) * 0.286) + (unit(index) - 0.5) * 0.04
                let inner: CGFloat = 10
                let outer: CGFloat = 17 + unit(index + 20) * 4
                var ray = Path()
                let cosine = CGFloat(cos(Double(angle)))
                let sine = CGFloat(sin(Double(angle)))
                ray.move(to: CGPoint(x: center.x + cosine * inner, y: center.y + sine * inner))
                ray.addLine(to: CGPoint(x: center.x + cosine * outer, y: center.y + sine * outer))
                context.stroke(ray, with: .color(tint.opacity(0.62)), lineWidth: 0.8)
            }
        }
        .accessibilityHidden(true)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 2_977).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

private struct FolioHeaderConstellation: View {
    let seed: Int
    let tint: Color

    var body: some View {
        Canvas { context, size in
            var points: [CGPoint] = []
            for index in 0..<6 {
                points.append(CGPoint(
                    x: 12 + unit(index) * max(1, size.width - 24),
                    y: 5 + unit(index + 20) * max(1, size.height - 10)
                ))
            }
            var thread = Path()
            if let first = points.first { thread.move(to: first) }
            points.dropFirst().forEach { thread.addLine(to: $0) }
            context.stroke(thread, with: .color(tint.opacity(0.12)), lineWidth: 0.7)
            for (index, point) in points.enumerated() {
                let radius: CGFloat = index.isMultiple(of: 3) ? 1.6 : 1
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(tint.opacity(0.40))
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 3_571).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

private struct FolioComposedTitleText: View {
    let text: String
    let pointSize: CGFloat
    let composition: FolioLeafComposition
    let accent: Color
    let width: CGFloat
    let measuredHeight: CGFloat
    let alignment: FolioParagraphAlignment

    var body: some View {
        FolioWrappedText(
            text: text,
            role: .title,
            pointSize: pointSize,
            composition: composition,
            color: composition.titleUsesAccent ? accent : BookPalette.ink,
            width: width,
            measuredHeight: measuredHeight,
            alignment: alignment
        )
            .frame(
                width: width,
                height: measuredHeight,
                alignment: alignment.frameAlignment
            )
            .overlay(alignment: composition.titleDevice == .letterhead ? .bottomLeading : .bottom) {
                if composition.titleDevice == .letterhead {
                    Rectangle()
                        .fill(accent.opacity(0.30))
                        .frame(width: 86, height: 0.8)
                        .offset(y: 5)
                }
            }
    }
}

/// UILabel's default horizontal compression resistance lets a long literary
/// line keep its single-line intrinsic width even when SwiftUI proposes the
/// narrower paper measure. This subclass makes the folio width intrinsic: the
/// label may grow downward, never sideways behind the fore-edge.
private final class FolioWrappingLabel: UILabel {
    var folioWidth: CGFloat = 1 {
        didSet {
            guard abs(folioWidth - oldValue) > 0.25 else { return }
            preferredMaxLayoutWidth = folioWidth
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        measuredSize()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        measuredSize()
    }

    private func measuredSize() -> CGSize {
        let width = max(1, folioWidth)
        let measured = super.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: ceil(measured.height))
    }
}

/// A paper-sized TextKit line box. `UIPageViewController` briefly makes its
/// transition canvas wider than the visible Book; SwiftUI Text can preserve
/// that ideal width and then be clipped when the curl settles. UILabel wraps
/// directly inside the stored folio measure, which is also what semantic
/// pagination used, so a glyph cannot fall behind either edge.
private struct FolioWrappedText: UIViewRepresentable {
    let text: String
    let role: FolioInkRole
    let pointSize: CGFloat
    let composition: FolioLeafComposition
    let color: Color
    let width: CGFloat
    let measuredHeight: CGFloat
    let alignment: FolioParagraphAlignment
    var accent: Color = BookPalette.lampGold
    var isOpeningFragment: Bool = false

    /// The word that gets the accent ink, or nil when this block should stay in
    /// one colour.
    ///
    /// The landing word of the opening sentence, because that is the one the
    /// sentence was built to arrive at — "something ordinary pretending to be
    /// *treasure*". Deterministic, so a leaf does not recolour itself between
    /// draws, and deliberately fussy about what it will accent: an article or a
    /// preposition in colour reads as a rendering fault rather than emphasis.
    private var accentRange: NSRange? {
        guard isOpeningFragment,
              role == .body,
              composition.accentsOpeningPhrase else { return nil }

        // The first sentence only. A short Page is usually one or two.
        let terminators = CharacterSet(charactersIn: ".!?")
        let firstSentenceEnd = text.rangeOfCharacter(from: terminators)
        let sentence = firstSentenceEnd.map { String(text[text.startIndex..<$0.lowerBound]) } ?? text

        let words = sentence
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        guard let landing = words.last(where: { word in
            word.count >= 5
                && word.allSatisfy(\.isLetter)
                && !Self.tooOrdinaryToAccent.contains(word.lowercased())
        }) else { return nil }

        // Match the last occurrence inside the first sentence, so a word that
        // also appears early is coloured where it lands, not where it started.
        guard let found = sentence.range(of: landing, options: .backwards) else { return nil }
        return NSRange(found, in: text)
    }

    /// Words that carry no weight even when they end a sentence.
    private static let tooOrdinaryToAccent: Set<String> = [
        "there", "these", "those", "their", "about", "which", "would", "could",
        "should", "again", "still", "where", "while", "after", "before", "being",
        "other", "another", "anything", "something", "everything", "nothing"
    ]

    func makeUIView(context: Context) -> FolioWrappingLabel {
        let label = FolioWrappingLabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = .clear
        label.adjustsFontForContentSizeCategory = false
        label.isAccessibilityElement = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: FolioWrappingLabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = composition.lineSpacing(for: role)
        paragraph.alignment = alignment.nsTextAlignment
        paragraph.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: role.uiFont(pointSize: pointSize, composition: composition),
            .foregroundColor: UIColor(color),
            .paragraphStyle: paragraph,
            .kern: composition.tracking(for: role)
        ]
        if role == .underlined {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.underlineColor] = UIColor(color)
        }

        label.folioWidth = width
        label.preferredMaxLayoutWidth = width

        let inked = NSMutableAttributedString(string: text, attributes: attributes)
        if let accentRange, accentRange.location != NSNotFound,
           accentRange.location + accentRange.length <= inked.length {
            inked.addAttribute(.foregroundColor, value: UIColor(accent), range: accentRange)
        }
        label.attributedText = inked
        label.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: FolioWrappingLabel,
        context: Context
    ) -> CGSize? {
        CGSize(width: width, height: max(1, measuredHeight))
    }
}

/// The last leaf of an ordinary Page is writable paper. It reuses the same
/// sentence craft control as the old sheet, but lives inside the fixed Book
/// rectangle and scrolls only when the reader opens the deeper word tools.
private struct FolioResponseLeafPanel: View {
    let surface: SurfacePage
    let accent: Color
    @Binding var draft: FolioResponseDraft
    var compact = false

    private static let innerWeatherOptions = [
        "Fog", "Rain", "Static", "Heavy", "Bright",
        "Restless", "Soft", "Numb", "Stormy", "Clearing"
    ]

    private var ask: (label: String, placeholder: String) {
        surface.type.marginAsk
    }

    private var placeholder: String {
        surface.payload.metadata["placeholder"]?.nonEmpty ?? ask.placeholder
    }

    private var presetOptions: [String] {
        switch surface.type {
        case .mood:
            return Self.innerWeatherOptions
        case .affirmations:
            return split(surface.payload.metadata["countersigns"])
        case .aboutYou:
            return split(surface.payload.metadata["exampleLines"])
        default:
            return split(surface.payload.metadata["leafResponseOptions"])
        }
    }

    private var presetTitle: String {
        switch surface.type {
        case .mood: return "NAME THE WEATHER"
        case .affirmations: return "OR BORROW A COUNTERSIGN"
        case .aboutYou:
            return surface.payload.metadata["choicePrompt"]?.nonEmpty
                ?? "OR TRY ONE ON"
        default: return "OR BORROW ONE OF MINE"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 9 : 13) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("I LEFT ROOM.")
                        .font(.system(size: 10, weight: .black, design: .serif))
                        .tracking(1.4)
                        .foregroundStyle(accent)
                    Text("One sentence is enough. Yours is better than a tidy one.")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                LivingTextEditor(
                    title: ask.label,
                    placeholder: placeholder,
                    text: $draft.text,
                    minHeight: compact ? 84 : 112
                )

                if !presetOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(presetTitle)
                            .font(.system(size: 9, weight: .black, design: .serif))
                            .tracking(1.0)
                            .foregroundStyle(accent.opacity(0.82))

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 76), spacing: 7)],
                            alignment: .leading,
                            spacing: 7
                        ) {
                            ForEach(presetOptions, id: \.self) { option in
                                presetButton(option)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.top, compact ? 6 : 8)
            .padding(.bottom, compact ? 10 : 18)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(accent.opacity(0.018))
        .accessibilityElement(children: .contain)
    }

    private func presetButton(_ option: String) -> some View {
        let isSelected = surface.type == .mood
            ? draft.selectedOption == option
            : draft.text.trimmingCharacters(in: .whitespacesAndNewlines) == option
        return Button {
            BookFeedback.play(.select)
            if surface.type == .mood {
                draft.selectedOption = draft.selectedOption == option ? nil : option
            } else {
                draft.text = option
            }
        } label: {
            Text(option)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(isSelected ? BookPalette.page : BookPalette.ink.opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 7)
                .padding(.vertical, 8)
                .background(
                    isSelected ? accent.opacity(0.88) : BookPalette.page.opacity(0.54),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(accent.opacity(isSelected ? 0.86 : 0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.bookPress())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func split(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw
            .components(separatedBy: "||")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// Generation previews finish with a deliberate request leaf. The large
/// action remains in the leaf footer; this field tells the truth about what
/// will happen before the reader wakes Gemma.
private struct FolioGenerationRequestLeaf: View {
    let surface: SurfacePage
    let accent: Color
    let isBusy: Bool
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 8 : 18) {
            Spacer(minLength: compact ? 4 : 20)

            Image(systemName: isBusy ? "scribble.variable" : "pencil.and.scribble")
                .font(.system(size: compact ? 25 : 42, weight: .regular))
                .foregroundStyle(accent.opacity(0.82))
                .symbolEffect(.pulse, isActive: isBusy)

            Text(isBusy ? "The ink is moving." : "This Page wants another leaf.")
                .font(.system(size: compact ? 17 : 24, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(BookPalette.ink)

            Text(isBusy
                ? "Gemma is writing privately on this device. The new leaf will slip in behind this one."
                : "Ask me to write it. When the ink dries, I’ll put the result directly behind the Page that called it.")
                .font(.system(size: compact ? 13 : 16, design: .serif))
                .lineSpacing(compact ? 2 : 4)
                .multilineTextAlignment(.center)
                .foregroundStyle(BookPalette.ink.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            if let privacy = surface.payload.metadata["privacy"]?.nonEmpty {
                Label(privacy.capitalized, systemImage: "lock.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
            }

            Spacer(minLength: compact ? 4 : 20)
        }
        .padding(.horizontal, compact ? 12 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Quiet furniture that lets independent text fields feel typeset rather than
/// scattered. It never encloses every box; a rule, filing corner, or tiny
/// registration mark is enough to make the whitespace intentional.
private struct FolioRegionFurniture: View {
    let regions: [FolioTextRegion]
    let pattern: LeafRegionPatternID
    let tint: Color
    let seed: Int

    var body: some View {
        Canvas { context, _ in
            switch pattern {
            case .continuous:
                break

            case .heroPlate:
                if let filing = regions.first(where: { $0.kind == .provenance }) {
                    quietRule(in: &context, y: filing.frame.minY - 5, frame: filing.frame)
                    diamond(in: &context, at: CGPoint(x: filing.frame.midX, y: filing.frame.minY - 5))
                }

            case .staggeredField:
                if let lower = regions.first(where: { $0.kind == .secondary }) {
                    let direction: CGFloat = unit(17) < 0.5 ? 1 : -1
                    let startX = direction > 0 ? lower.frame.minX : lower.frame.maxX - 62
                    var rule = Path()
                    rule.move(to: CGPoint(x: startX, y: lower.frame.minY - 7))
                    rule.addLine(to: CGPoint(x: startX + 62, y: lower.frame.minY - 7))
                    context.stroke(rule, with: .color(tint.opacity(0.16)), lineWidth: 0.8)
                }

            case .sectionedCabinet:
                for region in regions where region.kind != .provenance {
                    let bracket = CGRect(
                        x: region.frame.minX - 4,
                        y: region.frame.minY - 4,
                        width: region.frame.width + 8,
                        height: region.frame.height + 8
                    )
                    context.stroke(
                        Path(roundedRect: bracket, cornerRadius: 2),
                        with: .color(tint.opacity(0.055)),
                        style: StrokeStyle(lineWidth: 0.7, dash: [4, 5])
                    )
                }

            case .letterWithPostscript:
                if let postscript = regions.first(where: { $0.kind == .secondary }) {
                    var rule = Path()
                    rule.move(to: CGPoint(x: postscript.frame.minX, y: postscript.frame.minY - 6))
                    rule.addLine(to: CGPoint(
                        x: postscript.frame.minX + postscript.frame.width * 0.72,
                        y: postscript.frame.minY - 6
                    ))
                    context.stroke(rule, with: .color(tint.opacity(0.13)), lineWidth: 0.75)
                }
            }
        }
    }

    private func quietRule(in context: inout GraphicsContext, y: CGFloat, frame: CGRect) {
        var rule = Path()
        rule.move(to: CGPoint(x: frame.minX, y: y))
        rule.addLine(to: CGPoint(x: frame.maxX, y: y))
        context.stroke(rule, with: .color(tint.opacity(0.13)), lineWidth: 0.7)
    }

    private func diamond(in context: inout GraphicsContext, at point: CGPoint) {
        let rect = CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)
        var mark = Path()
        mark.move(to: CGPoint(x: rect.midX, y: rect.minY))
        mark.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        mark.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        mark.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        mark.closeSubpath()
        context.stroke(mark, with: .color(tint.opacity(0.20)), lineWidth: 0.7)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 3_919).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

private struct FolioDynamicRuling: View {
    let style: FolioRulingStyle
    let tint: Color
    let seed: Int

    var body: some View {
        Canvas { context, size in
            switch style {
            case .none:
                break
            case .field:
                stride(from: CGFloat(31), through: size.height, by: 27).forEach { y in
                    var line = Path()
                    line.move(to: CGPoint(x: 11, y: y))
                    line.addLine(to: CGPoint(x: size.width - 8, y: y + (unit(Int(y)) - 0.5) * 1.2))
                    context.stroke(line, with: .color(tint.opacity(0.065)), lineWidth: 0.65)
                }
                var margin = Path()
                margin.move(to: CGPoint(x: 43, y: 8))
                margin.addLine(to: CGPoint(x: 43, y: size.height - 8))
                context.stroke(margin, with: .color(BookPalette.rubricRed.opacity(0.07)), lineWidth: 0.8)
            case .ledger:
                stride(from: CGFloat(34), through: size.height, by: 31).forEach { y in
                    var line = Path()
                    line.move(to: CGPoint(x: 8, y: y))
                    line.addLine(to: CGPoint(x: size.width - 8, y: y))
                    context.stroke(line, with: .color(tint.opacity(0.055)), lineWidth: 0.6)
                }
                for fraction in [0.24, 0.78] {
                    var column = Path()
                    column.move(to: CGPoint(x: size.width * fraction, y: 8))
                    column.addLine(to: CGPoint(x: size.width * fraction, y: size.height - 8))
                    context.stroke(column, with: .color(tint.opacity(0.035)), lineWidth: 0.55)
                }
            case .correspondence:
                stride(from: CGFloat(46), through: size.height, by: 29).forEach { y in
                    var line = Path()
                    line.move(to: CGPoint(x: 18, y: y))
                    line.addLine(to: CGPoint(x: size.width - 14, y: y))
                    context.stroke(line, with: .color(tint.opacity(0.045)), lineWidth: 0.55)
                }
            case .constellation:
                var points: [CGPoint] = []
                for index in 0..<8 {
                    points.append(CGPoint(x: unit(index) * size.width, y: unit(index + 30) * size.height))
                }
                for (index, point) in points.enumerated() {
                    let radius: CGFloat = index.isMultiple(of: 4) ? 1.6 : 0.8
                    context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: radius * 2, height: radius * 2)), with: .color(tint.opacity(0.10)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 6_151).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

/// What the reader reaches after the last leaf of ink. The Book is not
/// pretending to be endless — it says plainly that it has come to the end of
/// what it set out, and offers somewhere deeper rather than a wall.
private struct FolioWornLeafShape: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        let left = rect.minX + 0.8
        let right = rect.maxX - 0.8
        let top = rect.minY + 0.8
        let bottom = rect.maxY - 0.8
        let corner: CGFloat = 12
        var path = Path()

        path.move(to: CGPoint(x: left + corner + jitter(0, scale: 2.4), y: top + jitter(1, scale: 1.7)))
        path.addLine(to: CGPoint(x: rect.midX * 0.62, y: top + jitter(2, scale: 2.0)))
        path.addLine(to: CGPoint(x: rect.midX * 1.42, y: top + jitter(3, scale: 1.8)))
        path.addLine(to: CGPoint(x: right - corner, y: top + jitter(4, scale: 1.5)))
        path.addQuadCurve(
            to: CGPoint(x: right - jitter(5, scale: 1.8), y: top + corner),
            control: CGPoint(x: right, y: top)
        )
        path.addLine(to: CGPoint(x: right - jitter(6, scale: 2.2), y: rect.midY * 0.72))
        path.addLine(to: CGPoint(x: right - jitter(7, scale: 1.7), y: rect.midY * 1.34))
        path.addLine(to: CGPoint(x: right - jitter(8, scale: 2.1), y: bottom - corner))
        path.addQuadCurve(
            to: CGPoint(x: right - corner, y: bottom - jitter(9, scale: 1.8)),
            control: CGPoint(x: right, y: bottom)
        )
        path.addLine(to: CGPoint(x: rect.midX * 1.38, y: bottom - jitter(10, scale: 1.8)))
        path.addLine(to: CGPoint(x: rect.midX * 0.58, y: bottom - jitter(11, scale: 2.2)))
        path.addLine(to: CGPoint(x: left + corner, y: bottom - jitter(12, scale: 1.5)))
        path.addQuadCurve(
            to: CGPoint(x: left + jitter(13, scale: 1.5), y: bottom - corner),
            control: CGPoint(x: left, y: bottom)
        )
        path.addLine(to: CGPoint(x: left + jitter(14, scale: 1.5), y: rect.midY * 1.30))
        path.addLine(to: CGPoint(x: left + jitter(15, scale: 1.3), y: rect.midY * 0.68))
        path.addLine(to: CGPoint(x: left + jitter(16, scale: 1.8), y: top + corner))
        path.addQuadCurve(
            to: CGPoint(x: left + corner, y: top + jitter(17, scale: 1.4)),
            control: CGPoint(x: left, y: top)
        )
        path.closeSubpath()
        return path
    }

    private func jitter(_ salt: Int, scale: CGFloat) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 3_571).stableScramble) % 10_000
        return CGFloat(raw) / 9_999 * scale
    }
}

private struct FolioLeafPatina: View {
    private enum MaterialAccident: Int, Hashable {
        case waterRing
        case inkSpatter
        case softCrease
    }

    let recipe: LeafDecorationRecipe
    let composition: FolioLeafComposition
    let inkUsedHeight: CGFloat
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let wear = recipe.wearLevel

            let headEdge = Path(CGRect(x: 0, y: 0, width: size.width, height: 8 + unit(1) * 7))
            context.fill(headEdge, with: .color(BookPalette.parchmentEdge.opacity(wear * 0.13)))

            let foreEdge = Path(CGRect(x: size.width - 9 - unit(2) * 7, y: 0, width: 16, height: size.height))
            context.fill(foreEdge, with: .color(BookPalette.parchmentEdge.opacity(wear * 0.16)))

            if recipe.hasFoxing {
                for index in 0..<13 {
                    let radius = 0.8 + unit(20 + index) * 2.6
                    let edgeBias = index.isMultiple(of: 3)
                    let x = edgeBias
                        ? (unit(50 + index) < 0.5 ? unit(70 + index) * 26 : size.width - unit(70 + index) * 28)
                        : unit(70 + index) * size.width
                    let y = unit(100 + index) * size.height
                    let spot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    context.fill(spot, with: .color(Color.brown.opacity(0.035 + Double(unit(130 + index)) * 0.055)))
                }
            }

            if selectedAccidents.contains(.waterRing) {
                let diameter = min(size.width, size.height) * (0.20 + unit(170) * 0.09)
                let contentBottom = min(
                    size.height * 0.72,
                    35 + composition.headerHeight + composition.topInset + inkUsedHeight
                )
                let hasLowerRoom = size.height - contentBottom > diameter * 0.72 + 112
                let origin = CGPoint(
                    x: hasLowerRoom
                        ? size.width * (0.56 + unit(171) * 0.17)
                        : size.width - diameter * 0.27,
                    y: hasLowerRoom
                        ? min(size.height - 125, contentBottom + diameter * 0.38)
                        : size.height * (0.42 + unit(172) * 0.18)
                )
                let ringRect = CGRect(
                    x: origin.x - diameter / 2,
                    y: origin.y - diameter / 2,
                    width: diameter,
                    height: diameter * 0.84
                )
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(Color.brown.opacity(0.075)),
                    lineWidth: 1.2
                )
                context.stroke(
                    Path(ellipseIn: ringRect.insetBy(dx: 4, dy: 3)),
                    with: .color(Color.brown.opacity(0.028)),
                    lineWidth: 3.5
                )
            }

            if selectedAccidents.contains(.inkSpatter) {
                let contentBottom = min(
                    size.height * 0.72,
                    35 + composition.headerHeight + composition.topInset + inkUsedHeight
                )
                let lowerY = min(size.height - 108, contentBottom + 42)
                let center = CGPoint(
                    x: size.width * (0.70 + unit(190) * 0.16),
                    y: lowerY > contentBottom + 24 ? lowerY : size.height * (0.52 + unit(191) * 0.16)
                )
                for index in 0..<8 {
                    let radius = 0.7 + unit(200 + index) * (index == 0 ? 4.5 : 1.8)
                    let x = center.x + (unit(220 + index) - 0.5) * 42
                    let y = center.y + (unit(240 + index) - 0.5) * 38
                    let drop = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2.1, height: radius * 1.65))
                    context.fill(drop, with: .color(BookPalette.ink.opacity(index == 0 ? 0.15 : 0.10)))
                }
            }

            if selectedAccidents.contains(.softCrease) {
                var crease = Path()
                let startY = size.height * (0.28 + unit(270) * 0.43)
                crease.move(to: CGPoint(x: size.width * 0.10, y: startY))
                crease.addCurve(
                    to: CGPoint(x: size.width * 0.90, y: startY + (unit(271) - 0.5) * 18),
                    control1: CGPoint(x: size.width * 0.33, y: startY - 5),
                    control2: CGPoint(x: size.width * 0.66, y: startY + 7)
                )
                context.stroke(crease, with: .color(Color.brown.opacity(0.045)), lineWidth: 1)
                context.stroke(crease, with: .color(.white.opacity(0.045)), lineWidth: 0.45)
            }

            if recipe.hasWornCorner {
                let corner = Path(ellipseIn: CGRect(x: size.width - 34, y: size.height - 29, width: 42, height: 37))
                context.fill(corner, with: .color(tint.opacity(0.026)))
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (recipe.seed &+ salt &* 4_049).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }

    /// Foxing and edge wear are the paper's baseline. Ordinary leaves take at
    /// most one foreground accident; the occasional richer composition may
    /// carry two. Nothing arrives wearing every story it owns at once.
    private var selectedAccidents: Set<MaterialAccident> {
        var candidates: [MaterialAccident] = []
        if recipe.hasWaterRing { candidates.append(.waterRing) }
        if recipe.hasInkSpatter { candidates.append(.inkSpatter) }
        if recipe.hasSoftCrease { candidates.append(.softCrease) }
        let limit = composition.decorationBudget >= 3 && unit(307) < 0.72 ? 2 : 1
        return Set(candidates.sorted { left, right in
            let leftRank = (recipe.seed &+ left.rawValue &* 7_919).stableScramble
            let rightRank = (recipe.seed &+ right.rawValue &* 7_919).stableScramble
            return leftRank < rightRank
        }.prefix(limit))
    }
}

/// The collision map shared by every foreground mark on a leaf. It derives
/// from the same stored paper dimensions and composition insets used by the
/// paginator, so the rail is real blank paper rather than a decorative layer
/// painted over prose.
private struct FolioLeafSpatialPlan {
    let safeBounds: CGRect
    let inkBounds: CGRect
    let inkRects: [CGRect]
    let preferredRail: CGRect
    let oppositeRail: CGRect
    let lowerField: CGRect
    let watermarkField: CGRect

    init(leaf: FolioLeaf, size: CGSize) {
        let composition = leaf.composition
        let footerTop = max(1, size.height - 136)
        let inkTop = FolioLeafMeasure.paperVerticalPadding
            + composition.headerHeight
            + 21
            + composition.topInset
        let inkFieldOriginY = FolioLeafMeasure.paperVerticalPadding
            + composition.headerHeight
            + 7
        var resolvedInkRects = leaf.fragments.map { fragment in
            CGRect(
                x: FolioLeafMeasure.paperPadding + fragment.placement.minX,
                y: inkFieldOriginY + fragment.placement.minY,
                width: fragment.placement.width,
                height: fragment.placement.height
            )
        }.filter { $0.width > 0 && $0.height > 0 }
        if let interaction = leaf.interactionPlacement {
            resolvedInkRects.append(CGRect(
                x: FolioLeafMeasure.paperPadding + interaction.minX,
                y: inkFieldOriginY + interaction.minY,
                width: interaction.width,
                height: interaction.height
            ))
        }
        inkRects = resolvedInkRects
        if let first = resolvedInkRects.first {
            inkBounds = resolvedInkRects.dropFirst().reduce(first) { partial, rect in
                partial.union(rect)
            }
        } else {
            let baseContentWidth = FolioLeafMeasure.typesettingWidth(pageWidth: size.width)
            inkBounds = CGRect(
                x: FolioLeafMeasure.paperPadding
                    + FolioLeafMeasure.inkPadding
                    + FolioLeafMeasure.typesettingSafetyInset
                    + composition.leadingInset,
                y: inkTop,
                width: composition.contentWidth(
                    for: .body,
                    baseContentWidth: baseContentWidth
                ),
                height: 0
            )
        }
        safeBounds = CGRect(
            x: 7,
            y: inkTop - 5,
            width: max(1, size.width - 14),
            height: max(1, footerTop - inkTop + 5)
        )

        let leadingRail = CGRect(
            x: safeBounds.minX,
            y: safeBounds.minY,
            width: max(0, inkBounds.minX - safeBounds.minX - 7),
            height: safeBounds.height
        )
        let trailingRail = CGRect(
            x: inkBounds.maxX + 7,
            y: safeBounds.minY,
            width: max(0, safeBounds.maxX - inkBounds.maxX - 7),
            height: safeBounds.height
        )
        switch composition.marginaliaSide {
        case .leading:
            preferredRail = leadingRail
            oppositeRail = trailingRail
        case .trailing:
            preferredRail = trailingRail
            oppositeRail = leadingRail
        case .none:
            if leadingRail.width >= trailingRail.width {
                preferredRail = leadingRail
                oppositeRail = trailingRail
            } else {
                preferredRail = trailingRail
                oppositeRail = leadingRail
            }
        }

        lowerField = Self.largestOpenField(
            between: inkTop + 34,
            and: footerTop - 5,
            avoiding: resolvedInkRects,
            pageWidth: size.width
        )
        watermarkField = CGRect(
            x: max(inkBounds.minX, size.width * 0.39),
            y: max(inkTop + 28, inkBounds.midY - 62),
            width: min(138, max(1, inkBounds.maxX - max(inkBounds.minX, size.width * 0.39))),
            height: min(138, max(1, footerTop - max(inkTop + 28, inkBounds.midY - 62)))
        )
    }

    /// Finds the largest vertical breath between typeset regions. Because the
    /// final acceptance test uses each exact ink rectangle, this can safely
    /// recover the intentional open field between a hero statement and its
    /// provenance line instead of treating their union as solid prose.
    private static func largestOpenField(
        between top: CGFloat,
        and bottom: CGFloat,
        avoiding rects: [CGRect],
        pageWidth: CGFloat
    ) -> CGRect {
        let insetX = FolioLeafMeasure.paperPadding + 8
        let width = max(0, pageWidth - insetX * 2)
        guard bottom > top else {
            return CGRect(x: insetX, y: top, width: width, height: 0)
        }

        let intervals = rects
            .map { (minY: max(top, $0.minY - 8), maxY: min(bottom, $0.maxY + 8)) }
            .filter { $0.maxY > top && $0.minY < bottom }
            .sorted { $0.minY < $1.minY }
        var gaps: [ClosedRange<CGFloat>] = []
        var cursor = top
        for interval in intervals {
            if interval.minY > cursor {
                gaps.append(cursor...interval.minY)
            }
            cursor = max(cursor, interval.maxY)
        }
        if cursor < bottom { gaps.append(cursor...bottom) }
        guard let largest = gaps.max(by: {
            ($0.upperBound - $0.lowerBound) < ($1.upperBound - $1.lowerBound)
        }) else {
            return CGRect(x: insetX, y: top, width: width, height: 0)
        }
        return CGRect(
            x: insetX,
            y: largest.lowerBound,
            width: width,
            height: max(0, largest.upperBound - largest.lowerBound)
        )
    }
}

private struct FolioMarginaliaAssetMark: View {
    let asset: IlluminationAsset
    let accent: Color
    let frame: CGRect
    let opacity: Double
    let rotation: Double

    var body: some View {
        Group {
            if asset.leafTraits?.crop == .fill {
                Image(asset.assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(asset.assetName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: frame.width, height: frame.height)
        .clipped()
        .colorMultiply(usesStrongTint ? accent : .white)
        .saturation(saturation)
        .opacity(opacity * opacityWeight)
        .blendMode(blendMode)
        .rotationEffect(.degrees(rotation))
        .position(x: frame.midX, y: frame.midY)
    }

    private var usesStrongTint: Bool {
        asset.canTint && (asset.leafTraits?.tintStrength ?? 1) >= 0.5
    }

    private var opacityWeight: Double {
        min(1.18, max(0.72, asset.leafTraits?.visualWeight ?? 1))
    }

    private var saturation: Double {
        switch asset.leafTraits?.semanticRole {
        case .watercolor: return 0.94
        case .botanical, .portrait: return 0.82
        case .fieldNote, .scribble: return 0.64
        default: return 0.72
        }
    }

    private var blendMode: BlendMode {
        switch asset.leafTraits?.blend {
        case .normal: return .normal
        case .screen: return .screen
        case .overlay: return .overlay
        case .multiply, nil: return .multiply
        }
    }
}

private struct FolioLeafMarginaliaMarks: View {
    private enum Content {
        case asset(IlluminationAsset)
        case handwriting(String)
    }

    private struct Placement: Identifiable {
        var id: String
        var content: Content
        var frame: CGRect
        var opacity: Double
        var rotation: Double
    }

    let leaf: FolioLeaf
    let accent: Color
    let handwrittenNote: String?

    var body: some View {
        GeometryReader { proxy in
            let resolved = placements(in: proxy.size)
            ZStack {
                ForEach(resolved) { placement in
                    switch placement.content {
                    case .asset(let asset):
                        FolioMarginaliaAssetMark(
                            asset: asset,
                            accent: accent,
                            frame: placement.frame,
                            opacity: placement.opacity,
                            rotation: placement.rotation
                        )
                    case .handwriting(let note):
                        Text(note)
                            .font(FolioInkRole.handwritten.swiftUIFont(pointSize: 12.5, composition: leaf.composition))
                            .foregroundStyle(accent.opacity(0.58))
                            .multilineTextAlignment(.center)
                            .lineSpacing(1)
                            .frame(width: placement.frame.width, height: placement.frame.height)
                            .rotationEffect(.degrees(placement.rotation))
                            .position(x: placement.frame.midX, y: placement.frame.midY)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func placements(in size: CGSize) -> [Placement] {
        // A standalone writing leaf is all writing surface. When interaction
        // shares a reading leaf, its measured rectangle joins the collision
        // map and decorations may still use genuinely empty paper elsewhere.
        guard leaf.interactionKind == nil || leaf.interactionPlacement != nil else {
            return []
        }

        let recipe = leaf.decorationRecipe
        let composition = leaf.composition
        let plan = FolioLeafSpatialPlan(leaf: leaf, size: size)
        var accepted: [Placement] = []
        var occupied: [CGRect] = []

        func accepts(_ frame: CGRect, allowsContentOverlap: Bool = false) -> Bool {
            guard plan.safeBounds.contains(frame) else { return false }
            if !allowsContentOverlap,
               plan.inkRects.contains(where: {
                   frame.intersects($0.insetBy(dx: -7, dy: -6))
               }) {
                return false
            }
            return !occupied.contains { $0.insetBy(dx: -5, dy: -5).intersects(frame) }
        }

        func appendFirstAvailable(
            id: String,
            content: Content,
            opacity: Double,
            rotation: Double,
            frames: [CGRect],
            allowsContentOverlap: Bool = false
        ) {
            for frame in frames {
                guard accepts(frame, allowsContentOverlap: allowsContentOverlap) else { continue }
                accepted.append(Placement(id: id, content: content, frame: frame, opacity: opacity, rotation: rotation))
                occupied.append(frame)
                return
            }
        }

        if leaf.isDecorationPlate {
            let plateField = plan.safeBounds.insetBy(dx: 16, dy: 18)
            let heroWidth = min(238, plateField.width * 0.68)
            let heroHeight = min(290, plateField.height * 0.52)
            let heroFrame = CGRect(
                x: plateField.midX - heroWidth / 2,
                y: plateField.minY + plateField.height * 0.10,
                width: heroWidth,
                height: heroHeight
            )
            if let primary = recipe.primaryAsset {
                appendFirstAvailable(
                    id: "plate-primary-\(primary.id)",
                    content: .asset(primary),
                    opacity: min(0.52, primary.defaultOpacity * 0.74),
                    rotation: rotation(salt: 3) * 0.46,
                    frames: [heroFrame]
                )
            }

            if let secondary = recipe.secondaryAsset {
                let side = min(82, plateField.width * 0.25)
                let secondaryFrame = CGRect(
                    x: plateField.minX + plateField.width * 0.04,
                    y: plateField.maxY - side - plateField.height * 0.06,
                    width: side,
                    height: side
                )
                appendFirstAvailable(
                    id: "plate-secondary-\(secondary.id)",
                    content: .asset(secondary),
                    opacity: min(0.38, secondary.defaultOpacity * 0.56),
                    rotation: rotation(salt: 11),
                    frames: [secondaryFrame]
                )
            }

            let plateHandwriting = recipe.handwrittenSnippet?.text.nonEmpty
                ?? handwrittenNote?.nonEmpty
            if let plateHandwriting {
                let noteWidth = min(142, plateField.width * 0.43)
                let noteHeight = min(106, plateField.height * 0.22)
                let noteFrame = CGRect(
                    x: plateField.maxX - noteWidth - plateField.width * 0.03,
                    y: plateField.maxY - noteHeight - plateField.height * 0.045,
                    width: noteWidth,
                    height: noteHeight
                )
                appendFirstAvailable(
                    id: "plate-handwriting",
                    content: .handwriting(plateHandwriting),
                    opacity: 1,
                    rotation: rotation(salt: 83),
                    frames: [noteFrame]
                )
            }
            return accepted
        }

        var remainingBudget = composition.decorationBudget
        if remainingBudget > 0,
           let support = recipe.supportAsset,
           supportsCurrentDialect(support) {
            let supportSize = desiredSize(
                for: support,
                fallback: CGSize(width: 126, height: 86)
            )
            appendFirstAvailable(
                id: "support-\(support.id)",
                content: .asset(support),
                opacity: min(0.34, support.defaultOpacity * 0.48),
                rotation: rotation(salt: 71) * 0.54,
                frames: candidateFrames(
                    in: plan.lowerField,
                    desiredSize: supportSize,
                    minimumScale: 0.68,
                    salt: 73
                ) + candidateFrames(
                    in: plan.preferredRail,
                    desiredSize: supportSize,
                    minimumScale: 0.58,
                    salt: 79
                ),
                allowsContentOverlap: support.leafTraits?.allowsTextOverlap == true
            )
            if let supportPlacement = accepted.first(where: { $0.id == "support-\(support.id)" }) {
                remainingBudget -= 1
                if let fastening = recipe.fasteningAsset,
                   supportsCurrentDialect(fastening) {
                    let tapeSize = desiredSize(
                        for: fastening,
                        fallback: CGSize(width: 54, height: 20)
                    )
                    let tapeFrame = CGRect(
                        x: supportPlacement.frame.midX - tapeSize.width / 2,
                        y: supportPlacement.frame.minY - tapeSize.height * 0.28,
                        width: tapeSize.width,
                        height: tapeSize.height
                    )
                    let crossesInk = plan.inkRects.contains {
                        tapeFrame.intersects($0.insetBy(dx: -5, dy: -4))
                    }
                    if plan.safeBounds.contains(tapeFrame), !crossesInk {
                        accepted.append(Placement(
                            id: "fastening-\(fastening.id)",
                            content: .asset(fastening),
                            frame: tapeFrame,
                            opacity: min(0.42, fastening.defaultOpacity * 0.58),
                            rotation: rotation(salt: 81) * 0.28
                        ))
                    }
                }
            }
        }

        let resolvedHandwriting = recipe.handwrittenSnippet?.text.nonEmpty
            ?? (unit(89) < 0.34 ? handwrittenNote?.nonEmpty : nil)
        if let resolvedHandwriting {
            let handwritingZones: [CGRect]
            switch composition.spatialStyle {
            case .heroPlate, .letterMargin:
                handwritingZones = [plan.lowerField, plan.preferredRail, plan.oppositeRail]
            case .fieldRail:
                handwritingZones = [plan.preferredRail, plan.lowerField, plan.oppositeRail]
            case .cabinetRail:
                handwritingZones = [plan.preferredRail, plan.oppositeRail, plan.lowerField]
            case .quietColumn:
                handwritingZones = [plan.lowerField, plan.preferredRail]
            }
            let handwritingFrames = handwritingZones.flatMap { zone in
                candidateFrames(
                    in: zone,
                    desiredSize: CGSize(width: 96, height: 82),
                    minimumScale: 0.62,
                    salt: 97
                )
            }
            let countBeforeHandwriting = accepted.count
            appendFirstAvailable(
                id: "handwriting",
                content: .handwriting(resolvedHandwriting),
                opacity: 1,
                rotation: rotation(salt: 83),
                frames: handwritingFrames
            )
            if accepted.count > countBeforeHandwriting {
                remainingBudget = max(0, remainingBudget - 1)
            }
        }

        if remainingBudget > 0,
           let primary = recipe.primaryAsset,
           supportsCurrentDialect(primary) {
            let width: CGFloat = primary.kind == .stamp ? 50 : 58
            let primarySize = desiredSize(
                for: primary,
                fallback: CGSize(width: width, height: width)
            )
            let directedFrames = traitFrames(
                for: primary,
                plan: plan,
                desiredSize: primarySize,
                salt: 107
            )
            let railFrames = directedFrames.isEmpty
                ? primaryFrames(
                    placement: recipe.primaryPlacement,
                    plan: plan,
                    desiredSize: primarySize,
                    salt: 113
                )
                : directedFrames
            if recipe.primaryPlacement == .faintWatermark
                || primary.leafTraits?.allowsTextOverlap == true
                || primary.leafTraits?.preferredAnchors?.contains(.watermark) == true {
                appendFirstAvailable(
                    id: "watermark-\(primary.id)",
                    content: .asset(primary),
                    opacity: min(0.095, primary.defaultOpacity * 0.16),
                    rotation: rotation(salt: 5),
                    frames: candidateFrames(
                        in: plan.watermarkField,
                        desiredSize: desiredSize(
                            for: primary,
                            fallback: CGSize(width: 128, height: 128)
                        ),
                        minimumScale: 0.72,
                        salt: 127
                    ),
                    allowsContentOverlap: true
                )
            } else {
                appendFirstAvailable(
                    id: "primary-\(primary.id)",
                    content: .asset(primary),
                    opacity: min(0.34, primary.defaultOpacity * 0.52),
                    rotation: rotation(salt: 3),
                    frames: railFrames
                )
            }
            if accepted.contains(where: { $0.id == "primary-\(primary.id)" }) {
                remainingBudget -= 1
            } else if accepted.contains(where: { $0.id == "watermark-\(primary.id)" }) {
                remainingBudget -= 1
            }
        }

        if remainingBudget > 0,
           let secondary = recipe.secondaryAsset,
           supportsCurrentDialect(secondary) {
            let width: CGFloat = secondary.kind == .stamp ? 42 : 48
            let secondarySize = desiredSize(
                for: secondary,
                fallback: CGSize(width: width, height: width)
            )
            appendFirstAvailable(
                id: "secondary-\(secondary.id)",
                content: .asset(secondary),
                opacity: min(0.25, secondary.defaultOpacity * 0.38),
                rotation: rotation(salt: 11),
                frames: {
                    let directed = traitFrames(
                        for: secondary,
                        plan: plan,
                        desiredSize: secondarySize,
                        salt: 137
                    )
                    return directed.isEmpty
                        ? candidateFrames(
                            in: plan.oppositeRail,
                            desiredSize: secondarySize,
                            minimumScale: 0.72,
                            salt: 139
                        ) + candidateFrames(
                            in: plan.lowerField,
                            desiredSize: secondarySize,
                            minimumScale: 0.82,
                            salt: 149
                        )
                        : directed
                }()
            )
        }

        return accepted
    }

    private func supportsCurrentDialect(_ asset: IlluminationAsset) -> Bool {
        guard let dialects = asset.leafTraits?.supportedDialects,
              !dialects.isEmpty else { return true }
        return dialects.contains(leaf.composition.dialect)
    }

    private func desiredSize(
        for asset: IlluminationAsset,
        fallback: CGSize
    ) -> CGSize {
        let weight = CGFloat(min(1.7, max(0.55, asset.leafTraits?.visualWeight ?? 1)))
        let ratio = CGFloat(asset.leafTraits?.aspectRatio ?? Double(fallback.width / max(1, fallback.height)))
        let area = max(1, fallback.width * fallback.height * weight)
        let height = sqrt(area / max(0.2, ratio))
        return CGSize(width: height * ratio, height: height)
    }

    private func traitFrames(
        for asset: IlluminationAsset,
        plan: FolioLeafSpatialPlan,
        desiredSize: CGSize,
        salt: Int
    ) -> [CGRect] {
        guard let anchors = asset.leafTraits?.preferredAnchors,
              !anchors.isEmpty else { return [] }
        let leadingRail = plan.preferredRail.minX <= plan.oppositeRail.minX
            ? plan.preferredRail
            : plan.oppositeRail
        let trailingRail = plan.preferredRail.minX > plan.oppositeRail.minX
            ? plan.preferredRail
            : plan.oppositeRail
        return anchors.enumerated().flatMap { index, anchor -> [CGRect] in
            let zone: CGRect
            let rotation: Int
            switch anchor {
            case .upperLeading: zone = leadingRail; rotation = 0
            case .upperTrailing: zone = trailingRail; rotation = 0
            case .middleLeading: zone = leadingRail; rotation = 1
            case .middleTrailing: zone = trailingRail; rotation = 1
            case .lowerLeading: zone = leadingRail; rotation = 2
            case .lowerTrailing: zone = trailingRail; rotation = 2
            case .lowerField: zone = plan.lowerField; rotation = 1
            case .watermark: zone = plan.watermarkField; rotation = 1
            }
            let frames = candidateFrames(
                in: zone,
                desiredSize: desiredSize,
                minimumScale: anchor == .lowerField || anchor == .watermark ? 0.62 : 0.70,
                salt: salt + index * 17
            )
            return rotateCandidates(frames, by: rotation)
        }
    }

    private func primaryFrames(
        placement: LeafMarginaliaPlacement,
        plan: FolioLeafSpatialPlan,
        desiredSize: CGSize,
        salt: Int
    ) -> [CGRect] {
        let preferred = candidateFrames(
            in: plan.preferredRail,
            desiredSize: desiredSize,
            minimumScale: 0.70,
            salt: salt
        )
        let opposite = candidateFrames(
            in: plan.oppositeRail,
            desiredSize: desiredSize,
            minimumScale: 0.70,
            salt: salt + 19
        )
        let lower = candidateFrames(
            in: plan.lowerField,
            desiredSize: desiredSize,
            minimumScale: 0.86,
            salt: salt + 31
        )
        switch placement {
        case .upperOuterMargin: return preferred + opposite + lower
        case .middleOuterMargin:
            return rotateCandidates(preferred, by: 1) + opposite + lower
        case .lowerOuterCorner:
            return Array(preferred.reversed()) + lower + Array(opposite.reversed())
        case .faintWatermark: return []
        }
    }

    /// Produces stable candidate boxes inside a semantic zone. The desired
    /// mark may shrink modestly to fit a phone rail, but disappears rather
    /// than becoming an illegible postage speck.
    private func candidateFrames(
        in zone: CGRect,
        desiredSize: CGSize,
        minimumScale: CGFloat,
        salt: Int
    ) -> [CGRect] {
        guard zone.width > 8, zone.height > 8 else { return [] }
        let insetZone = zone.insetBy(dx: 3, dy: 5)
        guard insetZone.width > 4, insetZone.height > 4 else { return [] }
        let scale = min(
            1,
            min(
                insetZone.width / max(1, desiredSize.width),
                insetZone.height / max(1, desiredSize.height)
            )
        )
        guard scale >= minimumScale else { return [] }
        let markSize = CGSize(
            width: desiredSize.width * scale,
            height: desiredSize.height * scale
        )
        let xTravel = max(0, insetZone.width - markSize.width)
        let yTravel = max(0, insetZone.height - markSize.height)
        let verticalFractions: [CGFloat] = [0.12, 0.48, 0.84]
        return verticalFractions.enumerated().map { index, fraction in
            let x = insetZone.minX + xTravel * unit(salt + index * 7)
            let jitteredFraction = min(
                1,
                max(0, fraction + (unit(salt + index * 11 + 3) - 0.5) * 0.12)
            )
            let y = insetZone.minY + yTravel * jitteredFraction
            return CGRect(origin: CGPoint(x: x, y: y), size: markSize)
        }
    }

    private func rotateCandidates(_ frames: [CGRect], by count: Int) -> [CGRect] {
        guard !frames.isEmpty else { return frames }
        let split = count % frames.count
        return Array(frames[split...]) + Array(frames[..<split])
    }

    private func rotation(salt: Int) -> Double {
        (Double(unit(salt)) - 0.5) * 15 + (leaf.documentLeafIndex.isMultiple(of: 2) ? -1.4 : 1.4)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (leaf.decorationRecipe.seed &+ salt &* 5_239).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

private struct FolioEndLeaf: View {
    let onExploreDeeper: () -> Void
    let onReturnToStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // A printer's asterism: the mark that closes a section.
            Text("⁂")
                .font(.system(size: 30, design: .serif))
                .foregroundStyle(BookPalette.lampGold.opacity(0.66))
                .padding(.bottom, 16)

            Text("That's all I set out tonight.")
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Nine more Pages are tucked deeper in the binding. I can shake them loose.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(BookPalette.ink.opacity(0.56))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
                .padding(.horizontal, 12)

            Button(action: onExploreDeeper) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 12, weight: .bold))
                    Text("Explore deeper")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                }
                .foregroundStyle(BookPalette.ink.opacity(0.90))
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(BookPalette.lampGold.opacity(0.20), in: Capsule())
                .overlay {
                    Capsule().stroke(BookPalette.lampGold.opacity(0.60), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 22)
            .accessibilityHint("Binds nine more Pages and turns to the first new leaf")

            Button(action: onReturnToStart) {
                Text("Back to the first leaf")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.52))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 13)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .parchmentSurface(accent: BookPalette.lampGold.opacity(0.70), isActive: false)
        .overlay(alignment: .leading) {
            FolioOpenLeafBinding(tint: BookPalette.lampGold)
                .frame(width: 31)
                .padding(.vertical, 8)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("The end of tonight's leaves")
    }
}

private struct FolioInkBleed: View {
    let tint: Color
    let seed: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            ForEach(0..<9, id: \.self) { index in
                let value = abs(seed.stableHash + index * 37)
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.035 + Double(value % 4) * 0.012))
                    .frame(
                        width: CGFloat(2 + value % 4),
                        height: CGFloat(5 + value % 15)
                    )
                    .blur(radius: CGFloat(value % 3) * 0.35)
                    .offset(y: CGFloat(value % 4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mask {
            LinearGradient(
                colors: [.clear, .white.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .blendMode(.multiply)
    }
}

private struct FolioMediaView: View {
    let media: FolioMedia
    let accent: Color

    var body: some View {
        Group {
            switch media {
            case .asset(let name, _):
                Image(name)
                    .resizable()
                    .scaledToFill()
            case .file(let path, _):
                if let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    missingImage
                }
            case .photoLibrary(let identifier, _):
                FolioPhotoLibraryImage(identifier: identifier, accent: accent)
            case .illuminated(let draft, _):
                IlluminatedArtifactPreview(draft: draft)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(accent.opacity(0.30), lineWidth: 1)
        }
        .accessibilityLabel(media.label)
    }

    private var missingImage: some View {
        ZStack {
            BookPalette.paper.opacity(0.46)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title)
                .foregroundStyle(accent.opacity(0.58))
        }
    }
}

private struct FolioPhotoLibraryImage: View {
    let identifier: String
    let accent: Color
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    BookPalette.paper.opacity(0.46)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(accent.opacity(0.58))
                }
            }
        }
        .task(id: identifier) {
            guard image == nil,
                  let asset = PHAsset.fetchAssets(
                    withLocalIdentifiers: [identifier],
                    options: nil
                  ).firstObject else { return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1_200, height: 1_200),
                contentMode: .aspectFill,
                options: options
            ) { loaded, _ in
                guard let loaded else { return }
                DispatchQueue.main.async { image = loaded }
            }
        }
    }
}

// MARK: - Reduced Motion pager

private struct FolioStillPager: View {
    let leaves: [FolioLeaf]
    @Binding var currentLeafID: String?
    let interactionStore: FolioInteractionStore
    let isBusy: (SurfacePage) -> Bool
    let isRetiring: (SurfacePage) -> Bool
    let animatesArrival: (SurfacePage) -> Bool
    let selectedSurfaceID: String?
    let glowScore: Int
    let showsGlow: Bool
    let onOpenGlow: () -> Void
    let onOpen: (SurfacePage) -> Void
    let onKeep: (SurfacePage, String) -> Void
    let onDismiss: (SurfacePage) -> Void
    let onExploreDeeper: () -> Void
    let onReturnToStart: () -> Void

    private var currentIndex: Int {
        guard let currentLeafID,
              let index = leaves.firstIndex(where: { $0.id == currentLeafID }) else { return 0 }
        return index
    }

    var body: some View {
        ZStack {
            if leaves.indices.contains(currentIndex), leaves[currentIndex].isEnding {
                FolioEndLeaf(
                    onExploreDeeper: onExploreDeeper,
                    onReturnToStart: onReturnToStart
                )
                .id(leaves[currentIndex].id)
                .transition(.opacity)
            } else if leaves.indices.contains(currentIndex) {
                let leaf = leaves[currentIndex]
                FolioLeafPage(
                    leaf: leaf,
                    interactionStore: interactionStore,
                    canGoBackward: currentIndex > 0,
                    canGoForward: currentIndex + 1 < leaves.count,
                    isBusy: isBusy(leaf.surface),
                    isRetiring: isRetiring(leaf.surface),
                    animatesArrival: animatesArrival(leaf.surface),
                    isSelected: selectedSurfaceID == leaf.documentID,
                    glowScore: glowScore,
                    showsGlow: showsGlow,
                    onOpenGlow: onOpenGlow,
                    onOpen: { onOpen(leaf.surface) },
                    onKeep: { input in onKeep(leaf.surface, input) },
                    onDismiss: { onDismiss(leaf.surface) },
                    onNavigate: move
                )
                .id(leaf.id)
                .transition(.opacity)
            }
        }
        .animation(BookMotion.pageTurn(true), value: currentLeafID)
    }

    private func move(_ delta: Int) {
        let next = currentIndex + delta
        guard leaves.indices.contains(next) else { return }
        currentLeafID = leaves[next].id
    }
}

// MARK: - Interactive native page curl

/// `UIPageViewController` supplies the finger-following paper curl used by
/// Apple's book readers. SwiftUI still owns every leaf and all actions.
private struct FolioCurlPager: UIViewControllerRepresentable {
    let leaves: [FolioLeaf]
    let pageSize: CGSize
    @Binding var currentLeafID: String?
    let interactionStore: FolioInteractionStore
    let isBusy: (SurfacePage) -> Bool
    let isRetiring: (SurfacePage) -> Bool
    let animatesArrival: (SurfacePage) -> Bool
    let selectedSurfaceID: String?
    let glowScore: Int
    let showsGlow: Bool
    let onOpenGlow: () -> Void
    let onOpen: (SurfacePage) -> Void
    let onKeep: (SurfacePage, String) -> Void
    let onDismiss: (SurfacePage) -> Void
    let onExploreDeeper: () -> Void
    let onReturnToStart: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal
        )
        controller.isDoubleSided = false
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .clear
        controller.view.directionalLayoutMargins = .zero
        controller.view.preservesSuperviewLayoutMargins = false
        controller.view.insetsLayoutMarginsFromSafeArea = false
        // Page curl owns an internal transition view. Left unclipped, its
        // dimmed paper backside paints a tall translucent strip behind the
        // fore-edge bookmarks even after the turn has settled.
        controller.view.clipsToBounds = true
        context.coordinator.synchronize(controller)
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIPageViewController,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.synchronize(uiViewController)
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: FolioCurlPager
        private var hosts: [String: UIHostingController<AnyView>] = [:]
        private var knownLeafIDs: [String] = []
        private var knownPageSize: CGSize = .zero
        private var hasInstalledLeaf = false
        private var isTransitioning = false

        init(parent: FolioCurlPager) {
            self.parent = parent
        }

        func synchronize(_ controller: UIPageViewController) {
            guard !isTransitioning else { return }

            let nextLeafIDs = parent.leaves.map(\.id)
            let leavesChanged = nextLeafIDs != knownLeafIDs
            let paperSizeChanged = abs(knownPageSize.width - parent.pageSize.width) > 0.5
                || abs(knownPageSize.height - parent.pageSize.height) > 0.5
            knownLeafIDs = nextLeafIDs
            knownPageSize = parent.pageSize
            if paperSizeChanged {
                // A host created for the old paper size can remain installed
                // inside UIPageViewController even after SwiftUI has narrowed
                // the Book. Recreate it rather than letting the curl retain an
                // invisible old canvas that clips every Page family alike.
                hosts.removeAll()
                hasInstalledLeaf = false
            } else {
                hosts = hosts.filter { nextLeafIDs.contains($0.key) }
            }

            guard !parent.leaves.isEmpty else {
                controller.setViewControllers(
                    nil,
                    direction: .forward,
                    animated: false,
                    completion: nil
                )
                hasInstalledLeaf = false
                return
            }

            let targetID = parent.currentLeafID.flatMap { requested in
                parent.leaves.contains(where: { $0.id == requested }) ? requested : nil
            } ?? parent.leaves[0].id
            guard let targetIndex = index(of: targetID) else { return }

            if let visible = controller.viewControllers?.first,
               leafID(for: visible) == targetID {
                refreshHost(for: targetID)
                return
            }

            let visibleIndex = controller.viewControllers?.first
                .flatMap(leafID(for:))
                .flatMap(index(of:))
            let direction: UIPageViewController.NavigationDirection =
                (visibleIndex ?? targetIndex) <= targetIndex ? .forward : .reverse
            let animated = hasInstalledLeaf && !leavesChanged
            let target = host(for: targetID)
            if animated { isTransitioning = true }
            controller.setViewControllers(
                [target],
                direction: direction,
                animated: animated,
                completion: { [weak self, weak controller] _ in
                    guard let self else { return }
                    self.isTransitioning = false
                    if let controller { self.synchronize(controller) }
                }
            )
            hasInstalledLeaf = true
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let id = leafID(for: viewController),
                  let currentIndex = index(of: id),
                  currentIndex > 0 else { return nil }
            return host(for: parent.leaves[currentIndex - 1].id)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let id = leafID(for: viewController),
                  let currentIndex = index(of: id),
                  currentIndex + 1 < parent.leaves.count else { return nil }
            return host(for: parent.leaves[currentIndex + 1].id)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            isTransitioning = true
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            isTransitioning = false
            if completed,
               let visible = pageViewController.viewControllers?.first,
               let id = leafID(for: visible) {
                parent.currentLeafID = id
            }
            synchronize(pageViewController)
        }

        private func host(for leafID: String) -> UIHostingController<AnyView> {
            if let host = hosts[leafID] {
                host.rootView = rootView(for: leafID)
                configure(host)
                return host
            }
            let host = UIHostingController(rootView: rootView(for: leafID))
            configure(host)
            hosts[leafID] = host
            return host
        }

        private func configure(_ host: UIHostingController<AnyView>) {
            host.preferredContentSize = parent.pageSize
            host.additionalSafeAreaInsets = .zero
            host.view.backgroundColor = .clear
            host.view.clipsToBounds = true
            host.view.directionalLayoutMargins = .zero
            host.view.preservesSuperviewLayoutMargins = false
            host.view.insetsLayoutMarginsFromSafeArea = false
        }

        private func refreshHost(for leafID: String) {
            hosts[leafID]?.rootView = rootView(for: leafID)
        }

        private func rootView(for leafID: String) -> AnyView {
            guard let leafIndex = index(of: leafID) else { return AnyView(EmptyView()) }
            let leaf = parent.leaves[leafIndex]

            if leaf.isEnding {
                return AnyView(FolioHostedPaperRoot(pageSize: parent.pageSize) {
                    FolioEndLeaf(
                        onExploreDeeper: { [weak self] in self?.parent.onExploreDeeper() },
                        onReturnToStart: { [weak self] in self?.parent.onReturnToStart() }
                    )
                })
            }

            return AnyView(FolioHostedPaperRoot(pageSize: parent.pageSize) {
                FolioLeafPage(
                    leaf: leaf,
                    interactionStore: parent.interactionStore,
                    canGoBackward: leafIndex > 0,
                    canGoForward: leafIndex + 1 < parent.leaves.count,
                    isBusy: parent.isBusy(leaf.surface),
                    isRetiring: parent.isRetiring(leaf.surface),
                    animatesArrival: parent.animatesArrival(leaf.surface),
                    isSelected: parent.selectedSurfaceID == leaf.documentID,
                    glowScore: parent.glowScore,
                    showsGlow: parent.showsGlow,
                    onOpenGlow: { [weak self] in self?.parent.onOpenGlow() },
                    onOpen: { [weak self] in self?.parent.onOpen(leaf.surface) },
                    onKeep: { [weak self] input in self?.parent.onKeep(leaf.surface, input) },
                    onDismiss: { [weak self] in self?.parent.onDismiss(leaf.surface) },
                    onNavigate: { [weak self] delta in self?.move(from: leafID, by: delta) }
                )
            })
        }

        private func move(from leafID: String, by delta: Int) {
            guard let currentIndex = index(of: leafID) else { return }
            let nextIndex = currentIndex + delta
            guard parent.leaves.indices.contains(nextIndex) else { return }
            parent.currentLeafID = parent.leaves[nextIndex].id
        }

        private func index(of leafID: String) -> Int? {
            parent.leaves.firstIndex(where: { $0.id == leafID })
        }

        private func leafID(for controller: UIViewController) -> String? {
            hosts.first(where: { $0.value === controller })?.key
        }
    }
}

/// `UIPageViewController` sometimes keeps a transition canvas wider than its
/// representable after a curl or a parent-width change. A fixed-size SwiftUI
/// root is centered in that canvas by default, leaving the visible paper to
/// show only its middle. Anchor the measured paper at the transition origin;
/// the outer folio supplies the rounded clip and no hidden width can become
/// part of typesetting again.
private struct FolioHostedPaperRoot<Paper: View>: View {
    let pageSize: CGSize
    let paper: Paper

    init(pageSize: CGSize, @ViewBuilder paper: () -> Paper) {
        self.pageSize = pageSize
        self.paper = paper()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            paper
                .frame(width: pageSize.width, height: pageSize.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
    }
}

private extension ContentSizeCategory {
    var isFolioAccessibilityCategory: Bool {
        switch self {
        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
             .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return true
        default:
            return false
        }
    }

    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .extraExtraExtraLarge
        case .accessibilityMedium: return .accessibilityMedium
        case .accessibilityLarge: return .accessibilityLarge
        case .accessibilityExtraLarge: return .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

extension SurfacePage {
    /// Prepared Pages may have dried before the Curator seats them, so they do
    /// not all carry the transient insertion marker. Their established prose
    /// fields are the stronger signal that the leaf should show the writing
    /// itself instead of another preview card.
    var pagesRisingHasWrittenProse: Bool {
        if payload.metadata["pagesRisingFolioGeneratedResult"] == "true" {
            return true
        }
        if type == .bookOfYou,
           payload.metadata["keptPageID"]?.nonEmpty != nil {
            return true
        }
        if type == .weather,
           payload.metadata["rawWeather"]?.nonEmpty != nil {
            return true
        }
        let proseKeys = [
            "storyScene",
            "letterProse",
            "noteProse",
            "gossipProse",
            "researchProse",
            "bleedProse",
            "classProse",
            "twoReadingsProse",
            "castBondProse",
            "quillChoosingProse",
            "bookJumpProse",
            "guildProse",
            "packProse"
        ]
        return proseKeys.contains { payload.metadata[$0]?.nonEmpty != nil }
    }

    /// This is the one remaining preview state: the reader has asked the local
    /// writer for a Page, but the writer has not put its prose on paper yet.
    var pagesRisingNeedsUserInitiatedGeneration: Bool {
        if type == .illuminatedPhoto,
           payload.metadata["cameraFirst"] == "true" {
            return false
        }
        return !pagesRisingHasWrittenProse
            && SurfaceReadinessState(surface: self).needsLocalBrainToOpen
    }

    /// Some generators retain their complete prose in typed metadata while the
    /// payload body stays a small old card-preview. Both the folio and the Keep
    /// path must read the same complete Page.
    var pagesRisingReadingBody: String {
        guard pagesRisingHasWrittenProse else { return payload.body }
        for key in [
            "storyScene",
            "letterProse",
            "noteProse",
            "gossipProse",
            "researchProse",
            "bleedProse",
            "classProse",
            "twoReadingsProse",
            "castBondProse",
            "quillChoosingProse",
            "bookJumpProse",
            "guildProse",
            "packProse"
        ] {
            if let prose = payload.metadata[key]?.nonEmpty,
               prose != "fallback" {
                return prose
            }
        }
        return payload.body
    }
}
