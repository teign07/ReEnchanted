import XCTest
@testable import InsideCoverCore

/// Manner signals: the Book reading *how* the reader writes: pace, hedging,
/// and the hour a subject keeps. Everything is measured against the reader's
/// own baseline, never a universal norm.
final class MannerSignalsTests: XCTestCase {

    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!

    private func daysAgo(_ days: Int, hour: Int = 10) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    private func page(_ text: String, at date: Date, id: String = UUID().uuidString, type: BookPageType = .diary) -> BookPage {
        BookPage(id: id, type: type, createdAt: date, promptText: "Prompt", userInput: text)
    }

    /// A page whose prose has `count` sentences of `length` words each.
    private func prosePage(sentences count: Int, length: Int, at date: Date, seasoning: String = "word") -> BookPage {
        let sentence = (0..<length).map { "\(seasoning)\($0)" }.joined(separator: " ")
        return page(Array(repeating: sentence, count: count).joined(separator: ". ") + ".", at: date)
    }

    // MARK: - Sentence pace

    func testPaceSignalNoticesFasterSentences() throws {
        let baseline = (0..<8).map { prosePage(sentences: 3, length: 15, at: daysAgo(20 + $0)) }
        let recent = (0..<4).map { prosePage(sentences: 3, length: 7, at: daysAgo(1 + $0)) }
        let signal = try XCTUnwrap(
            LiteraryContinuityProjector.sentencePaceSignal(prose: baseline + recent, now: now)
        )
        XCTAssertEqual(signal.kind, .manner)
        XCTAssertTrue(signal.tags.contains("fast"))
        XCTAssertTrue(signal.line.contains("walk faster"))
        XCTAssertTrue(signal.line.contains("seven words"), "The evidence is concrete: \(signal.line)")
    }

    func testPaceSignalNoticesSlowerSentences() throws {
        let baseline = (0..<8).map { prosePage(sentences: 3, length: 8, at: daysAgo(20 + $0)) }
        let recent = (0..<4).map { prosePage(sentences: 3, length: 14, at: daysAgo(1 + $0)) }
        let signal = try XCTUnwrap(
            LiteraryContinuityProjector.sentencePaceSignal(prose: baseline + recent, now: now)
        )
        XCTAssertTrue(signal.tags.contains("slow"))
        XCTAssertTrue(signal.line.contains("slowed into long walks"))
    }

    func testPaceSignalStaysQuietWithoutRealDrift() {
        let baseline = (0..<8).map { prosePage(sentences: 3, length: 12, at: daysAgo(20 + $0)) }
        let recent = (0..<4).map { prosePage(sentences: 3, length: 11, at: daysAgo(1 + $0)) }
        XCTAssertNil(LiteraryContinuityProjector.sentencePaceSignal(prose: baseline + recent, now: now))
    }

    func testPaceSignalNeedsBothWindowsPopulated() {
        // Plenty of recent pages but only three baseline pages: no verdict.
        let baseline = (0..<3).map { prosePage(sentences: 3, length: 15, at: daysAgo(20 + $0)) }
        let recent = (0..<5).map { prosePage(sentences: 3, length: 7, at: daysAgo(1 + $0)) }
        XCTAssertNil(LiteraryContinuityProjector.sentencePaceSignal(prose: baseline + recent, now: now))
    }

    // MARK: - Hedging

    private func hedgedPage(words: Int, hedges: Int, at date: Date) -> BookPage {
        var tokens = (0..<max(0, words - hedges * 1)).map { "plain\($0)" }
        tokens.append(contentsOf: Array(repeating: "maybe", count: hedges))
        return page(tokens.joined(separator: " ") + ".", at: date)
    }

    func testHedgeSignalNoticesHoveringPencil() throws {
        let baseline = (0..<10).map { hedgedPage(words: 45, hedges: $0 == 0 ? 1 : 0, at: daysAgo(15 + $0)) }
        let recent = (0..<3).map { hedgedPage(words: 45, hedges: 2, at: daysAgo(1 + $0)) }
        let signal = try XCTUnwrap(
            LiteraryContinuityProjector.hedgeInkSignal(prose: baseline + recent, now: now)
        )
        XCTAssertEqual(signal.kind, .manner)
        XCTAssertTrue(signal.tags.contains("hovering"))
        XCTAssertTrue(signal.line.contains("pencil is hovering"))
    }

    func testHedgeSignalNoticesWritingInInk() throws {
        let baseline = (0..<10).map { hedgedPage(words: 45, hedges: 1, at: daysAgo(15 + $0)) }
        let recent = (0..<3).map { hedgedPage(words: 45, hedges: 0, at: daysAgo(1 + $0)) }
        let signal = try XCTUnwrap(
            LiteraryContinuityProjector.hedgeInkSignal(prose: baseline + recent, now: now)
        )
        XCTAssertTrue(signal.tags.contains("ink"))
        XCTAssertTrue(signal.line.contains("writing in ink"))
    }

    func testHedgeSignalNeedsVolume() {
        // Rich hedging but tiny corpus: density means nothing yet.
        let baseline = [hedgedPage(words: 45, hedges: 1, at: daysAgo(15))]
        let recent = [hedgedPage(words: 45, hedges: 4, at: daysAgo(1))]
        XCTAssertNil(LiteraryContinuityProjector.hedgeInkSignal(prose: baseline + recent, now: now))
    }

    // MARK: - Hour-bound subjects

    func testHourboundSubjectFoundWhenHonest() throws {
        // Harbor: three pages, two days, always after dark, while most prose
        // lives in the morning.
        let harborPages = [
            page("The harbor was black glass and patient tonight.", at: daysAgo(3, hour: 22)),
            page("Walked past the harbor after the late train again.", at: daysAgo(5, hour: 23)),
            page("The harbor swallowed the ferry lights whole.", at: daysAgo(5, hour: 22))
        ]
        let morning = (0..<5).map { prosePage(sentences: 2, length: 8, at: daysAgo(2 + $0, hour: 9), seasoning: "plain") }
        let signals = LiteraryContinuityProjector.hourboundSubjectSignals(
            prose: harborPages + morning, now: now, calendar: .current
        )
        let harbor = try XCTUnwrap(signals.first { $0.subjectName == "harbor" })
        XCTAssertEqual(harbor.kind, .manner)
        XCTAssertTrue(harbor.line.contains("after dark"))
        XCTAssertTrue(harbor.line.contains("three times"))
        XCTAssertEqual(harbor.evidencePageIDs.count, 3)
    }

    func testHourboundStaysQuietWhenAllWritingSharesTheHour() {
        // A reader who only writes at night must not be told "only at night."
        let harborPages = [
            page("The harbor was black glass and patient tonight.", at: daysAgo(3, hour: 22)),
            page("Walked past the harbor after the late train again.", at: daysAgo(5, hour: 23)),
            page("The harbor swallowed the ferry lights whole.", at: daysAgo(7, hour: 22))
        ]
        let alsoNight = (0..<5).map { prosePage(sentences: 2, length: 8, at: daysAgo(2 + $0, hour: 23), seasoning: "plain") }
        XCTAssertTrue(
            LiteraryContinuityProjector.hourboundSubjectSignals(
                prose: harborPages + alsoNight, now: now, calendar: .current
            ).isEmpty
        )
    }

    // MARK: - Prose filter and digest integration

    func testMannerReadsOnlyTheReadersOwnProse() {
        let fuel = page("skipped lunch and maybe dinner too, probably fine", at: daysAgo(1), type: .fuel)
        let generated = BookPage(
            type: .bookOfYou, createdAt: daysAgo(1), promptText: "Braid",
            userInput: "A generated braid with plenty of words to pass the filter easily."
        )
        let prose = LiteraryContinuityProjector.mannerProse(in: [fuel, generated])
        XCTAssertTrue(prose.isEmpty, "Private logs and generated pages are not the reader's hand.")
    }

    func testDigestCarriesMannerSignals() {
        let baseline = (0..<8).map { prosePage(sentences: 3, length: 15, at: daysAgo(20 + $0)) }
        let recent = (0..<4).map { prosePage(sentences: 3, length: 7, at: daysAgo(1 + $0)) }
        let day = BookDay(id: "manner-day", date: daysAgo(10), pages: baseline + recent)
        let digest = LiteraryContinuityProjector.digest(
            days: [day], events: [], entityMemories: [], now: now
        )
        XCTAssertTrue(digest.signals.contains { $0.kind == .manner })
    }

    // MARK: - The Book's Patina

    func testPatinaLearnsOpenEndedWordNeighborhoodsAndReaderInventedTags() throws {
        let pages = (0..<8).map { index in
            page(
                "The violet sprocket turned beside the copper observatory while the paper comet refused its appointment!",
                at: daysAgo(60 + index * 4),
                id: "patina-\(index)"
            )
        }
        var learning = ReaderLearningModel()
        for index in 0..<2 {
            learning.record(ReaderLearningEvent(
                dayID: "liked-\(index)",
                occurredAt: daysAgo(70 + index),
                action: .loved,
                surfaceID: "surface-\(index)",
                sourceID: "invented-source",
                type: .diary,
                varietyKey: "invented",
                hour: 20,
                tags: ["clockwork-comedy"]
            ))
        }
        let patina = BookVoicePatina.derive(
            days: [BookDay(id: "patina", date: now, pages: pages)],
            readerLearning: learning,
            now: now
        )
        let grain = try XCTUnwrap(patina.enduring)

        XCTAssertEqual(patina.depth, .gathering)
        XCTAssertTrue(grain.attentionWords.contains("violet"))
        XCTAssertTrue(grain.attentionWords.contains("sprocket"))
        XCTAssertTrue(
            grain.wordNeighborhoods.contains("sprocket + violet"),
            "Open-ended neighborhoods were: \(grain.wordNeighborhoods)"
        )
        XCTAssertTrue(grain.readerFavoredTags.contains("clockwork comedy"))
        XCTAssertTrue(patina.promptSection.contains("open-ended evidence, not preset personality categories"))
        XCTAssertTrue(patina.promptSection.contains("Share a grain, not a fingerprint"))
    }

    func testPatinaKeepsAnyRecentVocabularyShiftSeasonalUntilItEarnsTheBinding() throws {
        let enduring = (0..<8).map { index in
            page(
                "The copper observatory kept a violet sprocket beside the paper comet every afternoon.",
                at: daysAgo(70 + index * 7),
                id: "old-\(index)"
            )
        }
        let recent = (0..<4).map { index in
            page(
                "The velvet orchestra left a silver kettle beside the crooked metronome after rehearsal.",
                at: daysAgo(1 + index * 3),
                id: "recent-\(index)"
            )
        }
        let patina = BookVoicePatina.derive(
            days: [BookDay(id: "seasons", date: now, pages: enduring + recent)],
            now: now
        )
        let enduringGrain = try XCTUnwrap(patina.enduring)
        let season = try XCTUnwrap(patina.season)

        XCTAssertTrue(enduringGrain.attentionWords.contains("sprocket"))
        XCTAssertFalse(enduringGrain.attentionWords.contains("orchestra"))
        XCTAssertTrue(season.attentionWords.contains("orchestra"))
        XCTAssertTrue(season.wordNeighborhoods.contains { $0.contains("orchestra") })
        XCTAssertTrue(patina.promptSection.contains("temporary weather, not identity"))
        XCTAssertTrue(patina.promptSection.contains("Never promote a temporary emotional season"))
    }

    func testPatinaExcludesGeneratedProsePrivateLogsAndChatTranscripts() throws {
        let safe = (0..<4).map { index in
            page(
                "The garden gate clicked while the rosemary leaned over the path.",
                at: daysAgo(60 + index),
                id: "safe-\(index)"
            )
        }
        let generated = BookPage(
            id: "generated",
            type: .bookOfYou,
            createdAt: daysAgo(70),
            promptText: "Braid",
            userInput: "Obsidianpassword obsidianpassword obsidianpassword obsidianpassword obsidianpassword."
        )
        let privateLog = page(
            "Obsidianpassword obsidianpassword obsidianpassword obsidianpassword obsidianpassword.",
            at: daysAgo(65),
            id: "private",
            type: .fuel
        )
        let chat = page(
            "Obsidianpassword obsidianpassword obsidianpassword obsidianpassword obsidianpassword.",
            at: daysAgo(64),
            id: "chat",
            type: .askTheBook
        )
        let patina = BookVoicePatina.derive(
            days: [BookDay(id: "private", date: now, pages: safe + [generated, privateLog, chat])],
            now: now
        )
        let grain = try XCTUnwrap(patina.enduring)

        XCTAssertFalse(grain.attentionWords.contains("obsidianpassword"))
        XCTAssertFalse(patina.promptSection.contains("obsidianpassword"))
        XCTAssertEqual(patina.evidencePageIDs.count, 4)
    }

    func testPatinaWaitsForEnoughReaderAuthoredPages() {
        let pages = (0..<3).map { index in
            page(
                "The river crossed the trail beside one patient stone.",
                at: daysAgo(index + 1),
                id: "young-\(index)"
            )
        }
        let patina = BookVoicePatina.derive(
            days: [BookDay(id: "young", date: now, pages: pages)],
            now: now
        )

        XCTAssertEqual(patina, .unwritten)
        XCTAssertEqual(patina.promptSection, "")
    }
}
