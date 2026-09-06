import XCTest
@testable import InsideCoverCore

/// Is the live Relational Loom recompute actually expensive?
///
/// Two user-facing paths rebuild it over the whole archive on every call
/// (`LiteraryContinuity.swift` braid context and dispute evidence). Before
/// replacing either with a grimoire read — which would change generated prose —
/// it is worth knowing what the recompute costs and what it produces that the
/// grimoire's projectors do not.
final class LoomCutoverBench: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private struct Dice {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(max(1, bound)))
        }
    }

    private func archive(days count: Int) -> [BookDay] {
        var dice = Dice(state: 0xC0FFEE)
        let weathers = ["rain", "clear", "fog", "bright", "snow"]
        let places = (0..<10).map { "place-\($0)" }
        var out: [BookDay] = []
        for index in 0..<count {
            let date = calendar.date(
                byAdding: .hour, value: 9 + dice.next(10),
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            var pages: [BookPage] = []
            for slot in 0...dice.next(3) {
                pages.append(BookPage(
                    id: "page-\(index)-\(slot)",
                    type: slot == 0 ? .diary : .souvenir,
                    createdAt: date,
                    promptText: "Prompt",
                    userInput: "The harbour and the lantern and the long walk home, number \(dice.next(500)).",
                    tags: ["entity:wicker", "choice:the-long-way"],
                    origin: .userAuthored,
                    context: BookPageContextSnapshot(
                        at: date, calendar: calendar,
                        weatherTags: [weathers[dice.next(weathers.count)]],
                        nearbyAnchorID: places[dice.next(places.count)]
                    )
                ))
            }
            out.append(BookDay(
                id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
                date: calendar.startOfDay(for: date),
                pages: pages
            ))
        }
        return out
    }

    private func seconds(_ work: () -> Void) -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        work()
        return CFAbsoluteTimeGetCurrent() - start
    }

    /// Long-running on purpose: something has to be on the stack long enough
    /// for `sample` to see it. Skipped unless explicitly asked for.
    func testProfileHook() throws {
        guard ProcessInfo.processInfo.environment["LOOM_PROFILE"] == "1" else {
            throw XCTSkip("set LOOM_PROFILE=1 to profile")
        }
        let days = archive(days: 1_460)
        for _ in 0..<20 {
            _ = RelationalLoom.connections(
                days: days, readerLearning: ReaderLearningModel(),
                facultyEntries: [], people: PeopleLedger(), calendar: self.calendar
            )
        }
    }

    func testWhatTheLiveLoomRecomputeCosts() {
        for size in [180, 730, 1_460] {
            let days = archive(days: size)
            var connections: [RelationalLoomConnection] = []
            let elapsed = seconds {
                connections = RelationalLoom.connections(
                    days: days,
                    readerLearning: ReaderLearningModel(),
                    facultyEntries: [],
                    people: PeopleLedger(),
                    calendar: self.calendar
                )
            }
            let families = Set(connections.flatMap { [$0.condition.family, $0.outcome.family] })
            print(String(
                format: "── loom recompute · %5d days: %8.1f ms · %3d connections · %2d families",
                size, elapsed * 1_000, connections.count, families.count
            ))
        }
    }

    /// What the old Loom can express that the grimoire's projectors cannot.
    ///
    /// This is the reason a straight cut-over would be a downgrade rather than
    /// an optimisation: the answer is not empty.
    func testWhichLoomFamiliesTheGrimoireDoesNotYetCover() {
        var covered: Set<String> = Set(GrimoireProjection.registered.flatMap { $0.domains })
        covered.insert(GrimoireProjection.blendDomain)
        // The two systems name several of the same things differently. A gap
        // list that counts vocabulary as missing coverage is a gap list nobody
        // can act on, so the known synonyms are mapped here.
        let synonyms: [String: String] = [
            "dayPart": "hour",
            "character": "cast",
            "activity": "pageKind",
            "tempo": "calendarLoad",
            "pulseBand": "readerState",
            "rutBand": "readerState",
            "innerWeather": "readerState"
        ]
        let loomFamilies = RelationalLoomFeature.Family.allCases.map(\.rawValue)
        let missing = loomFamilies
            .filter { !covered.contains(synonyms[$0] ?? $0) }
            .sorted()
        print("── grimoire covers \(covered.count) domains; loom has \(loomFamilies.count) families")
        print("── not yet covered: \(missing.joined(separator: ", "))")
        // Recorded, not asserted: this is a map of the remaining work, and it
        // should be allowed to shrink without breaking the build.
        XCTAssertFalse(loomFamilies.isEmpty)
    }
}
