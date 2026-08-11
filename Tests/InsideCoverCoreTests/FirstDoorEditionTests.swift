import XCTest
@testable import InsideCoverCore

/// The onboarding finale binds a real mini edition from a single synthetic
/// arrival day (souvenirs, Zara's letter, named constellations). These tests
/// pin the Shared-side behavior that makes that binding non-empty: the
/// curator must keep authored arrival pages, and the builder must carry the
/// named constellations into the star chart and foreword.
final class FirstDoorEditionTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var arrival: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 7, minute: 37)) ?? Date()
    }

    private func arrivalDay(_ now: Date) -> BookDay {
        let pages: [BookPage] = [
            BookPage(
                type: .souvenir,
                createdAt: now,
                promptText: "The first kept page",
                userInput: "I opened the Book at 7:37 AM on Saturday morning, while the day is still deciding what kind of page it is.",
                tags: ["onboarding", "first-page"],
                sourceID: "first-door"
            ),
            BookPage(
                type: .souvenir,
                createdAt: now.addingTimeInterval(60),
                promptText: "A belief, planted at the threshold",
                userInput: "Spoken aloud to Zara Finch: small true things matter",
                tags: ["onboarding", "belief"],
                sourceID: "first-door"
            ),
            BookPage(
                type: .letter,
                createdAt: now.addingTimeInterval(240),
                promptText: "Dear Reader,\n\nYou fell out of the Unwritten this morning and kept a page before anyone explained keeping.\n\nZara Finch",
                tags: ["onboarding", "zara", "letter"],
                // Reply-less letters only bind when the Book already wove them.
                usedInBookOfYou: true,
                sourceID: "zara-finch"
            )
        ]
        return BookDay(id: BookDay.id(for: now, calendar: calendar), date: calendar.startOfDay(for: now), pages: pages)
    }

    private func namedConstellation(id: String, subject: String, name: String, kind: LiterarySignalKind, now: Date) -> Constellation {
        Constellation(
            id: id,
            signalID: id,
            kind: kind,
            subjectID: id,
            subjectName: subject,
            name: name,
            phase: .named,
            firstNoticedAt: now,
            lastSeenAt: now,
            namedAt: now,
            wovenAt: nil,
            fadedAt: nil,
            sightingDayIDs: [BookDay.id(for: now, calendar: calendar)],
            strengthPeak: 3,
            latestLine: "Planted at the threshold.",
            evidencePageIDs: [],
            relatedEntityIDs: [],
            tags: ["onboarding"]
        )
    }

    private func firstDoorEdition() -> MonthlyEdition {
        let now = arrival
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)
        var edition = MonthlyEditionBuilder.edition(
            from: [arrivalDay(now)],
            constellations: [
                namedConstellation(id: "onboarding-first-belief", subject: "small true things matter", name: "The First Belief", kind: .beliefLifecycle, now: now),
                namedConstellation(id: "onboarding-sleeve-word", subject: "GLINT", name: "The Glint", kind: .pattern, now: now)
            ],
            readerName: "Reader",
            startDate: monthStart,
            endDate: now,
            generatedAt: now,
            calendar: calendar
        )
        edition.title = "Book of You: The First Door"
        edition.publicationKind = .special
        edition.publicationRecipeID = "first-door"
        edition.publicationCoverPlateID = "hedge-door"
        edition.firstDoorPublication = FirstDoorPublicationMatter(
            arrivalLine: "Bound on Saturday, July 4, 2026 at 7:37 AM.",
            signatures: [
                .init(id: "curse", title: "The Curse Proves Itself", evidence: "Two details went missing.", meaning: "The Rut left a gap."),
                .init(id: "learning", title: "The Book Learns You", evidence: "Small true things matter.", meaning: "The Book learned its manners."),
                .init(id: "consequence", title: "The Story Bites Back", evidence: "The reader kept a Page.", meaning: "The fiction changed."),
                .init(id: "return", title: "The Bindery Returns Proof", evidence: "The Page became this copy.", meaning: "The promise became tangible.")
            ],
            firstArgumentTitle: "The First Belief",
            firstArgumentBody: "The Academy took the Page's side.",
            closing: "Bring me another ordinary thing.\n\n- The Book",
            bookNote: "I was blank at this door. Then you gave me one true thing.",
            thresholdThread: [
                .init(id: "noticed", stage: "YOU NOTICED", detail: "One small true thing."),
                .init(id: "returned", stage: "THE PRESS RETURNED", detail: "The Page became this copy.")
            ],
            bindingConversation: BoundVolumeCastConversation(
                title: "The Copy on the Binding Table",
                setting: "The finished First Door was open between them.",
                lines: [
                    .init(
                        id: "zara-hinge",
                        speakerID: "zara-finch",
                        speakerName: "Zara Finch",
                        glyph: nil,
                        words: "The ordinary thing is the hinge."
                    ),
                    .init(
                        id: "wicker-bite",
                        speakerID: "wicker-eddies",
                        speakerName: "Wicker Eddies",
                        glyph: nil,
                        words: "I bit it. The page changed."
                    )
                ],
                evidenceIDs: ["first-door-detail"]
            )
        )
        return edition
    }

    func testArrivalDayBindsNonEmptyEdition() {
        let edition = firstDoorEdition()
        XCTAssertFalse(edition.isEmpty, "A single authored arrival day must still bind a non-empty edition.")
        XCTAssertGreaterThan(edition.pageCount, 0)
        XCTAssertEqual(edition.dayCount, 1)
    }

    func testCuratorKeepsAuthoredArrivalSouvenirs() {
        let edition = firstDoorEdition()
        let souvenirs = edition.sections.first { $0.id == "souvenirs" }
        XCTAssertNotNil(souvenirs, "Authored arrival souvenirs must survive curation into the souvenirs section.")
        XCTAssertGreaterThanOrEqual(souvenirs?.items.count ?? 0, 2)
    }

    func testZaraLetterBindsIntoLettersSection() {
        let edition = firstDoorEdition()
        let letters = edition.sections.first { $0.id == "letters" }
        XCTAssertNotNil(letters, "The synthesized Zara letter must bind into Letters And Voices.")
        XCTAssertTrue(
            letters?.items.contains { $0.body.contains("Zara Finch") } ?? false,
            "The letter body should carry Zara's signature."
        )
    }

    func testNamedConstellationsReachStarChartAndForeword() {
        let edition = firstDoorEdition()
        let alive = edition.constellations.filter(\.isAlive)
        XCTAssertEqual(alive.count, 2, "Both named arrival constellations must stay alive for the star chart page.")
        XCTAssertTrue(
            edition.foreword.contains("The First Belief") || edition.foreword.contains("The Glint"),
            "The foreword should name at least one arrival constellation."
        )
    }

    func testFirstDoorHasDurableSpecialEditionIdentityAndFourSignatures() throws {
        let edition = firstDoorEdition()
        XCTAssertTrue(edition.isFirstDoorEdition)
        XCTAssertEqual(edition.chapterHeading, "The Book of You (Reader): The First Door")
        XCTAssertEqual(edition.firstDoorPublication?.signatures.count, 4)
        XCTAssertEqual(edition.firstDoorPublication?.thresholdThread?.count, 2)
        XCTAssertEqual(edition.firstDoorPublication?.bindingConversation?.lines.count, 2)
        XCTAssertTrue(edition.firstDoorPublication?.bookNote?.contains("blank at this door") ?? false)
        XCTAssertEqual(edition.publicationCoverPlateID, "hedge-door")

        let data = try JSONEncoder().encode(edition)
        let decoded = try JSONDecoder().decode(MonthlyEdition.self, from: data)
        XCTAssertEqual(decoded.firstDoorPublication, edition.firstDoorPublication)
        XCTAssertEqual(decoded.publicationCoverPlateID, "hedge-door")
        XCTAssertTrue(decoded.isFirstDoorEdition)
    }

    func testOlderTitledFirstDoorArchiveStillDecodesWithoutSpecialMatter() throws {
        let edition = firstDoorEdition()
        let encoded = try JSONEncoder().encode(edition)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            return XCTFail("The encoded edition should be a JSON object.")
        }
        object.removeValue(forKey: "firstDoorPublication")
        object.removeValue(forKey: "publicationKind")
        object.removeValue(forKey: "publicationRecipeID")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(MonthlyEdition.self, from: legacyData)
        XCTAssertNil(decoded.firstDoorPublication)
        XCTAssertTrue(decoded.isFirstDoorEdition, "The historic title should preserve the edition's identity.")
    }

    func testEarlierFirstDoorMatterDecodesBeforeMoonshotLeavesExisted() throws {
        let edition = firstDoorEdition()
        let encoded = try JSONEncoder().encode(edition)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
              var matter = object["firstDoorPublication"] as? [String: Any] else {
            return XCTFail("The encoded edition should contain First Door matter.")
        }
        matter.removeValue(forKey: "bookNote")
        matter.removeValue(forKey: "thresholdThread")
        matter.removeValue(forKey: "bindingConversation")
        matter.removeValue(forKey: "readerCoverArtwork")
        object["firstDoorPublication"] = matter

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(MonthlyEdition.self, from: legacyData)
        XCTAssertNotNil(decoded.firstDoorPublication)
        XCTAssertNil(decoded.firstDoorPublication?.bookNote)
        XCTAssertNil(decoded.firstDoorPublication?.thresholdThread)
        XCTAssertNil(decoded.firstDoorPublication?.bindingConversation)
        XCTAssertNil(decoded.firstDoorPublication?.readerCoverArtwork)
    }

    func testReaderPhotographCoverSurvivesArchiveRoundTrip() throws {
        var edition = firstDoorEdition()
        edition.publicationCoverPlateID = nil
        guard var matter = edition.firstDoorPublication else {
            return XCTFail("The edition should contain First Door matter.")
        }
        matter.readerCoverArtwork = .init(
            imagePath: "/private/local/first-door-cover.png",
            titleLayout: .photographFooter,
            focusX: 0.31,
            focusY: 0.27
        )
        edition.firstDoorPublication = matter

        let data = try JSONEncoder().encode(edition)
        let decoded = try JSONDecoder().decode(MonthlyEdition.self, from: data)
        XCTAssertNil(decoded.publicationCoverPlateID)
        XCTAssertEqual(
            decoded.firstDoorPublication?.readerCoverArtwork,
            matter.readerCoverArtwork
        )
    }

    func testPhotographCoverReservesAContrastSafeFooter() {
        let layout = PublicationCoverTitleLayout.photographFooter
        let rect = layout.titleRect
        XCTAssertGreaterThanOrEqual(rect.y, 0.60)
        XCTAssertLessThanOrEqual(rect.y + rect.height, 0.95)
        XCTAssertGreaterThanOrEqual(rect.width, 0.80)
        XCTAssertGreaterThanOrEqual(
            layout.readabilityFieldOpacity,
            0.90,
            "A translucent decorative veil is not enough over arbitrary reader photography."
        )
        XCTAssertFalse(layout.usesDarkInk)
    }
}
