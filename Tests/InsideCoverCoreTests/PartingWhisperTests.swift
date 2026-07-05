import XCTest
@testable import InsideCoverCore

/// A tiny deterministic SplitMix64 generator so the probabilistic whisper roll
/// can be pinned in tests without depending on the system RNG.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class PartingWhisperTests: XCTestCase {
    private func surface(_ type: BookPageType) -> SurfacePage {
        SurfacePage(type: type, prompt: "prompt", detail: "detail")
    }

    func testWhisperNeverFiresWhenChanceIsZero() {
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<200 {
            let whisper = PartingWhisper.onDismiss(of: surface(.diary), whisperChance: 0, using: &rng)
            XCTAssertNil(whisper)
        }
    }

    func testWhisperAlwaysFiresWhenChanceIsOne() {
        var rng = SeededGenerator(seed: 2)
        for _ in 0..<200 {
            let whisper = PartingWhisper.onDismiss(of: surface(.diary), whisperChance: 1, using: &rng)
            XCTAssertNotNil(whisper)
        }
    }

    func testKeepsakeTierHonoursItsSubChance() {
        var neverRNG = SeededGenerator(seed: 3)
        for _ in 0..<200 {
            let whisper = PartingWhisper.onDismiss(
                of: surface(.diary),
                whisperChance: 1,
                keepsakeChance: 0,
                using: &neverRNG
            )
            XCTAssertEqual(whisper?.kind, .wink)
            XCTAssertNil(whisper?.keepsake)
        }

        var alwaysRNG = SeededGenerator(seed: 4)
        for _ in 0..<200 {
            let whisper = PartingWhisper.onDismiss(
                of: surface(.diary),
                whisperChance: 1,
                keepsakeChance: 1,
                using: &alwaysRNG
            )
            XCTAssertEqual(whisper?.kind, .keepsake)
            let keepsake = try? XCTUnwrap(whisper?.keepsake)
            XCTAssertFalse(keepsake?.object.isEmpty ?? true)
            XCTAssertFalse(keepsake?.glyph.isEmpty ?? true)
        }
    }

    func testPocketLedgerKeepsNewestAndHonoursCapacity() {
        var pocket = PocketLedger()
        let base = Date(timeIntervalSince1970: 1_000_000)
        for index in 0..<(PocketLedger.capacity + 10) {
            pocket.press(PocketKeepsake(
                id: "k-\(index)",
                dayID: "2026-07-04",
                pageType: .diary,
                object: "a pressed petal",
                glyph: "leaf",
                foundAt: base.addingTimeInterval(Double(index))
            ))
        }
        XCTAssertEqual(pocket.count, PocketLedger.capacity)
        // Newest first, and the very oldest were pushed out.
        XCTAssertEqual(pocket.newestFirst.first?.id, "k-\(PocketLedger.capacity + 9)")
        XCTAssertFalse(pocket.keepsakes.contains { $0.id == "k-0" })
    }

    func testPocketPressReplacesDuplicateIDs() {
        var pocket = PocketLedger()
        let stamp = Date(timeIntervalSince1970: 2_000_000)
        let make = { (object: String) in
            PocketKeepsake(id: "same", dayID: "d", pageType: .mood, object: object, glyph: "leaf", foundAt: stamp)
        }
        pocket.press(make("a pressed petal"))
        pocket.press(make("a coin of lamplight"))
        XCTAssertEqual(pocket.count, 1)
        XCTAssertEqual(pocket.keepsakes.first?.object, "a coin of lamplight")
    }

    func testWhisperFillsThePagePlaceholderAndDropsTheToken() {
        var rng = SeededGenerator(seed: 5)
        let whisper = PartingWhisper.onDismiss(of: surface(.souvenir), whisperChance: 1, using: &rng)
        let line = try? XCTUnwrap(whisper?.line)
        XCTAssertNotNil(line)
        XCTAssertFalse(line?.contains("{page}") ?? true)
        XCTAssertTrue(line?.contains("souvenir") ?? false)
    }

    func testExcludedTypesNeverWhisperEvenAtFullChance() {
        for type in PartingWhisper.excludedTypes {
            var rng = SeededGenerator(seed: 6)
            XCTAssertNil(PartingWhisper.onDismiss(of: surface(type), whisperChance: 1, using: &rng))
        }
    }

    func testPurchaseThankYouSurfaceNeverWhispers() {
        let thankYou = SurfacePage(
            type: .diary,
            prompt: "prompt",
            detail: "detail",
            payload: BookPagePayload(headline: "h", body: "b", metadata: ["purchaseThankYou": "true"])
        )
        var rng = SeededGenerator(seed: 7)
        XCTAssertNil(PartingWhisper.onDismiss(of: thankYou, whisperChance: 1, using: &rng))
    }
}
