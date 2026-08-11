import XCTest
@testable import InsideCoverCore

/// The chosen quill: the Quillquarium instrument that picks its writer and
/// is, by the oldest rule of the room, the reader's opposite. The mint must
/// be deterministic (re-offering the ceremony never changes the candidate),
/// the temperament must genuinely invert the observed hand, and the choosing
/// page must fire exactly once.
final class QuillCompanionTests: XCTestCase {
    private let adapter = QuillChoosingPageSourceAdapter()

    private func date(_ day: Int, hour: Int = 10) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func souvenir(_ text: String, on day: Int, hour: Int = 10) -> BookPage {
        BookPage(type: .souvenir, createdAt: date(day, hour: hour), promptText: "Souvenir", userInput: text)
    }

    private func hedgingPages() -> [BookPage] {
        (0..<10).map { index in
            souvenir("Maybe it was the rain today, I think, or sort of the light", on: 1 + (index % 4), hour: 8 + index)
        }
    }

    private func inputs(with pages: [BookPage], quill: ChosenQuill? = nil) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .map { id, pages in BookDay(id: id, date: pages[0].createdAt, pages: pages) }
        inputs.chosenQuill = quill
        return inputs
    }

    private func candidates(_ inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let today = BookDay(id: "today", date: now, pages: [])
        return adapter.candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now)
    }

    // MARK: - Temperament inversion

    func testHedgingReaderGetsBoldQuill() {
        let temperament = QuillTemperament.opposing(ReaderMannerProfile.measure(pages: hedgingPages()))
        let boldness = temperament.axes.first { $0.id == "boldness" }
        XCTAssertEqual(boldness?.readerSideIsHigh, false)
        XCTAssertTrue(boldness?.quillLeaning.contains("bold") == true)
        XCTAssertTrue((boldness?.strength ?? 0) > 0.3, "six hedges in six pages is real evidence")
    }

    func testBoldReaderGetsQuietQuill() {
        let pages = (0..<6).map { index in
            souvenir("What a day! Glorious rain! We ran the whole block home!", on: 1, hour: 8 + index)
        }
        let temperament = QuillTemperament.opposing(ReaderMannerProfile.measure(pages: pages))
        let boldness = temperament.axes.first { $0.id == "boldness" }
        XCTAssertEqual(boldness?.readerSideIsHigh, true)
        XCTAssertTrue(boldness?.quillLeaning.contains("quiet") == true)
    }

    func testQuestioningReaderGetsDeclaringQuill() {
        let pages = (0..<6).map { index in
            souvenir("Why does the kitchen feel different after dark? Who decided that?", on: 1, hour: 8 + index)
        }
        let temperament = QuillTemperament.opposing(ReaderMannerProfile.measure(pages: pages))
        let inquiry = temperament.axes.first { $0.id == "inquiry" }
        XCTAssertEqual(inquiry?.readerSideIsHigh, true)
        XCTAssertTrue(inquiry?.quillLeaning.contains("declares") == true)
    }

    func testTerseReaderGetsOrnateQuill() {
        let pages = (0..<6).map { index in
            souvenir("Rain again. Fine by me.", on: 1, hour: 8 + index)
        }
        let temperament = QuillTemperament.opposing(ReaderMannerProfile.measure(pages: pages))
        let ornament = temperament.axes.first { $0.id == "ornament" }
        XCTAssertEqual(ornament?.readerSideIsHigh, false)
        XCTAssertTrue(ornament?.quillLeaning.contains("ornate") == true)
    }

    // MARK: - Minting

    func testMintIsDeterministicAcrossSessions() {
        let pages = hedgingPages()
        let first = QuillChoosing.mint(from: pages, now: date(1, hour: 20))
        let second = QuillChoosing.mint(from: pages, now: date(3, hour: 9))
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(first?.name, second?.name)
        XCTAssertEqual(first?.make, second?.make)
        XCTAssertEqual(first?.temperament, second?.temperament)
    }

    func testMintNeedsSixProsePages() {
        let pages = Array(hedgingPages().prefix(5))
        XCTAssertNil(QuillChoosing.mint(from: pages, now: date(1, hour: 20)))
    }

    func testPrivateLogsDoNotCountTowardTheHand() {
        // Six body logs and five souvenirs: the body logs are private and the
        // hand cannot be read from five prose pages alone.
        let pages = (0..<6).map { index in
            BookPage(type: .body, createdAt: date(1, hour: 8 + index), promptText: "Body", userInput: "the knee complains again today")
        } + Array(hedgingPages().prefix(5))
        XCTAssertNil(QuillChoosing.mint(from: pages, now: date(1, hour: 20)))
    }

    // MARK: - The choosing page

    func testChoosingSurfacesForMatureLibrary() {
        let surfaced = candidates(inputs(with: hedgingPages()), now: date(6, hour: 20))
        XCTAssertEqual(surfaced.count, 1)
        let page = surfaced[0]
        XCTAssertEqual(page.type, .castBond)
        XCTAssertTrue(page.payload.metadata["tags"]?.contains(QuillChoosing.chosenTag) == true)
        let quillJSON = page.payload.metadata[QuillChoosing.metadataKey]
        XCTAssertNotNil(quillJSON?.nonEmpty)
        let quill = try? JSONDecoder().decode(ChosenQuill.self, from: Data((quillJSON ?? "").utf8))
        XCTAssertNotNil(quill)
        // The page must introduce the instrument by name and read the hand honestly.
        XCTAssertTrue(page.payload.body.contains(quill?.name ?? "§"))
        XCTAssertTrue(page.payload.body.contains("you had"))
        XCTAssertEqual(page.payload.metadata["pageTitle"], "The Pen Choosing")
        XCTAssertEqual(page.payload.metadata["locationAsset"], "LabyrinthLocationQuillquarium")
    }

    func testChoosingOffersTheSameQuillOnLaterDays() {
        // The same archive (same page ids) must present the same instrument,
        // however many days pass between offers.
        let pages = hedgingPages()
        let first = candidates(inputs(with: pages), now: date(6, hour: 20))
        let second = candidates(inputs(with: pages), now: date(9, hour: 9))
        XCTAssertEqual(
            first.first?.payload.metadata["quillName"],
            second.first?.payload.metadata["quillName"],
            "quills are patient; the candidate never changes its mind"
        )
    }

    func testChoosingCeremonyRestsForNinetyDaysAfterBeingSeen() throws {
        let shownAt = date(6, hour: 20)
        let page = try XCTUnwrap(candidates(inputs(with: hedgingPages()), now: shownAt).first)
        let history = CuratorVarietyGovernor.recordingServed(
            keys: page.curatorServedHistoryKeys,
            into: [:],
            now: shownAt
        )

        XCTAssertFalse(CuratorNoveltyPolicy.allowsAutomaticSurface(
            page,
            history: history,
            preferences: .none,
            now: shownAt.addingTimeInterval(89 * 86_400)
        ))
        XCTAssertTrue(CuratorNoveltyPolicy.allowsAutomaticSurface(
            page,
            history: history,
            preferences: .none,
            now: shownAt.addingTimeInterval(90 * 86_400)
        ))
    }

    func testChoosingWaitsForEnoughProse() {
        let surfaced = candidates(inputs(with: Array(hedgingPages().prefix(5))), now: date(1, hour: 20))
        XCTAssertTrue(surfaced.isEmpty)
    }

    func testChoosingWaitsForTheHandToAgeAcrossDays() {
        let sameDay = (0..<10).map {
            souvenir("Maybe the window kept changing its mind about the rain \($0).", on: 1, hour: 8 + $0)
        }
        XCTAssertTrue(candidates(inputs(with: sameDay), now: date(6, hour: 20)).isEmpty)
        XCTAssertTrue(candidates(inputs(with: hedgingPages()), now: date(4, hour: 20)).isEmpty)
    }

    func testChoosingDoesNotRepeatAfterKept() {
        var pages = hedgingPages()
        pages.append(BookPage(type: .castBond, createdAt: date(1, hour: 21),
                              promptText: "The Quill Chooses the Writer", userInput: "",
                              tags: [QuillChoosing.chosenTag, "quillquarium"]))
        XCTAssertTrue(candidates(inputs(with: pages), now: date(2, hour: 20)).isEmpty)
    }

    func testChoosingStopsOncePersisted() {
        let quill = QuillChoosing.mint(from: hedgingPages(), now: date(1, hour: 20))
        XCTAssertNotNil(quill)
        let surfaced = candidates(inputs(with: hedgingPages(), quill: quill), now: date(2, hour: 20))
        XCTAssertTrue(surfaced.isEmpty)
    }

    func testChoosingPromptIsNotTheGenericTwoCastPrompt() throws {
        let page = try XCTUnwrap(candidates(inputs(with: hedgingPages()), now: date(6, hour: 20)).first)
        let prompt = QuillChoosing.generationPrompt(surface: page)
        let quillJSON = try XCTUnwrap(page.payload.metadata[QuillChoosing.metadataKey])
        let quill = try JSONDecoder().decode(ChosenQuill.self, from: Data(quillJSON.utf8))
        XCTAssertTrue(prompt.contains("SECOND-PERSON PAST TENSE"))
        XCTAssertTrue(prompt.contains(quill.name))
        XCTAssertTrue(prompt.contains(quill.make))
        XCTAssertTrue(prompt.contains("Quillquarium"))
        XCTAssertTrue(prompt.contains("Do not introduce two cast members"))
        XCTAssertFalse(prompt.contains("The relationship web has crossed a milestone"))
    }

    func testGeneratedCeremonyRejectsUnrelatedFirstPersonProse() throws {
        let quill = try XCTUnwrap(QuillChoosing.mint(from: hedgingPages(), now: date(1, hour: 20)))
        let unrelated = String(repeating: "I walked through a sunny market and thought about my friendship with two strangers. ", count: 5)
        XCTAssertFalse(QuillChoosing.generatedCeremonyIsGrounded(unrelated, quill: quill))

        let grounded = """
        You had entered the Quillquarium while the living pens circled above you. The room was holding its breath, and every nib had turned toward your hand.

        \(quill.name) had waited in the highest school. It chose you, broke from the others, and landed before you with one bright drop of ink trembling at its point.

        You had written softly before, but the quill had arrived to be brave first. Your fingers closed around the \(quill.make), and the paper beneath it was warm.

        The choosing was not complete. If you kept the page, the quill would stay; if you let it wait, it would return patiently to the school.
        """
        XCTAssertTrue(QuillChoosing.generatedCeremonyIsGrounded(grounded, quill: quill))
    }

    // MARK: - Margin voice

    func testMarginNoteTakesRoughlyOneKeepInFive() throws {
        let quill = try XCTUnwrap(QuillChoosing.mint(from: hedgingPages(), now: date(1, hour: 20)))
        let input = "The kitchen held the last warm light of the evening."
        let notes = (0..<60).compactMap { index in
            QuillChoosing.marginNote(quill: quill, for: input, pageType: .souvenir, pageID: "page-\(index)")
        }
        XCTAssertGreaterThan(notes.count, 0)
        XCTAssertLessThan(notes.count, 30, "the quill borrows the margin; it must not own it")
        for note in notes {
            XCTAssertEqual(note.castSlug, "chosen-quill")
            XCTAssertEqual(note.castName, quill.name)
            XCTAssertFalse(note.line.contains("{word}"), "template words must be filled")
        }
    }

    func testMarginNoteRespectsPrivatePageTypes() throws {
        let quill = try XCTUnwrap(QuillChoosing.mint(from: hedgingPages(), now: date(1, hour: 20)))
        for index in 0..<60 {
            XCTAssertNil(QuillChoosing.marginNote(
                quill: quill,
                for: "the knee complains again today and loudly",
                pageType: .body,
                pageID: "page-\(index)"
            ))
        }
    }

    // MARK: - Story influence

    func testStoryDirectiveNamesTheQuillAndItsPush() throws {
        let quill = try XCTUnwrap(QuillChoosing.mint(from: hedgingPages(), now: date(1, hour: 20)))
        let directive = QuillChoosing.storyDirective(for: quill)
        XCTAssertTrue(directive.contains(quill.name))
        XCTAssertTrue(directive.contains(quill.temperament.dominant?.quillLeaning ?? "§"))
        XCTAssertTrue(directive.contains("never a narrator"))
    }

    func testQuillRecipeRequiresAChosenQuill() {
        let recipe = StoryFormRegistry.coreRecipes.first { $0.id == "the-quill-disagrees" }
        XCTAssertNotNil(recipe)
        XCTAssertTrue(recipe?.requirements.contains(.chosenQuill) == true)
        XCTAssertTrue(recipe.map(StoryFormRegistry.recipeIsValid) == true)
        XCTAssertTrue(recipe?.premiseTemplate.contains("{{quill}}") == true)
    }

    // MARK: - The Cast seat

    func testChosenQuillMintsAsCastMember() throws {
        let quill = try XCTUnwrap(QuillChoosing.mint(from: hedgingPages(), now: date(1, hour: 20)))
        let member = quill.castMember(now: date(1, hour: 21))
        XCTAssertEqual(member.name, quill.name)
        XCTAssertEqual(member.kind, .character)
        XCTAssertEqual(member.id, "user-cast-\(quill.id)", "the id derives from the quill so adoption can upsert without twins")
        XCTAssertTrue(member.tags.contains("chosen-quill"))
        // The Instrument Law rides in as a belief the story engine can quote.
        XCTAssertTrue(member.beliefs.contains { $0.contains("written, not waved") })
        XCTAssertEqual(member.goals, quill.wants)
        XCTAssertFalse(member.traits.isEmpty)
        // The entity conversion the story engine consumes must hold together.
        XCTAssertEqual(member.entity.kind, .character)
        XCTAssertEqual(member.entity.name, quill.name)
    }
}
