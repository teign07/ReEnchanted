import XCTest
@testable import InsideCoverCore

/// The Book must not arrange the evidence it then treats as proof.
///
/// Two separate contaminations, and a promise is judged on neither. The first
/// is the Book having *said* a thing — tell somebody rain brings out a word and
/// they notice the word in the rain. The second is the Book having *arranged*
/// it: a Working it set, an errand a talisman demanded. The reader really did
/// those, and they are real receipts — but doing what you were asked is not
/// independent evidence that the asking was right.
final class GrimoireInterventionTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func feature(
        _ id: String, _ domain: String, role: LoomFeatureRole
    ) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: id,
            conditionClause: "it was \(id)", outcomeClause: "you \(id)",
            role: role, provenance: .readerAuthored
        )
    }

    private func observation(day: Int, _ features: [LoomFeatureRef], asked: Bool = false) -> LoomObservation {
        LoomObservation(
            id: "day-\(day)", day: day,
            occurredAt: GrimoireDay.date(for: day, calendar: calendar),
            features: features, evidencePageID: "page-\(day)", evidenceLine: "",
            bookAsked: asked
        )
    }

    func testADayTheBookArrangedIsRememberedAsSuch() {
        var ledger = GrimoireLedger()
        let rain = feature("weather:rain", "weather", role: .conditionOnly)
        let word = feature("word:lantern", "word", role: .outcomeOnly)
        ledger.ingest([
            observation(day: 10, [rain, word]),
            observation(day: 11, [rain, word], asked: true)
        ])
        XCTAssertFalse(ledger.bookAskedDays.contains(10))
        XCTAssertTrue(ledger.bookAskedDays.contains(11))
    }

    /// The whole point: a claim cannot be propped up by behaviour the Book
    /// itself set in motion.
    func testAPromiseIsNotJudgedOnBehaviourTheBookArranged() throws {
        var ledger = GrimoireLedger()
        let rain = feature("weather:rain", "weather", role: .conditionOnly)
        let word = feature("word:lantern", "word", role: .outcomeOnly)
        let hour = feature("hour:night", "hour", role: .conditionOnly)

        // A clean run: rain and the word, reliably, on the reader's own steam.
        var observations: [LoomObservation] = []
        for day in 0..<60 {
            var features: [LoomFeatureRef] = [hour]
            if day % 2 == 0 { features.append(rain); features.append(word) }
            observations.append(observation(day: day, features))
        }
        ledger.ingest(observations)
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 61, calendar: calendar),
                                      budget: 1_000, calendar: calendar)
            passes += 1
            if report.finished || passes > 60 { break }
        }
        let id = GrimoireCorrespondence.key(
            shape: .conditional, condition: "weather:rain", outcome: "word:lantern"
        )
        XCTAssertNotNil(ledger.row(id))
        ledger.markSpoken(id, now: GrimoireDay.date(for: 61, calendar: calendar), calendar: calendar)

        // Now the Book arranges rainy-day outings and the word keeps appearing.
        // Every one of these is real, and none of it is a witness.
        var arranged: [LoomObservation] = []
        for day in 70..<100 where day % 2 == 0 {
            arranged.append(observation(day: day, [hour, rain, word], asked: true))
        }
        ledger.ingest(arranged)

        let row = try XCTUnwrap(ledger.row(id))
        XCTAssertNil(
            ledger.promiseEvidence(for: row, calendar: calendar),
            "the Book counted behaviour it set up as proof it was right"
        )
    }

    func testTheSameDaysStillCountForFindingThingsInTheFirstPlace() throws {
        // Arranged days are not evidence *for a promise*, but they still
        // happened, and the Book is allowed to notice them.
        var ledger = GrimoireLedger()
        let errand = feature("talisman:seal", "talisman", role: .conditionOnly)
        let paid = feature("errand-outcome:paid", "errandOutcome", role: .outcomeOnly)
        let hour = feature("hour:day", "hour", role: .conditionOnly)
        var observations: [LoomObservation] = []
        for day in 0..<60 {
            var features: [LoomFeatureRef] = [hour]
            let asked = day % 4 == 0
            if asked { features.append(errand); features.append(paid) }
            observations.append(observation(day: day, features, asked: asked))
        }
        ledger.ingest(observations)
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 61, calendar: calendar),
                                      budget: 1_000, calendar: calendar)
            passes += 1
            if report.finished || passes > 60 { break }
        }
        XCTAssertNotNil(
            ledger.row(GrimoireCorrespondence.key(
                shape: .conditional, condition: "talisman:seal", outcome: "errand-outcome:paid"
            )),
            "arranged days still happened and may still be counted"
        )
    }

    func testEveryBookArrangedSourceSaysSo() {
        let date = GrimoireDay.date(for: 40, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = BookDay(
            id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
            date: calendar.startOfDay(for: date), pages: []
        )
        let working = BookWorking(
            id: "w", recipeID: "unnecessary-route",
            initiatorKind: .character, initiatorID: "wicker", initiatorName: "Wicker",
            title: "t", summons: "s", invitation: "i", returnPrompt: "r",
            createdAt: date, startsAt: date, endsAt: date,
            status: .returned, effects: [], returnedAt: date
        )
        let errand = PactErrand(
            id: "e", talismanID: "ember-seal", territoryID: "t",
            openingLine: "o", terms: "t", offeredAt: date, deadline: date,
            status: .delivered, fieldReport: nil, talismanResponse: nil, deliveredAt: date
        )
        var aside = BookAsideReceipt(
            id: "a", servedAt: date, surfaceID: "s", sourceID: "src",
            intention: "i", thoughtKey: "t", wordingKey: "w"
        )
        aside.response = .goOn
        aside.respondedAt = date

        XCTAssertTrue(WorkingProjector.bookAsked(
            forDay: day, in: GrimoireSlice(days: [], workings: [working], calendar: calendar)
        ))
        XCTAssertTrue(PactErrandProjector.bookAsked(
            forDay: day, in: GrimoireSlice(days: [], pactErrands: [errand], calendar: calendar)
        ))
        XCTAssertTrue(AsideReplyProjector.bookAsked(
            forDay: day, in: GrimoireSlice(days: [], asideReceipts: [aside], calendar: calendar)
        ))
        // The weather is nobody's doing.
        XCTAssertFalse(MoonProjector.bookAsked(
            forDay: day, in: GrimoireSlice(days: [], calendar: calendar)
        ))
        XCTAssertFalse(WorkingProjector.bookAsked(
            forDay: day, in: GrimoireSlice(days: [], calendar: calendar)
        ))
    }

    func testTheMarkSurvivesTheVault() throws {
        var ledger = GrimoireLedger()
        let rain = feature("weather:rain", "weather", role: .conditionOnly)
        let word = feature("word:lantern", "word", role: .outcomeOnly)
        ledger.ingest([observation(day: 12, [rain, word], asked: true)])
        let restored = try JSONDecoder().decode(
            GrimoireLedger.self, from: JSONEncoder().encode(ledger)
        )
        XCTAssertTrue(restored.bookAskedDays.contains(12))
    }
}
