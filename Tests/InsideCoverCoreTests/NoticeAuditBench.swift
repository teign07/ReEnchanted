import XCTest
@testable import InsideCoverCore

/// Reads every "I Notice" and connection Page the engines would put on the
/// desk, the way the reader meets them. The archive is random but lived-in:
/// ordinary days, photos with what Vision saw, voice notes, places, weather,
/// a body, and two real patterns (rain slows the heart; harbor days run long).
/// Off by default: `NOTICE_AUDIT=1 swift test --filter NoticeAuditBench`.
final class NoticeAuditBench: XCTestCase {
    private struct Random {
        var state: UInt64
        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
        }
        mutating func pick<T>(_ items: [T]) -> T { items[Int(next() * Double(items.count)) % items.count] }
    }

    private let lines = [
        "Mom called while I was making toast and we talked about her garden for an hour.",
        "The bus was late again so I walked, and the maple on Elm Street has gone completely red.",
        "Couldn't sleep. Listened to the rain on the skylight until it stopped.",
        "Work was a slog. Two meetings that could have been emails.",
        "Found a perfect skipping stone at the harbor and kept it in my pocket all day.",
        "The cat knocked my coffee off the desk and looked pleased about it.",
        "Made soup with the last of the squash. The kitchen smelled like autumn.",
        "Walked down to the harbor at sunset. The boats were all facing the same way.",
        "Sam came over and we played cards until midnight. I lost every hand.",
        "Fog so thick this morning I couldn't see the end of the street.",
        "Read three chapters of the library book on the porch.",
        "A crow followed me from the bakery to the post office.",
        "Tired. Just tired. Went to bed early.",
        "The neighbor's kid drew a chalk dragon across the whole sidewalk.",
        "Long phone call with Dana about moving. Still don't know what she'll do.",
        "Rain all day. I reorganized the bookshelf by colour instead of working.",
        "The harbor was loud with gulls and someone's radio playing old songs.",
        "Burned the rice. Ate it anyway.",
        "Saw the first frost on the car windshield and drew a smiley face in it.",
        "Quiet day. Folded laundry and watched the light move across the floor."
    ]
    private let places = [("harbor", "the harbor"), ("home", "Home"), ("work", "Work"), ("bakery", "the bakery")]
    private let photoSubjects = [
        ("gull,water,pier", "gull", "blue", "0"), ("maple,tree,street", "maple", "orange", "0"),
        ("cat,desk,mug", "cat", "warm", "0"), ("soup,bowl,kitchen", "soup", "orange", "0"),
        ("boat,harbor,sunset", "boat", "gold", "0"), ("person,cards,table", "person", "warm", "2"),
        ("fog,street,lamp", "fog", "grey", "0"), ("chalk,sidewalk,dragon", "chalk", "green", "1")
    ]

    private func archive(days count: Int, now: Date, seed: UInt64) -> [BookDay] {
        var random = Random(state: seed)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var days: [BookDay] = []
        for ago in (1...count).reversed() {
            let dayStart = calendar.date(byAdding: .day, value: -ago, to: calendar.startOfDay(for: now))!
            let rain = random.next() < 0.3
            let weather = rain ? ["rain", "cloud"] : [random.pick(["bright", "cloud", "wind", "fog"])]
            var pages: [BookPage] = []
            for slot in 0..<(1 + Int(random.next() * 3)) {
                let hour = [8, 12, 18, 22][min(3, slot + Int(random.next() * 2))]
                let at = calendar.date(bySettingHour: hour, minute: Int(random.next() * 59), second: 0, of: dayStart)!
                let place = random.pick(places)
                var text = random.pick(lines)
                if place.0 == "harbor" { text += " I stayed by the water a long time and kept noticing small things." }
                var context = BookPageContextSnapshot(
                    at: at, calendar: calendar, weatherTags: weather,
                    calendarEventCount: Int(random.next() * 5),
                    nearbyAnchorID: place.0, locationLabel: place.1,
                    restingHeartRate: (rain ? 57 : 63) + Int(random.next() * 5),
                    heartRateVariability: 30 + random.next() * 30
                )
                context.sleepHours = 5.5 + random.next() * 3
                context.steps = 2_000 + Int(random.next() * 11_000)
                var media: [BookPageMediaAsset] = []
                if random.next() < 0.25 {
                    let subject = random.pick(photoSubjects)
                    media.append(BookPageMediaAsset(
                        kind: .photoLibraryAsset, reference: "/tmp/\(ago)-\(slot).jpg",
                        metadata: [
                            "assetLocalIdentifier": "audit-\(ago)-\(slot)", "attentionModality": "photo",
                            "attentionLabels": subject.0, "attentionSubject": subject.1,
                            "attentionColorMood": subject.2, "attentionPeopleCount": subject.3,
                            "attentionBrightness": "soft light", "attentionBackend": "appleVisionClassifier",
                            "attentionCertainty": "likely"
                        ]
                    ))
                }
                if random.next() < 0.08 {
                    media.append(BookPageMediaAsset(
                        kind: .audioFile, reference: "/tmp/v\(ago).m4a",
                        metadata: ["keptVoice": "true", BookPageMediaAsset.voiceTranscriptMetadataKey: text]
                    ))
                }
                pages.append(BookPage(
                    id: "audit-\(ago)-\(slot)", type: random.pick([.diary, .souvenir, .souvenir, .plainPage]),
                    createdAt: at, promptText: "What stayed with you?", userInput: text,
                    origin: .userAuthored, mediaAssets: media, context: context
                ))
            }
            days.append(BookDay(id: BookDay.id(for: dayStart, calendar: calendar), date: dayStart, pages: pages))
        }
        return days
    }

    func testReadEveryNoticeLikeAReader() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NOTICE_AUDIT"] == "1")
        let now = Date(timeIntervalSince1970: 1_792_950_000)
        let all = archive(days: 120, now: now, seed: 2026)
        var seen = Set<String>()
        var report: [String] = []
        for back in (0..<14).reversed() {
            let moment = now.addingTimeInterval(-Double(back) * 86_400)
            let history = all.filter { $0.date < Calendar.current.startOfDay(for: moment) }
            let today = BookDay(id: BookDay.id(for: moment), date: Calendar.current.startOfDay(for: moment), pages: [])
            var inputs = BookSourceInputs.empty
            inputs.days = history
            inputs.localBrainIsReady = true
            inputs.continuity = LiteraryContinuityProjector.digest(days: history, events: [], entityMemories: [], now: moment)
            let context = CuratorContext.make(for: today, recentDays: history)
            for adapter in BookPageSourceAdapters.active {
                for surface in adapter.candidates(for: today, context: context, inputs: inputs, now: moment)
                where [.bookNotices, .bookConnections, .bookRemembered].contains(surface.type) {
                    let body = surface.payload.body.replacingOccurrences(of: "\n", with: " ")
                    let key = surface.payload.headline + body.prefix(80)
                    guard seen.insert(key).inserted else { continue }
                    report.append("[\(String(describing: type(of: adapter)))] \(surface.payload.headline) :: \(body.prefix(500))")
                }
            }
        }
        print("NOTICE_AUDIT \(report.count) distinct pages")
        for line in report { print("NOTICE_AUDIT " + line) }
    }
}
