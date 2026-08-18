import XCTest
@testable import InsideCoverCore

final class BookInterjectionMoonshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private var relationship: BookRelationshipSnapshot {
        BookRelationshipSnapshot(
            stance: .pleased,
            depth: .companion,
            keptPageCount: 42,
            confirmedReadingCount: 3,
            softenedReadingCount: 1,
            protectedBoundaryCount: 0,
            returnedPageCount: 8,
            taughtRules: [],
            cherishedThreadName: "The Blue Door",
            latestWager: nil,
            recentReadingStatus: .confirmed
        )
    }

    private func surface(_ id: String, type: BookPageType = .souvenir) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: "test-source",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 70,
            reason: "A Page arrived.",
            prompt: "Look at this.",
            detail: "The corners are restless.",
            payload: BookPagePayload(headline: "A Page", body: "The original body remains whole.")
        )
    }

    private func interjectionSurface(
        _ id: String,
        subjectKey: String = "opinion:stairs",
        metadata additions: [String: String] = [:]
    ) -> SurfacePage {
        let base = surface(id, type: .bookNotices)
        var metadata = [
            "bookInterjectionID": "interjection-\(id)",
            "bookInterjectionSubjectKey": subjectKey,
            "bookInterjectionThoughtKey": "\(subjectKey):opinion",
            "bookInterjectionRegister": BookInterjectionRegister.opinion.rawValue,
            "bookActedMarginTitle": "I Have an Opinion",
            "bookActedMargin": "Stairs are shelves that escaped.",
            "bookInterjectionEvidencePageIDs": "evidence-a,evidence-b"
        ]
        for (key, value) in additions { metadata[key] = value }
        return SurfacePage(
            id: base.id, type: base.type, sourceID: base.sourceID,
            intent: base.intent, renderStyle: base.renderStyle, score: base.score,
            reason: base.reason, prompt: base.prompt, detail: base.detail,
            payload: BookPagePayload(
                headline: base.payload.headline,
                body: base.payload.body,
                metadata: metadata
            )
        )
    }

    private var interior: BookInteriorState {
        BookInteriorState(
            awakenedAt: now.addingTimeInterval(-120 * 86_400),
            fascination: BookFascination(
                id: "doorways",
                facet: .notice,
                subject: "doorways",
                line: "Doorways keep changing their minds about which room owns them.",
                evidencePageIDs: ["kept-door"],
                bornAt: now.addingTimeInterval(-80 * 86_400),
                lastDeepenedAt: now.addingTimeInterval(-86_400)
            ),
            sharedJoke: "The ribbon claims stairs are only shelves standing up."
        )
    }

    func testInterjectionUsesMarginWithoutMutatingTheAuthoredBody() throws {
        let original = surface("one")
        let decorated = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
            [original],
            interior: interior,
            days: [],
            selfFacts: [],
            relationship: relationship,
            receipts: [],
            appetite: .unruly,
            distressActive: false,
            rutward: false,
            now: now
        ).first)

        XCTAssertEqual(decorated.payload.body, original.payload.body)
        XCTAssertNotNil(decorated.payload.metadata["bookActedMargin"])
        XCTAssertNotNil(decorated.payload.metadata["bookInterjectionRegister"])
        XCTAssertEqual(decorated.payload.metadata["bookInterjectionSubjectKey"], "fascination:doorways")
    }

    func testOneFascinationCanReturnInAnotherRegisterButNotInsideItsRest() throws {
        let first = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
            [surface("first")], interior: interior, days: [], selfFacts: [],
            relationship: relationship, receipts: [], appetite: .alive,
            distressActive: false, rutward: false, now: now
        ).first)
        let receipt = try XCTUnwrap(BookInterjectionEditor.receipt(for: first, servedAt: now))

        let tooSoon = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
            [surface("soon")], interior: interior, days: [], selfFacts: [],
            relationship: relationship, receipts: [receipt], appetite: .alive,
            distressActive: false, rutward: false, now: now.addingTimeInterval(4 * 86_400)
        ).first)
        XCTAssertNotEqual(tooSoon.payload.metadata["bookInterjectionSubjectKey"], "fascination:doorways")

        let returned = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
            [surface("returned")], interior: interior, days: [], selfFacts: [],
            relationship: relationship, receipts: [receipt], appetite: .alive,
            distressActive: false, rutward: false, now: now.addingTimeInterval(6 * 86_400)
        ).first)
        XCTAssertEqual(returned.payload.metadata["bookInterjectionSubjectKey"], "fascination:doorways")
        XCTAssertNotEqual(returned.payload.metadata["bookInterjectionRegister"], receipt.register?.rawValue)
    }

    func testDistressSilencesEvenAnUnrulyCompanionBook() {
        let pages = [surface("a"), surface("b", type: .bookRemembered), surface("c", type: .bookNotices)]
        let decorated = BookInterjectionEditor.decoratingDesk(
            pages, interior: interior, days: [], selfFacts: [], relationship: relationship,
            receipts: [], appetite: .unruly, distressActive: true, rutward: false, now: now
        )
        XCTAssertFalse(decorated.contains { $0.payload.metadata["bookInterjectionID"] != nil })
    }

    func testDayOneBookCanMutterAboutItsOwnHouseWithoutReadingTheReader() throws {
        let decorated = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
            [surface("first-opening")], interior: .unawakened, days: [], selfFacts: [],
            relationship: .firstOpening, receipts: [], appetite: .alive,
            distressActive: false, rutward: false, now: now
        ).first)
        XCTAssertEqual(decorated.payload.metadata["bookInterjectionSource"], "shelf")
        XCTAssertTrue(
            decorated.payload.metadata["bookInterjectionSubjectKey"]?.hasPrefix("shelf:") == true
        )
    }

    func testAboutYouPermissionsAreOneWayAtIndexTime() {
        let forbiddenAnswer = "I am secretly terrified of glass elevators"
        let privateAnswer = "The hidden garden behind the old school"
        let facts = [
            SelfFact(
                id: "forbidden", questionID: "identity-1", question: "What matters?",
                answer: forbiddenAnswer, bookTranslation: "A fear near heights.",
                sensitivity: .identity, usePermission: .doNotUse, tags: [],
                createdAt: now, updatedAt: now
            ),
            SelfFact(
                id: "private", questionID: "interest-01", question: "What catches you?",
                answer: privateAnswer, bookTranslation: "A private garden.",
                sensitivity: .delight, usePermission: .privateContext, tags: ["interest"],
                createdAt: now, updatedAt: now
            )
        ]

        let index = BookPreoccupationIndex.building(
            interior: .unawakened, days: [], selfFacts: facts,
            relationship: relationship, now: now
        )
        XCTAssertFalse(index.contains { $0.subjectKey == "self-fact:forbidden" })
        let renderedPrivateLines = index
            .filter { $0.subjectKey == "self-fact:private" }
            .flatMap { $0.lines.values.flatMap { $0 } }
            .joined(separator: " ")
        XCTAssertFalse(renderedPrivateLines.localizedCaseInsensitiveContains(privateAnswer))
        XCTAssertFalse(renderedPrivateLines.localizedCaseInsensitiveContains("hidden garden"))
    }

    func testReaderResponseChangesTheFutureReceipt() throws {
        let decorated = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
            [surface("answerable")], interior: interior, days: [], selfFacts: [],
            relationship: relationship, receipts: [], appetite: .alive,
            distressActive: false, rutward: false, now: now
        ).first)
        let served = try XCTUnwrap(BookInterjectionEditor.receipt(for: decorated, servedAt: now))
        let answered = BookInterjectionEditor.responding(
            to: decorated, response: .wrong, in: [served], at: now.addingTimeInterval(60)
        )
        XCTAssertEqual(answered.first?.response, .wrong)
        XCTAssertNotNil(answered.first?.respondedAt)

        let later = BookInterjectionEditor.decoratingDesk(
            [surface("later")], interior: interior, days: [], selfFacts: [],
            relationship: relationship, receipts: answered, appetite: .unruly,
            distressActive: false, rutward: false, now: now.addingTimeInterval(30 * 86_400)
        )
        XCTAssertFalse(later.contains {
            $0.payload.metadata["bookInterjectionSubjectKey"] == "fascination:doorways"
        })
    }

    func testTheWholeInteriorCanBecomeAConversationSubject() {
        let tradition = BookPrivateTradition(
            id: "eraser-feast", kind: .erasersFeast, title: "The Eraser's Feast",
            observance: "We leave one mistake uncorrected until dusk.",
            originMemoryID: "memory-one", evidencePageIDs: ["page-one"],
            foundedAt: now.addingTimeInterval(-40 * 86_400), cadenceDays: 30,
            nextDueAt: now.addingTimeInterval(-60), lastObservedAt: nil,
            observanceCount: 0
        )
        let dispute = BookDispute(
            id: "argument-one", initiativeID: "initiative-one", opinionID: "opinion-one",
            subject: "rain", bookClaim: "Rain improves errands.", readerStance: .disagrees,
            readerLine: "Not when the bags split.", evidencePageIDs: ["rain-a"],
            semanticEvidencePageIDs: ["rain-b", "rain-a"], relationalConnectionIDs: [],
            relationalObservationKeys: [], relationReceipts: [],
            openedAt: now.addingTimeInterval(-20 * 86_400),
            lastEvolvedAt: now.addingTimeInterval(-86_400), firstReturnedAt: nil,
            lastReturnedAt: nil, returnCount: 0, status: .newEvidence
        )
        let state = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-200 * 86_400),
            promise: BookPromise(
                id: "promise-one", line: "I will keep one ordinary thing strange.",
                evidencePageIDs: ["promise-page"], madeAt: now.addingTimeInterval(-10 * 86_400),
                status: .keeping, resolvedAt: nil
            ),
            secret: BookSecret(
                id: "secret-one", family: .hope, tease: "Something under the seal is hopeful.",
                revelation: "I hope the reader outgrows the need for me.",
                sealedAt: now.addingTimeInterval(-100 * 86_400), status: .ready, revealedAt: nil
            ),
            recentSurprise: BookSurprise(
                id: "surprise-one", line: "The quiet Page was the one that returned.",
                evidencePageIDs: ["quiet-page"], happenedAt: now.addingTimeInterval(-86_400)
            ),
            currentDesireConflict: BookDesireConflict(
                id: "conflict-one", kind: .curiosityVersusPrivacy,
                firstWant: "to ask", secondWant: "to guard the sealed leaf",
                presentChoice: "I am guarding it.", involvedLoyaltyIDs: [],
                evidencePageIDs: ["sealed-page"], bornAt: now.addingTimeInterval(-3 * 86_400),
                lastShiftedAt: now, firstPresentedAt: nil
            ),
            privateTraditions: [tradition],
            secretLegacies: [BookSecretLegacy(
                id: "legacy-one", secretID: "old-secret", family: .method,
                stage: .echo, lastPresentedStage: .opened,
                line: "The revealed method changed how I notice doors.",
                evidencePageIDs: ["door-page"], bornAt: now.addingTimeInterval(-90 * 86_400),
                lastAdvancedAt: now, nextEligibleAt: now
            )],
            currentDispute: dispute
        )

        let keys = Set(BookPreoccupationIndex.building(
            interior: state, days: [], selfFacts: [], relationship: relationship, now: now
        ).map(\.subjectKey))
        XCTAssertTrue(keys.isSuperset(of: [
            "promise:promise-one", "secret:secret-one", "surprise:surprise-one",
            "desire-conflict:conflict-one", "tradition:eraser-feast",
            "secret-legacy:legacy-one", "dispute:argument-one"
        ]))
    }

    func testWrongBecomesARealDisputeAndRevisesCertainty() throws {
        let opinion = BookOpinion(
            id: "stairs", subject: "stairs", statement: "Stairs are escaped shelves.",
            strength: .held, evidencePageIDs: ["evidence-a"],
            formedAt: now.addingTimeInterval(-20 * 86_400), lastRevisedAt: now,
            revisions: [], firstPresentedAt: now
        )
        let page = interjectionSurface("wrong", metadata: ["bookOpinionID": opinion.id])
        let evolved = BookInterjectionEditor.applying(
            .wrong, to: page, interior: BookInteriorState(awakenedAt: now, opinion: opinion), at: now
        )

        XCTAssertEqual(evolved.opinion?.strength, .reconsidering)
        XCTAssertEqual(evolved.currentDispute?.readerLine, "You're wrong.")
        XCTAssertEqual(evolved.currentDispute?.evidencePageIDs, ["evidence-a", "evidence-b"])
        XCTAssertNotNil(evolved.currentFault)
    }

    func testGoOnAndNotNowChangeWhatTheBookCarriesForward() {
        let want = BookWant(
            id: "want-one", kind: .pursueAQuestion, line: "I want to keep following blue doors.",
            why: "They keep returning.", evidencePageIDs: ["blue-door"], bornAt: now,
            status: .stirring, resolvedAt: nil
        )
        let page = interjectionSurface("go-on", subjectKey: "want:want-one", metadata: [
            "bookWantID": want.id,
            "bookInterjectionEvidencePageIDs": "blue-door"
        ])
        let continued = BookInterjectionEditor.applying(
            .goOn, to: page, interior: BookInteriorState(awakenedAt: now, currentWant: want), at: now
        )
        XCTAssertEqual(continued.currentWant?.status, .satisfied)
        XCTAssertEqual(continued.autobiography.last?.kind, .conversationAnswered)

        let released = BookInterjectionEditor.applying(
            .notNow, to: page, interior: BookInteriorState(awakenedAt: now, currentWant: want), at: now
        )
        XCTAssertEqual(released.currentWant?.status, .released)
        XCTAssertTrue(released.autobiography.isEmpty)
    }

    func testOpeningAnInterjectionAdvancesItsLivingState() {
        let tradition = BookPrivateTradition(
            id: "tradition", kind: .dogEarDay, title: "Dog-Ear Day",
            observance: "One old Page gets the warm chair.", originMemoryID: "memory",
            evidencePageIDs: [], foundedAt: now.addingTimeInterval(-40 * 86_400),
            cadenceDays: 30, nextDueAt: now.addingTimeInterval(-1),
            lastObservedAt: nil, observanceCount: 0
        )
        let want = BookWant(
            id: "want", kind: .company, line: "I want company.", why: "The shelf is loud.",
            evidencePageIDs: [], bornAt: now, status: .stirring, resolvedAt: nil
        )
        let tension = BookInnerTension(
            id: "tension", kind: .speakingVersusSilence,
            firstPole: "to speak", secondPole: "to leave quiet alone",
            presentStance: "I am speaking once.", evidencePageIDs: [], bornAt: now,
            lastShiftedAt: now, firstPresentedAt: nil
        )
        let conflict = BookDesireConflict(
            id: "conflict", kind: .detourVersusCase,
            firstWant: "a detour", secondWant: "to finish my case",
            presentChoice: "The detour gets one Page.", involvedLoyaltyIDs: [],
            evidencePageIDs: [], bornAt: now, lastShiftedAt: now, firstPresentedAt: nil
        )
        let opened = BookInteriorEngine.recordingSurfaceOpened(
            BookInteriorState(
                awakenedAt: now, currentDesireConflict: conflict,
                privateTraditions: [tradition], currentWant: want, currentTension: tension
            ),
            desireConflictID: conflict.id, traditionID: tradition.id,
            wantID: want.id, tensionID: tension.id, now: now
        )
        XCTAssertEqual(opened.currentDesireConflict?.firstPresentedAt, now)
        XCTAssertEqual(opened.privateTraditions.first?.observanceCount, 1)
        XCTAssertEqual(opened.currentWant?.status, .voiced)
        XCTAssertEqual(opened.currentTension?.firstPresentedAt, now)
    }

    func testTalkativeBookDoesNotRepeatItsSentenceAcrossANinetyDaySeason() throws {
        var receipts: [BookInterjectionReceipt] = []
        var wordings: [String] = []
        var curious = relationship
        curious.stance = .curious

        for day in 0..<90 {
            let date = now.addingTimeInterval(Double(day) * 86_400)
            let page = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
                [surface("season-\(day)")], interior: interior, days: [], selfFacts: [],
                relationship: curious, receipts: receipts, appetite: .unruly,
                distressActive: false, rutward: false, now: date
            ).first)
            if let receipt = BookInterjectionEditor.receipt(for: page, servedAt: date) {
                wordings.append(receipt.wordingKey)
                receipts = BookInterjectionEditor.recording([receipt], into: receipts, now: date)
            }
        }

        XCTAssertGreaterThanOrEqual(wordings.count, 8)
        XCTAssertEqual(Set(wordings).count, wordings.count)
    }

    /// This contract used to assert only that `detail` differed, which the old
    /// prefix-prepending editor satisfied without telling the Page any
    /// differently — it would have passed with "Banana." glued to the front.
    /// It now asserts the shape of the telling actually moves. The full matrix
    /// lives in `BookWeatherTests`.
    func testStanceChangesHowACharacterOwnedPageEnters() {
        let original = SurfacePage(
            id: "chat", type: .askTheBook, sourceID: "test-source", intent: .reflect,
            renderStyle: .loreLetter, score: 70, reason: "A Page arrived.",
            prompt: "Look at this.", detail: "The corners are restless.",
            payload: BookPagePayload(
                headline: "A Page",
                body: "First, the throat-clearing.\n\nThen the finding itself.\n\nThen the leaves that did it.\n\nDo they belong together?"
            )
        )
        let loud = BookCharacterStanceEditor.voicing(
            original, telling: BookTelling(stance: .mischievous, intensity: 5)
        )
        let shut = BookCharacterStanceEditor.voicing(
            original, telling: BookTelling(stance: .protective, intensity: 5)
        )

        XCTAssertEqual(loud.payload.metadata["bookCharacterStance"], BookStance.mischievous.rawValue)
        XCTAssertEqual(loud.payload.metadata["bookCharacterCadence"], "crooked-and-loud")
        XCTAssertGreaterThan(
            loud.payload.body.components(separatedBy: "\n\n").count,
            shut.payload.body.components(separatedBy: "\n\n").count,
            "A loud Book must say more than a shut one about the same Page."
        )
        XCTAssertTrue(loud.payload.body.hasSuffix("?"), "It is still asking.")
        XCTAssertFalse(shut.payload.body.hasSuffix("?"), "A shut Book stops asking.")
        // Whatever the mood, the finding survives.
        XCTAssertTrue(shut.payload.body.contains("the finding itself"))
    }

    func testTheBookPhysicallyUnderlinesDogEarsAndLeavesPagesOpen() throws {
        var curious = relationship
        curious.stance = .curious

        let keptPage = BookPage(
            id: "kept-ink", type: .souvenir, createdAt: now.addingTimeInterval(-86_400),
            promptText: "What stayed?", userInput: "The blue cup held the last square of window light."
        )
        let days = [BookDay(id: "kept-day", date: keptPage.createdAt, pages: [keptPage])]
        var underlined: SurfacePage?
        for offset in 0..<40 where underlined == nil {
            let date = now.addingTimeInterval(Double(offset) * 86_400)
            let candidate = BookInterjectionEditor.decoratingDesk(
                [surface("underline-\(offset)")], interior: .unawakened, days: days,
                selfFacts: [], relationship: curious, receipts: [], appetite: .unruly,
                distressActive: false, rutward: false, now: date
            ).first
            if candidate?.payload.metadata["bookInterjectionRegister"] == BookInterjectionRegister.opinion.rawValue {
                underlined = candidate
            }
        }
        XCTAssertEqual(underlined?.payload.metadata["bookInterjectionPhysicalAct"], "underline")
        XCTAssertEqual(
            underlined?.payload.metadata["bookInterjectionTargetExcerpt"],
            "The blue cup held the last square of"
        )

        let favorite = BookFavorite(
            id: "favorite-one", pageID: "old-favorite", pageType: .souvenir,
            excerpt: "A moth on the stair.", reason: "It was braver than the lamp.",
            chosenAt: now.addingTimeInterval(-30 * 86_400), firstPresentedAt: nil
        )
        let dogEared = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
            [surface("dog-ear")],
            interior: BookInteriorState(awakenedAt: now, favorite: favorite),
            days: [], selfFacts: [], relationship: curious, receipts: [], appetite: .unruly,
            distressActive: false, rutward: false, now: now
        ).first)
        XCTAssertEqual(dogEared.payload.metadata["bookInterjectionPhysicalAct"], "dog-ear")

        var leftOpen: SurfacePage?
        for offset in 0..<40 where leftOpen == nil {
            let date = now.addingTimeInterval(Double(offset) * 86_400)
            let candidate = BookInterjectionEditor.decoratingDesk(
                [surface("left-open-\(offset)")], interior: interior, days: [], selfFacts: [],
                relationship: curious, receipts: [], appetite: .unruly,
                distressActive: false, rutward: false, now: date
            ).first
            if candidate?.payload.metadata["bookInterjectionRegister"] == BookInterjectionRegister.callback.rawValue {
                leftOpen = candidate
            }
        }
        XCTAssertEqual(leftOpen?.payload.metadata["bookInterjectionPhysicalAct"], "left-open")
    }

    func testCharacterLintSeesGeneratedServantLanguage() {
        var bad = surface("servant", type: .bookNotices)
        bad = SurfacePage(
            id: bad.id, type: bad.type, sourceID: bad.sourceID, intent: bad.intent,
            renderStyle: bad.renderStyle, score: bad.score, reason: bad.reason,
            prompt: bad.prompt, detail: "Whenever you like, I can help.", payload: bad.payload
        )
        XCTAssertTrue(BookCharacterLint.inspect(bad).contains { $0.rule == "servant-register" })
    }

    func testCharacterLintAlsoReadsTheBookMargin() {
        let base = surface("mechanical-margin", type: .bookNotices)
        let bad = SurfacePage(
            id: base.id, type: base.type, sourceID: base.sourceID,
            intent: base.intent, renderStyle: base.renderStyle, score: base.score,
            reason: base.reason, prompt: base.prompt, detail: base.detail,
            payload: BookPagePayload(
                headline: base.payload.headline,
                body: base.payload.body,
                metadata: ["bookActedMargin": "Tap below and choose an option."]
            )
        )
        XCTAssertTrue(BookCharacterLint.inspect(bad).contains { $0.rule == "mechanical-register" })
        XCTAssertTrue(BookCharacterLint.report([bad]).contains("mechanical-register"))
    }

    func testRegisterLabelsSoundLikeInterruptionsInsteadOfCategories() {
        XCTAssertEqual(BookInterjectionRegister.opinion.marginTitle, "Look.")
        XCTAssertEqual(BookInterjectionRegister.connection.marginTitle, "These Touched.")
        XCTAssertEqual(BookInterjectionRegister.admission.marginTitle, "Fine.")
        XCTAssertEqual(BookInterjectionRegister.appetite.marginTitle, "Mine.")
        XCTAssertEqual(BookInterjectionRegister.objection.marginTitle, "No.")
        XCTAssertEqual(BookInterjectionRegister.overhead.marginTitle, "Psst.")
        XCTAssertEqual(BookInterjectionRegister.digression.marginTitle, "Oh—")
        XCTAssertEqual(BookInterjectionRegister.callback.marginTitle, "It Came Back.")
        XCTAssertEqual(BookInterjectionRegister.withheld.marginTitle, "...")
    }

    func testHushedBookDoesNotLoseTheThoughtAndLeaveOnlyThroatClearing() throws {
        var hushed = relationship
        hushed.stance = .hushed
        let decorated = try XCTUnwrap(BookInterjectionEditor.decoratingDesk(
            [surface("hushed")], interior: interior, days: [], selfFacts: [],
            relationship: hushed, receipts: [], appetite: .unruly,
            distressActive: false, rutward: false, now: now
        ).first)
        let line = try XCTUnwrap(decorated.payload.metadata["bookActedMargin"])

        XCTAssertTrue(line.localizedCaseInsensitiveContains("doorways"))
        XCTAssertFalse(["Fine.", "Wait.", "Oh."].contains(line))
    }

    func testGeneratedInterjectionsDoNotExplainWhyTheyAreInterjections() throws {
        var generated: [SurfacePage] = []
        for offset in 0..<40 {
            let date = now.addingTimeInterval(Double(offset) * 86_400)
            generated += BookInterjectionEditor.decoratingDesk(
                [surface("voice-\(offset)")], interior: interior, days: [], selfFacts: [],
                relationship: relationship, receipts: [], appetite: .unruly,
                distressActive: false, rutward: false, now: date
            )
        }

        XCTAssertFalse(BookCharacterLint.inspect(generated).contains { $0.rule == "thin-interjection" })
    }
}
