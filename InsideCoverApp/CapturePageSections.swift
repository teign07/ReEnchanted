import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - CapturePageSheet sections as standalone views.
//
// Each struct boundary resets SwiftUI's generic type nesting (the cause of
// the sheet-presentation segfault) and keeps the sheet's state surface small.

struct ChapterBindingAcceptance: Equatable {
    var chapterID: String
    var chapterName: String = ""
    var sealLine: String = ""
    var oathLine: String = ""
    var invitationLine: String = ""
    var aftermathLine: String = ""
}

struct ChapterBindingFormView: View {
    let surface: SurfacePage
    let onBindChapter: (ChapterBindingAcceptance) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ceremonyIsAwake = false
    @State private var celebrationBurst = false
    @State private var isAcceptingBinding = false
    @State private var didPlayReveal = false

    private var chosenChapter: AcademyChapter? {
        AcademyChapterRegistry.chapter(id: surface.payload.metadata["chosenChapterID"] ?? "")
    }

    private var evidenceLines: [String] {
        (surface.payload.metadata["bindingEvidence"] ?? "")
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var memoryFragments: [String] {
        (surface.payload.metadata["bindingMemories"] ?? "")
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var ceremony: ChapterBindingCeremonyProfile {
        ChapterBindingCeremonyProfile(chapterID: chosenChapter?.id)
    }

    private var acceptance: ChapterBindingAcceptance? {
        guard let chapter = chosenChapter else { return nil }
        let sharedCeremony = ChapterBindingCeremony.profile(for: chapter)
        return ChapterBindingAcceptance(
            chapterID: chapter.id,
            chapterName: chapter.name,
            sealLine: surface.payload.metadata["bindingSealLine"]?.nonEmpty ?? sharedCeremony.sealLine,
            oathLine: surface.payload.metadata["bindingOathLine"]?.nonEmpty ?? sharedCeremony.oathLine,
            invitationLine: surface.payload.metadata["bindingInvitationLine"]?.nonEmpty ?? sharedCeremony.invitationLine,
            aftermathLine: surface.payload.metadata["bindingAftermathLine"]?.nonEmpty ?? sharedCeremony.aftermathLine
        )
    }

    private func revealCeremony() {
        guard !didPlayReveal else { return }
        didPlayReveal = true
        BookFeedback.chapterBindingReveal()
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.55, dampingFraction: 0.74)
        withAnimation(animation.delay(0.08)) {
            ceremonyIsAwake = true
            celebrationBurst = true
        }
    }

    private func acceptBinding() {
        guard let acceptance, !isAcceptingBinding else { return }
        BookFeedback.chapterBindingAccepted()
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.42, dampingFraction: 0.68)
        withAnimation(animation) {
            isAcceptingBinding = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.24 : 0.78)) {
            onBindChapter(acceptance)
            dismiss()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let chapter = chosenChapter {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(ceremony.gradient)
                            .overlay {
                                GeometryReader { proxy in
                                    ZStack {
                                        Circle()
                                            .fill(.white.opacity(0.14))
                                            .frame(width: proxy.size.width * 0.58)
                                            .blur(radius: 18)
                                            .offset(x: proxy.size.width * 0.34, y: -proxy.size.height * 0.16)
                                        Circle()
                                            .strokeBorder(BookPalette.lampGold.opacity(0.26), lineWidth: 1)
                                            .frame(width: proxy.size.width * 0.72)
                                            .offset(x: -proxy.size.width * 0.2, y: proxy.size.height * 0.12)
                                    }
                                }
                                .clipped()
                            }

                        ChapterBindingCelebrationBurst(
                            accent: ceremony.accent,
                            isExpanded: celebrationBurst,
                            reduceMotion: reduceMotion
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: chapter.symbolName)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(BookPalette.lampGold)
                                    .frame(width: 42, height: 42)
                                    .background(.black.opacity(0.16), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("The Binding Recognizes")
                                        .font(.caption2.weight(.black))
                                        .textCase(.uppercase)
                                        .foregroundStyle(.white.opacity(0.74))
                                    Text(chapter.name)
                                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                Spacer(minLength: 0)
                            }

                            Text(ceremony.heroLine)
                                .font(.system(.callout, design: .serif).italic())
                                .foregroundStyle(.white.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                    }
                    .scaleEffect(ceremonyIsAwake ? 1 : 0.97)
                    .opacity(ceremonyIsAwake ? 1 : 0.88)
                    .animation(.spring(response: 0.55, dampingFraction: 0.74), value: ceremonyIsAwake)

                    Text("Headmistress Thorne cups the air around the page, and somehow you feel the rings at your face: old ink, cool metal, the exact pressure of being read. The Great Hall fractures. Every kept page opens at once.")
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)

                    if !memoryFragments.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Your Life In The Fracture")
                                .font(.caption2.weight(.black))
                                .textCase(.uppercase)
                                .foregroundStyle(BookPalette.teal.opacity(0.86))
                            ForEach(memoryFragments.prefix(3), id: \.self) { fragment in
                                Text("\u{201C}\(fragment)\u{201D}")
                                    .font(.system(.caption, design: .serif).italic())
                                    .foregroundStyle(BookPalette.ink.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label(ceremony.sensoryLine, systemImage: ceremony.sensorySymbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ceremony.accent)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(chapter.philosophy)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(BookPalette.ink.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\u{201C}\(chapter.writeFraming)\u{201D}")
                            .font(.system(.caption, design: .serif).italic())
                            .foregroundStyle(BookPalette.ink.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let acceptance {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("The seal gives you work", systemImage: "seal.fill")
                                .font(.caption.weight(.black))
                                .textCase(.uppercase)
                                .foregroundStyle(ceremony.accent)

                            Text(acceptance.sealLine)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(BookPalette.ink.opacity(0.82))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(acceptance.oathLine)
                                .font(.system(.title3, design: .serif, weight: .bold))
                                .foregroundStyle(BookPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider()
                                .overlay(ceremony.accent.opacity(0.35))

                            Label("First Chapter invitation", systemImage: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.teal)
                            Text(acceptance.invitationLine)
                                .font(.callout)
                                .foregroundStyle(BookPalette.ink.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ceremony.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(ceremony.accent.opacity(0.28), lineWidth: 1)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.page.opacity(0.9), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ceremony.accent.opacity(0.48), lineWidth: 1.2)
                }
            }

            if !evidenceLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What the Binding read")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                    ForEach(evidenceLines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(line)
                        }
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button {
                acceptBinding()
            } label: {
                Label(
                    isAcceptingBinding
                        ? "Sealing the Binding..."
                        : (chosenChapter.map { "Accept \($0.name)'s Binding" } ?? "Accept the Binding"),
                    systemImage: "seal.fill"
                )
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(chosenChapter == nil || isAcceptingBinding)

            Text("The binding is real: your Chapter tints how Story Pages meet you, and its talisman warms with your Belief. The Book chose from kept pages and invested Belief, not from a preference quiz.")
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .overlay {
            if isAcceptingBinding {
                ChapterBindingAcceptedOverlay(
                    chapterName: chosenChapter?.name ?? "Chapter",
                    accent: ceremony.accent,
                    reduceMotion: reduceMotion
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .onAppear {
            revealCeremony()
        }
    }
}

private struct ChapterBindingCelebrationBurst: View {
    let accent: Color
    let isExpanded: Bool
    let reduceMotion: Bool

    private var palette: [Color] {
        [accent, BookPalette.lampGold, BookPalette.gold, BookPalette.paper.opacity(0.95), .white.opacity(0.86)]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<22, id: \.self) { index in
                    let offset = particleOffset(index: index, size: proxy.size)
                    Capsule(style: .continuous)
                        .fill(palette[index % palette.count])
                        .frame(
                            width: index.isMultiple(of: 3) ? 5 : 3,
                            height: index.isMultiple(of: 2) ? 24 : 15
                        )
                        .rotationEffect(.degrees(Double(index) * 23))
                        .scaleEffect(isExpanded ? 0.58 : 0.34)
                        .opacity(isExpanded ? 0 : 0.92)
                        .offset(
                            x: reduceMotion ? 0 : (isExpanded ? offset.width : 0),
                            y: reduceMotion ? 0 : (isExpanded ? offset.height : 0)
                        )
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.18)
                                : .easeOut(duration: 0.82).delay(Double(index) * 0.012),
                            value: isExpanded
                        )
                }

                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(accent.opacity(isExpanded ? 0 : 0.62), lineWidth: CGFloat(3 - index))
                        .frame(width: isExpanded ? proxy.size.width * (0.42 + CGFloat(index) * 0.18) : 40)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.18)
                                : .easeOut(duration: 0.72).delay(Double(index) * 0.06),
                            value: isExpanded
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.48)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func particleOffset(index: Int, size: CGSize) -> CGSize {
        let angle = (Double(index) / 22.0) * Double.pi * 2.0
        let radius = min(size.width, size.height) * (0.34 + CGFloat(index % 5) * 0.025)
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius * 0.62
        )
    }
}

private struct ChapterBindingAcceptedOverlay: View {
    let chapterName: String
    let accent: Color
    let reduceMotion: Bool

    @State private var sealPressed = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BookPalette.ink.opacity(0.78), accent.opacity(0.44)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.24))
                        .frame(width: sealPressed ? 118 : 86)
                    Circle()
                        .stroke(BookPalette.lampGold.opacity(0.82), lineWidth: 2)
                        .frame(width: sealPressed ? 138 : 92)
                    Image(systemName: "seal.fill")
                        .font(.system(size: sealPressed ? 58 : 42, weight: .black))
                        .foregroundStyle(BookPalette.lampGold)
                        .shadow(color: accent.opacity(0.5), radius: 18)
                }
                .scaleEffect(sealPressed ? 1 : 0.72)

                Text("\(chapterName) Bound")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(.white)
                Text("The seal holds.")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(BookPalette.lampGold.opacity(0.88))
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            let animation: Animation = reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(response: 0.38, dampingFraction: 0.58)
            withAnimation(animation) {
                sealPressed = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(chapterName) Bound. The seal holds.")
    }
}

private struct ChapterBindingCeremonyProfile {
    let chapterID: String?

    var accent: Color {
        switch chapterID {
        case "emberheart": Color(red: 0.86, green: 0.28, blue: 0.16)
        case "mossbloom": Color(red: 0.28, green: 0.56, blue: 0.34)
        case "tidecrest": Color(red: 0.16, green: 0.55, blue: 0.72)
        case "riddlewind": Color(red: 0.74, green: 0.55, blue: 0.18)
        case "duskthorn": Color(red: 0.42, green: 0.28, blue: 0.58)
        default: BookPalette.teal
        }
    }

    var gradient: LinearGradient {
        let dark = Color(red: 0.12, green: 0.09, blue: 0.12)
        return LinearGradient(
            colors: [dark, accent.opacity(0.86), BookPalette.ink.opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var heroLine: String {
        switch chapterID {
        case "emberheart": "Red ink races toward the place where your hand meets the pen."
        case "mossbloom": "Rain-dark soil breathes under the marble; something patient has been listening."
        case "tidecrest": "Moonlit water folds through the hall, sudden and complete."
        case "riddlewind": "A second voice finds yours in the dark and finishes the spell."
        case "duskthorn": "Violet thorns guard the edge where the story refuses to soften."
        default: "Ink, starlight, and impossible color gather at the binding."
        }
    }

    var sensoryLine: String {
        switch chapterID {
        case "emberheart": "Heat without flame. A door waiting for your choice."
        case "mossbloom": "Petrichor, old wood, and green persistence under the page."
        case "tidecrest": "Salt, streetlight, laughter, and the vivid present tense."
        case "riddlewind": "Cipher wind, shared breath, and the click of a solved lock."
        case "duskthorn": "Thorn-shadow, black glass, and the honest edge of protection."
        default: "The seal gathers from every story at once."
        }
    }

    var sensorySymbol: String {
        switch chapterID {
        case "emberheart": "flame.fill"
        case "mossbloom": "leaf.fill"
        case "tidecrest": "water.waves"
        case "riddlewind": "puzzlepiece.extension.fill"
        case "duskthorn": "theatermasks.fill"
        default: "seal.fill"
        }
    }
}

struct AnchorOfferFormView: View {
    let surface: SurfacePage
    let onAnchorPlace: (AnchorPlaceDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var anchorPlaceName = ""
    @State private var anchorPlaceWords = ""
    @State private var anchorPlaceKind: AnchorKind = .notice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sheetLabeledField("What is this place called?", text: $anchorPlaceName, placeholder: "The co-op, the back porch, the trailhead...")

            VStack(alignment: .leading, spacing: 6) {
                Text("WHAT DOES THIS PLACE HOLD?")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.teal.opacity(0.82))
                TextField(
                    "Not what it is — what it holds for you. Your exact words become the room.",
                    text: $anchorPlaceWords,
                    axis: .vertical
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .textFieldStyle(.plain)
                .lineLimit(2...5)
                .dictationInput(text: $anchorPlaceWords)
                .padding(10)
                .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("WHICH DIRECTION DOES IT POINT?")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.teal.opacity(0.82))
                Picker("Anchor kind", selection: $anchorPlaceKind) {
                    ForEach(AnchorKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                BookFeedback.play(.braidStart)
                let draft = AnchorPlaceDraft(
                    name: anchorPlaceName.trimmingCharacters(in: .whitespacesAndNewlines),
                    words: anchorPlaceWords.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: anchorPlaceKind,
                    latitude: Double(surface.payload.metadata["latitude"] ?? "") ?? 0,
                    longitude: Double(surface.payload.metadata["longitude"] ?? "") ?? 0
                )
                onAnchorPlace(draft)
                dismiss()
            } label: {
                Label("Anchor this place", systemImage: "mappin.and.ellipse")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(anchorPlaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("The Labyrinth will grow an Outer Stacks room from your words, and you can step inside the moment it is made. Location stays on your device.")
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.26), lineWidth: 1)
        }
    }

    private func sheetLabeledField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal.opacity(0.82))
            TextField(placeholder, text: text, axis: .vertical)
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .dictationInput(text: text)
                .padding(10)
                .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

struct ElectiveFlyleafListView: View {
    let ledger: FlyleafLedger
    let onCompleteElective: (String, String, String?, String?) -> Void
    let onReleaseElective: (String) -> Void
    let onOpenDoor: (FlyleafDoor) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var electiveProofDrafts: [String: String] = [:]
    @State private var proofPhotoURLs: [String: String] = [:]
    @State private var proofMessages: [String: String] = [:]
    @State private var locationProofSummaries: [String: String] = [:]
    @State private var verifyingLocationIDs: Set<String> = []
    @State private var completedElectiveIDs: Set<String> = []
    @State private var releaseCandidateID: String?

    private var activeElectives: [UnwrittenElective] {
        ledger.electives
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ledger.openThreadCount == 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Nothing is asking for you just now.", systemImage: "bookmark")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text("The empty space counts. A quest only lives here after you choose it, and every chosen note may be put to rest.")
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(BookPalette.page.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if !activeElectives.isEmpty {
                flyleafSectionTitle(
                    "Notes you chose",
                    detail: "\(activeElectives.count)/\(UnwrittenElective.maxActive) places in the binding"
                )
            }

            ForEach(activeElectives) { elective in
                VStack(alignment: .leading, spacing: 8) {
                    Text(elective.bookFavorID == nil ? "CHARACTER QUEST" : "BOOK FAVOR")
                        .font(.caption2.weight(.black))
                        .tracking(0.6)
                        .foregroundStyle(BookPalette.lampGold)
                    HStack(alignment: .firstTextBaseline) {
                        Text(elective.title)
                            .font(.callout.weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                        Spacer()
                        Text(elective.characterName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(BookPalette.teal)
                    }
                    Text(elective.ask)
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Counts as done: \(elective.practiceShape)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                    if let place = elective.targetPlaceName {
                        Label("GPS target: \(place)", systemImage: "location")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BookPalette.teal.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    TextField(
                        "Sentence proof...",
                        text: Binding(
                            get: { electiveProofDrafts[elective.id] ?? "" },
                            set: { electiveProofDrafts[elective.id] = $0 }
                        ),
                        axis: .vertical
                    )
                    .font(.callout)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .dictationInput(text: Binding(
                        get: { electiveProofDrafts[elective.id] ?? "" },
                        set: { electiveProofDrafts[elective.id] = $0 }
                    ))
                    .padding(8)
                    .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    HStack(spacing: 8) {
                        PhotosPicker(
                            selection: Binding(
                                get: { nil },
                                set: { item in
                                    guard let item else { return }
                                    Task { await loadQuestProofPhoto(from: item, electiveID: elective.id) }
                                }
                            ),
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label(
                                proofPhotoURLs[elective.id] == nil ? "Photo proof" : "Photo ready",
                                systemImage: proofPhotoURLs[elective.id] == nil ? "camera" : "checkmark.circle.fill"
                            )
                            .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.gold)

                        Button {
                            Task { await verifyLocationProof(for: elective) }
                        } label: {
                            Label(
                                verifyingLocationIDs.contains(elective.id) ? "Checking..." : locationProofSummaries[elective.id] == nil ? "GPS proof" : "GPS ready",
                                systemImage: locationProofSummaries[elective.id] == nil ? "location.magnifyingglass" : "location.fill"
                            )
                            .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.teal)
                        .disabled(elective.targetLatitude == nil || verifyingLocationIDs.contains(elective.id))
                    }

                    #if canImport(UIKit)
                    if let rawURL = proofPhotoURLs[elective.id],
                       let url = URL(string: rawURL),
                       let image = UIImage(contentsOfFile: url.path) {
                        HStack(spacing: 10) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(BookPalette.paper.opacity(0.9), lineWidth: 2)
                                }
                                .bookPhotographArrival(reduceMotion: reduceMotion)

                            Label("Evidence placed in the flyleaf", systemImage: "checkmark.seal")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BookPalette.teal)
                        }
                        .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))
                    }
                    #endif

                    if let message = proofMessages[elective.id] {
                        Text(message)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(message.contains("GPS says") ? BookPalette.gold : BookPalette.ink.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        Button {
                            let proof = (electiveProofDrafts[elective.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            let photoURL = proofPhotoURLs[elective.id]
                            let locationSummary = locationProofSummaries[elective.id]
                            guard !proof.isEmpty || photoURL != nil || locationSummary != nil else { return }
                            BookFeedback.play(.keepPage)
                            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.68)) {
                                completedElectiveIDs.insert(elective.id)
                            }
                            onCompleteElective(elective.id, proof, photoURL, locationSummary)
                        } label: {
                            Label(
                                completedElectiveIDs.contains(elective.id) ? "Completed" : "Complete with proof",
                                systemImage: completedElectiveIDs.contains(elective.id) ? "checkmark.seal.fill" : "checkmark.seal"
                            )
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.teal)
                        .disabled(
                            completedElectiveIDs.contains(elective.id) ||
                            !hasAnyProof(for: elective.id)
                        )

                        Button {
                            BookFeedback.play(.select)
                            releaseCandidateID = elective.id
                        } label: {
                            Label("Let rest", systemImage: "moon.zzz")
                                .font(.caption.weight(.bold))
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.ink.opacity(0.72))
                        .disabled(completedElectiveIDs.contains(elective.id))
                    }
                }
                .padding(12)
                .background(BookPalette.page.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.teal.opacity(completedElectiveIDs.contains(elective.id) ? 0.62 : 0.22), lineWidth: completedElectiveIDs.contains(elective.id) ? 1.6 : 1)
                }
                .overlay(alignment: .topTrailing) {
                    if completedElectiveIDs.contains(elective.id) {
                        Label("KEPT", systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(BookPalette.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(BookPalette.teal.opacity(0.12), in: Capsule())
                            .padding(9)
                            .transition(.scale(scale: 0.55).combined(with: .opacity))
                            .accessibilityLabel("Elective completed and kept")
                    }
                }
                .opacity(completedElectiveIDs.contains(elective.id) && !reduceMotion ? 0.82 : 1)
                .scaleEffect(completedElectiveIDs.contains(elective.id) && !reduceMotion ? 0.985 : 1)
                .animation(BookMotion.result(reduceMotion), value: proofPhotoURLs[elective.id])
            }

            if !ledger.doors.isEmpty {
                flyleafSectionTitle(
                    "Other open doors",
                    detail: "These live in their own parts of the Book. The flyleaf only remembers the way back."
                )
                .padding(.top, activeElectives.isEmpty ? 0 : 4)

                ForEach(ledger.doors) { door in
                    flyleafDoorCard(door)
                }
            }
        }
        .confirmationDialog(
            "Let this note rest?",
            isPresented: Binding(
                get: { releaseCandidateID != nil },
                set: { if !$0 { releaseCandidateID = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let releaseCandidateID {
                Button("Let it rest") {
                    BookFeedback.play(.dismissPage)
                    onReleaseElective(releaseCandidateID)
                    self.releaseCandidateID = nil
                }
                Button("Keep it tucked", role: .cancel) {
                    self.releaseCandidateID = nil
                }
            }
        } message: {
            Text("No proof is needed. It will free its place in the binding and will not count as completed.")
        }
    }

    private func flyleafSectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(0.8)
                .foregroundStyle(BookPalette.teal)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func flyleafDoorCard(_ door: FlyleafDoor) -> some View {
        Button {
            BookFeedback.play(.openPage)
            onOpenDoor(door)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(door.eyebrow, systemImage: symbolName(for: door.kind))
                        .font(.caption2.weight(.black))
                        .tracking(0.45)
                        .foregroundStyle(BookPalette.lampGold)
                    Spacer()
                }
                Text(door.title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                Text(door.detail)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                Text(door.statusLine)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Text(door.actionTitle)
                    Image(systemName: "arrow.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(BookPalette.page.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(door.eyebrow), \(door.title). \(door.statusLine). \(door.actionTitle)")
    }

    private func symbolName(for kind: FlyleafDoorKind) -> String {
        switch kind {
        case .bookJump: return "books.vertical"
        case .compassRun: return "safari"
        case .faeBargain: return "sparkles"
        case .pactErrand: return "map"
        }
    }

    private func hasAnyProof(for electiveID: String) -> Bool {
        !(electiveProofDrafts[electiveID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        proofPhotoURLs[electiveID] != nil ||
        locationProofSummaries[electiveID] != nil
    }

    @MainActor
    private func setProofMessage(_ message: String, electiveID: String) {
        proofMessages[electiveID] = message
    }

    private func loadQuestProofPhoto(from item: PhotosPickerItem, electiveID: String) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await setProofMessage("The photo could not be read.", electiveID: electiveID)
            return
        }
        do {
            let url = try saveQuestProofPhotoData(data)
            await MainActor.run {
                withAnimation(BookMotion.result(reduceMotion)) {
                    proofPhotoURLs[electiveID] = url.absoluteString
                    proofMessages[electiveID] = "Photo proof ready."
                }
                BookFeedback.play(.openPage)
            }
        } catch {
            await setProofMessage("The photo could not be saved.", electiveID: electiveID)
        }
    }

    private func verifyLocationProof(for elective: UnwrittenElective) async {
        await MainActor.run { verifyingLocationIDs.insert(elective.id) }
        let result = await QuestLocationProof.verify(elective: elective)
        await MainActor.run {
            verifyingLocationIDs.remove(elective.id)
            proofMessages[elective.id] = result.summary
            if result.success {
                locationProofSummaries[elective.id] = result.summary
            }
        }
    }

    private func saveQuestProofPhotoData(_ data: Data) throws -> URL {
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("QuestProofs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("quest-proof-\(UUID().uuidString).jpg")
        guard let jpeg = PressedPhotograph.downscaledJPEG(from: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try jpeg.write(to: url, options: [.atomic])
        return url
    }
}

struct SupportGuildSectionView: View {
    let surface: SurfacePage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(surface.payload.body)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            supportGuildDisclosure("Dr. Vellum", systemImage: "heart.text.square", value: surface.payload.metadata["vellumSection"])
            supportGuildDisclosure("Dr. Inkrest", systemImage: "cloud.sun", value: surface.payload.metadata["inkrestSection"])
            supportGuildDisclosure("Connections", systemImage: "point.3.connected.trianglepath.dotted", value: surface.payload.metadata["connectionsSection"])
            supportGuildDisclosure("Experiment", systemImage: "checklist", value: surface.payload.metadata["experimentSection"])
            supportGuildDisclosure("Safety", systemImage: "lock.shield", value: surface.payload.metadata["safetySection"])
        }
    }

    @ViewBuilder
    private func supportGuildDisclosure(_ title: String, systemImage: String, value: String?) -> some View {
        if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            DisclosureGroup {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            } label: {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }
            .padding(10)
            .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
            }
        }
    }
}
