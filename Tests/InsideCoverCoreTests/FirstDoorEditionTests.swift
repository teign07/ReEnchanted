import XCTest
@testable import InsideCoverCore

/// The onboarding finale binds a real mini edition from a single synthetic
/// arrival day (souvenirs, Zara's letter, named constellations). These tests
/// pin the Shared-side behavior that makes that binding non-empty: the
/// curator must keep authored arrival pages, and the builder must carry the
/// named constellations into the star chart and foreword.
final class FirstDoorEditionTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var arrival: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 7, minute: 37)) ?? Date()
    }

    private func arrivalDay(_ now: Date) -> BookDay {
        let pages: [BookPage] = [
            BookPage(
                type: .souvenir,
                createdAt: now,
                promptText: "The first kept page",
                userInput: "I opened the Book at 7:37 AM on Saturday morning, while the day is still deciding what kind of page it is.",
                tags: ["onboarding", "first-page"],
                sourceID: "first-door"
            ),
            BookPage(
                type: .souvenir,
                createdAt: now.addingTimeInterval(60),
                promptText: "A belief, planted at the threshold",
                userInput: "Spoken aloud to Zara Finch: small true things matter",
                tags: ["onboarding", "belief"],
                sourceID: "first-door"
            ),
            BookPage(
                type: .letter,
                createdAt: now.addingTimeInterval(240),
                promptText: "Dear Reader,\n\nYou fell out of the Unwritten this morning and kept a page before anyone explained keeping.\n\n— Zara Finch",
                tags: ["onboarding", "zara", "letter"],
                // Reply-less letters only bind when the Book already wove them.
                usedInBookOfYou: true,
                sourceID: "zara-finch"
            )
        ]
        return BookDay(id: BookDay.id(for: now, calendar: calendar), date: calendar.startOfDay(for: now), pages: pages)
    }

    private func namedConstellation(id: String, subject: String, name: String, kind: LiterarySignalKind, now: Date) -> Constellation {
        Constellation(
            id: id,
            signalID: id,
            kind: kind,
            subjectID: id,
            subjectName: subject,
            name: name,
            phase: .named,
            firstNoticedAt: now,
            lastSeenAt: now,
            namedAt: now,
            wovenAt: nil,
            fadedAt: nil,
            sightingDayIDs: [BookDay.id(for: now, calendar: calendar)],
            strengthPeak: 3,
            latestLine: "Planted at the threshold.",
            evidencePageIDs: [],
            relatedEntityIDs: [],
            tags: ["onboarding"]
        )
    }

    private func firstDoorEdition() -> MonthlyEdition {
        let now = arrival
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)
        return MonthlyEditionBuilder.edition(
            from: [arrivalDay(now)],
            constellations: [
                namedConstellation(id: "onboarding-first-belief", subject: "small true things matter", name: "The First Belief", kind: .beliefLifecycle, now: now),
                namedConstellation(id: "onboarding-sleeve-word", subject: "GLINT", name: "The Glint", kind: .pattern, now: now)
            ],
            readerName: "Reader",
            startDate: monthStart,
            endDate: now,
            generatedAt: now,
            calendar: calendar
        )
    }

    func testArrivalDayBindsNonEmptyEdition() {
        let edition = firstDoorEdition()
        XCTAssertFalse(edition.isEmpty, "A single authored arrival day must still bind a non-empty edition.")
        XCTAssertGreaterThan(edition.pageCount, 0)
        XCTAssertEqual(edition.dayCount, 1)
    }

    func testCuratorKeepsAuthoredArrivalSouvenirs() {
        let edition = firstDoorEdition()
        let souvenirs = edition.sections.first { $0.id == "souvenirs" }
        XCTAssertNotNil(souvenirs, "Authored arrival souvenirs must survive curation into the souvenirs section.")
        XCTAssertGreaterThanOrEqual(souvenirs?.items.count ?? 0, 2)
    }

    func testZaraLetterBindsIntoLettersSection() {
        let edition = firstDoorEdition()
        let letters = edition.sections.first { $0.id == "letters" }
        XCTAssertNotNil(letters, "The synthesized Zara letter must bind into Letters And Voices.")
        XCTAssertTrue(
            letters?.items.contains { $0.body.contains("Zara Finch") } ?? false,
            "The letter body should carry Zara's signature."
        )
    }

    func testNamedConstellationsReachStarChartAndForeword() {
        let edition = firstDoorEdition()
        let alive = edition.constellations.filter(\.isAlive)
        XCTAssertEqual(alive.count, 2, "Both named arrival constellations must stay alive for the star chart page.")
        XCTAssertTrue(
            edition.foreword.contains("The First Belief") || edition.foreword.contains("The Glint"),
            "The foreword should name at least one arrival constellation."
        )
    }
}
