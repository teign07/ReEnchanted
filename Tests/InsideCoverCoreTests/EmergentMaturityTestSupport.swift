import Foundation
@testable import InsideCoverCore

extension BookSourceInputs {
    /// Seeds enough backdated kept pages that `libraryReadyForReflectivePages`
    /// returns true, so tests of the reflective/emergent pages (Two Readings,
    /// the Loom, Book Notices, Book Remembers, Constellations) aren't blocked by
    /// the early-days maturity gate.
    func withMatureLibrary(now: Date = Date(), calendar: Calendar = .current) -> BookSourceInputs {
        var copy = self
        var seeded: [BookDay] = []
        for offset in 1...3 {
            let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) ?? now
            let pages = (0..<2).map { i in
                BookPage(
                    type: .diary,
                    createdAt: date.addingTimeInterval(Double(i) * 3600),
                    promptText: "seed",
                    userInput: "kept fragment \(offset)-\(i)"
                )
            }
            seeded.append(BookDay(id: BookDay.id(for: date), date: date, pages: pages))
        }
        copy.days = seeded + copy.days
        return copy
    }
}
