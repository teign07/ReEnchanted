import SwiftUI
#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif

/// "What the Book noticed" — Apple's Journaling Suggestions, offered as prompt
/// material. The picker runs out of process; the app only ever sees the moment
/// the reader chooses. iPhone-only, iOS 17.2+, and behind the framework's
/// availability, so it compiles to an empty view everywhere else.
///
/// Kept deliberately minimal: a chosen suggestion becomes a one-line seed
/// (its title, dated), handed back for the reader to write from. Richer
/// per-type handling (loading a suggested photo, a song, a route) can grow
/// here later without touching call sites.
struct BookNoticesPicker<Label: View>: View {
    let onSeed: (String) -> Void
    @ViewBuilder let label: () -> Label

    /// The `com.apple.developer.journal.allow` entitlement requires a paid
    /// Apple Developer team with the Journaling Suggestions capability approved.
    /// Flip to `true` (and re-add the entitlement to InsideCoverApp.entitlements)
    /// once that provisioning is in place; until then the picker would present
    /// nothing, so we keep the entry point hidden.
    static var entitlementProvisioned: Bool { false }

    static var isAvailable: Bool {
        #if canImport(JournalingSuggestions)
        if entitlementProvisioned, #available(iOS 17.2, *) {
            return UIDevice.current.userInterfaceIdiom == .phone
        }
        #endif
        return false
    }

    var body: some View {
        #if canImport(JournalingSuggestions)
        if #available(iOS 17.2, *), UIDevice.current.userInterfaceIdiom == .phone {
            JournalingSuggestionsPicker {
                label()
            } onCompletion: { suggestion in
                let seed = Self.seed(from: suggestion)
                await MainActor.run { onSeed(seed) }
            }
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }

    #if canImport(JournalingSuggestions)
    @available(iOS 17.2, *)
    private static func seed(from suggestion: JournalingSuggestion) -> String {
        let title = suggestion.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "" }
        if let date = suggestion.date?.start {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "\(title) — \(formatter.string(from: date))"
        }
        return title
    }
    #endif
}
