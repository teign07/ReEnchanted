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
                        .font(BookHand.book.font(fixedSize: width * CGFloat(margin.labelFontWidthRatio)))
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
                        .font(BookHand.book.font(fixedSize: width * 0.052))
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
                      : BookHand.book.font(fixedSize: width * CGFloat(annotation.fontWidthRatio)))
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

/// A small working deck. Its gesture shuffles the same order the draw consumes.
/// Motion stays inside the object; no timer or repeated idle animation runs.
private struct TarotDeckPile: View {
    let shuffleBeat: Int
    let onShuffle: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var grip = CGSize.zero
    @State private var split: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = min(142, proxy.size.width * 0.44)
            ZStack {
                ForEach(0..<7) { index in
                    let step = CGFloat(index - 3)
                    let packet: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                    TarotCardBack()
                        .frame(width: width, height: width * 12 / 7)
                        .shadow(color: BookPalette.ink.opacity(0.15), radius: 3, y: 2)
                        .rotationEffect(.degrees(Double(step) * 3 + Double(split * packet * 5)))
                        .offset(
                            x: step * width * 0.065 + split * packet * width * 0.22 + (reduceMotion ? 0 : grip.width * 0.12),
                            y: abs(step) * 2 - split * abs(step) * 4 + (reduceMotion ? 0 : grip.height * 0.12)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: 280)
        .frame(height: 272)
        .contentShape(Rectangle())
        .onTapGesture(perform: onShuffle)
        .gesture(
            DragGesture(minimumDistance: 18)
                .updating($grip) { value, state, _ in state = value.translation }
                .onEnded { value in
                    if max(abs(value.translation.width), abs(value.translation.height)) > 24 {
                        onShuffle()
                    }
                }
        )
        .task(id: shuffleBeat) {
            guard shuffleBeat > 0, !reduceMotion else { split = 0; return }
            withTransaction(Transaction(animation: nil)) { split = 0 }
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.16)) { split = 1 }
            do { try await Task.sleep(for: .milliseconds(170)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.40, dampingFraction: 0.76)) { split = 0 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shuffle the Unwritten Deck")
        .accessibilityValue(shuffleBeat == 0 ? "Ready to draw" : "Shuffled")
        .accessibilityHint("Double-tap to mix the cards. Shuffling is optional.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onShuffle() }
    }
}

/// The visible face changes at the edge of the turn, never at its beginning.
/// An animatable value also makes an interrupted turn settle on the right face.
private struct TarotCardTurn: View, Animatable {
    let card: TarotCardDefinition?
    let isReversed: Bool
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let turn = card == nil ? 0 : min(1, max(0, progress))
        let lift = sin(turn * .pi)
        ZStack {
            TarotCardBack()
                .opacity(turn < 0.5 ? 1 : 0)
            if let card {
                TarotCardFace(card: card)
                    .rotationEffect(isReversed ? .degrees(180) : .zero)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(turn >= 0.5 ? 1 : 0)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(BookPalette.page.opacity(lift * 0.8), lineWidth: 1.5)
        }
        .rotation3DEffect(.degrees(turn * 180), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
        .scaleEffect(1 + lift * 0.035)
        .offset(y: -lift * 9)
        .shadow(color: BookPalette.ink.opacity(0.16 + lift * 0.12), radius: 7 + lift * 9, y: 5 + lift * 7)
        .accessibilityHidden(true)
    }
}

/// A face-down card can be tapped or lifted from its lower corner. Keeping the
/// drag on that small handle leaves ordinary Book page turns outside it alone.
private struct TarotCardInHand: View {
    let drawn: TarotDrawnCard
    let isRevealed: Bool
    let canTurn: Bool
    let onTurn: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var cornerLift: CGFloat = 0

    private var card: TarotCardDefinition? { TarotDeck.card(id: drawn.cardID) }

    private var surface: some View {
        TarotCardTurn(
            card: card, isReversed: drawn.isReversed,
            progress: isRevealed ? 1 : (reduceMotion ? 0 : Double(cornerLift) * 0.42)
        )
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.80), value: cornerLift == 0)
        .animation(reduceMotion ? nil : .timingCurve(0.22, 0.68, 0.18, 1, duration: 0.62), value: isRevealed)
    }

    var body: some View {
        // Keep the animated surface at the same structural identity. Replacing
        // a Button with a preview here would replace it with an already-turned
        // face and swallow the flip animation.
        surface
            .overlay {
                if isRevealed, let card {
                    Color.clear.tarotCardPreviewOnTap(card, isReversed: drawn.isReversed)
                } else {
                    Button(action: onTurn) { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .disabled(!canTurn)
                        .accessibilityLabel("Turn the \(drawn.position.title.lowercased()) card")
                        .accessibilityValue(canTurn ? "Face down" : "Waiting its turn")
                        .accessibilityHint("Double-tap to turn it over.")
                        .overlay(alignment: .bottomTrailing) {
                            if canTurn {
                                Image(systemName: "arrow.up.left")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BookPalette.page)
                                    .frame(width: 52, height: 44)
                                    .background(BookPalette.ink.opacity(0.22), in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomTrailingRadius: 10))
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 8)
                                            .updating($cornerLift) { value, state, _ in
                                                state = min(1, max(0, -value.translation.height / 78))
                                            }
                                            .onEnded { value in
                                                if value.translation.height < -32 { onTurn() }
                                            }
                                    )
                                    .accessibilityHidden(true)
                            }
                        }
                }
            }
            .aspectRatio(7.0 / 12.0, contentMode: .fit)
            .frame(maxWidth: 254)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .folioControlUnbroken()
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
    @FolioPageState("tarotShuffledCardIDs") private var shuffledCardIDs: [String] = []
    @FolioPageState("tarotShuffleBeat") private var shuffleBeat = 0
    @FolioPageState("tarotDealProgress") private var dealProgress: CGFloat = 1
    @FolioPageState("tarotGathering") private var isGathering = false
    @FolioPageState("tarotExpandedCardIDs") private var expandedCardIDs: Set<String> = []
    @FolioPageState("tarotFirstLookOpen") private var firstLookOpen = false
    @FolioPageState("tarotReflectionOpen") private var reflectionOpen = false
    @FolioPageState("tarotSerenityOpen") private var serenityOpen = false
    @FolioPageState("tarotSerenityRequestID") private var serenityRequestID: String?

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
                Text("“Have a look. I can wait.”")
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
            TarotDeckPile(shuffleBeat: shuffleBeat, onShuffle: shuffleDeck)
                .frame(maxWidth: .infinity)
                .folioControlUnbroken()

            Button(shuffleBeat == 0 ? "Shuffle the deck" : "Shuffle again", action: shuffleDeck)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BookPalette.violet)
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .folioControlUnbroken()

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

            Text("Chance chooses the cards. You decide what fits.")
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
                cardPlace(drawn, isRevealed: index < revealedCount, canTurn: !isReadOnly && index == revealedCount && !isGathering)
                    .opacity(dealProgress)
                    .offset(x: (1 - dealProgress) * (index.isMultiple(of: 2) ? -20 : 20), y: (1 - dealProgress) * -36)
                    .rotationEffect(.degrees(Double(1 - dealProgress) * (index.isMultiple(of: 2) ? -5 : 5)))
                    .animation(dealingAnimation(at: index), value: dealProgress)
            }

            if !isReadOnly, revealedCount < artifact.cards.count {
                Button(action: revealNext) {
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
                .disabled(isGathering)
                .folioControlUnbroken()
            }

            if revealedCount == artifact.cards.count {
                firstLookNotes
                serenityReadingSection(artifact)
                carryingNotes

                if !isReadOnly {
                    Button("Gather the cards and begin again", action: gatherCards)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.violet)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .buttonStyle(.plain)
                        .disabled(isGathering)
                        .folioControlUnbroken()
                }
            }
        }
    }

    private func cardPlace(_ drawn: TarotDrawnCard, isRevealed: Bool, canTurn: Bool) -> some View {
        let card = TarotDeck.card(id: drawn.cardID)
        let notesOpen = expandedCardIDs.contains(drawn.id)
        return FolioControlStack(alignment: .leading, spacing: 14) {
            FolioControlStack(alignment: .leading, spacing: 3) {
                Text(drawn.position.title.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(BookPalette.ink)
                Text(drawn.position.prompt)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
            }

            TarotCardInHand(drawn: drawn, isRevealed: isRevealed, canTurn: canTurn, onTurn: revealNext)

            if isRevealed, let card {
                noteFold(notesOpen ? "Fold the card notes away" : "Read the card", isOpen: notesOpen) {
                    if notesOpen { expandedCardIDs.remove(drawn.id) }
                    else { expandedCardIDs.insert(drawn.id) }
                }
                if notesOpen {
                    cardNotes(card, drawn: drawn)
                }
            } else if canTurn {
                Text("Lift the corner, or tap. It has kept its face to itself long enough.")
                    .font(.caption.italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.64))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func cardNotes(_ card: TarotCardDefinition, drawn: TarotDrawnCard) -> some View {
        FolioControlStack(alignment: .leading, spacing: 12) {
            Text(card.keywords.joined(separator: " · "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.72))
            Text(card.lightMeaning)
                .font(.body)
            Text("Worn edge: \(card.shadowMeaning)")
                .font(.subheadline)
                .foregroundStyle(BookPalette.ink.opacity(0.68))
            if let note = reading?.revealProse?[drawn.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(note)
                    .font(.subheadline.italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle().fill(BookPalette.lampGold.opacity(0.55)).frame(width: 2)
        }
    }

    private func noteFold(_ title: String, isOpen: Bool, action: @escaping () -> Void) -> some View {
        Button {
            // Reflow the existing Folio control rows. No fixed-height drawer
            // can strand a paragraph underneath the next leaf.
            action()
            BookFeedback.pressTick()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                Text(title).font(.subheadline)
                Spacer(minLength: 0)
            }
            .foregroundStyle(BookPalette.violet)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOpen ? "Expanded" : "Folded")
        .folioControlUnbroken()
    }

    @ViewBuilder
    private func serenityReadingSection(_ artifact: TarotReadingArtifact) -> some View {
        FolioControlStack(alignment: .leading, spacing: 12) {
            if let prose = artifact.castReading?.trimmingCharacters(in: .whitespacesAndNewlines),
               !prose.isEmpty {
                noteFold("Serenity’s reading", isOpen: serenityOpen) {
                    serenityOpen.toggle()
                }
                if serenityOpen {
                    Text(prose)
                        .font(.body)
                        .foregroundStyle(BookPalette.ink.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }

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
                Text("Serenity can join you when you want another pair of eyes.")
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
                    Text("Serenity needs my private mind installed for a full reading. You can still turn every card and open its notes.")
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

    @ViewBuilder
    private var firstLookNotes: some View {
        let words = reading?.firstLook.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isReadOnly {
            if !words.isEmpty {
                keptReaderNote(title: "Your first look", words: words)
            }
        } else {
            noteFold("What caught your eye?", isOpen: firstLookOpen) { firstLookOpen.toggle() }
            if firstLookOpen {
                readingEditor(
                    title: "Your first look", prompt: "A detail you want to keep.",
                    placeholder: "The dog. That patch of blue. The hand at the window…",
                    text: Binding(get: { reading?.firstLook ?? "" }, set: { reading?.firstLook = $0 })
                )
            } else if !words.isEmpty {
                Text(words).font(.body.italic()).foregroundStyle(BookPalette.ink.opacity(0.80))
            }
        }
    }

    @ViewBuilder
    private var carryingNotes: some View {
        let words = reading?.reflection.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isReadOnly {
            if !words.isEmpty {
                keptReaderNote(title: "What you’re carrying", words: words)
            }
        } else {
            noteFold("Leave a note beside the cards", isOpen: reflectionOpen) { reflectionOpen.toggle() }
            if reflectionOpen {
                readingEditor(
                    title: "What you’re carrying", prompt: "Anything you want to take with you?",
                    placeholder: "A thought, an objection, a thing to try…",
                    text: Binding(get: { reading?.reflection ?? "" }, set: { reading?.reflection = $0 })
                )
            } else if !words.isEmpty {
                Text(words).font(.body).foregroundStyle(BookPalette.ink.opacity(0.80))
            }
        }
    }

    private func keptReaderNote(title: String, words: String) -> some View {
        FolioControlStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(1.1)
                .foregroundStyle(BookPalette.ink.opacity(0.64))
            Text(words)
                .font(.body)
                .foregroundStyle(BookPalette.ink)
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

    private func shuffleDeck() {
        guard reading == nil else { return }
        shuffledCardIDs = TarotDrawEngine.shuffledCardIDs()
        shuffleBeat += 1
        BookFeedback.pressTick()
    }

    private func draw(_ spread: TarotSpread) {
        guard reading == nil else { return }
        var artifact = TarotDrawEngine.draw(spread: spread, fromShuffledCardIDs: shuffledCardIDs)
            ?? TarotDrawEngine.draw(spread: spread)
        artifact.question = heldQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        artifact = TarotLocalInterpreter.fillReveals(in: artifact)
        expandedCardIDs = []
        firstLookOpen = false
        reflectionOpen = false
        serenityOpen = false
        showContextReceipt = false
        isGathering = false
        revealedCount = 0
        dealProgress = reduceMotion ? 1 : 0
        reading = artifact
        BookFeedback.play(.openPage)
        guard !reduceMotion else { return }
        let readingID = artifact.id
        Task { @MainActor in
            // Give the newly inserted leaves one frame at their packet origin.
            // This is presentation only; the whole draw is already fixed.
            try? await Task.sleep(for: .milliseconds(60))
            guard reading?.id == readingID else { return }
            dealProgress = 1
        }
    }

    private func dealingAnimation(at index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        if isGathering {
            return .easeInOut(duration: 0.24).delay(Double(index) * 0.06)
        }
        return .spring(response: 0.55, dampingFraction: 0.82).delay(Double(index) * 0.09)
    }

    private func gatherCards() {
        guard let reading, !isGathering else { return }
        isGathering = true
        serenityRequestID = nil
        isAskingSerenity = false
        BookFeedback.pressTick()
        if reduceMotion {
            finishGathering(readingID: reading.id)
        } else {
            dealProgress = 0
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(420))
                finishGathering(readingID: reading.id)
            }
        }
    }

    private func finishGathering(readingID: String) {
        guard reading?.id == readingID else { return }
        reading = nil
        revealedCount = 0
        dealProgress = 1
        isGathering = false
        expandedCardIDs = []
        readingMessage = ""
        shuffledCardIDs = TarotDrawEngine.shuffledCardIDs()
    }

    private func requestSerenityReading(includeArchive: Bool) {
        guard let current = reading, !isAskingSerenity else { return }
        let requestID = UUID().uuidString
        serenityRequestID = requestID
        isAskingSerenity = true
        readingMessage = includeArchive
            ? "The Stacks are finding the Pages that answer this spread…"
            : "Serenity is looking at the cards together…"
        Task {
            let result = await onRequestSerenityReading(current, includeArchive)
            await MainActor.run {
                guard serenityRequestID == requestID, let latest = reading, latest.id == current.id else { return }
                // The reader may keep writing while Serenity reads. Her older
                // snapshot must never erase those words when it comes back.
                var completed = result
                completed.firstLook = latest.firstLook
                completed.reflection = latest.reflection
                reading = completed
                serenityRequestID = nil
                isAskingSerenity = false
                serenityOpen = result.castReading?.isEmpty == false
                readingMessage = serenityOpen ? "" : "Serenity couldn’t finish the reading. The cards and your notes are still here."
                BookFeedback.play(serenityOpen ? .openPage : .error)
            }
        }
    }

    private func revealNext() {
        guard let reading, !isGathering, revealedCount < reading.cards.count else { return }
        TarotEditionEncounterStore.shared.record(.reading(reading, card: reading.cards[revealedCount]))
        withAnimation(reduceMotion ? nil : .timingCurve(0.22, 0.68, 0.18, 1, duration: 0.62)) {
            revealedCount += 1
        }
        BookFeedback.play(.openPage)
    }
}

// MARK: - The Inkbones Page

/// The Inkbones Page (docs/the-knock-plan.md §7.6): one Page where the dice
/// game and the divination are the same thing. Throw five bones up to three
/// times, tap the ones to keep, and the Curse throws back between throws.
/// What's left is the reading; the reader answers it in one sentence.
struct InkbonesPageView: View {
    @Binding var reading: InkbonesReading?
    @Binding var sentence: String
    let seed: String
    let stored: String?
    let isReadOnly: Bool
    let edge: () -> Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FolioPageState("inkbonesQuestion") private var question = ""
    @FolioPageState("inkbonesTumble") private var tumble = 0
    @FolioPageState("inkbonesCurseNote") private var curseNote = ""

    var body: some View {
        FolioControlStack(alignment: .leading, spacing: 16) {
            Text("THE INKBONES")
                .font(.caption2.weight(.black))
                .tracking(1.2)
                .foregroundStyle(BookPalette.gold)

            if let reading {
                bonesRow(reading)
                if reading.finished {
                    readingLines(reading)
                } else {
                    throwControls(reading)
                }
            } else {
                unthrown
            }
        }
        .onAppear {
            guard reading == nil, let stored, let data = stored.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(InkbonesReading.self, from: data) else { return }
            reading = decoded
        }
        .padding(18)
        .foregroundStyle(BookPalette.ink)
        .tint(BookPalette.teal)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.18), lineWidth: 1)
        }
        .environment(\.colorScheme, .light)
        .sensoryFeedback(.impact(weight: .medium), trigger: tumble)
        .accessibilityElement(children: .contain)
    }

    private var unthrown: some View {
        FolioControlStack(alignment: .leading, spacing: 12) {
            Text("Bring me one thing: a question, or just the day.")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            TextField("A question, or leave it for the day", text: $question, axis: .vertical)
                .font(.system(.body, design: .serif))
                .lineLimit(1...3)
                .padding(12)
                .background(BookPalette.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(isReadOnly)
            Button {
                BookFeedback.play(.braidStart)
                withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.6)) {
                    reading = InkbonesReading.begin(seed: seed, question: question, edge: edge())
                    tumble += 1
                }
            } label: {
                Label("Throw the bones", systemImage: "dice")
                    .font(.system(.headline, design: .serif))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .folioControlUnbroken()
            .disabled(isReadOnly)
        }
    }

    private func bonesRow(_ reading: InkbonesReading) -> some View {
        HStack(spacing: 8) {
            ForEach(reading.bones) { bone in
                Button {
                    guard !isReadOnly, !reading.finished, !bone.greyed else { return }
                    BookFeedback.play(.select)
                    self.reading?.toggleKeep(bone.id)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: bone.face.symbolName)
                            .font(.title3.weight(.semibold))
                        Text(bone.face.title)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .foregroundStyle(bone.greyed ? BookPalette.ink.opacity(0.3)
                                     : bone.kept ? BookPalette.page : BookPalette.ink)
                    .background(
                        bone.greyed ? Color.gray.opacity(0.25)
                            : bone.kept ? BookPalette.teal : BookPalette.paper.opacity(0.7),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(bone.kept ? BookPalette.teal : BookPalette.ink.opacity(0.2), lineWidth: bone.kept ? 2 : 1)
                    }
                    .rotationEffect(.degrees(reduceMotion || bone.kept ? 0 : Double(((tumble + bone.id * 7) % 5) - 2) * 3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(bone.greyed ? "\(bone.face.title), greyed by the Curse"
                                    : "\(bone.face.title)\(bone.kept ? ", kept" : "")")
                .accessibilityHint(reading.finished || bone.greyed ? "" : "Tap to keep or let go")
            }
        }
        .folioControlUnbroken()
    }

    private func throwControls(_ reading: InkbonesReading) -> some View {
        FolioControlStack(alignment: .leading, spacing: 10) {
            Text(reading.bones.contains(where: \.kept)
                 ? "Throw the rest again, or read them as they lie."
                 : "Tap the bones you want to keep. The others go back in the cup.")
                .font(.subheadline)
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
            if !curseNote.isEmpty {
                Text(curseNote)
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button {
                    throwAgain()
                } label: {
                    Label("Throw again · \(reading.throwsLeft) left", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isReadOnly || reading.throwsLeft == 0)
                Button {
                    BookFeedback.play(.braidComplete)
                    withAnimation { self.reading?.read() }
                } label: {
                    Label("Read them", systemImage: "text.book.closed")
                        .font(.caption.weight(.bold))
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.bordered)
                .disabled(isReadOnly)
            }
            .folioControlUnbroken()
            Text("The Curse needs \(reading.curseNeeds) to grey a bone you kept.")
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
        }
    }

    private func throwAgain() {
        guard var next = reading, next.throwsLeft > 0 else { return }
        let greyedBefore = next.greyedBone?.id
        next.throwAgain()
        if let roll = next.curseRolls.last {
            if next.greyedBone != nil, next.greyedBone?.id != greyedBefore, let greyed = next.greyedBone {
                curseNote = "The Curse threw a \(roll) and greyed your \(greyed.face.title)."
            } else {
                curseNote = "The Curse threw a \(roll). Missed."
            }
        }
        BookFeedback.play(next.finished ? .braidComplete : .braidStart)
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.6)) {
            reading = next
            tumble += 1
        }
    }

    private func readingLines(_ reading: InkbonesReading) -> some View {
        FolioControlStack(alignment: .leading, spacing: 10) {
            if !reading.question.isEmpty {
                Text("“\(reading.question)”")
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(reading.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.body, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(reading.ask)
                .font(.caption.weight(.black))
                .tracking(0.6)
                .foregroundStyle(BookPalette.gold)
                .padding(.top, 4)
            TextField("One sentence", text: $sentence, axis: .vertical)
                .font(.system(.body, design: .serif))
                .lineLimit(1...4)
                .padding(12)
                .background(BookPalette.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(isReadOnly)
        }
    }
}

/// Throws inked in a kept Page's margin, the way a reader notes a score.
struct InkbonesMarginMarksView: View {
    let marks: [InkbonesMarginMark.Mark]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "dice")
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.5))
            ForEach(Array(marks.prefix(4).enumerated()), id: \.offset) { index, mark in
                Text(mark.label)
                    .font(.system(.caption, design: .serif).italic().weight(.semibold))
                    .foregroundStyle(mark.thrower == .curse ? Color.gray : BookPalette.ink.opacity(0.78))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay {
                        Capsule().stroke(mark.thrower == .curse ? Color.gray.opacity(0.5) : BookPalette.ink.opacity(0.32),
                                         style: StrokeStyle(lineWidth: 1, dash: mark.thrower == .curse ? [3, 2] : []))
                    }
                    .rotationEffect(.degrees(index % 2 == 0 ? -3 : 2))
                    .fixedSize()
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Inkbones in the margin: " + marks.map(\.label).joined(separator: ", "))
    }
}

/// A few days after a reading: did the bones come true? Three taps and one
/// sentence about what actually happened.
struct InkbonesCameTrueView: View {
    let stored: String?
    @Binding var verdict: String?
    @Binding var sentence: String
    let storedVerdict: String?
    let isReadOnly: Bool

    private var reading: InkbonesReading? {
        stored.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(InkbonesReading.self, from: $0) }
    }

    private var chosen: InkbonesCameTrue.Verdict? {
        (verdict ?? storedVerdict).flatMap(InkbonesCameTrue.Verdict.init(rawValue:))
    }

    var body: some View {
        FolioControlStack(alignment: .leading, spacing: 14) {
            Text("THE INKBONES · A FEW DAYS ON")
                .font(.caption2.weight(.black))
                .tracking(1.2)
                .foregroundStyle(BookPalette.gold)

            if let reading {
                if !reading.question.isEmpty {
                    Text("“\(reading.question)”")
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    ForEach(reading.bones) { bone in
                        Image(systemName: bone.face.symbolName)
                            .font(.callout)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .foregroundStyle(bone.greyed ? BookPalette.ink.opacity(0.3) : BookPalette.ink)
                            .background(bone.greyed ? Color.gray.opacity(0.2) : BookPalette.paper.opacity(0.6),
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .accessibilityLabel(bone.greyed ? "\(bone.face.title), greyed" : bone.face.title)
                    }
                }
                ForEach(Array(reading.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.body, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                ForEach(InkbonesCameTrue.Verdict.allCases, id: \.rawValue) { option in
                    Button {
                        guard !isReadOnly else { return }
                        BookFeedback.play(.select)
                        verdict = option.rawValue
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(chosen == option ? BookPalette.page : BookPalette.ink)
                            .background(chosen == option ? BookPalette.teal : BookPalette.paper.opacity(0.7),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .folioControlUnbroken()

            if let chosen {
                Text(chosen.line)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                TextField("One sentence: what actually happened?", text: $sentence, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .lineLimit(1...4)
                    .padding(12)
                    .background(BookPalette.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .disabled(isReadOnly)
            }
        }
        .padding(18)
        .foregroundStyle(BookPalette.ink)
        .tint(BookPalette.teal)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.18), lineWidth: 1)
        }
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }
}
