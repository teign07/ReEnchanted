import XCTest
@testable import InsideCoverCore

final class IlluminationPaperVariationTests: XCTestCase {
    private func draft(seed: Int, analysis: PhotoAnalysis = .academyFallback,
                       purpose: IlluminatedPhotoPurpose = .photograph) -> IlluminatedPhotoDraft {
        IlluminatedPageComposer.compose(analysis: analysis, sourceAssetName: "IlluminatedPhotoSource",
            seed: seed, purpose: purpose)
    }

    func testPhotosHaveTwoOrThreeAnnotationsAndAtMostOnePaperScrap() {
        for seed in 0..<100 {
            let plan = draft(seed: seed).compositionPlan
            XCTAssertTrue((2...3).contains(plan.textSlots.count), "seed \(seed)")
            XCTAssertLessThanOrEqual(plan.textSlots.filter { $0.annotationStyle == .tornPaper }.count, 1)
            XCTAssertTrue(plan.textSlots.allSatisfy { !$0.body.isEmpty && $0.annotationStyle != nil })
            XCTAssertTrue((2...4).contains(plan.decorations.count), "seed \(seed)")
            XCTAssertEqual(Set(plan.decorations.map(\.assetName)).count, plan.decorations.count)
            XCTAssertTrue(plan.decorations.allSatisfy { $0.opacity >= 0.8 })
        }
    }

    func testTextAndArtShareRotatedCollisionBoundsAcrossManySeeds() {
        for seed in 0..<160 {
            let plan = draft(seed: seed * 1_337).compositionPlan
            assertClearLayout(plan)
            let photo = IlluminatedPhotoLayout.footprint(position: plan.photoFrame.position,
                size: plan.photoFrame.size, rotation: plan.photoFrame.rotationDegrees, padding: 22)
            for note in plan.textSlots {
                let bounds = IlluminatedPhotoLayout.footprint(position: note.position,
                    size: note.size, rotation: note.rotationDegrees)
                XCTAssertEqual(IlluminatedPhotoLayout.intersectionArea(bounds, photo), 0,
                    "Ink needs paper to read on, seed \(seed)")
            }
            if let subject = plan.marginaliaExclusionRect {
                let protected = CodableRect(x: subject.x - 40, y: subject.y - 40,
                    width: subject.width + 80, height: subject.height + 80)
                for art in plan.decorations {
                    let bounds = IlluminatedPhotoLayout.footprint(position: art.position,
                        size: art.size, rotation: art.rotationDegrees)
                    XCTAssertEqual(IlluminatedPhotoLayout.intersectionArea(bounds, protected), 0)
                }
            }
        }
    }

    func testDetectedSubjectAtAnEdgeStillHasClearSurroundings() {
        var analysis = PhotoAnalysis.academyFallback
        analysis.subjectRegion = VisualRegion(x: 0, y: 0.1, width: 0.6, height: 0.8)
        for seed in 0..<30 {
            let plan = IlluminatedPageComposer.compose(analysis: analysis, sourceAssetName: "Photo",
                seed: seed, sourceImageSize: CodableSize(width: 1800, height: 900)).compositionPlan
            assertClearLayout(plan)
            XCTAssertGreaterThanOrEqual(plan.decorations.count, 2)
        }
    }

    func testCompositionAndWordsStayStableWhenRevisited() {
        let first = draft(seed: 9_102).compositionPlan
        let second = draft(seed: 9_102).compositionPlan
        XCTAssertEqual(first.photoFrame, second.photoFrame)
        XCTAssertEqual(first.textSlots.map(\.body), second.textSlots.map(\.body))
        XCTAssertEqual(first.textSlots.map(\.position), second.textSlots.map(\.position))
        XCTAssertEqual(first.textSlots.map(\.annotationStyle), second.textSlots.map(\.annotationStyle))
        XCTAssertEqual(first.textSlots.map(\.paperAssetName), second.textSlots.map(\.paperAssetName))
        XCTAssertEqual(first.decorations.map(\.assetName), second.decorations.map(\.assetName))
        XCTAssertEqual(first.decorations.map(\.position), second.decorations.map(\.position))
    }

    func testFallbackHasManyOpeningsClosingsAndLabels() {
        let words = (0..<160).map { IlluminatedPhotoFallbackWords.marginalia(seed: $0 * 101) }
        XCTAssertGreaterThanOrEqual(Set(words.map(\.fieldNote)).count, 15)
        XCTAssertGreaterThanOrEqual(Set(words.map(\.closingLine)).count, 15)
        XCTAssertGreaterThanOrEqual(Set(words.map(\.stampLabel)).count, 7)
        XCTAssertTrue(words.allSatisfy { Set($0.observationList).count == 3 })
        XCTAssertNotEqual(draft(seed: 101).compositionPlan.textSlots.map(\.body),
                          draft(seed: 9_901).compositionPlan.textSlots.map(\.body))
    }

    func testObservedWritingIsNotReplacedByFallbackWords() {
        var analysis = PhotoAnalysis.academyFallback
        analysis.usesFallbackMarginalia = nil
        analysis.marginalia.fieldNote = "The red kettle has lost its lid."
        analysis.marginalia.closingLine = "The handle caught the window light."
        for seed in 0..<20 {
            let result = draft(seed: seed, analysis: analysis)
            XCTAssertEqual(result.analysis.marginalia, analysis.marginalia)
            XCTAssertEqual(result.compositionPlan.textSlots.first?.body, analysis.marginalia.fieldNote)
        }
    }

    func testEnchantmentResultGetsOneSpaceWithoutDuplicatingItAsObservations() {
        var analysis = PhotoAnalysis.academyFallback
        // Even a fallback marker cannot replace a completed spell's words.
        analysis.marginalia.fieldNote = "The kettle cleared its throat."
        analysis.marginalia.closingLine = String(repeating: "I am keeping the water warm. ", count: 30)
        analysis.marginalia.observationList = [analysis.marginalia.closingLine]
        for seed in 0..<30 {
            let result = draft(seed: seed, analysis: analysis, purpose: .enchantment)
            let plan = result.compositionPlan
            XCTAssertEqual(plan.textSlots.count, 2)
            XCTAssertEqual(plan.textSlots.filter { $0.body == analysis.marginalia.closingLine }.count, 1)
            XCTAssertFalse(plan.textSlots.contains { $0.slotId == "observation-list" })
            XCTAssertEqual(result.analysis.marginalia, analysis.marginalia)
            assertClearLayout(plan)
        }
    }

    func testShortVerseLinesAlsoReserveEnoughResultSpace() {
        var analysis = PhotoAnalysis.academyFallback
        analysis.marginalia.closingLine = (0..<12).map { "Line \($0) stays." }.joined(separator: "\n")
        let plan = draft(seed: 7, analysis: analysis, purpose: .enchantment).compositionPlan
        let result = plan.textSlots.first { $0.slotId == "closing-line" }
        XCTAssertEqual(result?.body, analysis.marginalia.closingLine)
        XCTAssertGreaterThanOrEqual(result?.size.height ?? 0, 12 * 42)
        assertClearLayout(plan)
    }

    func testLegacyPlansStillDecodeWithoutLayoutOrAnnotationStyle() throws {
        let data = try JSONEncoder().encode(draft(seed: 7).compositionPlan)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "layoutVersion")
        var slots = try XCTUnwrap(object["textSlots"] as? [[String: Any]])
        for index in slots.indices { slots[index].removeValue(forKey: "annotationStyle") }
        object["textSlots"] = slots
        let legacy = try JSONDecoder().decode(IlluminatedCompositionPlan.self,
            from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.layoutVersion)
        XCTAssertTrue(legacy.textSlots.allSatisfy { $0.annotationStyle == nil })
    }

    private func assertClearLayout(_ plan: IlluminatedCompositionPlan,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let bounds = plan.textSlots.map {
            IlluminatedPhotoLayout.footprint(position: $0.position, size: $0.size, rotation: $0.rotationDegrees)
        } + plan.decorations.map {
            IlluminatedPhotoLayout.footprint(position: $0.position, size: $0.size, rotation: $0.rotationDegrees)
        }
        for (index, box) in bounds.enumerated() {
            XCTAssertGreaterThanOrEqual(box.x, 28, file: file, line: line)
            XCTAssertGreaterThanOrEqual(box.y, 28, file: file, line: line)
            XCTAssertLessThanOrEqual(box.x + box.width, plan.canvasSize.width - 28, file: file, line: line)
            XCTAssertLessThanOrEqual(box.y + box.height, plan.canvasSize.height - 56, file: file, line: line)
            for other in bounds.dropFirst(index + 1) {
                XCTAssertEqual(IlluminatedPhotoLayout.intersectionArea(box, other), 0,
                    "seed \(plan.randomSeed)", file: file, line: line)
            }
        }
    }
}
