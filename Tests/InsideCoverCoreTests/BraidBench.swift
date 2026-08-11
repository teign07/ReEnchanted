import Foundation

@testable import InsideCoverCore

/// A fixed corpus of nights, and a report on how the Book writes them.
///
/// The point of this file is falsifiability. "The house writer beats the model"
/// is not a claim anyone can check by reading prose one night at a time, so the
/// bench holds a spread of nights still and measures the same things about each
/// of them every run. The golden file turns a prose regression into a reviewable
/// diff instead of a number that moved.
enum BraidBench {
    struct Night {
        var name: String
        var note: String
        var day: BookDay
        var context: BraidPromptBuilder.Context
        /// A day with nothing kept cannot reach a word band and should not
        /// drag the standing number around for the rest of the corpus.
        var expectsBand: Bool = true
    }

    struct Report {
        var name: String
        var note: String
        var scale: BraidPromptBuilder.BraidScale
        var title: String
        var text: String
        var tags: [String]
        var wordCount: Int
        var band: ClosedRange<Int>
        var paragraphShape: [Int]
        var sentenceLengths: [Int]
        var provenanceCounts: [String: Int]
        var issues: [String]
        var score: BraidTastingRoom.Score
        var candidateCount: Int
        var expectsBand: Bool
        var prosody: BraidComposition.Prosody

        var isInBand: Bool { !expectsBand || band.contains(wordCount) }

        /// How far under the band the page falls. The honest number: settling
        /// beats stop at two on purpose, so this is the gap that material:
        /// transformation, prosody, archive callbacks: still has to close.
        var shortfall: Int { expectsBand ? max(0, band.lowerBound - wordCount) : 0 }
    }

    // MARK: - Running

    static func reports() -> [Report] {
        corpus().map { report(for: $0) }
    }

    /// The same corpus read as consecutive nights rather than twenty-three
    /// isolated specimens. The golden remains the fixed baseline; this lane
    /// proves the rolling archive memory changes what the tasting room chooses.
    static func sequentialReports() -> [Report] {
        var archive: [BookDay] = []
        var result: [Report] = []
        for original in corpus() {
            var night = original
            night.context.braidStyleMemory = BraidPromptBuilder.recentBraidStyleMemory(
                before: night.day,
                in: archive
            )
            night.context.recentMoveAges = BraidPromptBuilder.recentMoveAges(
                before: night.day,
                in: archive
            )
            // Without the digest the fiction serial never fires here: the beat
            // is chosen from `memoryDigest.braids`, so consecutive nights were
            // being measured with continuity switched off - which is precisely
            // the writing this harness exists to watch.
            night.context.memoryDigest = BindingMemorySpine.digest(
                days: archive,
                now: night.day.date
            )
            let current = report(for: night)
            result.append(current)
            // The app stamps a kept braid with its residue before filing it,
            // and the fiction serial reads the next night's beat back out of
            // those tags. Without the stamp the archive here is amnesiac about
            // its own fiction, so no thread was ever picked up again.
            var kept = BookPage(
                id: "bench-braid-\(current.name)",
                type: .bookOfYou,
                createdAt: night.day.date,
                promptText: "Book of You: \(current.title)",
                userInput: current.text,
                tags: current.tags,
                origin: .generated
            )
            let prepared = DeterministicBraidwright.preparedContext(
                for: night.day, context: night.context
            )
            kept.tags = Array(
                BookOfYouResidue
                    .extract(from: kept, context: prepared)
                    .stamping(into: Set(kept.tags))
            ).sorted()
            archive.append(
                BookDay(id: night.day.id, date: night.day.date, pages: [kept])
            )
        }
        return result
    }

    static func recurrenceStanding(_ reports: [Report]) -> (nights: Int, pressure: Int) {
        var nights = 0
        var pressure = 0
        for (index, report) in reports.enumerated() {
            var memory = BraidPromptBuilder.BraidStyleMemory.empty
            let recent = reports[..<index].reversed().prefix(14)
            for (age, prior) in recent.enumerated() {
                memory.remember(prose: prior.text, age: age)
            }
            let current = memory.recurrencePenalty(in: report.text)
            if current > 0 { nights += 1 }
            pressure += current
        }
        return (nights, pressure)
    }

    static func report(for night: Night) -> Report {
        let prepared = DeterministicBraidwright.preparedContext(
            for: night.day, context: night.context
        )
        let composition = DeterministicBraidwright.composition(
            for: night.day, context: night.context
        )
        let scale = prepared.storyScore?.taleReading.scale
            ?? prepared.taleReading?.scale
            ?? .glimpse

        var provenance: [String: Int] = [:]
        for sentence in composition.sentences {
            let key: String
            switch sentence.provenance {
            case .receipt: key = "receipt"
            case .quotedReceipt: key = "quoted"
            case .authored: key = "authored"
            case .colophon: key = "colophon"
            }
            provenance[key, default: 0] += 1
        }

        return Report(
            name: night.name,
            note: night.note,
            scale: scale,
            title: composition.title,
            text: composition.text,
            tags: composition.tags,
            wordCount: composition.bodyWordCount,
            band: scale.targetWordBand,
            paragraphShape: composition.paragraphs.map(\.count),
            sentenceLengths: composition.sentenceLengths,
            provenanceCounts: provenance,
            issues: BraidOutputAudit
                .issues(in: composition.text, for: night.day, context: prepared)
                .map(\.rawValue)
                .sorted(),
            score: BraidTastingRoom.score(page: composition.page, context: prepared),
            candidateCount: DeterministicBraidwright
                .compositions(for: night.day, context: night.context).count,
            expectsBand: night.expectsBand,
            prosody: composition.prosody
        )
    }

    // MARK: - Rendering

    static func summaryTable(_ reports: [Report]) -> String {
        var lines: [String] = []
        lines.append(
            "night".padded(30) + "scale".padded(9) + "words".padded(7) + "band".padded(10)
                + "gap".padded(6) + "score".padded(7) + "cands".padded(7) + "rep".padded(5) + "issues"
        )
        lines.append(String(repeating: "-", count: 100))
        for report in reports {
            lines.append(
                report.name.padded(30)
                    + report.scale.rawValue.padded(9)
                    + "\(report.wordCount)".padded(7)
                    + "\(report.band.lowerBound)-\(report.band.upperBound)".padded(10)
                    + (report.shortfall == 0 ? "-" : "-\(report.shortfall)").padded(6)
                    + "\(report.score.total)".padded(7)
                    + "\(report.candidateCount)".padded(7)
                    + "\(report.prosody.repeatedOpenings)".padded(5)
                    + (report.issues.isEmpty ? "clean" : report.issues.joined(separator: ","))
            )
        }
        let inBand = reports.filter(\.isInBand).count
        let clean = reports.filter { $0.issues.isEmpty }.count
        let repeats = reports.map(\.prosody.repeatedOpenings).reduce(0, +)
        let averageScore = reports.isEmpty
            ? 0
            : reports.map(\.score.total).reduce(0, +) / reports.count
        lines.append(String(repeating: "-", count: 100))
        lines.append(
            "\(reports.count) nights · \(inBand) in band · \(clean) audit-clean · "
                + "average taste \(averageScore) · \(repeats) repeated openings"
        )
        return lines.joined(separator: "\n")
    }

    /// The committed artifact. Prose first, because the numbers are only ever a
    /// proxy for whether the page is worth reading.
    static func goldenText(_ reports: [Report]) -> String {
        var blocks: [String] = [
            "# Braid bench",
            "",
            "Regenerate with `BRAID_BENCH_RECORD=1 swift test --filter BraidBenchTests`.",
            "",
            summaryTable(reports),
            ""
        ]
        for report in reports {
            blocks.append(String(repeating: "=", count: 78))
            blocks.append("## \(report.name)")
            blocks.append("\(report.note)")
            blocks.append(
                "scale \(report.scale.rawValue) · words \(report.wordCount) "
                    + "(band \(report.band.lowerBound)-\(report.band.upperBound)) · "
                    + "taste \(report.score.total) · candidates \(report.candidateCount)"
            )
            blocks.append(
                "paragraphs \(report.paragraphShape) · sentences \(report.sentenceLengths)"
            )
            blocks.append(
                "prosody repeated-openings \(report.prosody.repeatedOpenings) · "
                    + "flat-run \(report.prosody.longestFlatRun) · "
                    + "spread \(report.prosody.lengthSpread)"
            )
            blocks.append(
                "provenance "
                    + report.provenanceCounts.sorted { $0.key < $1.key }
                        .map { "\($0.key):\($0.value)" }
                        .joined(separator: " ")
            )
            blocks.append("audit \(report.issues.isEmpty ? "clean" : report.issues.joined(separator: ", "))")
            blocks.append("")
            blocks.append(report.text)
            blocks.append("")
        }
        blocks.append(consecutiveSection())
        return blocks.joined(separator: "\n")
    }

    /// The same corpus read straight through, the way a reader meets it and the
    /// way a bound volume prints it.
    ///
    /// The section above holds twenty-three isolated specimens, which is the
    /// right instrument for "is this a good page" and the wrong one for "does
    /// this read like consecutive pages of one book". The fiction serial only
    /// exists between nights, so on isolated specimens it is invisible: it was
    /// shipped, tested in unit isolation, and never once appeared in the prose
    /// anybody reviews. This section is where a continuity regression has to
    /// show itself.
    static func consecutiveSection() -> String {
        let reports = sequentialReports()
        var blocks: [String] = [
            String(repeating: "=", count: 78),
            "# Consecutive nights",
            "",
            "The corpus read straight through, with the archive carried forward.",
            "Continuity beats can only appear here.",
            ""
        ]
        for report in reports {
            let threads = report.tags
                .filter { $0.hasPrefix("braid-move:tale:") || $0.hasPrefix("residue-fiction-") }
                .sorted()
            blocks.append(String(repeating: "-", count: 78))
            blocks.append(
                "## \(report.name) · \(report.wordCount)w"
                    + (threads.isEmpty ? "" : "\n\(threads.joined(separator: " "))")
            )
            blocks.append("")
            blocks.append(report.text)
            blocks.append("")
        }
        return blocks.joined(separator: "\n")
    }

    // MARK: - The corpus

    static func corpus() -> [Night] {
        [
            oneReceiptGlimpse(),
            plainDiaryDay(),
            multiBeatDay(),
            labyrinthOnlyNight(),
            crossingNight(),
            matchedSubjectsNight(),
            castMemberNight(),
            griefDay(),
            tenderShadowDay(),
            arcNight(),
            relationalLensNight(),
            fullBraidDay(),
            supportingLogsOnlyDay(),
            emptyDay(),
            readerAnswerNight(),
            longRamblingReceipt(),
            terseFragmentsDay(),
            pluralAnchorDay(),
            quotedSpeechDay(),
            unpunctuatedDay(),
            souvenirAnchoredNight(),
            namedReaderWithThemeNight(),
            longKeptSubjectNight()
        ]
    }

    // MARK: - Nights

    private static func oneReceiptGlimpse() -> Night {
        Night(
            name: "one-receipt-glimpse",
            note: "A single kept souvenir. The thinnest page the Book is allowed to make.",
            day: day("2026-08-09", [
                page("bowl", .souvenir, "09:00", "I put the chipped yellow bowl back on the shelf.")
            ]),
            context: .empty
        )
    }

    private static func plainDiaryDay() -> Night {
        Night(
            name: "plain-diary-day",
            note: "Two ordinary lived pages, no fiction, no shadow.",
            day: day("2026-08-10", [
                page("walk", .diary, "08:00", "I walked to the corner shop for bread and it started raining."),
                page("desk", .plainPage, "19:00", "I cleared the whole desk and found the missing library card.")
            ]),
            context: .empty
        )
    }

    private static func multiBeatDay() -> Night {
        Night(
            name: "multi-beat-day",
            note: "Three lived beats. Tests whether later receipts get their own move.",
            day: day("2026-08-11", [
                page("screw", .diary, "08:00", "I tightened the loose screw on the blue kitchen chair."),
                page("soup", .souvenir, "12:00", "I carried tomato soup to Sam and forgot the silver spoon."),
                page("letter", .plainPage, "20:00", "I finally posted the letter to the bank.")
            ]),
            context: .empty
        )
    }

    private static func labyrinthOnlyNight() -> Night {
        Night(
            name: "labyrinth-only",
            note: "Nothing lived was kept. The fiction page has to carry the spine alone.",
            day: day("2026-08-12", [
                labyrinth("door", "19:00", "The brass door refused the Registry and swallowed its latch.", tags: [])
            ]),
            context: .empty
        )
    }

    private static func crossingNight() -> Night {
        Night(
            name: "crossing",
            note: "One lived receipt and one Labyrinth receipt: the licensed impossible relation.",
            day: day("2026-08-13", [
                page("lamp", .diary, "08:00", "I rewired the brass lamp in the hallway."),
                labyrinth("fox", "19:00", "The fox offered a shorter road through the root bridge.",
                          tags: ["choice:refuse-the-shortcut"])
            ]),
            context: .empty
        )
    }

    private static func matchedSubjectsNight() -> Night {
        Night(
            name: "matched-subjects",
            note: "Both worlds hand up the same noun. Each must keep its own modifier.",
            day: day("2026-08-14", [
                page("blue-door", .diary, "08:00", "I painted the blue door before breakfast."),
                labyrinth("brass-door", "09:00",
                          "The brass door refused the Registry and swallowed its latch.", tags: [])
            ]),
            context: .empty
        )
    }

    private static func castMemberNight() -> Night {
        Night(
            name: "cast-member",
            note: "A named member of the Cast. Never furniture, never 'the wicker'.",
            day: day("2026-08-15", [
                page("bread", .diary, "08:00", "I baked bread for the first time since spring."),
                labyrinth("wicker", "19:00",
                          "Wicker refused the fox's shortcut and crossed the root bridge.",
                          tags: ["choice:refuse-the-shortcut"])
            ]),
            context: .empty
        )
    }

    private static func griefDay() -> Night {
        Night(
            name: "grief-day",
            note: "Unpermitted shadow. The quotation stays verbatim and the colophon plain, but the world may attend the day's ordinary object.",
            day: day("2026-08-16", [
                page("shop", .diary, "08:00", "I walked to the corner shop for bread."),
                page("call", .plainPage, "18:00", "My sister called about the funeral arrangements.")
            ]),
            context: .empty
        )
    }

    private static func tenderShadowDay() -> Night {
        Night(
            name: "tender-shadow",
            note: "Hard material the reader has since let take tale form.",
            day: day("2026-08-17", [
                page("hospital", .diary, "10:00", "I sat in the hospital corridor for three hours."),
                page("garden", .souvenir, "17:00", "I repotted the fern that survived the move.")
            ]),
            context: .empty
        )
    }

    private static func arcNight() -> Night {
        var night = Night(
            name: "arc-deepened",
            note: "A supplied arc movement the page has to make legible.",
            day: day("2026-08-18", [
                page("run", .diary, "07:00", "I ran the canal path again and it hurt less than Tuesday.")
            ]),
            context: .empty
        )
        var context = BraidPromptBuilder.Context()
        var score = BraidPromptBuilder.nightlyStoryScore(
            for: night.day, context: context, connections: [], constellations: [],
            now: night.day.date
        )
        score.arc = BraidPromptBuilder.NightlyStoryScore.ArcBeat(
            id: "arc-canal",
            movement: .deepened,
            priorState: "the canal path hurt on Tuesday",
            tonightDelta: "the canal path hurt less than it did on Tuesday",
            evidencePageIDs: ["run"],
            fictionChoicePageIDs: [],
            relationalConnectionIDs: []
        )
        context.storyScore = score
        context.taleReading = score.taleReading
        night.context = context
        return night
    }

    private static func relationalLensNight() -> Night {
        var night = Night(
            name: "relational-lens",
            note: "A supplied condition-and-outcome the page must dramatize, not analyse.",
            day: day("2026-08-19", [
                page("rain-note", .diary, "09:00", "I wrote three pages while the rain came down.")
            ]),
            context: .empty
        )
        var context = BraidPromptBuilder.Context()
        var score = BraidPromptBuilder.nightlyStoryScore(
            for: night.day, context: context, connections: [], constellations: [],
            now: night.day.date
        )
        score.relationalLens = BraidPromptBuilder.NightlyStoryScore.RelationalLens(
            connectionID: "rain-writing",
            observationKey: "rain->longer-writing",
            evidenceTier: .glimmer,
            condition: "when the rain sets in for the afternoon",
            outcomes: ["the writing gets longer"],
            evidencePageIDs: ["rain-note"],
            line: "Rain in the afternoon, and the writing runs longer."
        )
        context.storyScore = score
        context.taleReading = score.taleReading
        night.context = context
        return night
    }

    private static func fullBraidDay() -> Night {
        Night(
            name: "full-braid",
            note: "A heavy day. Five substantial story receipts plus fiction: the widest page.",
            day: day("2026-08-20", [
                page("market", .diary, "08:00",
                     "I bought plums and a bunch of coriander at the market, and the man on the "
                        + "corner stall gave me an extra handful because I was counting coins."),
                page("call", .plainPage, "11:00",
                     "I called the landlord about the dripping tap and he actually answered on the "
                        + "second ring, which has never once happened before today."),
                page("swim", .souvenir, "14:00",
                     "I swam in the lido and stayed in well past the point where the cold stopped "
                        + "being interesting and started being a decision."),
                page("cook", .diary, "18:00",
                     "I cooked the plums down with a cinnamon stick and forgot about them until the "
                        + "kitchen smelled like somebody else's childhood."),
                page("read", .plainPage, "21:00",
                     "I read forty pages standing up in the hallway because I forgot to sit down, "
                        + "and my back has opinions about it now."),
                labyrinth("crow", "22:00",
                          "The crow named its price and Eddies traded the paper crown for a length "
                            + "of red thread without arguing.",
                          tags: ["choice:trade-the-crown"])
            ]),
            context: .empty
        )
    }

    private static func supportingLogsOnlyDay() -> Night {
        Night(
            name: "supporting-logs-only",
            note: "Only weather and body logs were kept. Nothing may be promoted to plot.",
            day: day("2026-08-21", [
                page("weather", .weather, "08:00", "Twenty degrees with a light west wind."),
                page("body", .body, "09:00", "Slept badly, six hours, woke at four.")
            ]),
            context: .empty
        )
    }

    private static func emptyDay() -> Night {
        Night(
            name: "empty-day",
            note: "Nothing kept at all. The blank has to stay honest.",
            day: day("2026-08-22", []),
            context: .empty,
            expectsBand: false
        )
    }

    private static func readerAnswerNight() -> Night {
        var reply = labyrinth(
            "parley", "19:00", "The corridor offered three doors.", tags: [])
        reply.playerReply = "I chose the blue door because it felt honest."
        return Night(
            name: "reader-answer",
            note: "A Labyrinth page the reader answered in their own words.",
            day: day("2026-08-23", [
                page("keys", .diary, "08:00", "I found the spare keys under the seat of the car."),
                reply
            ]),
            context: .empty
        )
    }

    private static func longRamblingReceipt() -> Night {
        Night(
            name: "long-rambling-receipt",
            note: "Adversarial: one very long unbroken sentence from the reader.",
            day: day("2026-08-24", [
                page("ramble", .diary, "20:00",
                     "I meant to go to the studio but I ended up walking the long way round past the "
                        + "old bakery that closed last year and then I sat on the wall outside it for "
                        + "a while thinking about nothing in particular and eventually it got cold "
                        + "enough that I went home and made toast instead of dinner.")
            ]),
            context: .empty
        )
    }

    private static func terseFragmentsDay() -> Night {
        Night(
            name: "terse-fragments",
            note: "Adversarial: receipts with no verbs and no punctuation to speak of.",
            day: day("2026-08-25", [
                page("terse-a", .souvenir, "09:00", "Cold tea. Again."),
                page("terse-b", .plainPage, "18:00", "Two buses. One late.")
            ]),
            context: .empty
        )
    }

    private static func pluralAnchorDay() -> Night {
        Night(
            name: "plural-anchor",
            note: "The anchor noun is plural; the prose must not slip into the singular.",
            day: day("2026-08-26", [
                page("keys", .souvenir, "09:00", "I finally labelled the brass keys on the hall hook.")
            ]),
            context: .empty
        )
    }

    private static func quotedSpeechDay() -> Night {
        Night(
            name: "quoted-speech",
            note: "Adversarial: the reader quoted somebody else inside their own sentence.",
            day: day("2026-08-27", [
                page("quote", .diary, "13:00",
                     "My mother said \"you never call on a Tuesday\" and then laughed about it.")
            ]),
            context: .empty
        )
    }

    private static func unpunctuatedDay() -> Night {
        Night(
            name: "unpunctuated",
            note: "Adversarial: no terminal punctuation and inconsistent capitals.",
            day: day("2026-08-28", [
                page("scrawl", .plainPage, "22:00", "went to the river with dad and we didnt talk much")
            ]),
            context: .empty
        )
    }

    /// The reader stopped and chose one true line. It should own the page:
    /// title, voice and closing line, even though it was not kept first.
    private static func souvenirAnchoredNight() -> Night {
        var night = Night(
            name: "souvenir-anchored",
            note: "A One-Sentence Souvenir kept late. It has to take the spine from the earlier page.",
            day: day("2026-08-29", [
                page("errand", .diary, "09:00", "I dropped the parcel at the post office."),
                page("souvenir", .souvenir, "20:00", "I stood in the doorway and listened to the whole song before coming in.")
            ]),
            context: .empty
        )
        var context = BraidPromptBuilder.Context()
        context.souvenirAnchor = BraidPromptBuilder.SouvenirAnchor(
            pageID: "souvenir",
            pageTitle: "One true thing",
            keptText: "I stood in the doorway and listened to the whole song before coming in.",
            keptAt: night.day.date,
            reason: "the reader chose it",
            score: 90
        )
        night.context = context
        return night
    }

    /// The Book named this reader on night one and has a month of noticing
    /// behind it. Both should reach the page without becoming a report.
    private static func namedReaderWithThemeNight() -> Night {
        var night = Night(
            name: "named-reader-with-theme",
            note: "Reader role, a settled theme, and a standing tale law all in context.",
            day: day("2026-08-30", [
                page("window", .diary, "08:00", "I opened every window in the flat before the heat came."),
                page("letter", .souvenir, "19:00", "I read the old letter twice and put it back in the tin.")
            ]),
            context: .empty
        )
        var context = BraidPromptBuilder.Context()
        context.theme = BookTheme(
            id: "theme-thresholds",
            monthKey: "2026-08",
            name: "Thresholds",
            motifs: ["doorways", "the tin"],
            line: "You keep stopping at the edge of rooms.",
            strength: 8,
            evidencePageIDs: ["window"],
            excerptLines: [],
            discoveredAt: night.day.date,
            stability: .stable,
            observedDayCount: 12,
            settledAt: night.day.date
        )
        context.standingTaleLaws = ["Anything left open has to be closed by the one who opened it."]
        if let role = ReaderRoleRegistry.all.first {
            context.readerRole = ComposedRole(role: role, epithet: nil, hands: nil, mark: nil)
        }
        night.context = context
        return night
    }

    /// A subject the reader has been circling since spring. This is the page
    /// the model cannot write, because it never sees more than tonight.
    private static func longKeptSubjectNight() -> Night {
        var night = Night(
            name: "long-kept-subject",
            note: "A subject four months deep in the archive. The callback should fire.",
            day: day("2026-08-31", [
                page("river", .diary, "18:00", "I walked down to the river and did not go in.")
            ]),
            context: .empty
        )
        var context = BraidPromptBuilder.Context()
        context.subjectHistory = [
            "river": BraidPromptBuilder.SubjectHistory(
                occasions: 6,
                firstSeen: night.day.date.addingTimeInterval(-120 * 86_400),
                lastSeen: night.day.date.addingTimeInterval(-9 * 86_400)
            )
        ]
        night.context = context
        return night
    }

    // MARK: - Builders

    /// Pages are written with an hour only; the day stamps its own date onto
    /// them. A receipt dated to a different day than the `BookDay` holding it
    /// is not eligible material, and the whole corpus silently becomes the
    /// empty-day page, which is exactly what happened the first time.
    private static func day(_ id: String, _ pages: [BookPage]) -> BookDay {
        let stamped = pages.map { page -> BookPage in
            var page = page
            page.createdAt = date("\(id)T\(clockTime(of: page.createdAt))Z")
            return page
        }
        return BookDay(id: id, date: date("\(id)T21:00:00Z"), pages: stamped)
    }

    private static func clockTime(of moment: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: moment)
    }

    private static func page(
        _ id: String, _ type: BookPageType, _ hour: String, _ text: String
    ) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: date("2026-08-01T\(hour):00Z"),
            promptText: "One true thing",
            userInput: text,
            origin: .userAuthored
        )
    }

    private static func labyrinth(
        _ id: String, _ hour: String, _ text: String, tags: [String]
    ) -> BookPage {
        BookPage(
            id: id,
            type: .narrativeOS,
            createdAt: date("2026-08-01T\(hour):00Z"),
            promptText: "The Labyrinth turned a page.",
            userInput: text,
            tags: tags,
            sourceID: "narrative-os",
            origin: .generated
        )
    }

    private static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}

extension String {
    fileprivate func padded(_ width: Int) -> String {
        count >= width ? self + " " : self + String(repeating: " ", count: width - count)
    }
}
