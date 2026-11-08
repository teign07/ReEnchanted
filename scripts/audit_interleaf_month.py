#!/usr/bin/env python3
"""Exercise extracted production interleaf policies with synthetic month fixtures.

Runs a standalone Swift interpreter session, never xcodebuild/swift build/test.
There is no app/Photos/vault access. UIKit layout and gestures are not exercised.
"""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def block(path, anchor, indent=0, after=None):
    source = (ROOT / path).read_text()
    start = source.index(anchor, source.index(after) if after else 0)
    end = re.search(r"(?m)^" + " " * indent + r"}\s*$", source[start:])
    if not end:
        raise ValueError(anchor)
    return source[start:start + end.end()].rstrip()


def make_source():
    illumination = 'Shared/Illumination.swift'
    state = 'Shared/InsideCoverState.swift'
    ref = 'Shared/ReferenceLibrary.swift'
    pieces = ['import Foundation\n']
    manifest = []

    def add(path, anchor, indent=0):
        code = block(path, anchor, indent)
        pieces.append(code)
        manifest.append(dict(path=path, declaration=anchor, sha256=hashlib.sha256(code.encode()).hexdigest()))

    for anchor in ['extension String {\n    /// FNV', 'extension Int {\n    /// SplitMix']:
        add(state, anchor)
    for name in ['CodablePoint', 'CodableSize', 'CodableRect', 'ClosedDoubleRange', 'PhotoCandidate',
                 'PhotoMarginalia', 'TemplateFallbackPhrases', 'TemplateTextSlotSpec',
                 'TemplateDecorationSlotSpec', 'PhotoFrameSpec', 'DecorationPlacement']:
        add(state, 'struct ' + name + ':')
    for name in ['PackAvailability', 'CanvasPreference', 'PhotoOrientation', 'PhotoTreatment']:
        add(state, 'enum ' + name + ':')
    add('Shared/PagePacks.swift', 'enum LeafVisualDialectID:')
    for name in ['IlluminatedTemplateID', 'IlluminatedPageStatus', 'IlluminationAssetKind',
                 'LeafAssetSemanticRole', 'LeafAssetAnchor', 'LeafAssetBlend', 'LeafAssetCrop', 'MarkShelf',
                 'MarginaliaContentKey', 'IlluminatedFontStyle', 'IlluminatedAnnotationStyle',
                 'IlluminatedPhotoPurpose']:
        add(illumination, 'enum ' + name)
    for name in ['PhotoAnalysis', 'LeafAssetTraits', 'IlluminationAsset', 'IlluminationPlacementContext',
                 'IlluminationPlacementTrigger', 'IlluminationAssetPack', 'IlluminationTemplate',
                 'IlluminatedTextSlot', 'IlluminatedCompositionPlan', 'IlluminatedPhotoDraft',
                 'IlluminationMarginaliaSnippet', 'LeafDecorationRecipe']:
        add(illumination, 'struct ' + name + ':')
    illumination_source = (ROOT / illumination).read_text()
    a = illumination_source.index('    static let academyFallback = PhotoAnalysis(')
    b = illumination_source.index('\n    )', a) + len('\n    )')
    pieces.append('extension PhotoAnalysis {\n' + illumination_source[a:b] + '\n}')
    add(illumination, 'extension LeafAssetTraits {')
    add(illumination, 'extension IlluminationAsset {')
    add(illumination, 'private extension Set where Element == String {')
    add(illumination, 'extension MarkShelf {')
    # The second IlluminationAsset extension only adds shelf/occasion helpers.
    add(illumination, 'extension IlluminationAsset {\n    /// The permanent shelf')
    for name in ['CoreMarginsPack', 'LeafMarginaliaPlacement', 'LeafPaperStock', 'LeafMarginaliaDensity',
                 'LeafDecorationLibrary', 'IlluminationTemplateLibrary', 'IlluminationMarginaliaLibrary',
                 'IlluminatedPhotoFallbackWords', 'IlluminatedPhotoLayout', 'IlluminatedPageComposer',
                 'InterleafWritingCraft', 'InterleafCuration', 'InterleafPhotoCuration']:
        add(illumination, 'enum ' + name)
    add(illumination, 'struct IlluminationAssetResolver {')
    add(illumination, 'enum LeafMarkTier')
    # Which size tiers a mark can hold: hero, mid, crumb.
    add(illumination, 'extension IlluminationAsset {\n    /// Subjects that still read')
    for name in ['NoticingSource', 'Noticing']:
        add('Shared/NoticingCrossings.swift', ('enum ' if name.endswith('Source') else 'struct ') + name + ':')
    add(ref, 'struct LabyrinthIllustrationPlate:')
    add(ref, 'struct InterleafIllustration:')
    for name in ['TarotArcana', 'TarotSuit', 'TarotRank']:
        add('Shared/Tarot.swift', 'enum ' + name + ':')
    add('Shared/Tarot.swift', 'struct TarotCardDefinition:')
    add('Shared/Tarot.swift', 'enum TarotDeck {')
    add(ref, 'enum InterleafIllustrationLibrary {')
    add(ref, 'struct CharacterIllustrationProfile:')
    # Run the actual host-level reservation/visibility selection implementation.
    store = block('InsideCoverApp/PagesRisingFolio.swift', 'private final class FolioInterleafEncounterStore:')
    store = store.replace('private final class', 'final class').replace(': ObservableObject', '')
    store = store.replace('UserDefaults.standard', 'auditDefaults').replace('Date()', 'auditNow')
    store = store.replace('    let id = UUID()', '''    // Harness-only process-restart and pending-write probes.
    static func auditDrainPersistenceAndForgetMemory() {
        persistenceQueue.sync {}
        latestHistory = nil
        latestVisualHistory = nil
    }
    static func auditSuspendPersistence() { persistenceQueue.suspend() }
    static func auditResumePersistence() { persistenceQueue.resume() }
    let id = UUID()''')
    pieces.append(store)
    manifest.append(dict(path='InsideCoverApp/PagesRisingFolio.swift', declaration='FolioInterleafEncounterStore',
                         adaptation='ObservableObject/main actor removed; Date() injected fixture clock; UserDefaults replaced with isolated byte store; harness-only queue drain/cache reset and suspend/resume probes injected',
                         sha256=hashlib.sha256(store.encode()).hexdigest()))
    desk_key = block('InsideCoverApp/PagesRisingFolio.swift', 'private struct FolioDeskCacheKey:')
    desk_key = desk_key.replace('private struct', 'struct').replace('    @MainActor\n', '')
    pieces.append(desk_key)
    manifest.append(dict(path='InsideCoverApp/PagesRisingFolio.swift', declaration='FolioDeskCacheKey',
                         adaptation='Main actor removed; document keys, metrics and PhotoKit permission stubbed for key equality probes; native pagination is not executed',
                         sha256=hashlib.sha256(desk_key.encode()).hexdigest()))
    for name in ['MapPlateMark', 'MapPlateSpec', 'GazetteerLeaf']:
        add('Shared/Atlas.swift', 'struct ' + name + ':')
    page_source = (ROOT / 'Shared/PageModel.swift').read_text()
    cases = page_source[page_source.index('enum BookPageType:'):page_source.index('    var id: String { rawValue }')]
    cases = '\n'.join(re.findall(r'^    case .+$', cases, re.M))
    pieces.append('enum BookPageType: String, CaseIterable {\n' + cases + '\n}')
    # These are fixture adapters only, not substitutes for selection/recipe code.
    src = (ROOT / ref).read_text()
    a = src.index('    static let bundledCharacterIllustrationAssetNames:')
    b = src.index('\n    ]', a) + len('\n    ]')
    bundled = src[a:b]
    registry = '''
var auditNow = Date(timeIntervalSince1970: 1_793_491_200)
final class AuditDefaults {
    var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Data, forKey key: String) {
        precondition(!Thread.isMainThread, "History persistence reached the reading thread")
        values[key] = value
    }
}
let auditDefaults = AuditDefaults()
struct SurfacePage { var id: String }
struct FolioLayoutMetrics {}
struct FolioDocumentCacheKey: Hashable {
    var id: String
    init(surface: SurfacePage, metrics: FolioLayoutMetrics) { id = surface.id }
}
enum PHAuthorizationStatus { case authorized, limited }
enum PHAccessLevel { case readWrite }
enum PHPhotoLibrary {
    static func authorizationStatus(for access: PHAccessLevel) -> PHAuthorizationStatus { .authorized }
}
var auditMonthlyPackEnabled = false
struct FixturePack: Decodable { var id: String; var availability = "bundledFree"; var marginaliaPack: IlluminationAssetPack? = nil; var marginaliaSnippets: [IlluminationMarginaliaSnippet]? = nil; var interleafIllustrations: [InterleafIllustration]? = nil }
enum PageArchetypePackRegistry {
    static let monthly: FixturePack = try! JSONDecoder().decode(FixturePack.self,
        from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
    static func enabledPacks() -> [FixturePack] { auditMonthlyPackEnabled ? [monthly] : [] }
}
enum PackEntitlements { static func isUnlocked(_ id: String) -> Bool { false } }
enum MonthlyIssueMediaPath { static func resolving(_ value: String) -> String { value } }
enum GuestCast {
    static let assetName = "LabyrinthCharacterTheGuest"
    static let entityID = "visitor-the-guest"
    static let current = Present()
    struct Present { func isPresent() -> Bool { true } }
}
enum BookReferenceCatalog {
BUNDLED
    static let characterIllustrations: [CharacterIllustrationProfile] = {
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String: Any]
        let bytes = try! JSONSerialization.data(withJSONObject: root["characterIllustrations"]!)
        return try! JSONDecoder().decode([CharacterIllustrationProfile].self, from: bytes)
    }()
    static var labyrinthIllustrations: [LabyrinthIllustrationPlate] {
        characterIllustrations.compactMap { profile in
            let asset = profile.assetName?.isEmpty == false ? profile.assetName! : profile.intendedAssetName
            guard bundledCharacterIllustrationAssetNames.contains(asset) else { return nil }
            return .init(id: profile.id, assetName: asset, title: profile.characterName, caption: profile.core,
                note: "fixture", tags: Array((["illustration", profile.illustrationTag, profile.slug] + profile.tags).prefix(8)), characterID: profile.id)
        }
    }
}
struct VisualRegion: Codable, Equatable { var x: Double; var y: Double; var width: Double; var height: Double }
struct CreatureSighting: Codable, Equatable {}
struct BookPage {
    enum Privacy { case privateLocal, localSensitive }
    enum Origin { case userAuthored, generated, simulated }
    var id: String; var type: BookPageType = .souvenir; var createdAt: Date; var userInput: String
    var privacy: Privacy = .privateLocal; var origin: Origin = .userAuthored
    var readerAuthoredTextForAnalysis: String? { origin == .userAuthored ? userInput : nil }
    var bindingDisplayTitle: String { type.rawValue }
}
struct BookDay { var id: String; var date: Date; var pages: [BookPage] }
extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
    func bookPreviewSentenceLimit(_ count: Int) -> String { self }
}
'''.replace('BUNDLED', bundled)
    pieces.append(registry)
    # The actual registry with only the external entitlement/content-pack adapters above.
    add(illumination, 'enum IlluminationPackRegistry {')
    folio = (ROOT / 'InsideCoverApp/PagesRisingFolio.swift').read_text()
    scale = block('InsideCoverApp/PagesRisingFolio.swift', '    private func midTierScale(salt:', 4)
    unit = block('InsideCoverApp/PagesRisingFolio.swift', '    private func unit(_ salt: Int)', 4, after='private struct FolioLeafMarginaliaMarks:')
    kernel = scale.replace('private func midTierScale(salt: Int) -> CGFloat', 'func auditMarginaliaScale(seed: Int, salt: Int) -> Double')
    kernel = kernel.replace('leaf.isDecorationPlate', 'true').replace('unit(', 'auditUnit(seed, ')
    unit = unit.replace('private func unit(_ salt: Int) -> CGFloat', 'func auditUnit(_ seed: Int, _ salt: Int) -> Double')
    unit = unit.replace('leaf.decorationRecipe.seed', 'seed').replace('CGFloat(', 'Double(')
    pieces += [kernel, unit]
    manifest.append(dict(path='InsideCoverApp/PagesRisingFolio.swift', declaration='midTierScale + unit', adaptation='explicit seed and Double for standalone interpreter'))
    return '\n\n'.join(pieces), manifest



def write_report(output):
    from collections import Counter
    summaries = json.loads((output / 'summary.json').read_text())
    rows = json.loads((output / 'encounters.json').read_text())
    asset_root = ROOT / 'InsideCoverApp/Assets.xcassets'
    image_sets = {p.stem: p for p in asset_root.rglob('*.imageset')}
    selected_names = {a for row in rows for a in row['marginalia']}
    selected_names.update(row['selectedID'] for row in rows if row['actual'] == 'illustration')
    missing = []
    for name in sorted(selected_names):
        if name.startswith('{{asset-path:'):
            continue  # Authored monthly identities, no delivery/install exercised.
        folder = image_sets.get(name)
        if not folder:
            missing.append(name)
            continue
        content = json.loads((folder / 'Contents.json').read_text())
        files = [x['filename'] for x in content.get('images', []) if x.get('filename')]
        if not files or not all((folder / f).is_file() for f in files):
            missing.append(name)
    lines = [
        '# Interleaf month audit', '',
        'Current production selection/recipe code, executed in an isolated Swift interpreter harness. No app build or app data access.', '',
        f'{len(summaries)} synthetic scenarios, 31 consecutive days (November 1 through December 1, UTC), 2 openings per day, 10 boundaries per opening: **{len(rows):,} interleaves**.', '',
        '| Scenario | Texts selected (unique IDs) | Illustrations (unique) | Photos (unique) | Maps (unique) | Marginalia recipes (unique marks) | Handwritten captions (unique) |',
        '|---|---:|---:|---:|---:|---:|---:|'
    ]
    for item in summaries:
        lines.append('| ' + ' | '.join(str(x) for x in [item['name'], item['uniqueTexts'], item['uniqueIllustrations'],
            item['uniquePhotos'], item['uniquePlaces'], item['uniqueMarginalia'], item['uniqueSnippets']]) + ' |')
    lines += ['', '## What was exercised', '',
        '- The existing host encounter store, with a fixture clock and isolated encoded history bytes reloaded on every opening.',
        '- The real 2 photo / 3 illustration / 5 quieter slot policy, text rest, map rest, unseen-first art selection, per-boundary stability, and source-level photo selection.',
        '- Bundled marginalia recipes, handwritten caption ranking, all density ceilings, paper stocks, primary placements, and actual marginalia scale arithmetic.',
        '- New sentence selection, stable decoration choices, recent mark/caption avoidance, and spacing after crowded interleaves. Fixture recipes are treated as placed for history; the actual UIKit collision/visibility path is not simulated.',
        '- All six illuminated-photo templates, shared photo compositor, varied image aspect ratios, distinct decoration selection, and pairwise rotated collision checks.',
        '- A Guest pack fixture using the authored November margins JSON and the four canonical story phases; monthly art identities and gates are exercised, not asset delivery.', '',
        '## Result and correction', '']
    baseline_path = output / 'baseline/summary.json'
    if baseline_path.exists():
        baseline = {x['name']: x for x in json.loads(baseline_path.read_text())}
        for item in summaries:
            if item['name'] in baseline:
                before = baseline[item['name']]
                lines.append(f"- {item['name']}: distinct handwritten captions **{before['uniqueSnippets']} → {item['uniqueSnippets']}**.")
    lines += ['',
        'The audit found that `book`/`margin` container tags made two captions dominate. Those tags no longer count as subject evidence in handwritten caption ranking; literal subject matches remain preferred.', '',
        'Recorded selection/geometry invariant failures: ' + str(sum(len(x['invariantFailures']) for x in summaries)) + '.',
        'Selected bundled art with missing image files: ' + (', '.join(missing) if missing else 'none') + '.', '',
        '## Well-stocked month', '',
        '| Day | Reader text | Findings | Writing tips | Illustrations | Photos | Maps | Pure marginalia |',
        '|---|---:|---:|---:|---:|---:|---:|---:|'
    ]
    stocked = [x for x in rows if x['scenario'] == 'well-stocked']
    for day in range(1, 32):
        counts = Counter(x['actual'] for x in stocked if x['day'] == day)
        lines.append('| ' + ' | '.join(str(x) for x in [day] + [counts[k] for k in ['reader-text','noticing','writing-tip','illustration','photo','map','marginalia']]) + ' |')
    lines += ['', '## Breadth and limits', '']
    for item in summaries:
        selected = [x for x in rows if x['scenario'] == item['name']]
        decorated = [x for x in selected if x['actual'] in ('marginalia','reader-text','noticing')]
        scales = Counter('familiar' if x['primaryScale'] == 1 else 'smaller' if x['primaryScale'] < 1 else 'larger' for x in decorated)
        captions = sorted(item['snippetCounts'].items(), key=lambda x: -x[1])[:3]
        discoveries = sum(x.get('discoveryCandidate') is not None for x in decorated)
        paired = sum(x.get('drawingCaptionMatch') is True for x in decorated)
        lines += [f"### {item['name']}", '',
            f"- Actual encounter counts: {item['kinds']}.",
            f"- Fallback counts: {item['fallbackCounts']}.",
            f"- Density ceilings: {item['densities']}; size bands: {dict(scales)}.",
            f"- Paper stocks: {item['papers']}; primary placement choices: {item['placements']}.",
            f"- Most frequent captions: {captions}.",
            f"- Proposed discoveries: {discoveries}; recipes with a shared drawing/caption subject: {paired}. Both still require native fitting and visual review.",
            f"- Longest adjacent same-primary/same-caption run: {item['maxSamePrimaryRun']}/{item['maxSameSnippetRun']}.", '']
    lines += ['## What this does not establish', '',
        '- These are recipe/selection results, not rendered phone or iPad leaves. Native collision fitting can omit proposed marks.',
        '- UIKit typography, clipping, Dynamic Type, VoiceOver, tapping the quotation, page curling, and reveal timing were not executed.',
        '- No PhotoKit permission, real library queries, iCloud delivery, decoded pixel cache, installed pack entitlement, live Gazetteer ranking, or full XCTest run was exercised.',
        '- Reader text, finding lines, place candidates and photo metadata are explicitly synthetic fixtures. Real keep provenance/source-opening routes are not replaced or claimed tested by these fixture adapters.',
        '- Small libraries necessarily repeat photos. Depleted text/map pools yield marginalia; the audit does not invent more personal material.', '',
        'History writes were also asserted off the main thread. Suspended-write reopening, ordered persistence/reload, and actual binding-key equality after exposure were checked with fixture adapters. These are regression probes, not device frame-time measurements.', '',
        'Reproduce: `python3 scripts/audit_interleaf_month.py`.', '',
        'Raw evidence: `summary.json`, `encounters.json`, `source-manifest.json`, and baseline equivalents. The manifest fingerprints extracted source declarations and lists adaptations.', '']
    (output / 'report.md').write_text('\n'.join(lines))
    print(f"Report: {output / 'report.md'}; missing bundled art: {len(missing)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/fixtures/interleaf-month-audit')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    source, manifest = make_source()
    driver = (ROOT / 'scripts/interleaf_month_driver.swift').read_text()
    (args.output / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    with tempfile.TemporaryDirectory(prefix='reenchanted-interleaf-audit-') as tmp:
        harness = Path(tmp) / 'main.swift'
        harness.write_text(source + '\n\n' + driver)
        completed = subprocess.run(['/usr/bin/swift', '-module-cache-path', str(Path(tmp) / 'module-cache'),
            str(harness), str(ROOT / 'Shared/BookReferenceLibrary.json'), str(args.output),
            str(ROOT / 'ContentPacks/the-guest/margins.reenchantedpack.json')],
            text=True, capture_output=True)
        (args.output / 'stderr.txt').write_text(completed.stderr)
        if completed.returncode:
            print(completed.stderr[-18000:])
            raise SystemExit(completed.returncode)
        print(completed.stdout)
        write_report(args.output)


if __name__ == '__main__':
    main()
