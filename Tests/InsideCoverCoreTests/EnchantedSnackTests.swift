import XCTest
@testable import InsideCoverCore

final class EnchantedSnackTests: XCTestCase {
    func testProseFirstPageGetsMomentaryBeat() {
        let page = SurfacePage(type: .diary, prompt: "p", detail: "d")
        if case .momentary = MomentaryAttentionEngine.firstBeat(for: page, learning: .init()) {} else { XCTFail("expected momentary") }
    }
    func testNativeAndSpecializedPagesRemainNative() {
        XCTAssertEqual(MomentaryAttentionEngine.firstBeat(for: SurfacePage(type: .radio, prompt: "p", detail: "d"), learning: .init()), .native)
        let missionPayload = BookPagePayload(headline: "p", body: "d", metadata: ["playfulMissionID": "mission"])
        let page = SurfacePage(type: .diary, prompt: "p", detail: "d", payload: missionPayload)
        XCTAssertEqual(MomentaryAttentionEngine.firstBeat(for: page, learning: .init()), .native)
        let kept = SurfacePage(type: .diary, prompt: "p", detail: "d", payload: BookPagePayload(headline: "p", body: "d", metadata: ["keptReadback": "true"]))
        XCTAssertEqual(MomentaryAttentionEngine.firstBeat(for: kept, learning: .init()), .native)
    }
    func testPromptAndRecognitionPreserveExactWords() {
        let prompt = MomentaryAttentionEngine.prompt(for: SurfacePage(type: .diary, prompt: "p", detail: "d"), learning: .init())
        XCTAssertEqual(prompt?.question, "What caught first?")
        XCTAssertTrue(MomentaryAttentionEngine.recognition(for: "blue cup", stage: .notice).contains("“blue cup”"))
    }
}
