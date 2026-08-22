# Marginalia Shelves — organizing the cabinet for Pagewright (implementation plan)

Goal: the shared mark cabinet has outgrown the tray that browses it. Pagewright
sorts marks by `IlluminationAssetKind`, which is a *rendering* property — how
the compositor treats an image — not a browsing one. That held at ~40 marks.
The core pack now ships **205 assets, 219 of them doodles**, so four tray
categories are nearly empty (Tape 4, Grain 3, Seals 13, Paper 17) and one —
"Field" — is everything else.

Three concrete failures today:

1. `PagewrightMarginaliaAssetCache.sortedAssets` filters on `kind` only. The tag
   list attached to each tray category merely *sorts*. "Field" and the folio's
   `["edge", "light", "marginalia"]` request return the same 219 doodles in a
   different order.
2. `previewAssets(kind:tags:count:)` caps the list at 80. **139 marks ship,
   are catalogued, carry achievements, and cannot be placed by hand.**
3. The 53 Academy notes and warnings — handwritten, story-bearing, the newest
   and most characterful things in the cabinet — have no home. They land in
   "Field" between 43 coffee stains.

The fix is one new browsing axis, a featured monthly shelf on machinery that
already exists, and three small places where rummaging is allowed to be fun.

## House laws for this work

- **No new Swift files in `Shared/`.** `MarkShelf` and its resolver go into
  `Shared/Illumination.swift`, which is already in `Package.swift` sources and
  the pbxproj. New test files under `Tests/InsideCoverCoreTests/` are fine.
- **Pure logic in `Shared/`, platform glue in `InsideCoverApp/`.** Shelf
  resolution must be a deterministic static function in the core so `swift test`
  covers it. The tray is the only thing that lives in the app target.
- **Kind keeps its job.** `IlluminationAssetKind` still decides how a mark
  composites. Shelf decides where a reader finds it. Nothing reads shelf to make
  a rendering decision.
- **Shelves are cross-pack.** A shelf spans every unlocked pack. Pack becomes
  provenance on the tile, not a mode the reader switches between.
- **No new model calls.** Everything here is deterministic.
- Run tests per README:
  `CLANG_MODULE_CACHE_PATH=/private/tmp/insidecover-module-cache
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/insidecover-spm-module-cache swift test`

## Phase 1 — `MarkShelf` and its resolver

Add to `Shared/Illumination.swift`:

- `enum MarkShelf: String, CaseIterable` — the browsing axis. Cases below.
- `static func shelf(for asset: IlluminationAsset) -> MarkShelf` — a tag cascade
  in the exact shape of the existing `PagewrightMarginaliaAchievement.quest(for:)`
  ladder, which is *already* classifying these same assets into these same
  families for the lock system. One classifier, two consumers.
- `var shelf: MarkShelf?` on `LeafAssetTraits` — an authored override. Absent,
  the resolver decides, so a third-party pack that ships a bee doodle lands on
  Creatures & Company without doing anything.

Shelves, with today's counts from the core pack:

| Shelf | Count | Drawn from |
|---|---|---|
| `thisMonth` | 0 | placement-triggered; see Phase 3 |
| `handwriting` | 53 | academy notes + warnings |
| `flourish` | ~55 | flourish, ornament |
| `wear` | ~46 | stain, grain, edge, pale, speckle |
| `pressedAndGrown` | 18 | botanical, flower, fern, feather, moss |
| `skyAndNight` | ~19 | moon, moth, star, constellation, weather |
| `sealsAndLabels` | ~23 | stamps, tags, field labels, observer marks |
| `paper` | 17 | scraps, torn edges, blank slips |
| `wayfinding` | 12 | compass, map, ticket, passage, arrival |
| `shore` | 10 | harbor, tide, lighthouse, rain, shell |
| `creaturesAndCompany` | 9 | paw, bee, teacup, home, heart |
| `fastenings` | 4 | tape, clips |
| `theDrawer` | 12/day | see Phase 5 |

Twelve shelves plus the drawer, 4–55 items each, every name a phrase a reader
would say out loud. Nothing called "Field."

Order matters in the cascade: subject beats medium, same as
`LeafAssetTraits.derived`. A botanical *stamp* belongs on Pressed & Grown, not
Seals & Labels. Handwriting wins over everything — an Academy note about the
moon is handwriting first.

## Phase 2 — a registry query that spans packs

`IlluminationPackRegistry` currently answers "which pack" (`preferredPack`,
`packsSupporting`). Pagewright needs "which marks", across everything unlocked,
honoring the placement gate the folio already respects.

Add:

```swift
static func marks(
    on shelf: MarkShelf,
    context: IlluminationPlacementContext = .empty
) -> [IlluminationAsset]
```

- Spans `unlockedPacks`, not one selected pack.
- Filters `asset.placementTrigger?.allows(context) ?? true` — the same gate
  `IlluminationAssetResolver` applies. This is what makes Phase 3 nearly free.
- Stable ordering, so a mark does not move between launches.
- **No count cap.** The 80-item `prefix` is the bug that hides 139 marks.

## Phase 3 — This Month

The machinery exists and Pagewright is the only surface ignoring it.
`IlluminationPlacementTrigger` already takes `months`, `activeWorldEventIDs`,
and `worldEventPhases`; the folio honors it, the tray does not.

- Any mark whose trigger names the live month or the active world event appears
  on `thisMonth`, pinned first in the shelf list.
- The shelf is **dated and voiced**: its header carries the event's
  `WorldEventPhase.scene`, which is already reader-facing prose in the Book's
  voice. Fall back to the packet logline for packs that omit it.
- It refreshes **when the phase turns**, not on a calendar tick. The event
  engine already resolves phases; the shelf just asks.
- When an event ends, marks do not evaporate. Used ones settle onto their
  permanent shelf; unused ones drop to a `pastMonths` shelf at the bottom.
  *(Open question for bj: permanent "you had to be there" scarcity is also a
  real design and changes how the pilot pack is authored. Defaulting to
  "settles, never vanishes" until told otherwise — a scrapbook that deletes
  your materials is a bad feeling.)*

No monthly packs exist yet, so the contract ships first and costs nothing.
**Pilot: Dictionary Rebellion.** It already has event-triggered *snippets* in
`PagePacks.swift` with the `event:<id>` / `event-phase:<phase>` tag convention
worked out, and zero image marks. Eight to twelve assembly marks prove the seam
end to end.

## Phase 4 — the tray rewrite

In `InsideCoverApp/ContentViewFeatures.swift`:

- Replace `PagewrightMarkTrayCategory` with `MarkShelf`.
- `PagewrightMarginaliaAssetCache` keys by shelf instead of the six hardcoded
  `defaultRequests`, and drops the `count` cap.
- Pack name moves out of the tray header and onto the tile as a provenance chip.
- **Add a search field.** The scrap tray has one. At 219 marks, so does this.

## Phase 5 — where the rummaging goes

Keep the shelves tidy and put the fun in three specific places.

1. **The Drawer.** One shelf that is deliberately unsorted: twelve marks pulled
   from anywhere in the cabinet, date-seeded, reshuffled daily. Rummaging is
   only fun when the pile is *small* and *changes*. 219 items in a scroll is not
   rummaging, it is a spreadsheet.
2. **Fewer locks, better locks.** Every asset currently carries an achievement,
   so a shelf of 49 flourishes reads as 49 riddles — a grind, not a treasure.
   Open the ordinary shelves; reserve locks for marks with actual character
   (Academy notes, event marks, cast sigils). The ratio matters more than the
   mechanism.
3. **The Book hands you three.** A small persistent row: three marks picked for
   *this* canvas, scored against what is already on the page.
   `IlluminationPackRegistry.preferredPack(for:motifs:)` already does this
   scoring for photos. Zero rummaging cost, high hit rate, in character.

## Phase 6 — guards

New `Tests/InsideCoverCoreTests/MarkShelfTests.swift`:

- Every asset in every bundled pack resolves to a shelf.
- No shelf holds more than N marks (start at 60) — the lint that stops the next
  200 marks from recreating "Field."
- No shelf other than `thisMonth`, `pastMonths`, and `theDrawer` is empty.
- An authored `leafTraits.shelf` beats the resolver.
- A mark with a `placementTrigger` naming an event does not appear on a
  permanent shelf while that event is live, and does appear once it is over.

And `docs/marginalia-content-pack-contract.md` gains the `shelf` field plus the
monthly-trigger convention.
