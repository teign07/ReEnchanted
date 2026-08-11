import XCTest
@testable import InsideCoverCore

/// The Fae economy was mechanically good and morally uniform, which makes the
/// creatures task-givers in costume. These tests exist to prove the six laws
/// are genuinely incompatible: that two species can read one honest report and
/// disagree about whether it was paid. If these ever collapse into agreement,
/// the Fae have gone back to being quest-givers.
final class FaeLawTests: XCTestCase {

    private let terms = "Bring me the colour of the door you passed."

    // MARK: The laws disagree

    func testTwoSpeciesReachOppositeVerdictsOnTheSameReport() {
        // Beautiful, warm, and with no terminal punctuation.
        let report = "the kettle hissed and the whole window went white with it"

        let salamander = FaeLaw.judge(report: report, kind: .sentenceSalamander, terms: terms)
        let pixie = FaeLaw.judge(report: report, kind: .punctuationPixie, terms: terms)

        XCTAssertTrue(salamander.accepted, "The salamander should take heat wherever it finds it")
        XCTAssertFalse(pixie.accepted, "The pixie should refuse an unclosed sentence however lovely")
    }

    func testAColdCorrectReportPassesTheOneAndFailsTheOther() {
        let report = "The door was green."

        let pixie = FaeLaw.judge(report: report, kind: .punctuationPixie, terms: terms)
        let salamander = FaeLaw.judge(report: report, kind: .sentenceSalamander, terms: terms)

        XCTAssertTrue(pixie.accepted, "It closes; the pixie has no further business")
        XCTAssertFalse(salamander.wholehearted, "Nothing in it is hot")
    }

    /// The classic fae move: technically correct, spiritually wrong.
    func testALawCanBeMetInLetterAndNotInSpirit() {
        let report = "The door was green."
        let verdict = FaeLaw.judge(report: report, kind: .punctuationPixie, terms: terms)
        XCTAssertTrue(verdict.accepted)
        XCTAssertFalse(verdict.wholehearted)
        XCTAssertTrue(verdict.isTechnicallyCorrectButSpirituallyWrong)
    }

    func testTheElfRefusesABetterSubstitute() {
        // Richer, more observant, and not the thing that was named.
        let generous = "I brought you the smell of the rain on the step instead, which was better."
        let asked = "Bring me the colour of the door you passed."

        let elf = FaeLaw.judge(report: generous, kind: .literaryElf, terms: asked)
        XCTAssertFalse(elf.accepted, "Substitution is the insult, however generous")

        let exact = "The colour of the door was green."
        XCTAssertTrue(FaeLaw.judge(report: exact, kind: .literaryElf, terms: asked).accepted)
    }

    func testTheSpriteRefusesGrandeurThatOthersWouldAccept() {
        let grand = "It made me think about everything in my whole life and how the world keeps turning."
        let sprite = FaeLaw.judge(report: grand, kind: .bookSprite, terms: terms)
        XCTAssertFalse(sprite.accepted, "Grandeur reads to a sprite as somebody hiding")

        let small = "There was a chip out of the paint, low down, about the size of a thumb."
        XCTAssertTrue(FaeLaw.judge(report: small, kind: .bookSprite, terms: terms).wholehearted)
    }

    func testTheDwarfWantsProvenanceAndTheGoblinWantsLeverage() {
        let sourced = "At the bus stop on Weller Street, about 7, the paint was still wet."
        let dwarf = FaeLaw.judge(report: sourced, kind: .deepLoreDwarf, terms: terms)
        XCTAssertTrue(dwarf.wholehearted)

        let pretty = "It was the loveliest soft green you ever saw."
        XCTAssertFalse(
            FaeLaw.judge(report: pretty, kind: .deepLoreDwarf, terms: terms).accepted,
            "No place, no hour, no name: the dwarf will not write it down"
        )
        XCTAssertFalse(
            FaeLaw.judge(report: pretty, kind: .goblin, terms: terms).accepted,
            "Beauty is worthless to a goblin"
        )
    }

    /// The strong claim: across a spread of ordinary reports, the six species
    /// must not behave like one species.
    func testTheSixLawsAreNotOneLaw() {
        let reports = [
            "The door was green.",
            "the kettle hissed and the window went white",
            "At the bus stop on Weller Street, about 7, the paint was still wet.",
            "It made me think about everything in my whole life.",
            "Nobody had touched the second gate in weeks; the latch was still down.",
            "green"
        ]

        var disagreements = 0
        for report in reports {
            let verdicts = FaeKind.allCases.map {
                FaeLaw.judge(report: report, kind: $0, terms: terms).accepted
            }
            if Set(verdicts).count > 1 { disagreements += 1 }
        }
        XCTAssertGreaterThanOrEqual(
            disagreements, 4,
            "Only \(disagreements) of \(reports.count) reports split the species: the laws have collapsed into one law"
        )
    }

    // MARK: The dissent is surfaced

    func testWhenTheLawsDisagreeTheReaderIsToldSo() {
        let report = "the kettle hissed and the whole window went white with it"
        let verdict = FaeLaw.verdict(report: report, kind: .sentenceSalamander, terms: terms)
        XCTAssertTrue(verdict.accepted)
        XCTAssertNotNil(verdict.dissent, "Another species disagreed and nobody said anything")
        XCTAssertTrue(
            FaeKind.allCases.contains { verdict.dissent?.contains($0.name) == true },
            "The dissent should name who is objecting: \(verdict.dissent ?? "nil")"
        )
    }

    func testARefusalCarriesTheObjectionOfWhoeverWouldHaveAccepted() {
        let report = "the kettle hissed and the whole window went white with it"
        let verdict = FaeLaw.verdict(report: report, kind: .punctuationPixie, terms: terms)
        XCTAssertFalse(verdict.accepted)
        XCTAssertNotNil(verdict.dissent)
        XCTAssertTrue(
            verdict.dissent?.contains("nonsense") == true || verdict.dissent?.contains("without a second look") == true,
            "A refusal everybody agreed with is not a law, it is a rule: \(verdict.dissent ?? "nil")"
        )
    }

    // MARK: Voice and shape

    func testEverySpeciesStatesWhatItIsActuallyMeasuring() {
        for kind in FaeKind.allCases {
            let creed = FaeLaw.creed(for: kind)
            XCTAssertFalse(creed.isEmpty, "\(kind) measures nothing")
            let lowered = creed.lowercased()
            XCTAssertFalse(lowered.contains("polite"), "\(kind) is measuring politeness, which is a human currency")
            XCTAssertFalse(lowered.contains("effort"), "\(kind) is measuring effort")
            XCTAssertFalse(lowered.contains("sincer"), "\(kind) is measuring sincerity")
        }
    }

    func testNoVerdictScoldsTheReader() {
        let reports = ["", "green", "The door was green.", "everything all the time"]
        for report in reports {
            for kind in FaeKind.allCases {
                let verdict = FaeLaw.judge(report: report, kind: kind, terms: terms)
                let lowered = verdict.response.lowercased()
                XCTAssertFalse(lowered.contains("you should have"), "\(kind) scolded: \(verdict.response)")
                XCTAssertFalse(lowered.contains("try harder"), "\(kind) scolded: \(verdict.response)")
                XCTAssertFalse(lowered.contains("disappoint"), "\(kind) was disappointed: \(verdict.response)")
                XCTAssertFalse(verdict.response.isEmpty)
            }
        }
    }

    /// A creature that refuses must still be characterful about it: the
    /// refusal is the fae being itself, not the app withholding.
    func testARefusalExplainsTheLawRatherThanTheFailure() {
        let unclosed = "the door was green"
        let pixie = FaeLaw.judge(report: unclosed, kind: .punctuationPixie, terms: terms)
        XCTAssertFalse(pixie.accepted)
        XCTAssertTrue(
            pixie.response.contains("full stop") || pixie.response.contains("door left open"),
            "The pixie should say what its law is: \(pixie.response)"
        )
        XCTAssertTrue(
            pixie.response.contains("not being difficult") || pixie.response.contains("will wait"),
            "A refusal should read as alien logic, not as punishment"
        )
    }

    func testAnEmptyReportIsNeverWholehearted() {
        for kind in FaeKind.allCases {
            XCTAssertFalse(
                FaeLaw.judge(report: "", kind: kind, terms: terms).wholehearted,
                "\(kind) was moved by nothing at all"
            )
        }
    }
}
