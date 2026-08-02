import XCTest
@testable import InsideCoverCore

final class NoticeNowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    func testEveryPromptIsPresentTenseAndCarriesACaptureAsk() {
        for p in NoticeNowRegistry.all {
            XCTAssertFalse(p.text.isEmpty, "\(p.id) has no text")
            XCTAssertFalse(p.capture.isEmpty, "\(p.id) has no capture ask")
            // The interrupt must never imply a multi-step run.
            for banned in [" run ", " a run", "Compass", "constraint", " step "] {
                XCTAssertFalse(p.text.contains(banned), "\(p.id) leaks run framing: \(banned)")
            }
        }
    }

    func testPromptIDsAreUnique() {
        let ids = NoticeNowRegistry.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testAnytimePoolIsLocationBlind() {
        // The backbone pool has to work from a chair: no place, weather, or
        // hour tags allowed, or a reader with no signals gets a prompt they
        // cannot act on.
        for p in NoticeNowRegistry.anytime {
            XCTAssertTrue(p.tags.isEmpty, "\(p.id) is in the anytime pool but is tagged \(p.tags)")
        }
    }

    func testContextTagsReadHourWeatherPlaceAndBody() {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "steady rain",
            source: "test",
            currentTemperature: nil,
            forecast: "wind later",
            conditionSymbolName: "cloud.rain"
        )
        inputs.currentPlaceContext = .work
        let tags = NoticeNowRegistry.tags(inputs: inputs, now: now)
        XCTAssertTrue(tags.contains("rain"))
        XCTAssertTrue(tags.contains("wind"))
        XCTAssertTrue(tags.contains("work"))
    }

    func testMatchingContextOutranksTheAnytimeBackbone() {
        // Several pools can be live at once (night AND transit). The invariant
        // is that a context-matched prompt always beats the untagged backbone,
        // never that one particular pool wins the tie.
        var inputs = BookSourceInputs.empty
        inputs.currentPlaceContext = .transit
        let chosen = NoticeNowRegistry.prompt(inputs: inputs, now: now)
        let active = NoticeNowRegistry.tags(inputs: inputs, now: now)
        XCTAssertFalse(
            chosen.tags.isEmpty,
            "context was available but the untagged backbone won: \(chosen.id)"
        )
        XCTAssertFalse(
            active.intersection(Set(chosen.tags)).isEmpty,
            "\(chosen.id) matched none of the active context \(active)"
        )
    }

    func testShadowVariantDrawsOnlyFromTheShadowPool() {
        let chosen = NoticeNowRegistry.prompt(inputs: .empty, now: now, shadowVariant: true)
        XCTAssertTrue(NoticeNowRegistry.shadow.contains { $0.id == chosen.id })
    }

    func testBrightVariantNeverReturnsAShadowPrompt() {
        for hour in 0..<24 {
            let when = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            let chosen = NoticeNowRegistry.prompt(inputs: .empty, now: when)
            XCTAssertFalse(chosen.tags.contains("shadow-wonder"), "hour \(hour) leaked a shadow prompt")
        }
    }

    func testStandaloneNoticeCardNeverRepeatsItsInstruction() throws {
        // Kept page text is composed as `surface.prompt + payload.body`, and
        // the card renders `prompt` as its title. If the body also carried the
        // instruction the reader would read it twice on every kept page.
        let day = BookDay.today()
        let context = CuratorContext.make(for: day)
        let inputs = BookSourceInputs.empty
        let pages: [SurfacePage] = WonderCompassPageSourceAdapter()
            .candidates(for: day, context: context, inputs: inputs, now: now)
        let notice = try XCTUnwrap(pages.first { page in
            page.payload.metadata["standalone"] == "true"
                && page.payload.metadata["compassStep"] == "notice"
        })
        let id: String = try XCTUnwrap(notice.payload.metadata["noticeNowID"])
        let source: NoticeNowPrompt = try XCTUnwrap(NoticeNowRegistry.all.first { $0.id == id })
        XCTAssertEqual(notice.prompt, source.text)
        XCTAssertEqual(notice.payload.body, source.capture)
        XCTAssertFalse(notice.payload.body.contains(source.text))
    }

    func testNoSignalStillReturnsAUsablePrompt() {
        let chosen = NoticeNowRegistry.prompt(inputs: .empty, now: now)
        XCTAssertFalse(chosen.text.isEmpty)
    }
}
