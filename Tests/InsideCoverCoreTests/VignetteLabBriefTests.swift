import XCTest
@testable import InsideCoverCore

/// The Mac lab's feed for Story vignettes. Builds real Story Page surfaces the
/// way the desk does (four recipe variants per two-hour slot) across a spread
/// of days, with and without kept Pages, and writes one surface per recipe so
/// `scripts/vignette_lab/lab.py` can send Gemma what the phone would. Rows
/// with a vignette plan carry the exact device brief (`system`, `brief`).
///
///     VIGNETTE_SURFACES_OUT=/tmp/v.json swift test --filter testWriteTheVignetteSurfacesWhenAsked
final class VignetteLabBriefTests: XCTestCase {

    func testWriteTheVignetteSurfacesWhenAsked() throws {
        guard let out = ProcessInfo.processInfo.environment["VIGNETTE_SURFACES_OUT"] else {
            throw XCTSkip("set VIGNETTE_SURFACES_OUT to write the lab surfaces")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!
        let kept: [(String, BookPageType, String)] = [
            ("The kettle clicked off and nobody came for it, so I drank the water cold.", .diary, ""),
            ("The rain made the parking lot look like a page under glass.", .souvenir, "souvenir"),
            ("Mara didn't text back. I kept checking the stairwell for the sound of her keys.", .diary, ""),
            ("Found a red mitten on the bus seat and put it on the railing so its owner would see.", .diary, ""),
            ("I want to stop saying yes to things I don't want to do.", .diary, ""),
        ]
        var byRecipe: [String: [String: Any]] = [:]
        for offset in 0..<40 {
            let now = calendar.date(byAdding: .hour, value: offset * 7, to: start)!
            let dayDate = calendar.startOfDay(for: now)
            let pages: [BookPage] = offset % 3 == 0 ? [] : kept.enumerated().compactMap { index, item in
                guard (index + offset) % 2 == 0 else { return nil }
                return BookPage(
                    id: "lab-\(offset)-\(index)",
                    type: item.1,
                    createdAt: now.addingTimeInterval(-Double(index + 1) * 3_600),
                    promptText: "Keep what mattered.",
                    userInput: item.0,
                    tags: item.2.isEmpty ? [] : [item.2],
                    origin: .userAuthored
                )
            }
            let day = BookDay(id: BookDay.id(for: dayDate), date: dayDate, pages: pages)
            for variant in 0..<4 {
                let surface = NarrativeOSPageSourceAdapter.draftCandidate(
                    for: day, inputs: .empty, now: now, recipeVariantIndex: variant
                )
                let metadata = surface.payload.metadata
                guard let recipeID = metadata["storyRecipeID"], !recipeID.isEmpty,
                      byRecipe[recipeID] == nil else { continue }
                var row: [String: Any] = [
                    "name": recipeID,
                    "surfaceType": surface.type.rawValue,
                    "headline": surface.payload.headline,
                    "metadata": metadata,
                ]
                if let plan = VignettePlan.decode(metadata: metadata[VignettePlan.metadataKey]) {
                    row["system"] = VignetteBrief.system
                    row["brief"] = VignetteBrief.prompt(for: plan)
                    row["happenings"] = plan.happenings
                    row["cast"] = [plan.lead.name, plan.companion?.name].compactMap { $0 }
                }
                byRecipe[recipeID] = row
            }
        }
        let rows = byRecipe.keys.sorted().compactMap { byRecipe[$0] }
        XCTAssertFalse(rows.isEmpty)
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: out))
        print("wrote \(rows.count) vignette surfaces to \(out)")
    }
}
