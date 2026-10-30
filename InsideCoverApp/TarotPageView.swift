import SwiftUI

/// One physical card face, shared by readings, interleaves and the existing
/// full-screen artifact inspector. Typography stays live and consistent.
struct TarotCardFace: View {
    let card: TarotCardDefinition

    private var title: String {
        guard card.arcana == .major,
              let number = Int(card.id.replacingOccurrences(of: "major-", with: "")),
              (0...21).contains(number) else { return card.name }
        let numerals = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"]
        return "\(numerals[number]) · \(card.name)"
    }

    var body: some View {
        GeometryReader { proxy in
            let inset = max(3, proxy.size.width * 0.018)
            VStack(spacing: 0) {
                illustration
                Text(title)
                    .font(.system(size: max(12, proxy.size.width * 0.054), weight: .semibold, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity)
                    .frame(height: proxy.size.height * 0.085)
                    .padding(.horizontal, inset * 2)
            }
            .padding(inset)
            .background(BookPalette.page)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.35), lineWidth: max(0.6, proxy.size.width * 0.002))
                    .padding(inset)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .aspectRatio(7.0 / 12.0, contentMode: .fit)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.name)
        .accessibilityValue(TarotDeck.marginalia(for: card.id)?.accessibleDescription ?? "")
    }

    private var illustration: some View {
        GeometryReader { available in
            let width = min(available.size.width, available.size.height * 7 / 12)
            let height = width * 12 / 7
            ZStack(alignment: .topLeading) {
                Image(card.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
                if let margin = TarotDeck.marginalia(for: card.id) {
                    Text(margin.label)
                        .font(.custom("BradleyHandITCTT-Bold", fixedSize: width * CGFloat(margin.labelFontWidthRatio)))
                        .foregroundStyle(BookPalette.ink.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: width * CGFloat(margin.labelWidth), alignment: .leading)
                        .background {
                            if margin.labelOnPaper {
                                BookPalette.page.opacity(0.96)
                                    .padding(-width * 0.008)
                                    .blur(radius: width * 0.006)
                            }
                        }
                        .rotationEffect(.degrees(margin.labelRotation), anchor: .topLeading)
                        .offset(x: width * CGFloat(margin.labelX), y: height * CGFloat(margin.labelY))
                    Text(margin.note)
                        .font(.custom("BradleyHandITCTT-Bold", fixedSize: width * 0.052))
                        .foregroundStyle(BookPalette.ink.opacity(0.86))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .rotationEffect(.degrees(-1), anchor: .leading)
                        .frame(width: width * CGFloat(margin.noteWidth),
                               height: height * min(0.075, 1 - CGFloat(margin.noteY)),
                               alignment: .topLeading)
                        .offset(x: width * CGFloat(margin.noteX), y: height * CGFloat(margin.noteY))
                    ForEach(margin.additional.indices, id: \.self) { index in
                        additionalAnnotation(margin.additional[index], width: width, height: height)
                    }
                }
            }
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func additionalAnnotation(_ annotation: TarotDeck.Marginalia.Annotation,
                                      width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if let first = annotation.leader.first, let last = annotation.leader.last {
                Path { path in
                    path.move(to: CGPoint(x: width * CGFloat(first.x), y: height * CGFloat(first.y)))
                    for point in annotation.leader.dropFirst() {
                        path.addLine(to: CGPoint(x: width * CGFloat(point.x), y: height * CGFloat(point.y)))
                    }
                }
                .stroke(BookPalette.ink.opacity(0.55), lineWidth: max(0.4, width * 0.00125))
                Circle()
                    .fill(BookPalette.ink.opacity(0.55))
                    .frame(width: width * 0.003, height: width * 0.003)
                    .position(x: width * CGFloat(last.x), y: height * CGFloat(last.y))
            }
            Text(annotation.text)
                .font(annotation.isInscription
                      ? .system(size: width * CGFloat(annotation.fontWidthRatio), weight: .regular, design: .serif)
                      : .custom("BradleyHandITCTT-Bold", fixedSize: width * CGFloat(annotation.fontWidthRatio)))
                .foregroundStyle(BookPalette.ink.opacity(0.78))
                .lineLimit(annotation.maxLines)
                .minimumScaleFactor(0.75)
                .frame(width: width * CGFloat(annotation.width), alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    if annotation.onPaper {
                        BookPalette.page.opacity(0.94)
                            .padding(-width * 0.008)
                            .blur(radius: width * 0.006)
                    }
                }
                .rotationEffect(.degrees(annotation.rotation), anchor: .topLeading)
                .offset(x: width * CGFloat(annotation.x), y: height * CGFloat(annotation.y))
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// Paired, rotated impressions make the back exactly orientation-neutral,
/// including its paper wear. A generated pattern alone cannot guarantee that.
struct TarotCardBack: View {
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ForEach(0..<2, id: \.self) { half in
                    Image("TarotBackUnwritten")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height / 2)
                        .clipped()
                        .rotationEffect(.degrees(Double(half) * 180))
                }
            }
            .background(Color(red: 0.16, green: 0.10, blue: 0.22))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.85), lineWidth: 1.5)
                    .padding(proxy.size.width * 0.045)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .aspectRatio(7.0 / 12.0, contentMode: .fit)
        .accessibilityLabel("The Unwritten Deck, face down")
    }
}

struct TarotPageView: View {
    @Binding var reading: TarotReadingArtifact?
    let isReadOnly: Bool
    let localBrainIsReady: Bool
    let isLocalBrainWorking: Bool
    let onRequestSerenityReading: (TarotReadingArtifact, Bool) async -> TarotReadingArtifact

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FolioPageState("heldQuestion") private var heldQuestion = ""
    @FolioPageState("revealedCount") private var revealedCount = 0
    @FolioPageState("isAskingSerenity") private var isAskingSerenity = false
    @FolioPageState("readingMessage") private var readingMessage = ""
    @FolioPageState("showContextReceipt") private var showContextReceipt = false
    @FolioPageState("didSeedTarotPage") private var didSeedTarotPage = false

    var body: some View {
        FolioControlStack(alignment: .leading, spacing: 20) {
            hostNote

            if let reading {
                readingView(reading)
            } else {
                unopenedDeck
            }

            Text("The Unwritten Deck · after Pamela Colman Smith")
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .accessibilityLabel("The Unwritten Deck. Based on Pamela Colman Smith’s Rider–Waite–Smith illustrations.")
        }
        .onAppear {
            guard !didSeedTarotPage else { return }
            didSeedTarotPage = true
            if let reading {
                heldQuestion = reading.question
                revealedCount = isReadOnly ? reading.cards.count : 0
            }
        }
        .onChange(of: reading) { _, newReading in
            guard let newReading else { return }
            heldQuestion = newReading.question
            if isReadOnly {
                revealedCount = newReading.cards.count
            }
        }
        // The app's surrounding chrome lives in Dark Mode, but Tarot is an
        // ink-on-parchment ceremony. Give the whole ceremony an opaque paper
        // field so unboxed headings and prompts never become dark-on-dark, and
        // let native controls resolve their insertion point and placeholder as
        // light-surface controls instead of inheriting the app-wide night mode.
        .padding(18)
        .foregroundStyle(BookPalette.ink)
        .tint(BookPalette.violet)
        .background(
            BookPalette.page,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.18), lineWidth: 1)
        }
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }

    private var hostNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("LabyrinthCharacterSerenityBrown")
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(BookPalette.violet.opacity(0.28), lineWidth: 1)
                }
                .accessibilityLabel("Serenity Brown")

            FolioControlStack(alignment: .leading, spacing: 3) {
                Text("SERENITY READS BESIDE YOU")
                    .font(.caption2.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(BookPalette.ink)
                Text("The cards aren’t a verdict. Notice the image first; keep only what feels honestly useful.")
                    .font(.subheadline)
                    .foregroundStyle(BookPalette.ink.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(BookPalette.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
        }
    }

    private var unopenedDeck: some View {
        FolioControlStack(alignment: .leading, spacing: 18) {
            tarotCardBack
                .frame(width: 150, height: 252)
                .frame(maxWidth: .infinity)
                .shadow(color: BookPalette.ink.opacity(0.22), radius: 16, y: 10)

            FolioControlStack(alignment: .leading, spacing: 7) {
                Text("Hold something lightly")
                    .font(.headline)
                    .foregroundStyle(BookPalette.ink)
                TextField("A question, situation, or nothing at all", text: $heldQuestion, axis: .vertical)
                    .textFieldStyle(.plain)
                    .folioControlUnbroken()
                    .inkFeedback(text: heldQuestion)
                    .foregroundStyle(BookPalette.ink)
                    .padding(13)
                    .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(BookPalette.violet.opacity(0.20), lineWidth: 1)
                    }
            }

            ForEach(TarotSpread.allCases, id: \.rawValue) { spread in
                Button {
                    draw(spread)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: spread == .oneCard ? "rectangle.portrait" : "rectangle.portrait.on.rectangle.portrait.angled")
                            .font(.title3)
                            .frame(width: 28)
                        FolioControlStack(alignment: .leading, spacing: 2) {
                            Text(spread.title)
                                .font(.headline)
                            Text(spread.subtitle)
                                .font(.caption)
                                .opacity(0.78)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(BookPalette.ink)
                    .padding(14)
                    .background(BookPalette.lampGold.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .folioControlUnbroken()
            }

            Text("78 cards · drawn on this device · no card is chosen by AI")
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.56))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func readingView(_ artifact: TarotReadingArtifact) -> some View {
        FolioControlStack(alignment: .leading, spacing: 22) {
            FolioControlStack(alignment: .leading, spacing: 4) {
                Text(artifact.spread.title.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(BookPalette.ink)
                if !artifact.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Held lightly: \(artifact.question)")
                        .font(.subheadline.italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                }
            }

            ForEach(Array(artifact.cards.enumerated()), id: \.element.id) { index, drawn in
                cardPlace(drawn, isRevealed: index < revealedCount)
                    .onTapGesture {
                        guard !isReadOnly, index == revealedCount else { return }
                        revealNext()
                    }
            }

            if !isReadOnly, revealedCount < artifact.cards.count {
                Button {
                    revealNext()
                } label: {
                    Label(
                        revealedCount == 0 ? "Turn the first card" : "Turn the next card",
                        systemImage: "hand.tap"
                    )
                    .font(.headline)
                    .foregroundStyle(BookPalette.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(BookPalette.violet, in: Capsule())
                }
                .buttonStyle(.plain)
                .folioControlUnbroken()
            }

            if revealedCount == artifact.cards.count {
                serenityReadingSection(artifact)
                readerNotes

                if !isReadOnly {
                    Button("Gather the cards and begin again") {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            reading = nil
                            revealedCount = 0
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.violet)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func cardPlace(_ drawn: TarotDrawnCard, isRevealed: Bool) -> some View {
        let card = TarotDeck.card(id: drawn.cardID)
        FolioControlStack(alignment: .leading, spacing: 12) {
            FolioControlStack(alignment: .leading, spacing: 3) {
                Text(drawn.position.title.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(BookPalette.ink)
                Text(drawn.position.prompt)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
            }

            Group {
                if isRevealed, let card {
                    TarotCardFace(card: card)
                        .rotationEffect(drawn.isReversed ? .degrees(180) : .zero)
                        .accessibilityLabel("\(card.name)\(drawn.isReversed ? ", reversed" : "")")
                        .tarotCardPreviewOnTap(card, isReversed: drawn.isReversed)
                } else {
                    tarotCardBack
                        .accessibilityLabel("Face-down tarot card")
                }
            }
            .aspectRatio(7.0 / 12.0, contentMode: .fit)
            .frame(maxWidth: 254)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: BookPalette.ink.opacity(0.20), radius: 14, y: 8)
            .frame(maxWidth: .infinity)

            if isRevealed, let card {
                FolioControlStack(alignment: .leading, spacing: 9) {
                    Text(card.name)
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(card.keywords.joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.78))
                    Text(card.lightMeaning)
                        .font(.body)
                        .foregroundStyle(BookPalette.ink.opacity(0.80))
                    Text("Worn edge: \(card.shadowMeaning)")
                        .font(.subheadline)
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                    if let fieldNote = reading?.revealProse?[drawn.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !fieldNote.isEmpty {
                        Divider()
                            .overlay(BookPalette.ink.opacity(0.18))
                        Text("A NOTE IN THE MARGIN")
                            .font(.caption2.weight(.black))
                            .tracking(1)
                            .foregroundStyle(BookPalette.ink.opacity(0.72))
                        Text(fieldNote)
                            .font(.subheadline.italic())
                            .foregroundStyle(BookPalette.ink.opacity(0.82))
                    }
                }
                .padding(15)
                .background(BookPalette.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                }
            } else {
                Text("It is face-down and listening. Tap when you want it caught.")
                    .font(.caption.italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.54))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func serenityReadingSection(_ artifact: TarotReadingArtifact) -> some View {
        FolioControlStack(alignment: .leading, spacing: 12) {
            if let prose = artifact.castReading?.trimmingCharacters(in: .whitespacesAndNewlines),
               !prose.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                    Text("SERENITY BROWN READ BESIDE YOU")
                        .font(.caption.weight(.black))
                        .tracking(1)
                }
                .foregroundStyle(BookPalette.ink)
                Text(prose)
                    .font(.body)
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                if let receipt = artifact.contextReceipt, !receipt.sources.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showContextReceipt.toggle()
                        }
                    } label: {
                        Label(
                            showContextReceipt ? "Hide what Serenity read" : "See what Serenity read",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink)
                    }
                    .buttonStyle(.plain)
                    .folioControlUnbroken()

                    if showContextReceipt {
                        contextReceipt(receipt)
                    }
                }
            } else if !isReadOnly {
                Text("Serenity can read only the cards, or (with your say-so) read beside a few recent Pages the Stacks finds connected.")
                    .font(.subheadline)
                    .foregroundStyle(BookPalette.ink.opacity(0.72))

                Button {
                    requestSerenityReading(includeArchive: false)
                } label: {
                    serenityButtonLabel("Let Serenity read the cards", symbol: "map")
                }
                .buttonStyle(.plain)
                .folioControlUnbroken()
                .disabled(isAskingSerenity || isLocalBrainWorking || !localBrainIsReady)

                Button {
                    requestSerenityReading(includeArchive: true)
                } label: {
                    serenityButtonLabel("Read beside my recent Pages", symbol: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(.plain)
                .folioControlUnbroken()
                .disabled(isAskingSerenity || isLocalBrainWorking || !localBrainIsReady)

                if !localBrainIsReady {
                    Text("Serenity needs my private mind installed for a full reading. The card notes above stay local and work without it.")
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.64))
                } else if !readingMessage.isEmpty {
                    Text(readingMessage)
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                }
            }
        }
        .padding(16)
        .background(BookPalette.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.18), lineWidth: 1)
        }
    }

    private func serenityButtonLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            if isAskingSerenity {
                ProgressView()
                    .tint(BookPalette.paper)
            } else {
                Image(systemName: symbol)
            }
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(BookPalette.paper)
        .padding(14)
        .background(BookPalette.violet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func contextReceipt(_ receipt: TarotReadingContextReceipt) -> some View {
        FolioControlStack(alignment: .leading, spacing: 10) {
            Text("\(receipt.sources.count) SOURCES · \(receipt.edges.count) EDGES")
                .font(.caption2.weight(.black))
                .tracking(0.9)
                .foregroundStyle(BookPalette.ink.opacity(0.72))
            ForEach(receipt.sources) { source in
                FolioControlStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink)
                    Text("\(source.dateLabel) · \(source.kind)")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                    Text(source.excerpt)
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.74))
                        .lineLimit(3)
                }
            }
            if !receipt.edges.isEmpty {
                Text("The Stacks also kept the \(receipt.edges.count) labeled connection\(receipt.edges.count == 1 ? "" : "s") that helped these Pages rise together.")
                    .font(.caption2.italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
            }
        }
        .padding(12)
        .background(BookPalette.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var readerNotes: some View {
        FolioControlStack(alignment: .leading, spacing: 18) {
            readingEditor(
                title: "Before the field notes",
                prompt: "What did you notice first?",
                placeholder: "A color, gesture, object, feeling…",
                text: Binding(
                    get: { reading?.firstLook ?? "" },
                    set: { reading?.firstLook = $0 }
                )
            )
            readingEditor(
                title: "What you’re carrying",
                prompt: "What feels useful, not certain, just useful?",
                placeholder: "One sentence is enough.",
                text: Binding(
                    get: { reading?.reflection ?? "" },
                    set: { reading?.reflection = $0 }
                )
            )
        }
    }

    private func readingEditor(
        title: String,
        prompt: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        FolioControlStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(1.1)
                .foregroundStyle(BookPalette.ink)
            Text(prompt)
                .font(.headline)
                .foregroundStyle(BookPalette.ink)
            if isReadOnly {
                Text(text.wrappedValue.isEmpty ? "No note was kept here." : text.wrappedValue)
                    .font(.body)
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .padding(.top, 3)
            } else {
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(2...6)
                    .inkFeedback(text: text.wrappedValue)
                    .textFieldStyle(.plain)
                    .folioControlUnbroken()
                    .foregroundStyle(BookPalette.ink)
                    .padding(13)
                    .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(BookPalette.violet.opacity(0.20), lineWidth: 1)
                    }
            }
        }
    }

    private var tarotCardBack: some View {
        TarotCardBack()
    }

    private func draw(_ spread: TarotSpread) {
        var artifact = TarotDrawEngine.draw(spread: spread)
        artifact.question = heldQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        artifact = TarotLocalInterpreter.fillReveals(in: artifact)
        reading = artifact
        revealedCount = 0
        BookFeedback.play(.openPage)
    }

    private func requestSerenityReading(includeArchive: Bool) {
        guard let current = reading, !isAskingSerenity else { return }
        isAskingSerenity = true
        readingMessage = includeArchive
            ? "The Stacks are finding the Pages that answer this spread…"
            : "Serenity is looking at the cards together…"
        Task {
            let result = await onRequestSerenityReading(current, includeArchive)
            await MainActor.run {
                reading = result
                isAskingSerenity = false
                readingMessage = result.castReading?.isEmpty == false
                    ? ""
                    : "Serenity couldn’t finish the reading. The cards and your notes are still here."
                BookFeedback.play(result.castReading?.isEmpty == false ? .openPage : .error)
            }
        }
    }

    private func revealNext() {
        guard let reading, revealedCount < reading.cards.count else { return }
        TarotEditionEncounterStore.shared.record(.reading(reading, card: reading.cards[revealedCount]))
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82)) {
            revealedCount += 1
        }
        BookFeedback.play(.openPage)
    }
}
