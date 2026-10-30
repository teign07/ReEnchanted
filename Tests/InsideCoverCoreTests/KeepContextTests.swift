import XCTest
@testable import InsideCoverCore

/// The richer keep-time captures (Shared/KeepContext.swift) and what noticing
/// and the writing sessions do with them.
final class KeepContextTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_792_900_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func page(_ id: String, hoursAgo: Double, text: String = "Folded the laundry and watched the light on the floor.",
                      _ change: (inout BookPageContextSnapshot) -> Void = { _ in }) -> BookPage {
        let at = now.addingTimeInterval(-hoursAgo * 3_600)
        var context = BookPageContextSnapshot(at: at, calendar: calendar)
        change(&context)
        return BookPage(id: id, type: .diary, createdAt: at, promptText: "", userInput: text,
                        origin: .userAuthored, context: context)
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { calendar.startOfDay(for: $0.createdAt) }
            .map { BookDay(id: BookDay.id(for: $0.key, calendar: calendar), date: $0.key, pages: $0.value) }
            .sorted { $0.date < $1.date }
    }

    func testEveryNewCaptureRoundTripsAndOldPagesStillOpen() throws {
        var context = BookPageContextSnapshot(at: now)
        context.writing = WritingProcess(secondsWriting: 140, charactersDeleted: 80, pauses: 2, spokenOrPastedChunks: 1, charactersKept: 60)
        context.holding = HoldingSnapshot(posture: .sideways, moving: false, batteryPercent: 9, charging: false,
                                          lowPowerMode: true, screenBrightness: 0.1, headphones: true)
        context.minutesSinceEventEnded = 7
        context.sunAltitude = 3.2
        context.sea = SeaReading(seaLevelMeters: 1.1, rising: true, waveHeightMeters: 0.6)
        context.air = AirReading(usAQI: 42)
        context.kpIndex = 5.3
        context.bodyExtras = BodyExtras(daylightMinutes: 95, lastWorkout: "swim", minutesSinceWorkout: 40)
        let roundTrip = try JSONDecoder().decode(BookPageContextSnapshot.self, from: JSONEncoder().encode(context))
        XCTAssertEqual(roundTrip, context)

        let old = #"{"timeZoneIdentifier":"UTC","utcOffsetSeconds":0,"dayPart":"evening","weatherTags":[]}"#
        let older = try JSONDecoder().decode(BookPageContextSnapshot.self, from: Data(old.utf8))
        XCTAssertNil(older.holding)
        XCTAssertNil(older.writing)
        XCTAssertNil(older.sea)
    }

    func testTheSunsHeightIsRoughlyRight() {
        // Near the March equinox, noon on the equator is close to overhead and
        // midnight is far below.
        let equinoxNoonUTC = Date(timeIntervalSince1970: 1_773_964_800 + 12 * 3_600) // 2026-03-20 12:00 UTC
        XCTAssertGreaterThan(SunHeight.degrees(at: equinoxNoonUTC, latitude: 0, longitude: 0), 80)
        XCTAssertLessThan(SunHeight.degrees(at: equinoxNoonUTC.addingTimeInterval(12 * 3_600), latitude: 0, longitude: 0), -60)
        XCTAssertEqual(SunHeight.light(degrees: 4), "golden hour")
        XCTAssertEqual(SunHeight.light(degrees: -3), "blue hour")
        XCTAssertEqual(SunHeight.light(degrees: -12), "dark")
    }

    func testAPhotoCarriedFromTheBeachSaysHowFar() {
        let asset = BookPageMediaAsset(kind: .photoLibraryAsset, reference: "/tmp/b.jpg", metadata: [
            PhotoDetails.latitudeKey: "42.6556", PhotoDetails.longitudeKey: "-70.6203"
        ])
        let home = BookPageContextSnapshot(at: now, latitude: 42.3601, longitude: -71.0589)
        let kilometres = PhotoDetails.carriedKilometres(asset, keptAt: home) ?? 0
        XCTAssertEqual(kilometres, 49, accuracy: 3)
    }

    func testWritingOnYourSideMakesShorterPages() throws {
        var pages: [BookPage] = []
        for index in 0..<40 {
            let sideways = index % 4 == 0
            let words = sideways ? 6 + index % 3 : 30 + index % 9
            pages.append(page("p\(index)", hoursAgo: Double(index) * 20 + 2,
                              text: Array(repeating: "harbor", count: words).joined(separator: " ")) {
                $0.holding = HoldingSnapshot(posture: sideways ? .sideways : .upright)
            })
        }
        let found = NoticingCrossings.computeNoticings(days: days(pages), now: now, calendar: calendar)
        let side = try XCTUnwrap(found.first { $0.id == "crossing-posture-sideways-words" })
        XCTAssertTrue(side.line.hasPrefix("When you write lying on your side, your pages come out shorter."), side.line)
        XCTAssertNil(found.first { $0.id.hasPrefix("crossing-posture-upright") }, "upright is the ordinary state here, not a finding")
    }

    func testGoldenHourIsNeverCrossedWithTheHour() {
        let sun = NoticingCrossings.categoryMeasures.first { $0.id == "sunLight" }
        XCTAssertEqual(sun?.entangledNumbers, ["hour"])
        XCTAssertEqual(NoticingCrossings.categoryMeasures.first { $0.id == "screen" }?.entangledNumbers, ["hour"])
        XCTAssertEqual(NoticingCrossings.categoryMeasures.first { $0.id == "dayPart" }?.entangledNumbers, ["hour"])
    }

    func testCrossingOutMoreThanYouKept() throws {
        let pages = (0..<5).map { page("p\($0)", hoursAgo: Double($0) * 24 + 30) } + [
            page("messy", hoursAgo: 3) { $0.writing = WritingProcess(secondsWriting: 600, charactersDeleted: 400, charactersKept: 90) }
        ]
        let found = NoticingCrossings.computeNoticings(days: days(pages), now: now, calendar: calendar)
        let crossed = try XCTUnwrap(found.first { $0.id == "record-crossed-out-messy" })
        XCTAssertEqual(crossed.line, "You crossed out more than you kept on this one. I only got what you left. I didn't read the rest.")
    }

    func testTheFirstFaceAndAuroraWeather() throws {
        var pages = (0..<24).map { page("p\($0)", hoursAgo: Double($0) * 24 + 30) }
        var selfie = page("selfie", hoursAgo: 2) { $0.kpIndex = 6 }
        selfie.mediaAssets = [BookPageMediaAsset(kind: .photoLibraryAsset, reference: "/tmp/s.jpg",
                                                 metadata: [PhotoDetails.cameraKey: "front", "assetLocalIdentifier": "s"])]
        pages.append(selfie)
        let found = NoticingCrossings.computeNoticings(days: days(pages), now: now, calendar: calendar)
        XCTAssertNotNil(found.first { $0.id == "first-face-selfie" })
        let aurora = try XCTUnwrap(found.first { $0.headline == "A Storm You Can't Hear" })
        XCTAssertEqual(aurora.errand, "Tonight, if it's clear, look north.")
    }

    func testTheBookCanSenseHowAPageWasKept() {
        var context = BookPageContextSnapshot(at: now, weatherTags: ["rain"], locationLabel: "the harbor")
        context.holding = HoldingSnapshot(posture: .sideways, screenBrightness: 0.1, headphones: true)
        context.sea = SeaReading(rising: true)
        XCTAssertEqual(ThinkingMaterials.moment(context), "lying on your side, in the dark, with headphones in, as the tide came in")
        XCTAssertNil(ThinkingMaterials.moment(BookPageContextSnapshot(at: now)))
    }

    func testAConnectionRetoldInPlainWordsOrDropped() {
        let feature = { (id: String, family: RelationalLoomFeature.Family, label: String) in
            RelationalLoomFeature(id: id, family: family, label: label, conditionClause: label, outcomeClause: label,
                                  symbolName: "circle", carriesReaderSuppliedMeaning: false)
        }
        let connection = RelationalLoomConnection(
            id: "c1", observationKey: "relational:c1", headline: "Everything Has Neighbors",
            line: "When you were at the bakery, your subject leaned boat.",
            condition: feature("place:bakery", .place, "the bakery"), outcome: feature("subject:boat", .subject, "Subject boat"),
            evidence: [], evidencePageIDs: ["a", "b"], inHits: 6, inCount: 8, outHits: 2, outCount: 20,
            evidenceTier: .established, strength: 80
        )
        XCTAssertNil(RetoldConnections.accept("DROP", connection: connection))
        XCTAssertNil(RetoldConnections.accept("At the bakery your photographic palette leaned boat, six of eight times.", connection: connection),
                     "no jargon")
        XCTAssertNil(RetoldConnections.accept("Every time you go to the bakery you photograph boats. Twelve times now.", connection: connection),
                     "twelve was never counted")
        let plain = "When you go to the bakery, you come home with pictures of boats. Six times out of eight."
        XCTAssertEqual(RetoldConnections.accept(plain, connection: connection), plain)
        let surface = RetoldConnections.surface(plain, connection: connection)
        XCTAssertEqual(surface.payload.headline, "Something Keeps Happening")
        XCTAssertTrue(surface.payload.metadata["tags"]?.contains("connection-spoke:c1") == true)
    }
}
