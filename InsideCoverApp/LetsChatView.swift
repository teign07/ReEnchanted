import SwiftUI
import Observation

// MARK: - Let's Chat surface
//
// Small views for the conversation. The sheet still owns the turns and the
// sending (so keep, evidence and persistence keep working); these draw them.
// Streaming text lives in `LetsChatLiveState`, read only by the live bubble,
// so a reply arriving token by token redraws one view rather than the whole
// page sheet.

/// What the Book is doing right now, what it has already done, and the reply
/// as it is written. Every line comes from the code doing the work, so the
/// bubble says what is actually happening rather than animating a guess.
@MainActor
@Observable
final class LetsChatLiveState {
    struct Receipt: Identifiable, Equatable {
        let id = UUID()
        var text: String
        /// Set for a page it opened: an icon, and who it is from and when.
        var symbol: String? = nil
        var detail: String? = nil
    }

    /// True from send until the reply has landed.
    var isActive = false
    var text = ""
    /// The message just sent, shown at once while the reply is made.
    var readerLine: String?
    /// Steps already finished, kept above the one in progress.
    var receipts: [Receipt] = []
    /// The step in progress.
    var current = LetsChatStatusCopy.starting
    var currentStartedAt = Date()
    private var hasRetried = false

    func begin(readerLine: String) {
        self.readerLine = readerLine
        text = ""
        receipts = []
        hasRetried = false
        isActive = true
        current = LetsChatStatusCopy.starting
        currentStartedAt = Date()
    }

    /// Finish the step in progress (optionally leaving a receipt) and start the next.
    func advance(receipt: String? = nil, to next: String) {
        if let receipt { receipts.append(Receipt(text: receipt)) }
        setCurrent(next)
    }

    func setCurrent(_ line: String) {
        guard line != current else { return }
        current = line
        currentStartedAt = Date()
    }

    /// Lists the pages it opened one at a time, as a person would lay them out.
    /// They are all known when the search returns; the stagger is only so the
    /// eye can follow. Stops quietly if the reply lands first.
    func reveal(leaves: [Receipt]) async {
        for leaf in leaves {
            guard isActive else { return }
            receipts.append(leaf)
            try? await Task.sleep(for: .milliseconds(140))
        }
    }

    func apply(_ stage: LetsChatStage) {
        guard isActive else { return }
        switch stage {
        case .waking:
            setCurrent(LetsChatStatusCopy.line(for: .waking))
        case .reading:
            // A second try goes straight back through reading; keep saying so.
            guard !hasRetried else { return }
            let woke = current == LetsChatStatusCopy.line(for: .waking)
            advance(receipt: woke ? "My pencil's awake." : nil, to: LetsChatStatusCopy.line(for: .reading))
        case .retrying:
            hasRetried = true
            text = ""
            setCurrent(LetsChatStatusCopy.line(for: .retrying))
        }
    }

    func finish() {
        isActive = false
        readerLine = nil
        text = ""
        receipts = []
    }
}

/// Lets code that is not part of the view tree (a streaming callback) ask the
/// page to scroll to the latest line without changing any state the sheet's
/// body reads.
@MainActor
final class LetsChatScrollHandle {
    var scrollToBottom: (() -> Void)?
}

enum LetsChatOffer: Equatable {
    case remember(String)
    case keepChat
}

struct LetsChatBubble: View {
    enum Role { case reader, book }

    let role: Role
    let text: String

    var body: some View {
        switch role {
        case .reader:
            Text(text)
                .font(.body)
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    BookPalette.teal.opacity(0.15),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 16,
                        style: .continuous
                    )
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 44)
                .accessibilityLabel("You said: \(text)")
        case .book:
            HStack(alignment: .top, spacing: 8) {
                LetsChatBookMark()
                Text(text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.9))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        BookPalette.page,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: 4,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: 16,
                            style: .continuous
                        )
                    )
                    .overlay {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: 16,
                            style: .continuous
                        )
                        .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 28)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("The Book said: \(text)")
        }
    }
}

struct LetsChatBookMark: View {
    var body: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(BookPalette.teal)
            .frame(width: 24, height: 24)
            .background(BookPalette.teal.opacity(0.14), in: Circle())
            .padding(.top, 4)
            .accessibilityHidden(true)
    }
}

/// The reply in progress: what the Book has done, what it is doing now with a
/// moving pencil and ink line, and then the words themselves as they arrive.
struct LetsChatLiveBubble: View {
    let live: LetsChatLiveState
    let reduceMotion: Bool
    /// Called as the reply grows, so the page can keep its last line in view.
    var onGrow: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(live.receipts) { receipt in
                if let symbol = receipt.symbol {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(receipt.text)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            if let detail = receipt.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(BookPalette.ink.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .foregroundStyle(BookPalette.ink.opacity(0.8))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(BookPalette.page.opacity(0.8), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.1), lineWidth: 1)
                    }
                    .padding(.leading, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text(receipt.text)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(BookPalette.teal.opacity(0.85))
                    .padding(.leading, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if live.text.isEmpty {
                workingRow
            } else {
                LetsChatBubble(role: .book, text: live.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: live.receipts)
        .onChange(of: live.text) { _, _ in onGrow() }
        .onChange(of: live.current) { _, _ in onGrow() }
        .onChange(of: live.receipts) { _, _ in onGrow() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(live.text.isEmpty ? live.current : live.text)
    }

    private var workingRow: some View {
        HStack(alignment: .top, spacing: 8) {
            LetsChatBookMark()
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "pencil.and.scribble")
                        .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                    Text(live.current)
                        .font(.system(.callout, design: .serif).italic())
                        .fixedSize(horizontal: false, vertical: true)
                        .id(live.current)
                        .transition(.opacity)
                }
                LetsChatInkLine(reduceMotion: reduceMotion)
                    .frame(height: 3)
                    .frame(maxWidth: 160)
                // A long step says so instead of looking stuck.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if context.date.timeIntervalSince(live.currentStartedAt) > 12 {
                        Text("Still at it. This one's taking a while.")
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.55))
                            .transition(.opacity)
                    }
                }
            }
            .foregroundStyle(BookPalette.ink.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                BookPalette.page.opacity(0.7),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: live.current)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A short line of ink that keeps being drawn: a highlight sliding along a
/// faint track. Still, with a partial fill, when Reduce Motion is on.
struct LetsChatInkLine: View {
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(BookPalette.teal.opacity(0.14))
                if reduceMotion {
                    Capsule()
                        .fill(BookPalette.teal.opacity(0.55))
                        .frame(width: width * 0.4)
                } else {
                    TimelineView(.animation) { context in
                        let cycle = 1.7
                        let phase = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: cycle) / cycle
                        let segment = width * 0.38
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        BookPalette.teal.opacity(0),
                                        BookPalette.teal.opacity(0.75),
                                        BookPalette.teal.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: segment)
                            .offset(x: -segment + (width + segment) * phase)
                    }
                }
            }
            .clipShape(Capsule())
        }
        .accessibilityHidden(true)
    }
}

/// "The Book wants to do this. Say yes." Nothing happens until the reader taps.
struct LetsChatOfferCard: View {
    let offer: LetsChatOffer
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.callout, design: .serif).italic())
                .foregroundStyle(BookPalette.ink.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(action: onAccept) {
                    Label(acceptTitle, systemImage: acceptSymbol)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(BookPalette.teal.opacity(0.18), in: Capsule())
                        .overlay { Capsule().stroke(BookPalette.teal.opacity(0.4), lineWidth: 1) }
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)

                Button("Never mind", action: onDecline)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(BookPalette.ink.opacity(0.65))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
    }

    private var title: String {
        switch offer {
        case .remember(let text):
            return "Should I remember that? “\(text)” I'll keep it as something you told me."
        case .keepChat:
            return "Want me to keep this chat as a Page?"
        }
    }

    private var acceptTitle: String {
        switch offer {
        case .remember: return "Remember it"
        case .keepChat: return "Keep it"
        }
    }

    private var acceptSymbol: String {
        switch offer {
        case .remember: return "bookmark.fill"
        case .keepChat: return "seal.fill"
        }
    }
}

/// Tap-to-say chips. Used for the opening suggestions and the two follow-ups.
struct LetsChatChips: View {
    let chips: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button(chip) { onTap(chip) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(BookPalette.teal)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Things you could say")
    }
}

/// The leaves a reply drew on, as chips under it. Tapping one opens it.
struct LetsChatLeaves: View {
    let evidence: [AskTheBookEvidence]
    let searchedRecordCount: Int
    let onOpen: (AskTheBookEvidence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                evidence.isEmpty
                    ? "I went through \(searchedRecordCount) records. Nothing fit."
                    : "I opened these:",
                systemImage: "books.vertical"
            )
            .font(.caption2.weight(.bold))
            .foregroundStyle(BookPalette.teal.opacity(0.88))

            if !evidence.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(evidence) { item in
                            Button { onOpen(item) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.result.kind.symbolName)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.result.title)
                                            .font(.caption.weight(.bold))
                                            .lineLimit(1)
                                        Text([item.authority.readerLabel, item.result.dateLabel]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " · "))
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(BookPalette.ink)
                        }
                    }
                }
            }
        }
        .padding(.leading, 32)
    }
}

/// The pinned composer. A field that grows to five lines, dictation, and a
/// send button; nothing else between the reader and the Book.
struct LetsChatComposer: View {
    @Binding var text: String
    let isBusy: Bool
    let placeholder: String
    var focus: FocusState<Bool>.Binding
    let onSend: () -> Void

    private var canSend: Bool {
        !isBusy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...5)
                .font(.body)
                .foregroundStyle(BookPalette.ink)
                .focused(focus)
                .submitLabel(.send)
                .onSubmit { if canSend { onSend() } }
                .inkFeedback(text: text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .dictationInput(text: $text)
                .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }

            Button(action: onSend) {
                Image(systemName: isBusy ? "ellipsis" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSend ? BookPalette.page : BookPalette.ink.opacity(0.35))
                    .frame(width: 38, height: 38)
                    .background(
                        canSend ? BookPalette.teal : BookPalette.ink.opacity(0.1),
                        in: Circle()
                    )
            }
            .buttonStyle(.bookPress())
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
