import XCTest
@testable import InsideCoverCore

final class EarnedReaderTracePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: day,
            hour: hour
        ))!
    }

    private func capturedDay(_ day: Int, line: String) -> BookDay {
        let createdAt = date(day)
        return BookDay(
            id: BookDay.id(for: createdAt, calendar: calendar),
            date: calendar.startOfDay(for: createdAt),
            pages: [
                BookPage(
                    id: "evidence-\(day)",
                    type: .souvenir,
                    createdAt: createdAt,
                    promptText: "Brought from elsewhere",
                    userInput: line,
                    tags: ["reader-evidence"],
                    sourceID: "souvenir-page",
                    origin: .userAuthored
                )
            ]
        )
    }

    private func currentDay() -> BookDay {
        let now = date(30, hour: 20)
        return BookDay(
            id: BookDay.id(for: now, calendar: calendar),
            date: calendar.startOfDay(for: now),
            pages: []
        )
    }

    func testNewEvidenceCreatesOneReturnDebtAfterTheLibraryMatures() {
        var inputs = BookSourceInputs.empty
        inputs.days = [
            capturedDay(1, line: "The radiator corrected its own knock."),
            capturedDay(5, line: "An orange peel became a paper moon."),
            capturedDay(10, line: "One square of cold sky waited upstairs."),
            capturedDay(29, line: "The cold window warmed the lamplight.")
        ]

        let owed = EarnedReaderTracePolicy.owedEvidencePage(
            day: currentDay(),
            inputs: inputs,
            distressActive: false,
            now: date(30, hour: 20)
        )

        XCTAssertEqual(owed?.id, "evidence-29")
    }

    func testReturnDebtNeedsBothNewEvidenceAndThreeDaysOfRest() {
        var inputs = BookSourceInputs.empty
        inputs.days = [
            capturedDay(1, line: "The radiator corrected its own knock."),
            capturedDay(5, line: "An orange peel became a paper moon."),
            capturedDay(10, line: "One square of cold sky waited upstairs."),
            capturedDay(29, line: "The cold window warmed the lamplight.")
        ]
        inputs.surfaceHistory[SurfacePage.earnedReaderTraceHistoryKey] = SurfaceHistoryRecord(
            lastShownAt: date(28),
            recentShowCount: 1
        )

        XCTAssertNil(EarnedReaderTracePolicy.owedEvidencePage(
            day: currentDay(),
            inputs: inputs,
            distressActive: false,
            now: date(30, hour: 20)
        ))

        inputs.surfaceHistory[SurfacePage.earnedReaderTraceHistoryKey] = SurfaceHistoryRecord(
            lastShownAt: date(20),
            recentShowCount: 1
        )
        XCTAssertEqual(EarnedReaderTracePolicy.owedEvidencePage(
            day: currentDay(),
            inputs: inputs,
            distressActive: false,
            now: date(30, hour: 20)
        )?.id, "evidence-29")

        inputs.surfaceHistory[SurfacePage.earnedReaderTraceHistoryKey] = SurfaceHistoryRecord(
            lastShownAt: date(30, hour: 8),
            recentShowCount: 1
        )
        XCTAssertNil(EarnedReaderTracePolicy.owedEvidencePage(
            day: currentDay(),
            inputs: inputs,
            distressActive: true,
            now: date(30, hour: 20)
        ))
    }

    func testProfilePersonalizationIsNotMistakenForEarnedRecognition() {
        let profileLetter = SurfacePage(
            id: "profile-letter",
            type: .letter,
            sourceID: "letters-page",
            prompt: "A letter for Rowan",
            detail: "Markets and ferry terminals are worth writing to.",
            payload: BookPagePayload(
                headline: "A letter",
                body: "Address the player as Rowan.",
                metadata: ["senderID": "lysander-mosswood"]
            )
        )
        let exactDiary = SurfacePage(
            id: "exact-diary",
            type: .diary,
            sourceID: "diary-page",
            prompt: "The green cart squealed like a gate. What changed?",
            detail: "The Book chose one exact line.",
            payload: BookPagePayload(
                headline: "What the Page Left Out",
                body: "One sentence is enough.",
                metadata: [
                    "journalEvidencePageID": "green-cart",
                    "journalEvidenceExcerpt": "The green cart squealed like a gate."
                ]
            )
        )

        XCTAssertFalse(profileLetter.carriesEarnedReaderTrace)
        XCTAssertTrue(exactDiary.carriesEarnedReaderTrace)
    }

    func testCuratorSpendsTheDebtAsAVisibleEchoWithoutAnotherTask() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = [
            capturedDay(1, line: "The radiator corrected its own knock."),
            capturedDay(5, line: "An orange peel became a paper moon."),
            capturedDay(10, line: "One square of cold sky waited upstairs."),
            capturedDay(29, line: "The cold window warmed the lamplight.")
        ]
        inputs.resurfacingCandidates = inputs.days.flatMap(\.pages)
        inputs.bookInterior = BookInteriorState(
            awakenedAt: date(1).addingTimeInterval(-14 * 86_400)
        )
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)

        let desk = BookCurator.surfacedPages(
            for: currentDay(),
            context: CuratorContext.make(for: currentDay()),
            inputs: inputs,
            now: date(30, hour: 20),
            limit: 3
        )
        let trace = try XCTUnwrap(desk.first(where: \.carriesEarnedReaderTrace))

        XCTAssertEqual(trace.payload.metadata["rememberedText"], "The cold window warmed the lamplight.")
        XCTAssertEqual(
            trace.payload.metadata[BookSessionIntention.metadataRole],
            BookSessionRole.echo.rawValue
        )
        XCTAssertTrue(trace.payload.body.contains("No errand."))
        XCTAssertTrue(trace.payload.body.contains("I kept it"))
        XCTAssertLessThanOrEqual(desk.filter(\.isReaderFacingAsk).count, 1)
    }
}
