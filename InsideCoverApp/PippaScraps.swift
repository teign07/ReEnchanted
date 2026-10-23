import SwiftUI
import UIKit

/// Her reading desk is local and idle work. Nothing here is called by a frame,
/// a shake, or a keystroke. Enrichments with unchanged reader words reuse it.
private actor PippaReadingWorker {
    private var signature: Int?
    private var reading = PippaReading()

    func prepare(days: [BookDay]) -> PippaReading {
        var hasher = Hasher()
        var seen = Set<String>()
        var writings: [PippaWordFinds.Writing] = []
        for day in days {
            for page in day.pages where seen.insert(page.id).inserted {
                guard !Task.isCancelled else { return reading }
                guard page.privacy != .localSensitive else { continue }
                let texts = page.readerAuthoredTexts
                guard !texts.isEmpty else { continue }
                hasher.combine(page.id)
                hasher.combine(page.createdAt)
                hasher.combine(texts)
                writings.append(.init(id: page.id, date: page.createdAt, texts: texts))
            }
        }
        let next = hasher.finalize()
        guard next != signature else { return reading }
        let made = PippaWordFinds.prepare(writings: writings)
        guard !Task.isCancelled else { return reading }
        signature = next
        reading = made
        return made
    }
}

@MainActor
@Observable
final class PippaReadingDesk {
    static let shared = PippaReadingDesk()
    private(set) var reading = PippaReading()
    @ObservationIgnored private let worker = PippaReadingWorker()
    @ObservationIgnored private var preparation: Task<Void, Never>?
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var recentIDs: [String] = []
    @ObservationIgnored private var recentWords: [String] = []
    @ObservationIgnored private var favourite: String?
    @ObservationIgnored private var encounter = 0

    func prepare(days: [BookDay]) {
        preparation?.cancel()
        revision &+= 1
        let ticket = revision
        let worker = worker
        preparation = Task(priority: .background) { [weak self] in
            // Let the Keep's absorption, retirement and archive writes finish.
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            await KeepReplyStage.waitForQuiet()
            guard !Task.isCancelled else { return }
            let made = await worker.prepare(days: days)
            guard !Task.isCancelled, let self, ticket == self.revision else { return }
            if self.reading != made { self.reading = made }
            if let favourite = self.favourite, made.favouriteScrap(for: favourite) == nil {
                self.favourite = nil
            }
            self.preparation = nil
        }
    }

    /// A bounded deck, with no immediate word or message repeats. A favourite
    /// is a callback, not a reason to show the same first word forever.
    func nextScrap() -> PippaScrap {
        encounter += 1
        let personal = reading.scraps.filter {
            !recentIDs.contains($0.id) && ($0.word.map { !recentWords.contains($0) } ?? true)
        }
        // Choose a kind of discovery before a particular scrap. Twenty words
        // must not drown out the one punctuation count or cross-Page meeting.
        let families = Dictionary(grouping: personal) { $0.id.split(separator: ":").first.map(String.init) ?? "word" }
        var candidates = encounter % 3 == 1 ? PippaScrap.cheek : (families.values.randomElement() ?? [])
        if encounter % 7 == 0, let favourite,
           let callback = reading.favouriteScrap(for: favourite), !recentIDs.contains(callback.id) {
            candidates = [callback]
        }
        candidates = candidates.filter { !recentIDs.contains($0.id) }
        if candidates.isEmpty {
            candidates = PippaScrap.cheek.filter { $0.id != recentIDs.last }
        }
        let scrap = candidates.randomElement() ?? PippaScrap.cheek[0]
        recentIDs = Array((recentIDs + [scrap.id]).suffix(8))
        if let word = scrap.word {
            recentWords = Array((recentWords + [word]).suffix(4))
            if favourite == nil { favourite = word }
        }
        return scrap
    }
}

/// Immutable geometry, shared by her existing Canvas and the card's finite
/// GeometryEffect. Native text is laid out once, not resolved into every frame.
struct PippaDeliveryFlight {
    enum Kind: Equatable { case shake, exclamation, touch }
    var kind: Kind
    var startedAt: TimeInterval
    var origin: CGPoint
    var landing: CGPoint
    var cardCentre: CGPoint
    var room: CGSize
    var cardWidth: CGFloat

    static let duration = 2.4
    static let release = 0.76

    func progress(at time: TimeInterval) -> Double {
        min(1, max(0, (time - startedAt) / Self.duration))
    }

    func fairy(at progress: Double, returningTo ambient: CGPoint) -> CGPoint {
        let below = CGPoint(x: origin.x, y: room.height + 38)
        let launch = CGPoint(x: room.width - 35, y: room.height + 25)
        let tow = CGPoint(x: cardCentre.x + cardWidth * 0.38, y: cardCentre.y - 75)
        let release = CGPoint(x: tow.x + 12, y: tow.y - 16)
        if kind == .shake {
            if progress < 0.18 { return Self.mix(origin, below, progress / 0.18) }
            if progress < 0.30 { return Self.mix(below, launch, (progress - 0.18) / 0.12) }
            if progress < 0.60 { return Self.mix(launch, tow, (progress - 0.30) / 0.30) }
        } else if progress < 0.60 {
            return Self.mix(origin, tow, progress / 0.60)
        }
        if progress < Self.release { return Self.mix(tow, release, (progress - 0.60) / 0.16) }
        if progress < 0.90 { return Self.mix(release, landing, (progress - Self.release) / 0.14) }
        return Self.mix(landing, ambient, (progress - 0.90) / 0.10)
    }

    func card(at progress: Double) -> CGPoint {
        let below = CGPoint(x: room.width - cardWidth * 0.5 - 20,
                            y: room.height + max(150, room.height * 0.5))
        let tow = CGPoint(x: cardCentre.x - 9, y: cardCentre.y + 12)
        let release = CGPoint(x: cardCentre.x + 3, y: cardCentre.y - 12)
        if progress < 0.30 { return below }
        if progress < 0.60 { return Self.mix(below, tow, (progress - 0.30) / 0.30) }
        if progress < Self.release { return Self.mix(tow, release, (progress - 0.60) / 0.16) }
        return Self.mix(release, cardCentre, (progress - Self.release) / 0.24)
    }

    static func mix(_ a: CGPoint, _ b: CGPoint, _ fraction: Double) -> CGPoint {
        let t = min(1, max(0, fraction))
        let eased = CGFloat(t * t * (3 - 2 * t))
        return CGPoint(x: a.x + (b.x - a.x) * eased, y: a.y + (b.y - a.y) * eased)
    }
}

private struct PippaCardFlightEffect: GeometryEffect {
    var progress: Double
    let flight: PippaDeliveryFlight
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let point = flight.card(at: progress)
        let tilt = progress < PippaDeliveryFlight.release ? sin(progress * .pi * 3) * 0.10 : (1 - progress) * -0.12
        var transform = CGAffineTransform(translationX: point.x - flight.cardCentre.x,
                                          y: point.y - flight.cardCentre.y)
        transform = transform.translatedBy(x: size.width / 2, y: size.height / 2)
            .rotated(by: tilt).translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}

struct PippaMessageCard: View {
    let scrap: PippaScrap
    let flight: PippaDeliveryFlight
    let restsImmediately: Bool
    let isReleased: Bool
    let dismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var progress = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pippa Pilcrow")
                    .font(.system(.caption, design: .serif).weight(.bold))
                Spacer(minLength: 12)
                Button(action: dismiss) {
                    Image(systemName: "xmark").font(.caption.weight(.bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Put Pippa’s scrap away")
            }
            .foregroundStyle(BookPalette.ink.opacity(0.72))

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { words }
                    .frame(height: min(350, flight.room.height * 0.42))
            } else {
                words
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(width: flight.cardWidth)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.99, green: 0.94, blue: 0.79))
                .overlay { RoundedRectangle(cornerRadius: 5).stroke(BookPalette.ink.opacity(0.4), lineWidth: 1) }
                .shadow(color: .black.opacity(0.22), radius: 3, x: 1, y: 3)
        }
        .modifier(PippaCardFlightEffect(progress: restsImmediately ? 1 : progress, flight: flight))
        .position(flight.cardCentre)
        .allowsHitTesting(isReleased || restsImmediately)
        .accessibilityHidden(!isReleased && !restsImmediately)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("A scrap from Pippa")
        .task {
            guard !restsImmediately else { progress = 1; return }
            withAnimation(.linear(duration: PippaDeliveryFlight.duration)) { progress = 1 }
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(scrap.line)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let ornament = scrap.ornament {
                Text(ornament)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(BookPalette.teal)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// A passive UIKit shake receiver. It claims an otherwise idle responder slot,
/// never an editor's focus, and uses no accelerometer stream or polling timer.
struct PippaShakeReceiver: UIViewRepresentable {
    var isEnabled: Bool
    var onShake: () -> Void

    func makeUIView(context: Context) -> Receiver {
        let view = Receiver()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: Receiver, context: Context) {
        view.onShake = onShake
        view.enabled = isEnabled
        view.updateFocusSoon()
    }

    static func dismantleUIView(_ view: Receiver, coordinator: ()) {
        view.enabled = false
        view.onShake = nil
        view.resignFirstResponder()
    }

    final class Receiver: UIView {
        var enabled = false
        var onShake: (() -> Void)?
        override var canBecomeFirstResponder: Bool { enabled }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updateFocusSoon()
        }

        func updateFocusSoon() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.enabled, self.window?.isKeyWindow == true else {
                    if self.isFirstResponder { self.resignFirstResponder() }
                    return
                }
                // Do not dismiss typing, dictation or a hardware-keyboard
                // editor when SwiftUI updates the surrounding Book.
                guard !UIApplication.shared.reenchantedHasFocusedTextInput() else { return }
                if !self.isFirstResponder { self.becomeFirstResponder() }
            }
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake, enabled,
                  !UIApplication.shared.reenchantedHasFocusedTextInput() else {
                super.motionEnded(motion, with: event)
                return
            }
            onShake?()
        }
    }
}
