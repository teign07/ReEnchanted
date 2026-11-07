# Permanent illustrated interleaves

October 18, 2026. Seven portrait leaves extend the existing interleave cabinet.
Pippa Pilcrow's dossier is the primary visual reference: a strong central ink
and watercolour illustration, surrounded by observational sketches, paper
scraps, short handwritten notes and faded stamps. The new plates depict
places and actions, with their own marginalia.

| Leaf | Bundled asset |
| --- | --- |
| The shelf that kept growing | `InterleafShelfThatKeptGrowing` |
| Under the Kitchen table | `InterleafUnderTheKitchenTable` |
| The Book's sleeping place | `InterleafBooksSleepingPlace` |
| The window after everyone leaves | `InterleafWindowAfterEveryoneLeaves` |
| A way into the story | `InterleafWayIntoTheStory` |
| The word duel | `InterleafWordDuel` |
| The forgotten stacks | `InterleafForgottenStacks` |

The Book Jump and duel use the existing Permancer and Penny portraits as
character references. The goblin uses the existing crouching goblin. The
forgotten stacks suggest the Nothing through shadows and disappearing detail;
the illustration makes no claim about the Reader's life or activity.

## Integration

`InterleafIllustrationLibrary.permanentScenes` adds the leaves to the existing
selection pool. They are available year-round and use the existing semantic
matching, recent-image exclusion, full-leaf fitting and artifact inspector.
They add no scene events, monthly dependencies or navigation paths.

Generic `book` and `margin` tags are deliberately absent from this collection:
the selector includes those motifs on every Page, so tagging only some new
plates with them would make those plates win unrelated encounters.

## Assets and reproduction

Only optimized JPEG derivatives belong in the seven `Interleaf*.imageset`
folders in `InsideCoverApp/Assets.xcassets`. They retain their native portrait
dimensions, preserving the fine ink and marginal lettering. Compression is
lossy; the full PNG masters are kept outside the app bundle at
`output/imagegen/permanent-interleaves-v1/masters/`.

The built-in `image_gen.imagegen` tool generated the art. Exact prompts,
references, source paths, derivative sizes and SHA-256 hashes are recorded in
`output/imagegen/permanent-interleaves-v1/manifest.json`. The window plate
received one lettering correction, removing an unwanted apostrophe from its
title. No existing cast artwork was replaced.

The seven PNG masters total 27,524,874 bytes. The seven app JPEGs total
5,416,400 bytes: an 80.32% reduction in encoded asset size. Each is
1024 × 1536 pixels, in sRGB, encoded with `sips` JPEG quality 72; no upscaling
or downscaling was used. The largest app image is 830,921 bytes. This measures
file size, not decoded memory use or app performance.

Artwork inspection and asset/source validation do not establish the runtime
appearance. All seven assets were checked for catalogue filenames, dimensions,
profiles, hashes and decode success; Swift syntax and whitespace checks passed.
No app build, installation or publication was performed.

## Everyday life additions — November 6, 2026

Eight more portrait leaves join the same permanent pool, bringing it to fifteen.
The original seven remain unchanged. These are small, newly authored incidents
grounded in existing cast habits and room lore, without monthly plot reveals.
Some have short handwritten notes; others let the scene stand alone.

| Leaf | Bundled asset |
| --- | --- |
| Breakfast has not been approved | `InterleafBreakfastHasNotBeenApproved` |
| Somebody else's handwriting | `InterleafSomebodyElsesHandwriting` |
| An island in the tea | `InterleafAnIslandInTheTea` |
| The card that wouldn't file | `InterleafTheCardThatWouldntFile` |
| The rain came in first | `InterleafTheRainCameInFirst` |
| Before the pens wake | `InterleafBeforeThePensWake` |
| The wrong door | `InterleafTheWrongDoor` |
| The Book kept the blanket | `InterleafTheBookKeptTheBlanket` |

Each has a distinct title and semantic tags for its depicted people, place,
objects, and mood. The additions use the existing year-round selection,
repeat avoidance, full-leaf presentation, and inspector. They add no gates or
new encounter mechanism.

The PNG masters remain at `output/interleaf-illustrations-2026-11-06/`.
The eight app JPEGs retain 1024 × 1536 pixels, use sRGB and the existing
`sips` quality-72 conversion, and total 5,339,737 bytes, compared with
29,828,963 bytes for the masters (82.10% less encoded storage). The largest
JPEG is 727,727 bytes. This is a file-size comparison, not a memory or
performance measurement.

Exact generation prompts, canonical art references, conversion settings,
subject tags, paths, and source/derivative SHA-256 hashes are preserved in
[the production record](art-provenance/interleaf-everyday-2026-11-06.json).
The PNG masters and prior images are preserved.

Validation: all fifteen permanent entries have unique IDs and asset names;
all declared files decode and retain their dimensions; the eight new JPEGs
have sRGB profiles; Swift syntax and whitespace checks pass. The converted
artwork was visually inspected. No app build, XCTest, installation, or native
presentation check was run.
