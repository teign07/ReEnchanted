import XCTest
@testable import InsideCoverCore

final class BindingStoryPromptTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var monthStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9))!
    }

    private func date(day: Int, hour: Int = 22) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func braid(day: Int, title: String, scene: String, kept: String) -> BookPage {
        BraidPageDetails.annotated(
            BookPage(
                id: "braid-\(day)-\(title)",
                type: .bookOfYou,
                createdAt: date(day: day),
                promptText: "Book of You",
                userInput: """
                \(title)

                \(scene)

                The Book kept the page: \(kept).
                """,
                tags: ["braid"]
            ),
            context: .empty
        )
    }

    private func issue(pages: [BookPage]) -> WeeklyIssue {
        WeeklyIssue(
            number: 3,
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 8, hour: 0),
            dateRange: "Jul 1–7",
            keptCount: pages.count,
            highlights: [],
            pages: pages
        )
    }

    private func edition(pages: [BookPage]) -> MonthlyEdition {
        let days = Dictionary(grouping: pages) { calendar.startOfDay(for: $0.createdAt) }
            .map { day, pages in
                BookDay(id: BookDay.id(for: day, calendar: calendar), date: day, pages: pages)
            }
        return MonthlyEditionBuilder.edition(
            from: days,
            readerName: "Reader",
            startDate: monthStart,
            endDate: date(day: 31, hour: 23),
            generatedAt: date(day: 31, hour: 23),
            calendar: calendar
        )
    }

    func testMonthlyStoryAuthoritySurvivesExcerptingAndVolumeBinding() throws {
        let receipt = AuthoredContentReceipt(contentID: "scene", occurrenceID: "choice", channel: .storyScene,
            scope: .init(scopeID: "october", runID: "2026"), state: .nodeCompleted,
            recordedAt: date(day: 3), choiceID: "hold-door", storyText: "Serenity held the west door for Wicker.")
        let source = braid(day: 3, title: "Long Day", scene: String(repeating: "An ordinary afternoon. ", count: 100), kept: "the cup")
        let bound = MonthlyIssueBraidMatter.binding([receipt], into: source)
        let restored = try JSONDecoder().decode(BookPage.self, from: JSONEncoder().encode(bound))
        XCTAssertEqual(MonthlyIssuePublicationMatter.receipts(in: restored.tags), [receipt])
        XCTAssertEqual(MonthlyIssueBraidMatter.binding([receipt], into: restored), restored)
        XCTAssertEqual(restored.readerContributions, source.readerContributions)
        let weekly = try XCTUnwrap(BindingStoryPromptBuilder.weekly(for: issue(pages: [restored])))
        XCTAssertTrue(weekly.prompt.contains("Serenity held the west door for Wicker."))
        XCTAssertTrue(weekly.prompt.contains("recorded choice: hold-door"))
        XCTAssertTrue(weekly.prompt.contains("Follow what changed this week"))
        let month = edition(pages: [restored])
        let monthly = try XCTUnwrap(BindingStoryPromptBuilder.monthly(for: month))
        XCTAssertTrue(monthly.prompt.contains("Serenity held the west door for Wicker."))
        XCTAssertTrue(monthly.prompt.contains("Recognize the encountered route"))
        let annual = AnnualEdition(title: "Year", subtitle: "", year: 2026, readerName: "Reader",
            generatedAt: month.endDate, startDate: month.startDate, endDate: month.endDate,
            dayCount: month.dayCount, pageCount: month.pageCount, foreword: "", chapters: [month],
            constellations: [], wagers: [], closing: "", continuity: month.continuity, memorySpine: nil)
        let volume = try XCTUnwrap(BindingStoryPromptBuilder.annual(for: annual))
        XCTAssertTrue(volume.prompt.contains("Serenity held the west door for Wicker."))
        XCTAssertTrue(volume.prompt.contains("Use a callback only when another supplied month supports"))
        var seasonal = try JSONDecoder().decode(AnnualEdition.self, from: JSONEncoder().encode(annual))
        seasonal.publicationKind = .seasonal
        let seasonalPrompt = try XCTUnwrap(BindingStoryPromptBuilder.annual(for: seasonal))
        XCTAssertTrue(seasonalPrompt.prompt.contains("one seasonal binding"))
        XCTAssertTrue(seasonalPrompt.prompt.contains("Serenity held the west door for Wicker."))
    }

    func testKeptStoryCanSupplyPublicationContextWithoutANightlyBraid() throws {
        let receipt = AuthoredContentReceipt(contentID: "scene", occurrenceID: "choice", channel: .storyScene,
            state: .nodeCompleted, recordedAt: date(day: 3), choiceID: "wait",
            storyText: "Wicker waited beside the closed door.")
        let source = BookPage(id: "story", type: .narrativeOS, createdAt: date(day: 3),
            promptText: "The closed door", userInput: "The scene's full prose.", origin: .generated)
        let kept = MonthlyIssuePublicationMatter.retaining([receipt], in: source)
        XCTAssertEqual(kept.userInput, source.userInput)
        XCTAssertEqual(kept.readerContributions, source.readerContributions)
        XCTAssertEqual(MonthlyIssuePublicationMatter.retaining([receipt], in: kept), kept)
        XCTAssertEqual(MonthlyIssuePublicationMatter.tags(for: [receipt]),
            MonthlyIssuePublicationMatter.tags(for: [receipt]), "Frozen receipt tags must have stable bytes")
        let weekly = try XCTUnwrap(BindingStoryPromptBuilder.weekly(for: issue(pages: [kept])))
        XCTAssertTrue(weekly.prompt.contains("Wicker waited beside the closed door."))
        let month = edition(pages: [kept])
        let monthly = try XCTUnwrap(BindingStoryPromptBuilder.monthly(for: month))
        XCTAssertTrue(monthly.prompt.contains("Wicker waited beside the closed door."))
        let braided = MonthlyIssueBraidMatter.binding([receipt], into:
            braid(day: 3, title: "Tonight", scene: "The cup was blue.", kept: "the cup"))
        XCTAssertEqual(MonthlyIssuePublicationMatter.receipts(in: kept.tags + braided.tags), [receipt])
        let combined = try XCTUnwrap(BindingStoryPromptBuilder.weekly(for: issue(pages: [kept, braided])))
        XCTAssertEqual(combined.prompt.components(separatedBy: "recorded choice: wait").count, 2)
    }

    func testObservationPairBindsExactReaderWordsWithoutChangingAuthorship() throws {
        let first = AuthoredReaderAnchor(pageID: "first", contributionIndex: 0, text: "A moth sat on the blue sill.")
        var returned = BookPage(id: "returned", type: .narrativeOS, createdAt: date(day: 3),
            promptText: "Go back once", userInput: "BOOK ACKNOWLEDGEMENT", playerReply: "Only its dust was left.", origin: .generated)
        returned.tags.append(AuthoredObservationPair.tagPrefix + (try JSONEncoder().encode(first)).base64EncodedString())
        let expected = "The first look\n\nA moth sat on the blue sill.\n\nThis time\n\nOnly its dust was left."
        XCTAssertEqual(returned.publicationBodyText, expected)
        XCTAssertEqual(returned.readerAuthoredTextForAnalysis, "Only its dust was left.")
        let bound = edition(pages: [returned])
        let restored = try JSONDecoder().decode(MonthlyEdition.self, from: JSONEncoder().encode(bound))
        let item = try XCTUnwrap(restored.sections.flatMap(\.items).first(where: { $0.id == returned.id }))
        XCTAssertEqual(item.body, expected)
        XCTAssertEqual(item.observationPair?.first, first)
        XCTAssertEqual(item.observationPair?.second, "Only its dust was left.")
        var legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        legacyJSON.removeValue(forKey: "observationPair")
        let legacyItem = try JSONDecoder().decode(MonthlyEditionItem.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        XCTAssertNil(legacyItem.observationPair)
        XCTAssertEqual(legacyItem.body, expected)
        XCTAssertFalse(AuthoredObservationPair.needsAlignmentLeaf(afterPageIndex: 5, firstLeafCount: 1))
        XCTAssertTrue(AuthoredObservationPair.needsAlignmentLeaf(afterPageIndex: 6, firstLeafCount: 1))
        XCTAssertTrue(AuthoredObservationPair.needsAlignmentLeaf(afterPageIndex: 5, firstLeafCount: 2))
        var bookOnly = BookPage(id: "empty", type: .narrativeOS, promptText: "Return", userInput: "Invented second look", origin: .generated)
        bookOnly.tags = returned.tags
        XCTAssertNil(AuthoredObservationPair.from(bookOnly))
        returned.privacy = .localSensitive
        XCTAssertNil(AuthoredObservationPair.from(returned))
    }

    func testExactBraidEchoRemovalPreservesFullerScenesAndReaderResponses() {
        let receipt = AuthoredContentReceipt(contentID: "scene", occurrenceID: "choice", channel: .storyScene,
            state: .nodeCompleted, recordedAt: date(day: 3), storyText: "Wicker closed the door.")
        let exact = MonthlyIssuePublicationMatter.retaining([receipt], in:
            BookPage(id: "exact", type: .narrativeOS, createdAt: date(day: 3), promptText: "Door", userInput: receipt.storyText!, origin: .generated))
        let braided = MonthlyIssueBraidMatter.binding([receipt], into: braid(day: 3, title: "Tonight", scene: "A blue cup.", kept: "the cup"))
        var fuller = exact
        fuller.id = "fuller"
        fuller.userInput += " Serenity stayed in the hall."
        let replied = MonthlyIssuePublicationMatter.retaining([receipt], in:
            BookPage(id: "reply", type: .narrativeOS, promptText: "Door", userInput: receipt.storyText!, playerReply: "I would have stayed.", origin: .generated))
        XCTAssertEqual(MonthlyIssuePublicationMatter.removingExactBraidEchoes(from: [exact, fuller, replied, braided]).map(\.id), [fuller.id, replied.id, braided.id])
        XCTAssertEqual(MonthlyIssuePublicationMatter.removingExactBraidEchoes(from: [exact]), [exact])
        var editedBraid = braided
        editedBraid.userInput = "The scene passage is no longer here."
        XCTAssertEqual(MonthlyIssuePublicationMatter.removingExactBraidEchoes(from: [exact, editedBraid]), [exact, editedBraid])
        let bound = edition(pages: [exact, braided])
        XCTAssertFalse(bound.sections.first(where: { $0.id == "letters" })?.items.contains(where: { $0.id == exact.id }) ?? false)
    }

    func testPublicationSelectionKeepsEarlierRunsAndBothEndsWithinBudget() {
        let receipts = (0..<30).map { index in
            AuthoredContentReceipt(contentID: "scene-\(index)", occurrenceID: "choice", channel: .storyScene,
                scope: .init(scopeID: index < 3 ? "october" : "november", runID: "2026"),
                state: .nodeCompleted, recordedAt: Date(timeIntervalSince1970: Double(index)),
                storyText: "Passage \(index)")
        }
        let selected = MonthlyIssuePublicationMatter.selection(receipts + receipts, limit: 4)
        XCTAssertEqual(selected.map(\.contentID), ["scene-0", "scene-2", "scene-3", "scene-29"])
        XCTAssertTrue(MonthlyIssuePublicationMatter.selection(receipts, limit: 0).isEmpty)
        XCTAssertEqual(MonthlyIssuePublicationMatter.selection(receipts, limit: 12).count, 12)
    }

    func testPublicationContextDeduplicatesAndDoesNotPromoteReportsOrOffers() {
        let report = AuthoredContentReceipt(contentID: "report", occurrenceID: "news", channel: .storyScene,
            state: .reported, recordedAt: date(day: 4), storyText: "The Count left the school.")
        let offer = AuthoredContentReceipt(contentID: "offer", occurrenceID: "invitation", channel: .storyScene,
            state: .accepted, recordedAt: date(day: 5), storyText: "UNPLAYED SCENE")
        let tags = MonthlyIssuePublicationMatter.tags(for: [report, offer])
        let prompt = MonthlyIssuePublicationMatter.promptSection(tags: tags + tags + [MonthlyIssuePublicationMatter.tagPrefix + "corrupt"], frame: "week")
        XCTAssertTrue(prompt.contains("Learned history; no attendance or choice"))
        XCTAssertEqual(prompt.components(separatedBy: "The Count left the school.").count, 2)
        XCTAssertFalse(prompt.contains("UNPLAYED SCENE"))
        XCTAssertEqual(MonthlyIssuePublicationMatter.promptSection(tags: [], frame: "month"), "")
    }

    func testWeeklyStoryPromptReadsEveryDailyBindingInChronologicalOrder() throws {
        let late = braid(day: 7, title: "The Open Door", scene: "The latch finally lifted.", kept: "an opening can stay quiet")
        let early = braid(day: 1, title: "Rain at the Glass", scene: "Rain found the kitchen window.", kept: "the first knock mattered")
        let middle = braid(day: 4, title: "A Lamp Between", scene: "The lamp held against the dim room.", kept: "small light was still light")
        let unrelated = BookPage(
            type: .fuel,
            createdAt: date(day: 2),
            promptText: "Fuel",
            userInput: "SENTINEL RAW FUEL MUST NOT REACH GEMMA"
        )

        let spec = try XCTUnwrap(BindingStoryPromptBuilder.weekly(for: issue(pages: [late, unrelated, middle, early]), calendar: calendar))
        let prompt = spec.prompt

        let earlyIndex = try XCTUnwrap(prompt.range(of: "Rain at the Glass")?.lowerBound)
        let middleIndex = try XCTUnwrap(prompt.range(of: "A Lamp Between")?.lowerBound)
        let lateIndex = try XCTUnwrap(prompt.range(of: "The Open Door")?.lowerBound)
        XCTAssertLessThan(earlyIndex, middleIndex)
        XCTAssertLessThan(middleIndex, lateIndex)
        XCTAssertTrue(prompt.contains("2026-07-01"))
        XCTAssertTrue(prompt.contains("2026-07-07"))
        XCTAssertFalse(prompt.contains("SENTINEL RAW FUEL"))
        XCTAssertTrue(prompt.contains("binding of bindings"))
        XCTAssertTrue(prompt.contains("choose the truest architecture"))
        XCTAssertTrue(prompt.contains("do not force the week into one continuous plot"))
        XCTAssertTrue(prompt.contains("Hardship without explicit Rut influence is not a Rut battle"))
        XCTAssertTrue(prompt.contains("do not produce a day-by-day recap"))
        XCTAssertTrue(prompt.contains("Do not invent events"))
        XCTAssertEqual(spec.sourceID, "weekly-binding-story")
    }

    func testMonthlyStoryPromptRepresentsAllThirtyOneBindingsWithinLocalBudget() throws {
        let pages = (1...31).map { day in
            braid(
                day: day,
                title: String(format: "Night %02d", day),
                scene: String(repeating: "A distinct long scene kept returning to the window and changing its light. ", count: 12),
                kept: "night \(day) left its own unmistakable stitch in the month"
            )
        }
        let spec = try XCTUnwrap(BindingStoryPromptBuilder.monthly(for: edition(pages: pages), calendar: calendar))

        for day in 1...31 {
            XCTAssertTrue(spec.prompt.contains(String(format: "Night %02d", day)), "missing day \(day)")
        }
        let first = try XCTUnwrap(spec.prompt.range(of: "Night 01")?.lowerBound)
        let last = try XCTUnwrap(spec.prompt.range(of: "Night 31")?.lowerBound)
        XCTAssertLessThan(first, last)
        XCTAssertLessThan(spec.prompt.count, 12_000, "month prompt must leave room in Gemma's 4,096-token context window")
        XCTAssertEqual(spec.sourceID, "monthly-binding-story")
        XCTAssertGreaterThan(spec.maxTokens, BindingStoryPromptBuilder.weekly(for: issue(pages: [pages[0]]), calendar: calendar)!.maxTokens)
    }

    func testBindingLeavesPreserveStoryFormRutInfluenceAndRegisterAsSeparateAxes() throws {
        var page = braid(
            day: 3,
            title: "Three Blue Cups",
            scene: "The cups did not become a single plot.",
            kept: "the fragments belonged beside one another"
        )
        page.tags.append(contentsOf: [
            "\(BookOfYouResidue.storyFormPrefix)\(BraidPromptBuilder.StoryForm.mosaic.rawValue)",
            "\(BookOfYouResidue.rutInfluencePrefix)\(BraidPromptBuilder.RutInfluence.mixed.rawValue)",
            "\(BookOfYouResidue.narrativeRegisterPrefix)\(BraidPromptBuilder.NarrativeRegister.fierce.rawValue)"
        ])

        let spec = try XCTUnwrap(BindingStoryPromptBuilder.weekly(for: issue(pages: [page]), calendar: calendar))

        XCTAssertTrue(spec.prompt.contains("Story form: mosaic"))
        XCTAssertTrue(spec.prompt.contains("Rut influence: mixed"))
        XCTAssertTrue(spec.prompt.contains("Register: fierce"))
    }

    func testAnnualStoryPromptReadsMonthlyBindingsAndTheirAxisMixtures() throws {
        var januaryBraid = braid(
            day: 3,
            title: "The Blue Cup",
            scene: "Three fragments stayed separate.",
            kept: "the month did not need one plot"
        )
        januaryBraid.tags.append(contentsOf: [
            "\(BookOfYouResidue.storyFormPrefix)\(BraidPromptBuilder.StoryForm.mosaic.rawValue)",
            "\(BookOfYouResidue.rutInfluencePrefix)\(BraidPromptBuilder.RutInfluence.mixed.rawValue)",
            "\(BookOfYouResidue.narrativeRegisterPrefix)\(BraidPromptBuilder.NarrativeRegister.fierce.rawValue)"
        ])
        var january = edition(pages: [januaryBraid])
        january.monthName = "January 2026"
        january.bindingStory = "January kept three blue fragments apart until their disagreement became the shape."

        var february = edition(pages: [
            braid(
                day: 7,
                title: "The Returned Key",
                scene: "The old key came back without explaining itself.",
                kept: "return was not the same as repair"
            )
        ])
        february.monthName = "February 2026"
        february.startDate = january.startDate.addingTimeInterval(31 * 86_400)
        february.bindingStory = "February returned the key, but left the locked room unresolved."

        let annual = AnnualEdition(
            title: "The Annual",
            subtitle: "2026",
            year: 2026,
            readerName: "Reader",
            generatedAt: february.endDate,
            startDate: january.startDate,
            endDate: february.endDate,
            dayCount: january.dayCount + february.dayCount,
            pageCount: january.pageCount + february.pageCount,
            foreword: "",
            chapters: [february, january],
            constellations: [],
            wagers: [],
            closing: "",
            continuity: january.continuity,
            memorySpine: nil
        )

        let spec = try XCTUnwrap(BindingStoryPromptBuilder.annual(for: annual, calendar: calendar))
        let januaryIndex = try XCTUnwrap(spec.prompt.range(of: "January kept three blue fragments")?.lowerBound)
        let februaryIndex = try XCTUnwrap(spec.prompt.range(of: "February returned the key")?.lowerBound)

        XCTAssertLessThan(januaryIndex, februaryIndex)
        XCTAssertTrue(spec.prompt.contains("Story-form mix: mosaic 1"))
        XCTAssertTrue(spec.prompt.contains("Rut-influence mix: mixed 1"))
        XCTAssertTrue(spec.prompt.contains("Register mix: fierce 1"))
        XCTAssertTrue(spec.prompt.contains("do not force the year into one continuous plot"))
        XCTAssertTrue(spec.prompt.contains("hardship without explicit Rut influence is not a Rut battle"))
        XCTAssertEqual(spec.sourceID, "annual-binding-story")
    }

    func testStoryGenerationIsSkippedWithoutDailyBookOfYouBindings() {
        let souvenir = BookPage(
            type: .souvenir,
            createdAt: date(day: 1),
            promptText: "Souvenir",
            userInput: "A real kept page, but not a nightly binding."
        )

        XCTAssertNil(BindingStoryPromptBuilder.weekly(for: issue(pages: [souvenir]), calendar: calendar))
        XCTAssertNil(BindingStoryPromptBuilder.monthly(for: edition(pages: [souvenir]), calendar: calendar))
    }

    func testBindingStoriesSurviveCodableRoundTrips() throws {
        var weekly = issue(pages: [braid(day: 1, title: "First Thread", scene: "A thread appeared.", kept: "it held")])
        weekly.bindingStory = "The week became one piece of cloth."
        let decodedWeekly = try JSONDecoder().decode(WeeklyIssue.self, from: JSONEncoder().encode(weekly))
        XCTAssertEqual(decodedWeekly.bindingStory, weekly.bindingStory)

        var monthly = edition(pages: [braid(day: 1, title: "First Thread", scene: "A thread appeared.", kept: "it held")])
        monthly.bindingStory = "The month learned what the thread connected."
        let decodedMonthly = try JSONDecoder().decode(MonthlyEdition.self, from: JSONEncoder().encode(monthly))
        XCTAssertEqual(decodedMonthly.bindingStory, monthly.bindingStory)
    }

    func testPublicationBindingCheckpointRoundTripKeepsCompletedLeaves() throws {
        let savedAt = date(day: 4, hour: 12)
        var checkpoint = PublicationBindingCheckpoint(
            sourceFingerprint: "same-source",
            payload: "unwritten",
            updatedAt: date(day: 3, hour: 12)
        )
        checkpoint.record(
            payload: "the foreword is dry",
            completedStage: "foreword",
            at: savedAt
        )
        checkpoint.markCompleted("binding-story", at: savedAt)

        let encoded = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(
            PublicationBindingCheckpoint<String>.self,
            from: encoded
        )

        XCTAssertEqual(decoded.payload, "the foreword is dry")
        XCTAssertEqual(decoded.updatedAt, savedAt)
        XCTAssertTrue(decoded.hasCompleted("foreword"))
        XCTAssertTrue(decoded.hasCompleted("binding-story"))
        XCTAssertTrue(decoded.matches(sourceFingerprint: "same-source"))
        XCTAssertFalse(decoded.matches(sourceFingerprint: "changed-source"))
    }

    func testPublicationBindingCheckpointRejectsAnOlderSchema() {
        var checkpoint = PublicationBindingCheckpoint(
            sourceFingerprint: "same-source",
            payload: "saved leaf"
        )
        checkpoint.schemaVersion = 0

        XCTAssertFalse(checkpoint.matches(sourceFingerprint: "same-source"))
    }
}
