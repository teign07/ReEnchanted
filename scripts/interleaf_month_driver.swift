// Fixture runner for audit_interleaf_month.py. Production declarations are
// extracted verbatim except the documented UI/defaults/clock adapter.
let output = URL(fileURLWithPath: CommandLine.arguments[2])
var auditCalendar = Calendar(identifier: .gregorian)
auditCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let topics = ["A frog in the pond.", "Moonlight on the path.", "A fox at the door.", "A quill and ink bottle.",
              "A library full of secrets.", "A walk with a map.", "A blue thread and a warning.",
              "Laughter in the margins.", "A camera and a photograph.", "A scroll with a wax seal.",
              "A dream at dusk.", "A question mark and a goblin."]
let types: [BookPageType] = [.souvenir, .todaysSky, .lore, .diary, .academyClass, .location,
                            .bookNotices, .narrativeOS, .illuminatedPhoto, .letter, .rest, .quip,
                            .bookFae, .wickerDare, .gamePage, .enchantment, .theBleed, .packPage]

struct Encounter: Codable {
    var scenario: String; var day: Int; var opening: Int; var boundary: Int; var scheduled: String; var actual: String
    var selectedID: String?; var text: String?; var marginalia: [String]; var snippet: String?
    var density: String; var paper: String; var placement: String; var primaryScale: Double
    var quoteUsesOwnSubjects: Bool?; var photoLayout: String?; var photoNotes: [String]?; var photoTemplate: String?
    var discoveryCandidate: String?; var drawingCaptionMatch: Bool?
}
struct Scenario: Codable {
    var name: String; var encounters: Int; var kinds: [String: Int]; var scheduled: [String: Int]
    var uniqueIllustrations: Int; var illustrationRevisits: Int; var uniqueTexts: Int; var textRepeats: Int
    var uniquePlaces: Int; var placeRevisits: Int; var uniquePhotos: Int; var photoRevisits: Int
    var uniqueMarginalia: Int; var uniquePrimaryMarginalia: Int; var uniqueSnippets: Int
    var primaryCounts: [String: Int]; var snippetCounts: [String: Int]; var densities: [String: Int]
    var placements: [String: Int]; var papers: [String: Int]; var maxSamePrimaryRun: Int; var maxSameSnippetRun: Int
    var photoLayouts: [String: Int]; var fallbackCounts: [String: Int]; var invariantFailures: [String]
}
func increment(_ key: String, _ counter: inout [String: Int]) { counter[key, default: 0] += 1 }
func maxRun(_ values: [String?]) -> Int {
    var maxSeen = 0, current = 0; var last: String?
    for value in values {
        if let value { current = value == last ? current + 1 : 1; maxSeen = max(maxSeen, current); last = value }
        else { current = 0; last = nil }
    }
    return maxSeen
}
func scale(_ seed: Int, _ salt: Int) -> Double {
    // The generator injects this method's actual numeric kernel from the
    // marginalia view; this is not a second implementation of the arithmetic.
    auditMarginaliaScale(seed: seed, salt: salt)
}
func photoAnalysis(_ topic: String, index: Int) -> PhotoAnalysis {
    .init(scene: "A photograph from your library, returned between Pages.", motifs: LeafDecorationLibrary.semanticMotifs(in: topic),
          mood: "fixture", suggestedTemplate: IlluminatedTemplateID.allCases[index % IlluminatedTemplateID.allCases.count],
          marginalia: .init(fieldNote: "fixture", stampLabel: "fixture", observationList: [], closingLine: "fixture"),
          souvenirCandidates: [], usesFallbackMarginalia: true)
}
var all: [Encounter] = [], summaries: [Scenario] = []
let configurations: [(name: String, texts: Int, maps: Int, photos: Int)] = [
    ("well-stocked", 240, 16, 90), ("limited-material", 8, 2, 3), ("no-personal-material", 0, 0, 0),
    ("guest-pack-fixture", 240, 16, 90)
]
let start = Date(timeIntervalSince1970: 1_793_491_200)
let illustrations = InterleafIllustrationLibrary.available

// Writing tips share the live text rotation, attribution, and rest period;
// their handwritten reminders share the ordinary marginalia catalogue.
let writingTips = InterleafWritingCraft.texts
precondition(writingTips.count == 21 && Set(writingTips.map(\.id)).count == 21)
precondition(writingTips.allSatisfy {
    $0.kind == .writingTip && $0.attribution == "THE BOOK, ON WRITING"
        && $0.sources.isEmpty && $0.sourcePageIDs.isEmpty
})
precondition(InterleafWritingCraft.lessons.allSatisfy {
    !$0.title.isEmpty && !$0.explanation.isEmpty && !$0.why.isEmpty
        && !$0.example.isEmpty && !$0.text.contains("\n1. ")
        && $0.text.hasPrefix("Sentence writing tip: ")
        && $0.text.split(whereSeparator: \.isWhitespace).count <= 50
})
precondition(InterleafWritingCraft.marginalia.allSatisfy { $0.text.hasPrefix("Writing tip:\n") })
let reminderIDs = Set(InterleafWritingCraft.marginalia.map { "\($0.packID)|\($0.id)" })
precondition(reminderIDs.count == 21)
precondition(reminderIDs.isSubset(of: Set(IlluminationMarginaliaLibrary.availableSnippets.map { "\($0.packID)|\($0.id)" })))
let mixedWritingPool = InterleafCuration.rotationTexts([
    .init(id: "writing-probe-reader", text: "I found a little stone.", kind: .reader),
    .init(id: "writing-probe-noticing", text: "Three walks by the river.", kind: .noticing)
], grimoireResidue: "The Book kept this scrap.")
precondition(Set(mixedWritingPool.map(\.kind)) == Set(InterleafCuration.Text.Kind.allCases))
var writingProbeUsed = Set<String>()
for seed in mixedWritingPool.indices {
    let chosen = InterleafCuration.text(from: mixedWritingPool, recentlySeen: [:], excluding: writingProbeUsed, now: start, seed: seed)!
    precondition(InterleafCuration.text(from: mixedWritingPool.reversed(), recentlySeen: [:], excluding: writingProbeUsed, now: start, seed: seed) == chosen)
    writingProbeUsed.formUnion(chosen.historyKeys)
}
precondition(InterleafCuration.text(from: mixedWritingPool, recentlySeen: [:], excluding: writingProbeUsed, now: start, seed: 0) == nil)
let writingHistory = Dictionary(uniqueKeysWithValues: writingTips.flatMap { tip in tip.historyKeys.map { ($0, start) } })
precondition(InterleafCuration.text(from: writingTips, recentlySeen: writingHistory, excluding: [], now: start.addingTimeInterval(29 * 86_400), seed: 0) == nil)
precondition(InterleafCuration.text(from: writingTips, recentlySeen: writingHistory, excluding: [], now: start.addingTimeInterval(30 * 86_400), seed: 0) != nil)
for seed in 0..<200 {
    precondition(IlluminationMarginaliaLibrary.select(motifs: ["writing-tip"], seed: seed, count: 1).first?.id.hasPrefix("writing-tip:") == true)
}
print("Writing probes passed: 21 lessons/reminders; mixed pool; Book attribution; deterministic selection; shared 30-day text rest.")

// Tarot stays an occasional illustration even though its cabinet is larger
// than the permanent scene cabinet. These execute the production selector.
let tarotPlates = TarotDeck.interleafIllustrations
precondition(tarotPlates.count == 78 && Set(tarotPlates.map(\.assetName)).count == 78)
precondition(tarotPlates.allSatisfy { $0.isTarotCard && !$0.tags.isEmpty })
let ordinaryProbe = InterleafIllustration(id: "probe-scene", assetName: "scene", title: "A scene", tags: ["book"])
let plateProbe = tarotPlates + [ordinaryProbe]
var relatedTarotCount = 0, unrelatedTarotCount = 0
for seed in 0..<10_000 {
    let related = InterleafIllustrationLibrary.select(from: plateProbe,
        context: .init(semanticTags: ["moon"], month: nil, year: nil, activeWorldEventIDs: [], worldEventPhases: []), seed: seed)
    let unrelated = InterleafIllustrationLibrary.select(from: plateProbe,
        context: .init(semanticTags: ["book", "margin", "unrelated-subject"], month: nil, year: nil, activeWorldEventIDs: [], worldEventPhases: []), seed: seed)
    if let related, related.isTarotCard {
        relatedTarotCount += 1
        precondition(related.tags.contains("moon"), "A related Tarot offer lost its literal subject")
    }
    if unrelated?.isTarotCard == true { unrelatedTarotCount += 1 }
}
precondition((2_000...3_000).contains(relatedTarotCount))
precondition((500...900).contains(unrelatedTarotCount))
let recentMoon = tarotPlates.first { $0.assetName == "TarotMajor18Moon" }!
for seed in 0..<1_000 {
    let choice = InterleafIllustrationLibrary.select(from: [recentMoon, ordinaryProbe],
        context: .init(semanticTags: ["moon"], month: nil, year: nil, activeWorldEventIDs: [], worldEventPhases: []),
        seed: seed, recentlySeen: [recentMoon.assetName: start.addingTimeInterval(-86_400)], now: start)
    precondition(choice?.isTarotCard == false, "A recent related card ignored its seven-day rest")
}
let words = TarotDeck.interleafSubjectTags(in: "A NEW START, rain, and a family at home. Not rainbow or homework.")
precondition(words.contains("new-start") && words.contains("rain") && words.contains("family") && words.contains("home"))
let substrings = TarotDeck.interleafSubjectTags(in: "rainbow homework noteworthy")
precondition(!substrings.contains("rain") && !substrings.contains("home") && !substrings.contains("work"))
if TarotDeck.version == "unwritten-v2" {
    for card in TarotDeck.all {
        guard let margin = TarotDeck.marginalia(for: card.id) else {
            preconditionFailure("Missing authored card marginalia: \(card.id)")
        }
        precondition(!margin.label.isEmpty && !margin.note.isEmpty)
        precondition(margin.note.split(separator: " ").count <= 12)
        precondition(TarotDeck.illustrationContext(for: card.id)?.contains(margin.note) == true)
    }
    let bookcraft = TarotDeck.interleafSubjectTags(in: "Pens, paper knives, book clasps, and book leaves.")
    precondition(Set(["pen", "paper-knife", "book-clasp", "book-leaf"]).isSubset(of: Set(bookcraft)))
    precondition(!TarotDeck.interleafSubjectTags(in: "Open the window.").contains("pen"))
    precondition(TarotDeck.marginalia(for: "missing-card") == nil)
    print("ReEnchanted revision probes passed: 78 authored labels/notes; Cast context; literal bookcraft plurals.")
}
print("Tarot probes passed: 78 identities; literal subjects; related/unrelated offers \(relatedTarotCount)/\(unrelatedTarotCount) per10,000 illustration slots.")

// Exercise the actual store with its writer deliberately held: reopening must
// see pending encounters, and seeing a leaf must leave its binding key intact.
let probeText = InterleafCuration.Text(id: "pending-probe", text: "The pond has swallowed another moon.", kind: .reader)
func cacheKey(_ store: FolioInterleafEncounterStore, texts: [InterleafCuration.Text] = [probeText]) -> FolioDeskCacheKey {
    FolioDeskCacheKey(surfaces: [.init(id: "probe")], interleafTexts: texts, grimoireResidue: nil,
        interleafEncounters: store, placeLeaves: [], metrics: .init(), illustrationSignature: Data(), controlPageCounts: [:])
}
FolioInterleafEncounterStore.auditSuspendPersistence()
let pendingStore = FolioInterleafEncounterStore()
let beforeExposure = cacheKey(pendingStore)
precondition(pendingStore.recordVisible(probeText))
pendingStore.recordVisual("illustration:pending-probe")
precondition(cacheKey(pendingStore) == beforeExposure, "Exposure invalidated the binding cache")
precondition(cacheKey(pendingStore, texts: []) != beforeExposure, "Changed source ink failed to invalidate the binding cache")
let immediateReopening = FolioInterleafEncounterStore()
precondition(immediateReopening.history == pendingStore.history && immediateReopening.visualHistory == pendingStore.visualHistory,
    "Reopening lost pending history")
precondition(cacheKey(immediateReopening) != beforeExposure, "A fresh opening reused an old binding key")
precondition(auditDefaults.values.isEmpty, "The deliberately suspended writer did not stay suspended")
// A newer snapshot must win when multiple writes to the same key are queued.
pendingStore.recordVisual("place:pending-probe")
FolioInterleafEncounterStore.auditResumePersistence()
FolioInterleafEncounterStore.auditDrainPersistenceAndForgetMemory()
let diskReopening = FolioInterleafEncounterStore()
precondition(diskReopening.history == pendingStore.history && diskReopening.visualHistory == pendingStore.visualHistory,
    "Encoded reload lost or reordered pending history")
print("Persistence/cache probes passed: off-main writes; immediate and encoded reopen; ordered snapshots; stable exposure key; fresh source/opening keys.")

let multiPage = BookPage(id: "multi", createdAt: auditNow,
    userInput: "I found the little stone. The gull followed me home! We left the window open.")
let multi = InterleafCuration.texts(days: [.init(id: "day", date: auditNow, pages: [multiPage])], noticings: [])
precondition(multi.map(\.text) == ["I found the little stone.", "The gull followed me home!", "We left the window open."])
precondition(multi.allSatisfy { $0.sourcePageIDs == ["multi"] && $0.sources.first?.pageID == "multi" })
precondition(Set(multi.map(\.id)).count == 3 && multi.first?.id == "reader:multi")
precondition(InterleafCuration.texts(days: [], noticings: []).isEmpty)
precondition((0..<1_000).compactMap { InterleafCuration.discovery(seed: $0) }.count > 30)
let baselineProbe = LeafDecorationLibrary.recipe(pageType: .souvenir, metadata: [:], semanticText: "A frog at the pond.",
    documentID: "memory-probe", leafIndex: 0, decorationPlate: true, densityOverride: .rich)
let unshown = FolioInterleafEncounterStore()
_ = unshown.chooseDecoration(for: "prepared", baseline: baselineProbe) { assets, notes in
    precondition(!assets.contains("probe-art") && !notes.contains("fixture|probe-note"), "An unseen mark was recorded")
    return baselineProbe
}
unshown.recordMarginalia(["margin-asset:probe-art", "margin-note:fixture|probe-note"])
let afterViewing = FolioInterleafEncounterStore()
_ = afterViewing.chooseDecoration(for: "fresh", baseline: baselineProbe) { assets, notes in
    precondition(assets.contains("probe-art") && notes.contains("fixture|probe-note"), "Visible marginalia was not remembered")
    return baselineProbe
}
auditNow = auditNow.addingTimeInterval(8 * 86_400)
let afterRest = FolioInterleafEncounterStore()
_ = afterRest.chooseDecoration(for: "rested", baseline: baselineProbe) { assets, notes in
    precondition(!assets.contains("probe-art") && !notes.contains("fixture|probe-note"), "Marginalia never rested")
    return baselineProbe
}
auditNow = start
let breathed = InterleafCuration.curatedDecoration(baseline: baselineProbe, pageType: .souvenir, metadata: [:],
    semanticText: "A frog at the pond.", documentID: "memory-probe", previous: nil, recentAssets: [], recentNotes: [], neighborIsCrowded: true)
precondition(breathed.density == .ordinary, "A crowded neighbor left no breathing room")
let authored = InterleafCuration.curatedDecoration(baseline: baselineProbe, pageType: .souvenir, metadata: ["leafMarginaliaDensity": "rich"],
    semanticText: "A frog at the pond.", documentID: "memory-probe", previous: nil, recentAssets: [], recentNotes: [], neighborIsCrowded: true)
precondition(authored.density == .rich, "An authored density was overridden")
let exhaustedCabinet = Set(CoreMarginsPack.pack.allAssets.map(\.assetName))
for seed in 0..<50 {
    let recipe = LeafDecorationLibrary.recipe(pageType: .souvenir, metadata: [:], semanticText: "A frog at the pond.",
        documentID: "exhausted-\(seed)", leafIndex: 0, decorationPlate: true,
        excludingAssetNames: exhaustedCabinet, densityOverride: .overdone)
    let names = ([recipe.primaryAsset, recipe.secondaryAsset].compactMap { $0 } + recipe.companionAssets).map(\.assetName)
    precondition(Set(names).count == names.count, "A depleted cabinet duplicated a mark on one leaf")
    precondition(names.count >= 3, "A depleted cabinet became unnecessarily empty")
}
print("Sentence/provenance and rare discovery probes passed.")

for config in configurations {
    FolioInterleafEncounterStore.auditDrainPersistenceAndForgetMemory()
    auditDefaults.values = [:]
    auditMonthlyPackEnabled = config.name == "guest-pack-fixture"
    var photoHistory: [String: Date] = [:]
    var lastText: [String: Date] = [:]
    var lastMap: [String: Date] = [:]
    var rows: [Encounter] = [], failures: [String] = [], fallbackCounts: [String: Int] = [:]
    var photoLayouts: [String: Int] = [:]
    let places = (0..<config.maps).map { i in
        GazetteerLeaf(anchorID: "place-\(i)", title: "Fixture place \(i)", line: "\(i + 3) things kept here.",
            plate: .init(id: "map-\(i)", latitude: 44 + Double(i)/100, longitude: -69, latitudeSpan: 0.006,
                longitudeSpan: 0.006, marks: [], showsLabels: false, isLoosened: true))
    }
    let savedTexts = (0..<config.texts).map { i in
        InterleafCuration.Text(id: "fixture-\(i)", text: "\(topics[i % topics.count]) Fixture keep \(i).",
            kind: i % 4 == 0 ? .noticing : .reader)
    }
    let texts = InterleafCuration.rotationTexts(savedTexts, grimoireResidue: nil)
    var photos: [PhotoCandidate] = []
    for i in 0..<config.photos {
        let captured = start.addingTimeInterval(Double(i) * -9_000.0)
        let photo = PhotoCandidate(id: UUID(), assetLocalIdentifier: "photo-\(i)", creationDate: captured,
            pixelWidth: 1600, pixelHeight: 1200, isFavorite: i % 5 == 0,
            score: Double(i % 7), reasons: [], discoveredAt: start)
        photos.append(photo)
    }
    for day in 0..<31 { for opening in 0..<2 {
        auditNow = start.addingTimeInterval(Double(day) * 86_400 + Double(opening) * 14_400)
        FolioInterleafEncounterStore.auditDrainPersistenceAndForgetMemory()
        let store = FolioInterleafEncounterStore() // reload the encoded history at every opening
        var usedArt = Set<String>(), usedMaps = Set<String>(), usedInk = Set<String>(), usedPhotos = Set<String>()
        var previousDecoration: LeafDecorationRecipe?
        var reservedDecorations: [LeafDecorationRecipe] = []
        var visibleMarginalia: [String] = []
        let mixSeed = "\(config.name)|day-\(day)|opening-\(opening)".stableHash
        for boundary in 0..<10 {
            let id = "\(config.name)|\(day)|\(opening)|between-\(boundary)"
            let seed = "\(id)|\(boundary)|interstitial-v1".stableHash
            let slot = InterleafCuration.slot(at: boundary, seed: mixSeed)
            let other = InterleafCuration.otherIndex(at: boundary, seed: mixSeed) % 5
            let scheduled = slot == .photo ? "photo" : slot == .illustration ? "illustration" : (other == 0 || other == 2) ? "text" : other == 1 ? "map" : "marginalia"
            let topic = topics[(day + opening + boundary) % topics.count]
            let type = types[(day + opening + boundary) % types.count]
            let dateParts = auditCalendar.dateComponents([.year, .month], from: auditNow)
            let metadata = ["decorationMonth": String(dateParts.month!), "decorationYear": String(dateParts.year!),
                "decorationWorldEventIDs": auditMonthlyPackEnabled ? "the-guest" : "",
                "decorationWorldEventPhases": ["SETUP", "BUILDUP", "CLIMAX", "AFTERMATH"][min(3, day / 8)]]
            let context = LeafDecorationLibrary.resolvedPlacementContext(
                motifs: LeafDecorationLibrary.resolvedMotifs(pageType: type, metadata: metadata, semanticText: topic), metadata: metadata)
            var actual = "marginalia", selected: String?, ink: String?, quote: InterleafCuration.Text?
            var photoPlan: IlluminatedCompositionPlan?
            switch scheduled {
            case "illustration":
                if let name = store.chooseIllustration(for: id, from: illustrations, context: context, excluding: usedArt, seed: seed &+ 7_919) {
                    selected = name; actual = "illustration"; usedArt.insert(name); store.recordVisual("illustration:\(name)")
                    if store.chooseIllustration(for: id, from: illustrations, context: context, excluding: [], seed: seed &+ 7_919) != name { failures.append("unstable illustration") }
                }
            case "map":
                if let place = store.choosePlace(for: id, from: places, excluding: usedMaps) {
                    if let previous = lastMap[place.anchorID], auditNow.timeIntervalSince(previous) < 7 * 86_400 {
                        failures.append("map repeated inside its rest period")
                    }
                    lastMap[place.anchorID] = auditNow
                    selected = place.anchorID; actual = "map"; usedMaps.insert(place.anchorID); store.recordVisual("place:\(place.anchorID)")
                    if store.choosePlace(for: id, from: places, excluding: [])?.anchorID != place.anchorID { failures.append("unstable map") }
                }
            case "text":
                quote = store.choose(for: id, from: texts, excluding: usedInk, seed: seed)
                if let quote {
                    switch quote.kind {
                    case .reader: actual = "reader-text"
                    case .noticing: actual = "noticing"
                    case .receipt: actual = "receipt"
                    case .writingTip: actual = "writing-tip"
                    }
                    selected = quote.id; ink = quote.text
                    if let previous = lastText[quote.id], auditNow.timeIntervalSince(previous) < InterleafCuration.textRest {
                        failures.append("text repeated inside its rest period")
                    }
                    lastText[quote.id] = auditNow
                    usedInk.formUnion(quote.historyKeys); _ = store.recordVisible(quote)
                    if store.choose(for: id, from: texts, excluding: [], seed: seed) != quote { failures.append("unstable text") }
                }
            case "photo":
                let ranked = InterleafPhotoCuration.ranked(photos, subjectTags: [:], wantedTags: [], relatedIdentifiers: [],
                    recentlySeen: photoHistory, excluding: usedPhotos, captureDatesToAvoid: [], now: auditNow, seed: seed)
                if let chosen = ranked.first {
                    selected = chosen.assetLocalIdentifier; actual = "photo"; usedPhotos.insert(chosen.assetLocalIdentifier)
                    photoHistory[chosen.assetLocalIdentifier] = auditNow
                    let composedSeed = Int(UInt(bitPattern: (seed ^ chosen.assetLocalIdentifier.stableHash).stableScramble) % UInt(Int.max))
                    photoPlan = IlluminatedPageComposer.compose(analysis: photoAnalysis(topic, index: day + opening + boundary), sourceAssetName: "FixturePhoto",
                        seed: composedSeed, assetLocalIdentifier: chosen.assetLocalIdentifier,
                        sourceImageSize: .init(width: boundary % 2 == 0 ? 1600 : 1000, height: boundary % 2 == 0 ? 1000 : 1600)).compositionPlan
                }
            default: break
            }
            if actual == "marginalia", scheduled != "marginalia" { increment(scheduled, &fallbackCounts) }
            let decoration = InterleafCuration.decorationContext(quotation: quote, neighboringText: topic, pageType: type, metadata: metadata, seed: seed)
            let baseline = LeafDecorationLibrary.recipe(pageType: decoration.pageType, metadata: decoration.metadata,
                semanticText: decoration.text, documentID: id, leafIndex: 0, decorationPlate: true)
            var recipe = baseline
            if actual == "marginalia" || actual == "reader-text" || actual == "noticing" {
                recipe = store.chooseDecoration(for: id, baseline: baseline) { recentAssets, recentNotes in
                    InterleafCuration.curatedDecoration(baseline: baseline, pageType: decoration.pageType,
                        metadata: decoration.metadata, semanticText: decoration.text, documentID: id,
                        previous: previousDecoration, recentAssets: recentAssets, recentNotes: recentNotes,
                        reservedAssets: Set(reservedDecorations.flatMap { [$0.primaryAsset?.assetName, $0.secondaryAsset?.assetName].compactMap { $0 } }),
                        reservedNotes: Set(reservedDecorations.compactMap { $0.handwrittenSnippet.map { "\($0.packID)|\($0.id)" } }))
                }
                let held = store.chooseDecoration(for: id, baseline: baseline) { _, _ in fatalError("Held decoration rerolled") }
                if held != recipe { failures.append("unstable decoration") }
                if let previousDecoration,
                   (previousDecoration.density == .rich || previousDecoration.density == .overdone),
                   (recipe.density == .rich || recipe.density == .overdone) {
                    failures.append("consecutive crowded interleaves")
                }
                // This fixture treats proposed marks as placed. Native collision
                // fitting and visibility callbacks need separate device proof.
                let assets = ([recipe.primaryAsset, recipe.secondaryAsset].compactMap { $0 } + recipe.companionAssets)
                    .map { "margin-asset:\($0.assetName)" }
                let notes = recipe.handwrittenSnippet.map { ["margin-note:\($0.packID)|\($0.id)"] } ?? []
                visibleMarginalia += assets + notes
                previousDecoration = recipe
                reservedDecorations = Array((reservedDecorations + [recipe]).suffix(3))
            } else {
                previousDecoration = nil
            }
            var marks: [String] = [], snippet: String?, layout: String?
            if actual == "marginalia" || actual == "reader-text" || actual == "noticing" {
                marks = ([recipe.primaryAsset, recipe.secondaryAsset].compactMap { $0 } + recipe.companionAssets).map(\.assetName)
                snippet = recipe.handwrittenSnippet?.text
            }
            if let plan = photoPlan {
                marks = plan.decorations.map(\.assetName)
                layout = "\(plan.textSlots.count)-notes|\(plan.decorations.count)-marks|r\(plan.photoFrame.rotationDegrees)"
                increment(layout!, &photoLayouts)
                let boxes = plan.textSlots.map { IlluminatedPhotoLayout.footprint(position: $0.position, size: $0.size, rotation: $0.rotationDegrees) }
                    + plan.decorations.map { IlluminatedPhotoLayout.footprint(position: $0.position, size: $0.size, rotation: $0.rotationDegrees) }
                for a in boxes.indices { for b in boxes.indices where b > a {
                    if IlluminatedPhotoLayout.intersectionArea(boxes[a], boxes[b]) > 0.001 { failures.append("photo collision") }
                }}
                if Set(plan.decorations.map(\.assetName)).count != plan.decorations.count { failures.append("duplicate photo mark") }
            }
            rows.append(.init(scenario: config.name, day: day + 1, opening: opening + 1, boundary: boundary,
                scheduled: scheduled, actual: actual, selectedID: selected, text: ink, marginalia: marks, snippet: snippet,
                density: recipe.density.rawValue, paper: recipe.paperStock.rawValue, placement: recipe.primaryPlacement.rawValue,
                primaryScale: scale(recipe.seed, 223), quoteUsesOwnSubjects: quote.map { decoration.text == $0.text }, photoLayout: layout,
                photoNotes: photoPlan?.textSlots.map(\.body), photoTemplate: photoPlan.map { $0.templateId.rawValue + "|" + $0.photoTreatment.rawValue },
                discoveryCandidate: actual == "marginalia" ? InterleafCuration.discovery(seed: recipe.seed) : nil,
                drawingCaptionMatch: recipe.primaryAsset.flatMap { primary in recipe.handwrittenSnippet.map { note in
                    let subjects = Set((primary.tags + (primary.leafTraits?.subjectTags ?? [])).map { $0.lowercased() })
                        .subtracting(["book", "margin", "margins", "generic", "illustration", "labyrinth"])
                    return !subjects.isDisjoint(with: Set(note.tags.map { $0.lowercased() }))
                } }))
        }
        // Selection reserves planned marks; only the simulated visible pass
        // updates history. Never count prewarming as an encounter.
        store.recordMarginalia(visibleMarginalia)
    }}
    var kinds: [String: Int] = [:], scheduled: [String: Int] = [:], primaries: [String: Int] = [:], snippets: [String: Int] = [:]
    var densities: [String: Int] = [:], papers: [String: Int] = [:], placements: [String: Int] = [:]
    for row in rows {
        increment(row.actual, &kinds); increment(row.scheduled, &scheduled)
        if let primary = row.marginalia.first { increment(primary, &primaries) }
        if let snippet = row.snippet { increment(snippet, &snippets) }
        if row.actual == "marginalia" || row.actual == "reader-text" || row.actual == "noticing" || row.actual == "writing-tip" {
            increment(row.density, &densities); increment(row.paper, &papers); increment(row.placement, &placements)
        }
    }
    func ids(_ kinds: Set<String>) -> [String] { rows.filter { kinds.contains($0.actual) }.compactMap(\.selectedID) }
    let arts = ids(["illustration"]), textsSeen = ids(["reader-text", "noticing", "writing-tip"]), maps = ids(["map"]), photoIDs = ids(["photo"])
    let textRepeats = textsSeen.count - Set(textsSeen).count
    summaries.append(.init(name: config.name, encounters: rows.count, kinds: kinds, scheduled: scheduled,
        uniqueIllustrations: Set(arts).count, illustrationRevisits: arts.count - Set(arts).count,
        uniqueTexts: Set(textsSeen).count, textRepeats: textRepeats, uniquePlaces: Set(maps).count, placeRevisits: maps.count - Set(maps).count,
        uniquePhotos: Set(photoIDs).count, photoRevisits: photoIDs.count - Set(photoIDs).count,
        uniqueMarginalia: Set(rows.flatMap(\.marginalia)).count, uniquePrimaryMarginalia: primaries.count, uniqueSnippets: snippets.count,
        primaryCounts: primaries, snippetCounts: snippets, densities: densities, placements: placements, papers: papers,
        maxSamePrimaryRun: maxRun(rows.map { $0.marginalia.first }), maxSameSnippetRun: maxRun(rows.map(\.snippet)),
        photoLayouts: photoLayouts, fallbackCounts: fallbackCounts, invariantFailures: Array(Set(failures)).sorted()))
    all += rows
}
FolioInterleafEncounterStore.auditDrainPersistenceAndForgetMemory()
// Targeted probes of the weak point found by the month audit.
auditMonthlyPackEnabled = false
let containerCaptions = (0..<200).compactMap {
    IlluminationMarginaliaLibrary.select(motifs: ["book", "margin", "margins", "illustration"], seed: $0, count: 1).first?.id
}
precondition(Set(containerCaptions).count > 20, "Container tags still starve caption variety")
let letterCaption = IlluminationMarginaliaLibrary.select(motifs: ["book", "margin", "letter"], seed: 7, count: 1).first!
precondition(letterCaption.tags.contains("letter"), "Literal subject matching was lost")
precondition(summaries.allSatisfy { $0.invariantFailures.isEmpty }, "A month invariant failed")
for summary in summaries {
    precondition(summary.encounters == 620)
    precondition(summary.scheduled["photo"] == 124 && summary.scheduled["illustration"] == 186)
    precondition(summary.densities.count == 4 && summary.papers.count == 5 && summary.placements.count == 4)
}


try encoder.encode(all).write(to: output.appendingPathComponent("encounters.json"))
try encoder.encode(summaries).write(to: output.appendingPathComponent("summary.json"))
for summary in summaries {
    print("\(summary.name): \(summary.encounters) encounters; \(summary.uniqueIllustrations) illustrations; \(summary.uniqueMarginalia) marks; \(summary.uniqueSnippets) captions; failures=\(summary.invariantFailures)")
}
