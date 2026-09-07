import XCTest
@testable import InsideCoverCore

/// Phase 1 of `docs/correspondences-plan.md`: the inherited half of the
/// Correspondences shelf, so it is full on a reader's first night instead of
/// empty for the month the Book needs to work anything out for itself.
final class InheritedCorrespondenceTests: XCTestCase {

    private var all: [InheritedCorrespondence] { CorrespondenceLibraryRegistry.all }

    func testTheShelfIsNotEmptyOnANewReadersFirstNight() {
        XCTAssertGreaterThanOrEqual(all.count, 10)
    }

    func testEveryRowIsAttributed() {
        for row in all {
            XCTAssertFalse(
                row.tradition.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(row.id) claims a correspondence with nobody's name on it"
            )
            XCTAssertFalse(row.subject.isEmpty, "\(row.id) has no subject")
            XCTAssertFalse(row.sense.isEmpty, "\(row.id) has no sense")
            XCTAssertFalse(row.lore.isEmpty, "\(row.id) has no lore")
        }
    }

    func testIdentifiersAreUnique() {
        let ids = all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate correspondence id")
    }

    /// The Academy may invent. It may not invent *and* sound like a source.
    /// An Academy row that can be checked belongs in the untested ladder, not
    /// in the furniture — and above all not in both. It printed twice the first
    /// time the Academy was given a correspondence with an observable.
    func testNoRowBelongsToTwoSectionsAtOnce() {
        var seen: [String: String] = [:]
        for section in CorrespondenceShelf.sections() {
            for row in section.rows {
                if let already = seen[row.id] {
                    XCTFail("\(row.id) is printed in both \(already) and \(section.id)")
                }
                seen[row.id] = section.id
            }
        }
    }

    func testAcademyInventionsSaySoInTheirAttribution() {
        let academy = all.filter { $0.source == .academy }
        XCTAssertFalse(academy.isEmpty, "the Academy should have opinions of its own")
        for row in academy {
            XCTAssertTrue(
                row.attributionLine.contains("Academy"),
                "\(row.id) is invented and does not admit it"
            )
        }
    }

    func testEveryRowKnowsItIsInherited() {
        XCTAssertTrue(all.allSatisfy { $0.origin == .inherited })
    }

    // MARK: Lore-only rows are furniture, permanently

    func testLoreOnlyRowsAreNeverTestable() {
        for row in CorrespondenceLibraryRegistry.loreOnly {
            XCTAssertNil(row.observable)
            XCTAssertFalse(
                row.isTestable,
                "\(row.id) has no observable and must never be treated as a claim"
            )
        }
    }

    func testTheShelfIsMostlyFurniture() {
        XCTAssertGreaterThan(
            CorrespondenceLibraryRegistry.loreOnly.count,
            CorrespondenceLibraryRegistry.testable.count,
            "most correspondence lore maps onto nothing measurable, and that is the point"
        )
    }

    func testTestableAndLoreOnlyPartitionTheShelf() {
        let testable = Set(CorrespondenceLibraryRegistry.testable.map(\.id))
        let lore = Set(CorrespondenceLibraryRegistry.loreOnly.map(\.id))
        XCTAssertTrue(testable.isDisjoint(with: lore))
        XCTAssertEqual(testable.union(lore), Set(all.map(\.id)))
    }

    // MARK: The wiring lint

    /// The context that *should* produce a given feature, derived from the
    /// feature id itself rather than from a fixed list — so the corpus may be
    /// keyed to any category Maps can return, not only ones a probe remembered
    /// to enumerate.
    private func contextThatShouldProduce(_ observable: String) -> BookPageContextSnapshot? {
        if observable.hasPrefix("place-kind:") {
            let kind = String(observable.dropFirst("place-kind:".count))
            // "water" is not a category. It is the reading the projector makes
            // *from* a category, so probe it with one that means water.
            let placeKind = kind == "water" ? PlaceKind.waterKinds.sorted().first : kind
            return BookPageContextSnapshot(locationLabel: "Somewhere", placeKind: placeKind)
        }
        if observable.hasPrefix("weather:") {
            // The projector emits `weather:<tag>` for whatever tag it is given,
            // so feeding it the key would prove nothing. Check the key against
            // the closed vocabulary the Book can actually produce first.
            let tag = String(observable.dropFirst("weather:".count))
            guard RadioPageContext.knownWeatherTags.contains(tag) else { return nil }
            return BookPageContextSnapshot(weatherTags: [tag])
        }
        if observable.hasPrefix("hour:") {
            let hours = ["morning": 9, "afternoon": 14, "evening": 19, "night": 2]
            guard let hour = hours[String(observable.dropFirst("hour:".count))],
                  let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
            else { return nil }
            return BookPageContextSnapshot(at: date)
        }
        return nil
    }

    private func emits(_ observable: String) -> Bool {
        guard let context = contextThatShouldProduce(observable) else { return false }
        return WorldConditionsProjector.features(for: context).contains { $0.id == observable }
    }

    /// A row keyed to a feature nothing emits is a correspondence the Book can
    /// never have an opinion about — it would sit in "inherited, untested"
    /// forever while looking like it was waiting for evidence.
    func testEveryTestableRowIsKeyedToAFeatureSomethingActuallyProduces() {
        // Proof the lint has teeth before it is trusted: a key nothing emits,
        // and a well-shaped key for a category the projector is never given.
        XCTAssertFalse(emits("weather:brimstone"), "the lint accepts weather nobody has")
        XCTAssertFalse(emits("nonsense:at-all"), "the lint accepts an unknown feature family")
        XCTAssertFalse(emits("hour:elevenses"), "the lint accepts an hour band that does not exist")
        XCTAssertTrue(emits("weather:rain"), "the lint rejects weather the Book really does report")

        for row in CorrespondenceLibraryRegistry.testable {
            let observable = row.observable ?? ""
            XCTAssertTrue(
                emits(observable),
                "\(row.id) is keyed to \(observable), which no projector emits"
            )
        }
    }

    /// The vocabulary constant is only worth having if it still describes what
    /// the function emits, so drive the function with every trigger word it
    /// knows and compare.
    func testTheWeatherVocabularyMatchesWhatIsActuallyProduced() {
        let everyTrigger = "storm thunder bolt rain drizzle shower snow sleet ice freezing "
            + "fog mist haze wind gust breez cloud overcast clear sun bright frost hot heat warm cold chill"
        let produced = RadioPageContext.weatherTags(
            weather: WeatherSourceSignal(phrase: everyTrigger, source: "test", conditionSymbolName: "")
        )
        XCTAssertEqual(
            produced, RadioPageContext.knownWeatherTags,
            "knownWeatherTags has drifted from the tags weatherTags really emits"
        )
    }

    func testMatchingFindsRowsByObservable() {
        let water = CorrespondenceLibraryRegistry.matching(observable: "place-kind:water")
        XCTAssertFalse(water.isEmpty)
        XCTAssertTrue(water.allSatisfy { $0.observable == "place-kind:water" })
        XCTAssertTrue(CorrespondenceLibraryRegistry.matching(observable: "weather:brimstone").isEmpty)
    }

    func testRowsSurviveARoundTrip() throws {
        let pack = try XCTUnwrap(CorrespondenceLibraryRegistry.bundledPacks.first)
        let decoded = try JSONDecoder().decode(
            CorrespondencePack.self,
            from: JSONEncoder().encode(pack)
        )
        XCTAssertEqual(decoded, pack)
    }
}

/// Phase 2: what the shelf prints.
final class CorrespondenceShelfTests: XCTestCase {

    /// With no ledger the shelf is the inherited half alone — which is exactly
    /// a new reader's first night, and it must still be worth opening.
    func testAColdShelfIsStillWorthOpening() {
        let sections = CorrespondenceShelf.sections()
        XCTAssertEqual(sections.map(\.id), ["untested", "folk", "academy"])
        XCTAssertTrue(sections.flatMap(\.rows).allSatisfy { $0.origin == .inherited })
        XCTAssertGreaterThanOrEqual(sections.flatMap(\.rows).count, 10)
    }

    func testNothingTheBookHasNotSaidReachesTheShelf() {
        XCTAssertTrue(
            CorrespondenceShelf.sections().allSatisfy { $0.rows.allSatisfy { $0.origin == .inherited } },
            "an empty ledger must contribute no findings of the Book's own"
        )
    }

    func testEverySectionSaysSomethingAndHoldsSomething() {
        for section in CorrespondenceShelf.sections() {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.note.isEmpty, "\(section.id) has a heading and no voice")
            XCTAssertFalse(section.rows.isEmpty, "\(section.id) is an empty heading")
        }
    }

    /// Every inherited row appears exactly once. A row that fell between the
    /// "untested" and "furniture" filters would simply vanish from the shelf.
    func testEveryInheritedRowIsPrintedExactlyOnce() {
        let printed = CorrespondenceShelf.sections().flatMap(\.rows).map(\.id)
        XCTAssertEqual(printed.count, Set(printed).count, "a row is printed twice")
        XCTAssertEqual(
            Set(printed),
            Set(CorrespondenceLibraryRegistry.all.map { "inherited:\($0.id)" }),
            "a row went missing between the sections"
        )
    }

    func testEveryPrintedRowSaysWhoSaysSo() {
        for row in CorrespondenceShelf.sections().flatMap(\.rows) {
            XCTAssertFalse(row.headline.isEmpty, "\(row.id) has no headline")
            XCTAssertFalse(row.attribution.isEmpty, "\(row.id) claims something with nobody's name on it")
        }
    }

    func testAnEmptyShelfPrintsNoEmptyHeadings() {
        XCTAssertTrue(CorrespondenceShelf.sections(inherited: []).isEmpty)
    }

    /// The contents line is redrawn on every desk build, so a number in it
    /// would have to be right every time.
    func testTheContentsLineCarriesNoCount() {
        XCTAssertFalse(CorrespondenceShelf.contentsDetail.contains { $0.isNumber })
    }
}

/// Phase 3: what happens where the two halves meet.
///
/// These hand-build ledger rows on purpose. The claim under test is not "the
/// Book can find X" — that would need real observations projected through the
/// engine, and `InheritedCorrespondenceTests`' wiring lint already covers the
/// feature ids these rows are keyed to. The claim here is narrower: *given* a
/// row in a given state, the shelf says the right thing about it and puts it in
/// the right place.
final class CorrespondenceMeetingTests: XCTestCase {

    private func ledger(_ pairs: [(condition: String, state: GrimoireClaimState)]) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        for (index, pair) in pairs.enumerated() {
            ledger.rows["r\(index)"] = GrimoireCorrespondence(
                id: "r\(index)", shape: .conditional,
                conditionID: pair.condition, outcomeID: "word:lantern",
                state: pair.state, firstObservedAt: Date(), lastObservedAt: Date(),
                falsifier: nil, revisions: [], readerStatus: nil,
                lastSpokenAt: Date(), strengthPeak: 60, interestPeak: 40
            )
        }
        return ledger
    }

    private var waterRow: InheritedCorrespondence {
        CorrespondenceLibraryRegistry.all.first { $0.observable == "place-kind:water" }!
    }

    func testNoEvidenceMeansNoMeeting() {
        XCTAssertNil(CorrespondenceShelf.meetingLine(for: waterRow, in: GrimoireLedger()))
    }

    func testLoreOnlyRowsCanNeverMeetAnything() {
        let furniture = CorrespondenceLibraryRegistry.loreOnly
        let busy = ledger([("place-kind:water", .standing), ("weather:rain", .standing)])
        for row in furniture {
            XCTAssertNil(
                CorrespondenceShelf.meetingLine(for: row, in: busy),
                "\(row.id) has no observable and must never acquire evidence"
            )
        }
    }

    func testTheBookAgreesWhenItsOwnRuleStands() {
        let line = CorrespondenceShelf.meetingLine(
            for: waterRow, in: ledger([("place-kind:water", .standing)])
        )
        XCTAssertNotNil(line)
        XCTAssertTrue(line?.contains("agree") == true)
    }

    /// The important direction: the Book contradicting inherited lore, on
    /// borrowed authority, which it can do long before it has rules of its own.
    func testTheBookContradictsWhenItHadToCrossItsOwnRuleOut() {
        let line = CorrespondenceShelf.meetingLine(
            for: waterRow, in: ledger([("place-kind:water", .crossedOut)])
        )
        XCTAssertNotNil(line)
        XCTAssertTrue(line?.contains("cross") == true)
        // The hedge, not its wording. Asserting the exact phrase is how a
        // contraction pass breaks a test that was checking a real rule.
        XCTAssertTrue(
            line?.contains("your days to go on") == true,
            "a contradiction must not claim the tradition is wrong, only that it didn't hold here"
        )
    }

    /// A crossing-out outranks agreement: owing a correction is more
    /// interesting than the Book being pleased with itself.
    func testTakingSomethingBackOutranksAgreement() {
        let line = CorrespondenceShelf.meetingLine(
            for: waterRow,
            in: ledger([("place-kind:water", .standing), ("place-kind:water", .crossedOut)])
        )
        XCTAssertTrue(line?.contains("cross") == true)
    }

    func testAnUnrelatedRuleIsNotAMeeting() {
        XCTAssertNil(CorrespondenceShelf.meetingLine(
            for: waterRow, in: ledger([("weather:fog", .standing)])
        ))
    }

    // MARK: Placement

    func testAMetRowLeavesTheUntestedSection() {
        let met = CorrespondenceShelf.sections(ledger: ledger([("place-kind:water", .standing)]))
        let untested = met.first { $0.id == "untested" }?.rows.map(\.id) ?? []
        let meeting = met.first { $0.id == "met" }?.rows.map(\.id) ?? []
        XCTAssertFalse(untested.contains("inherited:\(waterRow.id)"))
        XCTAssertTrue(meeting.contains("inherited:\(waterRow.id)"))
    }

    func testEveryInheritedRowIsStillPrintedExactlyOnceWithEvidence() {
        let sections = CorrespondenceShelf.sections(
            ledger: ledger([
                ("place-kind:water", .standing),
                ("weather:rain", .crossedOut),
                ("hour:evening", .watching)
            ])
        )
        let printed = sections.flatMap(\.rows).filter { $0.origin == .inherited }.map(\.id)
        XCTAssertEqual(printed.count, Set(printed).count, "a row is printed twice")
        XCTAssertEqual(printed.count, CorrespondenceLibraryRegistry.all.count)
    }

    /// A claim with no days behind it is not a claim. Hand-built rows have no
    /// ingested observations, so the shelf must decline to print them rather
    /// than print a half-built sentence.
    func testAFindingWithNothingUnderItIsNotPrinted() {
        let bare = ledger([("place-kind:water", .standing)])
        let row = bare.rows.values.first!
        XCTAssertNil(CorrespondenceShelf.item(for: row, ledger: bare))
        let sections = CorrespondenceShelf.sections(ledger: bare)
        XCTAssertTrue(sections.flatMap(\.rows).allSatisfy { $0.origin == .inherited })
    }
}

/// Phase 4: what the reader told the Book, printed as told rather than counted.
final class CorrespondenceToldTests: XCTestCase {

    private func fact(
        _ id: String,
        translation: String,
        permission: SelfFactUsePermission = .quoteAllowed,
        sensitivity: SelfFactSensitivity = .delight
    ) -> SelfFact {
        SelfFact(
            id: id, questionID: "q-\(id)", question: "Where do you think best?",
            answer: "near the water, always",
            bookTranslation: translation,
            sensitivity: sensitivity, usePermission: permission,
            tags: ["place"], createdAt: Date(), updatedAt: Date()
        )
    }

    func testAToldFactPrintsAsToldAndUnchecked() {
        let items = CorrespondenceShelf.toldItems(
            from: [fact("water", translation: "You think better near water.")]
        )
        let item = items.first
        XCTAssertEqual(item?.origin, .told)
        XCTAssertEqual(item?.headline, "You think better near water.")
        XCTAssertFalse(item?.isTestable ?? true, "nothing told is testable on the strength of being told")
        XCTAssertTrue(
            item?.attribution.contains("haven't checked") ?? false,
            "the Book must not present what it was told as something it worked out"
        )
    }

    /// The Book prints its own translation, never the reader's raw answer.
    func testTheReadersOwnWordsAreNotPrinted() {
        let items = CorrespondenceShelf.toldItems(
            from: [fact("water", translation: "You think better near water.")]
        )
        XCTAssertFalse(items.contains { $0.headline.contains("near the water, always") })
    }

    func testOnlyQuotableFactsReachTheShelf() {
        let facts = [
            fact("a", translation: "Quotable.", permission: .quoteAllowed),
            fact("b", translation: "Private.", permission: .privateContext),
            fact("c", translation: "Story only.", permission: .storyOnly),
            fact("d", translation: "Forbidden.", permission: .doNotUse)
        ]
        let printed = CorrespondenceShelf.toldItems(from: facts).map(\.headline)
        XCTAssertEqual(printed, ["Quotable."])
    }

    func testAFactWithNoTranslationIsNotPrinted() {
        XCTAssertTrue(CorrespondenceShelf.toldItems(from: [fact("x", translation: "")]).isEmpty)
    }

    func testTheToldSectionAppearsOnlyWhenThereIsSomethingInIt() {
        XCTAssertNil(CorrespondenceShelf.sections().first { $0.id == "told" })
        let withFacts = CorrespondenceShelf.sections(
            told: [fact("water", translation: "You think better near water.")]
        )
        let told = withFacts.first { $0.id == "told" }
        XCTAssertNotNil(told)
        XCTAssertTrue(told?.note.contains("not my counting") ?? false)
    }

    /// A told fact must never be mistaken for one of the Book's own findings,
    /// which are the only rows allowed to make a claim about the reader.
    func testNothingToldIsFiledWithTheBooksOwnFindings() {
        let sections = CorrespondenceShelf.sections(
            told: [fact("water", translation: "You think better near water.")]
        )
        for id in ["standing", "spoken", "watching", "crossed"] {
            let rows = sections.first { $0.id == id }?.rows ?? []
            XCTAssertTrue(rows.allSatisfy { $0.origin == .observed }, "\(id) admitted a told row")
        }
    }
}

/// A lint for the drift bj named on 2026-09-06: "simple, direct, clear,
/// childlike". The first draft of this corpus was none of those — it was a
/// clever adult essayist with opinions about folklore, and the tells were
/// structural rather than lexical, so they are checkable.
///
/// These are deliberately loose. They are not trying to score prose; they are
/// trying to catch the shapes that only appear when someone is writing an essay
/// instead of speaking.
final class CorrespondenceVoiceTests: XCTestCase {

    private var prose: [(id: String, text: String)] {
        CorrespondenceLibraryRegistry.all.flatMap {
            [(id: $0.id, text: $0.lore), (id: "\($0.id).sense", text: $0.sense)]
        } + CorrespondenceShelf.sections().map {
            (id: "section.\($0.id)", text: $0.note)
        } + [(id: "contents", text: CorrespondenceShelf.contentsDetail)]
    }

    private func sentences(_ text: String) -> [String] {
        text.split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// bj, 2026-09-06: "Longer sentences are ok, I said simple clear and
    /// direct, not short." Correct — length was never the tell. "You go out to
    /// the hives, you knock, and you tell them plainly who has died" is long and
    /// perfectly direct. What goes wrong is *structure*, which the other checks
    /// here cover. This stays only as a loose backstop against a genuine runaway.
    func testNoSentenceRunsAwayEntirely() {
        for entry in prose {
            for sentence in sentences(entry.text) {
                XCTAssertLessThanOrEqual(
                    sentence.split(separator: " ").count, 60,
                    "\(entry.id) has a sentence that has stopped being a sentence"
                )
            }
        }
    }

    /// The Book uses full stops. A semicolon is an adult balancing two clauses.
    func testTheBookDoesNotUseSemicolons() {
        for entry in prose {
            XCTAssertFalse(entry.text.contains(";"), "\(entry.id) balances a clause instead of stopping")
        }
    }

    /// ", which …" was the single commonest tell in the first draft: a fact,
    /// then the narrator's clever remark about the fact.
    func testNoCleverAppositiveAsides() {
        for entry in prose {
            XCTAssertFalse(
                entry.text.contains(", which "),
                "\(entry.id) appends an observation about its own observation"
            )
        }
    }

    /// The Book uses contractions. Writing it out formally — "it is not", "did
    /// not", "cannot" — turns it into a Victorian narrator, which is the
    /// specific drift this codebase keeps having to correct.
    ///
    /// A ratio rather than a ban, because a full form is sometimes the point:
    /// a vow lands heavier uncontracted. The named constructions below have no
    /// such excuse.
    func testTheBookTalksRatherThanNarrates() {
        var contracted = 0
        var total = 0
        var stiff: [String] = []
        for entry in prose {
            total += 1
            if entry.text.range(of: #"\w'(s|t|re|ve|ll|d|m)\b"#, options: .regularExpression) != nil {
                contracted += 1
            }
            for formal in ["it is not ", "does not ", "did not ", "cannot ", "will not ",
                           "I have never", "I am not ", "would not ", "could not ",
                           "that is why", "there is no "] {
                if entry.text.lowercased().contains(formal) {
                    stiff.append("\(entry.id): \(formal.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(stiff.isEmpty, "the Book turned narrator: \(stiff)")
        XCTAssertGreaterThan(
            Double(contracted) / Double(max(1, total)), 0.4,
            "only \(contracted) of \(total) lines carry a contraction; the voice is drying out"
        )
    }

    /// It is a Book, not a reference work: it is allowed to want things, prefer
    /// things and be wrong. If nothing in the corpus is in the first person,
    /// the voice has flattened back into an encyclopedia.
    func testTheBookIsPresentInItsOwnShelf() {
        let firstPerson = CorrespondenceLibraryRegistry.all.filter {
            $0.lore.contains("I ") || $0.lore.contains("I'")
        }
        XCTAssertGreaterThanOrEqual(
            firstPerson.count, 3,
            "nobody is speaking: the shelf has become a reference work"
        )
    }
}
