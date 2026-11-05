import SwiftUI
import UIKit

// MARK: - Tapping the reader's words
//
// Every word on a leaf that's in the reader's own hand can be touched. Touch one
// and the Book looks it up in its dictionary of you (`BookDictionary`): what
// sort of word it is to you, when it comes out, what it goes about with, and
// the other times you wrote it, each one a way back to that Page. Now and then
// a word is loose for the day: the Pixie keeps landing on it, and touching it
// sends it running. Catch it and it's pressed into the dictionary.
//
// The word itself is the anchor (see the book-object law): a popover pinned to
// it, nothing on a homescreen. All archive work happens off the main thread.

/// The reader's words, counted from the kept archive, built once on demand and
/// refreshed when it's gone stale.
@MainActor
final class WordsOfYoursStore {
    static let shared = WordsOfYoursStore()

    private var words: WordsOfYours?
    private var builtAt = Date.distantPast
    private var building: Task<WordsOfYours, Never>?

    /// How old a count may be before a lookup quietly recounts.
    private static let freshFor: TimeInterval = 120

    private init() {}

    /// The last count, even if it's stale: a card shows it at once and
    /// updates if a recount finds more.
    var cached: WordsOfYours? { words }

    var isFresh: Bool { words != nil && Date().timeIntervalSince(builtAt) < Self.freshFor }

    func current() async -> WordsOfYours {
        if let words, isFresh { return words }
        if let building { return await building.value }
        // The archive read and the count both run detached: the whole archive
        // decode must never touch the main actor (see BookDatabase).
        let task = Task.detached(priority: .userInitiated) {
            WordsOfYours.build(passages: WordsOfYours.passages(in: BookDatabase.loadDaysDetached()))
        }
        building = task
        let result = await task.value
        words = result
        builtAt = Date()
        building = nil
        return result
    }
}

/// Words the reader has caught, kept in their own small file beside the vault.
/// Not the Pocket: the Pocket only holds what was let go.
@MainActor
final class CaughtWords {
    struct Catch: Codable, Equatable {
        let word: String
        let leafKey: String
        let dayID: String
        let caughtAt: Date
    }

    static let shared = CaughtWords()
    private(set) var all: [Catch] = []
    private var loaded = false

    private init() {}

    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("caught-words.json")
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let url = Self.fileURL, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Catch].self, from: data) else { return }
        all = decoded
    }

    func caughtAt(_ word: String) -> Date? {
        loadIfNeeded()
        guard let key = WordsOfYours.key(word) else { return nil }
        return all.last { $0.word == key }?.caughtAt
    }

    func isCaught(on leafKey: String, dayID: String) -> Bool {
        loadIfNeeded()
        return all.contains { $0.leafKey == leafKey && $0.dayID == dayID }
    }

    var count: Int {
        loadIfNeeded()
        return Set(all.map(\.word)).count
    }

    func record(_ word: String, leafKey: String, dayID: String, at date: Date = Date()) {
        loadIfNeeded()
        guard let key = WordsOfYours.key(word), !isCaught(on: leafKey, dayID: dayID) else { return }
        all.append(Catch(word: key, leafKey: leafKey, dayID: dayID, caughtAt: date))
        if all.count > 4_000 { all.removeFirst(all.count - 4_000) }
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(all) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// The loose word on the leaf in front of the reader, in window coordinates,
/// for the Pixie to land on. One at a time; the last leaf to offer one wins.
@MainActor
@Observable
final class LooseWordPerch {
    static let shared = LooseWordPerch()
    private(set) var rect: CGRect?
    @ObservationIgnored private var owner: ObjectIdentifier?

    private init() {}

    func offer(_ rect: CGRect, from source: AnyObject) {
        owner = ObjectIdentifier(source)
        // Layout passes repeat the same rect; don't wake her for nothing.
        if let current = self.rect, abs(current.minX - rect.minX) < 0.5, abs(current.minY - rect.minY) < 0.5 { return }
        self.rect = rect
    }

    func withdraw(from source: AnyObject) {
        guard owner == ObjectIdentifier(source) else { return }
        owner = nil
        rect = nil
    }
}

/// What a leaf tells its words about where they are.
struct FolioWordContext {
    /// Stable for the leaf: the kept Page's id, or the surface's.
    var leafKey: String
    /// The kept Page this leaf shows, so it isn't listed as its own echo.
    var pageID: String?
    var openPage: (String) -> Void
}

private struct FolioWordContextKey: EnvironmentKey {
    static let defaultValue: FolioWordContext? = nil
}

extension EnvironmentValues {
    var folioWordContext: FolioWordContext? {
        get { self[FolioWordContextKey.self] }
        set { self[FolioWordContextKey.self] = newValue }
    }
}

// MARK: - The card

/// The Book's dictionary entry for one of the reader's words.
struct WordOfYoursCard: View {
    let word: String
    let pageID: String?
    let justCaught: Bool
    var onOpenPage: (String) -> Void = { _ in }

    @State private var entry: BookDictionaryEntry?

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return formatter
    }()

    var body: some View {
        // A long-lived word has more echoes than a popover has room for; the
        // card scrolls rather than pushing its headword off the top.
        ScrollView {
            content
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 320)
        .frame(maxHeight: 460)
        .background(BookPalette.page)
        .task { await load() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(justCaught ? "CAUGHT · MY DICTIONARY OF YOU" : "MY DICTIONARY OF YOU")
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .tracking(1.4)
                .foregroundStyle(justCaught ? BookPalette.gold : BookPalette.teal)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word)
                    .font(BookHand.reader.font(30, relativeTo: .title))
                    .foregroundStyle(BookHand.readerInkColor)
                if let kind = entry?.kind {
                    Text(kind)
                        .font(.system(size: 14, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                }
            }

            if let entry {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(entry.senses.enumerated()), id: \.offset) { index, sense in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(BookPalette.teal)
                            Text(.init(sense))
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(BookPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let first = entry.first {
                    sightingRow(first, label: "The first time, \(Self.day.string(from: first.date))")
                }
                if !entry.echoes.isEmpty {
                    Text("AND AGAIN")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .tracking(1.4)
                        .foregroundStyle(BookPalette.teal)
                        .padding(.top, 2)
                    ForEach(Array(entry.echoes.enumerated()), id: \.offset) { _, echo in
                        sightingRow(echo, label: Self.day.string(from: echo.date))
                    }
                }
                if entry.moreCount > 0 {
                    Text(entry.moreCount == 1 ? "And once more, further back." : "And \(BookDictionary.spelled(entry.moreCount)) more times, further back.")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.6))
                }
            } else {
                Text("Hold on. I'm finding every time you wrote it.")
                    .font(BookHand.book.font(17))
                    .foregroundStyle(BookPalette.ink.opacity(0.7))
            }
        }
        .padding(18)
        .frame(width: 320, alignment: .leading)
    }

    private func sightingRow(_ sighting: WordsOfYours.Sighting, label: String) -> some View {
        Button {
            onOpenPage(sighting.pageID)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .tracking(1.1)
                    .foregroundStyle(BookPalette.ink.opacity(0.5))
                Text(underlined(sighting.line))
                    .font(BookHand.reader.font(15))
                    .foregroundStyle(BookHand.readerInkColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens that Page")
    }

    /// The line with this word underlined in the Book's accent, wherever it
    /// sits, in whatever form it was written.
    private func underlined(_ line: String) -> AttributedString {
        var text = AttributedString(line)
        guard let key = WordsOfYours.key(word) else { return text }
        let forms = Set([key] + WordsOfYours.variants(of: key))
        let ns = line as NSString
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byWords) { found, range, _, _ in
            guard let found, let foundKey = WordsOfYours.key(found), forms.contains(foundKey),
                  let swiftRange = Range(range, in: line),
                  let lower = AttributedString.Index(swiftRange.lowerBound, within: text),
                  let upper = AttributedString.Index(swiftRange.upperBound, within: text) else { return }
            text[lower..<upper].underlineStyle = .single
            text[lower..<upper].underlineColor = UIColor(BookPalette.gold)
        }
        return text
    }

    private func load() async {
        let store = WordsOfYoursStore.shared
        let caught = CaughtWords.shared.caughtAt(word)
        if let cached = store.cached {
            entry = BookDictionary.entry(for: word, in: cached, caughtAt: caught, excludingPage: pageID)
            if store.isFresh { return }
        }
        let words = await store.current()
        let word = word, pageID = pageID
        // NLTagger and the sorting stay off the main thread too.
        let fresh = await Task.detached(priority: .userInitiated) {
            BookDictionary.entry(for: word, in: words, caughtAt: caught, excludingPage: pageID)
        }.value
        entry = fresh
    }
}

// MARK: - Presenting it from the word

@MainActor
enum WordCardPresenter {
    private final class Adaptivity: NSObject, UIPopoverPresentationControllerDelegate {
        static let shared = Adaptivity()
        // A popover on the phone too: the card stays pinned to its word
        // instead of becoming a sheet that hides the leaf.
        func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle { .none }
    }

    static func present(word: String, from view: UIView, rect: CGRect, context: FolioWordContext, justCaught: Bool) {
        guard let presenter = view.nearestViewController?.topPresenter,
              presenter.presentedViewController == nil else { return }
        var card = WordOfYoursCard(word: word, pageID: context.pageID, justCaught: justCaught)
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        let open = context.openPage
        card.onOpenPage = { [weak host] pageID in
            host?.dismiss(animated: true) { open(pageID) }
        }
        host.rootView = AnyView(card)
        host.sizingOptions = .preferredContentSize
        host.view.backgroundColor = UIColor(BookPalette.page)
        host.modalPresentationStyle = .popover
        if let popover = host.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = rect
            popover.permittedArrowDirections = [.up, .down]
            popover.backgroundColor = UIColor(BookPalette.page)
            popover.delegate = Adaptivity.shared
        }
        presenter.present(host, animated: true)
    }
}

extension UIView {
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }
}

private extension UIViewController {
    /// The controller that can present right now: walk up to the one that owns
    /// the presentation context, then down past anything already shown.
    var topPresenter: UIViewController {
        var root: UIViewController = self
        while let parent = root.parent { root = parent }
        var top = root
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }
}

// MARK: - The chase

/// A loose word running across the leaf. It covers the window for the couple
/// of seconds it runs, so a miss lands on nothing; catch it inside the moment
/// or it dives back into its line.
final class LooseWordChaseView: UIView {
    private let word: UIView
    private let home: CGRect
    private var onCaught: ((CGRect) -> Void)?
    private var onEscaped: (() -> Void)?
    private var finished = false

    static let runDuration: CFTimeInterval = 2.4

    init(bounds: CGRect, word: UIView, home: CGRect) {
        self.word = word
        self.home = home
        super.init(frame: bounds)
        backgroundColor = .clear
        word.frame = home
        addSubview(word)
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func run(across arena: CGRect, seed: Int, caught: @escaping (CGRect) -> Void, escaped: @escaping () -> Void) {
        onCaught = caught
        onEscaped = escaped
        let start = CGPoint(x: home.midX, y: home.midY)
        let inner = arena.insetBy(dx: max(24, home.width / 2 + 8), dy: 40)
        var points = [start]
        var state = UInt64(truncatingIfNeeded: seed) | 1
        func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 10_000) / 10_000
        }
        // A scamper: short darts this way and that, then home.
        for _ in 0..<4 {
            points.append(CGPoint(x: inner.minX + next() * inner.width, y: inner.minY + next() * inner.height))
        }
        points.append(start)
        let path = UIBezierPath()
        path.move(to: points[0])
        for index in 1..<points.count {
            let a = points[index - 1], b = points[index]
            let lift = CGPoint(x: (a.x + b.x) / 2 + (next() - 0.5) * 80, y: min(a.y, b.y) - 30 - next() * 50)
            path.addQuadCurve(to: b, controlPoint: lift)
        }

        let travel = CAKeyframeAnimation(keyPath: "position")
        travel.path = path.cgPath
        travel.calculationMode = .paced
        let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wobble.values = [0, -0.25, 0.22, -0.18, 0.3, -0.12, 0.2, 0]
        let bob = CAKeyframeAnimation(keyPath: "transform.scale")
        bob.values = [1, 1.25, 1.05, 1.3, 1.1, 1.25, 1]
        let group = CAAnimationGroup()
        group.animations = [travel, wobble, bob]
        group.duration = Self.runDuration
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in self?.escape() }
        word.layer.add(group, forKey: "scamper")
        CATransaction.commit()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        finished ? nil : self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !finished, let touch = touches.first,
              let presentation = word.layer.presentation() else { return }
        // The finger's generous and the word's quick; a little slack is fair.
        let reach = presentation.frame.insetBy(dx: -22, dy: -22)
        guard reach.contains(touch.location(in: self)) else { return }
        catchIt(at: presentation)
    }

    private func catchIt(at presentation: CALayer) {
        finished = true
        word.layer.position = presentation.position
        word.layer.transform = presentation.transform
        word.layer.removeAllAnimations()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let home = self.home
        UIView.animate(withDuration: 0.18, animations: {
            self.word.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
        }, completion: { _ in
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4, animations: {
                self.word.transform = .identity
                self.word.center = CGPoint(x: home.midX, y: home.midY)
            }, completion: { _ in
                self.onCaught?(home)
                self.finish()
            })
        })
    }

    private func escape() {
        guard !finished else { return }
        finished = true
        onEscaped?()
        finish()
    }

    private func finish() {
        onCaught = nil
        onEscaped = nil
        UIView.animate(withDuration: 0.2, animations: { self.word.alpha = 0 }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}
