import Foundation

enum BookInterruptionKind: String, Codable, Equatable {
    case ordinary, person, weather, braid, festival, interior, favor, anchor, outcome, working, attention
}
enum BookInterruptionWindow: String, Codable, CaseIterable, Equatable { case morning, evening }
struct BookInterruptionCandidate: Equatable {
    var id: String
    var dayID: String
    var window: BookInterruptionWindow
    var kind: BookInterruptionKind
    var isSpecific: Bool = false
    var priority: Int = 0
    /// Earlier expiry/fire wins between otherwise equal contextual hinges.
    var expiresAt: Date? = nil
}
struct BookInterruptionPlan: Equatable { var winners: [BookInterruptionCandidate] }

enum BookInterruptionBudget {
    /// Foreground/when-in-use location cannot guarantee a delivered global cap.
    /// Anchor arrivals therefore remain in-app proximity events.
    static let externalAnchorNotificationsEnabled = false

    static func plan(candidates: [BookInterruptionCandidate], cadence: BookWhisperCadence, consumed: Set<String> = []) -> BookInterruptionPlan {
        let allowed: Set<BookInterruptionWindow>
        switch cadence {
        case .inside: allowed = []
        case .both: allowed = [.morning, .evening]
        case .morning: allowed = [.morning]
        case .evening: allowed = [.evening]
        }
        let eligible = candidates.filter {
            ($0.kind == .attention || allowed.contains($0.window))
                && !consumed.contains("\($0.dayID)|\($0.window.rawValue)")
        }
        let winners = Dictionary(grouping: eligible, by: { "\($0.dayID)|\($0.window.rawValue)" })
            .values.compactMap { $0.sorted { a, b in
                if a.isSpecific != b.isSpecific { return a.isSpecific && !b.isSpecific }
                if a.priority != b.priority { return a.priority > b.priority }
                switch (a.expiresAt, b.expiresAt) {
                case let (left?, right?) where left != right: return left < right
                case (_?, nil): return true
                case (nil, _?): return false
                default: break
                }
                return a.id < b.id
            }.first }.sorted { $0.id < $1.id }
        return BookInterruptionPlan(winners: winners)
    }
}
