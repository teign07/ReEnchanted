import SwiftUI

struct TarotPageView: View {
    @Binding var reading: TarotReadingArtifact?
    let isReadOnly: Bool
    let localBrainIsReady: Bool
    let isLocalBrainWorking: Bool
    let onRequestAuroraReading: (TarotReadingArtifact, Bool) async -> TarotReadingArtifact

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heldQuestion = ""
    @State private var revealedCount = 0
    @State private var isAskingAurora = false
    @State private var readingMessage = ""
    @State private var showContextReceipt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            hostNote

            if let reading {
                readingView(reading)
            } else {
                unopenedDeck
            }
        }
        .onAppear {
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
        .accessibilityElement(children: .contain)
    }

    private var hostNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 30, height: 30)
                .background(BookPalette.violet.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("AURORA HOLDS THE LAMP")
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
        VStack(alignment: .leading, spacing: 18) {
            tarotCardBack
                .frame(width: 150, height: 252)
                .frame(maxWidth: .infinity)
                .shadow(color: BookPalette.ink.opacity(0.22), radius: 16, y: 10)

            VStack(alignment: .leading, spacing: 7) {
                Text("Hold something lightly")
                    .font(.headline)
                    .foregroundStyle(BookPalette.ink)
                TextField("A question, situation, or nothing at all", text: $heldQuestion, axis: .vertical)
                    .textFieldStyle(.plain)
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
                        VStack(alignment: .leading, spacing: 2) {
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
            }

            Text("78 cards · drawn on this device · no card is chosen by AI")
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.56))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func readingView(_ artifact: TarotReadingArtifact) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
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
            }

            if revealedCount == artifact.cards.count {
                auroraReadingSection(artifact)
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
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
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
                    Image(card.assetName)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(drawn.isReversed ? .degrees(180) : .zero)
                        .accessibilityLabel("\(card.name)\(drawn.isReversed ? ", reversed" : "")")
                } else {
                    tarotCardBack
                        .accessibilityLabel("Face-down tarot card")
                }
            }
            .aspectRatio(0.583, contentMode: .fit)
            .frame(maxWidth: 254)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: BookPalette.ink.opacity(0.20), radius: 14, y: 8)
            .frame(maxWidth: .infinity)

            if isRevealed, let card {
                VStack(alignment: .leading, spacing: 9) {
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
                Text("Tap only when you’re ready to see it.")
                    .font(.caption.italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.54))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func auroraReadingSection(_ artifact: TarotReadingArtifact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let prose = artifact.auroraReading?.trimmingCharacters(in: .whitespacesAndNewlines),
               !prose.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                    Text("AURORA READ BESIDE YOU")
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
                            showContextReceipt ? "Hide what Aurora read" : "See what Aurora read",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink)
                    }
                    .buttonStyle(.plain)

                    if showContextReceipt {
                        contextReceipt(receipt)
                    }
                }
            } else if !isReadOnly {
                Text("Aurora can read only the cards, or—with your say-so—read beside a few recent Pages the Stacks finds connected.")
                    .font(.subheadline)
                    .foregroundStyle(BookPalette.ink.opacity(0.72))

                Button {
                    requestAuroraReading(includeArchive: false)
                } label: {
                    auroraButtonLabel("Let Aurora read the cards", symbol: "moon.stars")
                }
                .buttonStyle(.plain)
                .disabled(isAskingAurora || isLocalBrainWorking || !localBrainIsReady)

                Button {
                    requestAuroraReading(includeArchive: true)
                } label: {
                    auroraButtonLabel("Read beside my recent Pages", symbol: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(.plain)
                .disabled(isAskingAurora || isLocalBrainWorking || !localBrainIsReady)

                if !localBrainIsReady {
                    Text("Aurora needs the Book’s private mind installed for a full reading. The card notes above stay local and work without it.")
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

    private func auroraButtonLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            if isAskingAurora {
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
        VStack(alignment: .leading, spacing: 10) {
            Text("\(receipt.sources.count) SOURCES · \(receipt.edges.count) EDGES")
                .font(.caption2.weight(.black))
                .tracking(0.9)
                .foregroundStyle(BookPalette.ink.opacity(0.72))
            ForEach(receipt.sources) { source in
                VStack(alignment: .leading, spacing: 2) {
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
        VStack(alignment: .leading, spacing: 18) {
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
                prompt: "What feels useful—not certain, just useful?",
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
        VStack(alignment: .leading, spacing: 6) {
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
                    .textFieldStyle(.plain)
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
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.08, blue: 0.23),
                            Color(red: 0.29, green: 0.11, blue: 0.31)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.82), lineWidth: 2)
                .padding(8)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.36), lineWidth: 1)
                .padding(15)
            ForEach(0..<4, id: \.self) { turn in
                Image(systemName: "sparkle")
                    .font(.system(size: 38, weight: .thin))
                    .foregroundStyle(BookPalette.lampGold.opacity(0.72))
                    .rotationEffect(.degrees(Double(turn) * 90))
                    .offset(y: -40)
                    .rotationEffect(.degrees(Double(turn) * 90))
            }
            Circle()
                .stroke(BookPalette.lampGold.opacity(0.68), lineWidth: 1.5)
                .frame(width: 74, height: 74)
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(BookPalette.lampGold)
        }
    }

    private func draw(_ spread: TarotSpread) {
        var artifact = TarotDrawEngine.draw(spread: spread)
        artifact.question = heldQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        artifact = TarotLocalInterpreter.fillReveals(in: artifact)
        reading = artifact
        revealedCount = 0
        BookFeedback.play(.openPage)
    }

    private func requestAuroraReading(includeArchive: Bool) {
        guard let current = reading, !isAskingAurora else { return }
        isAskingAurora = true
        readingMessage = includeArchive
            ? "The Stacks are finding the Pages that answer this spread…"
            : "Aurora is looking at the cards together…"
        Task {
            let result = await onRequestAuroraReading(current, includeArchive)
            await MainActor.run {
                reading = result
                isAskingAurora = false
                readingMessage = result.auroraReading?.isEmpty == false
                    ? ""
                    : "Aurora couldn’t finish the reading. The cards and your notes are still here."
                BookFeedback.play(result.auroraReading?.isEmpty == false ? .openPage : .error)
            }
        }
    }

    private func revealNext() {
        guard let reading, revealedCount < reading.cards.count else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82)) {
            revealedCount += 1
        }
        BookFeedback.play(.openPage)
    }
}
