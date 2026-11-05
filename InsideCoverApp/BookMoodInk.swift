import SwiftUI
import UIKit
import os

/// Carries the Book's mood lettering from where the mood is reconciled to the
/// leaves that draw it.
///
/// Pushed, never polled: `refreshBookInterior` hands it the interior, and it
/// changes only when the mood crosses a step (`BookMoodLettering` sorts every
/// mood into three strengths). So the leaves redraw a few times a day at most,
/// and nothing here wakes the screen on its own.
@MainActor
@Observable
final class BookMoodInk {
    static let shared = BookMoodInk()

    private(set) var lettering: BookMoodLettering?

    private init() {
        #if DEBUG
        if let forced = Self.forced, let stance = forced.stance {
            let held = BookMoodLettering(stance: stance, strength: forced.strength, night: false)
            lettering = held
            Self.tempoLock.withLock { $0 = held.tempo }
        }
        #endif
    }

    func update(interior: BookInteriorState?, now: Date = Date()) {
        var next = BookMoodLettering.current(interior: interior, now: now)
        #if DEBUG
        if let forced = Self.forced {
            next = forced.stance.map { BookMoodLettering(stance: $0, strength: forced.strength, night: false) }
        }
        #endif
        guard next != lettering else { return }
        lettering = next
        appLog.info("Mood ink: \(next.map { "\($0.stance.rawValue) \($0.strength)\($0.night ? " night" : "")" } ?? "plain", privacy: .public)")
        let tempo = next?.tempo ?? 1
        Self.tempoLock.withLock { $0 = tempo }
    }

    #if DEBUG
    /// `--smoke-mood mischievous:3` holds the Book in one mood so its ink can
    /// be looked at; `--smoke-mood plain` shows the ink without any mood.
    private static let forced: (stance: BookStance?, strength: Int)? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--smoke-mood"), arguments.indices.contains(index + 1) else { return nil }
        let parts = arguments[index + 1].split(separator: ":")
        let strength = parts.count > 1 ? Int(parts[1]) ?? 3 : 3
        return (parts.first.flatMap { BookStance(rawValue: String($0)) }, strength)
    }()
    #endif

    nonisolated private static let tempoLock = OSAllocatedUnfairLock(initialState: 1.0)

    /// How long new ink takes to arrive, against the usual time. Read by the
    /// ink clock wherever it runs, so it's kept behind a lock rather than on
    /// the main actor.
    nonisolated static var tempo: Double { tempoLock.withLock { $0 } }
}

extension BookMoodLettering {
    /// `color`, leaned toward this mood's ink and pressed as hard as the mood
    /// presses.
    func inked(_ color: Color, lean: Double) -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return color }
        let mixed = RGB(red: Double(red), green: Double(green), blue: Double(blue)).mixed(toward: hue, by: lean)
        return Color(red: mixed.red, green: mixed.green, blue: mixed.blue).opacity(Double(alpha) * inkOpacity)
    }
}
