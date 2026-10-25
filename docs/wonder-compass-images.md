# Wonder Compass images

The app bundles 100 image files imported from **The Wonder Compass EBook.epub**
(101 placements across 40 reading sections; the Compass emblem appears twice).
The original book cover opens Read This First, before its first paragraph,
using the same tap-to-zoom viewer as the chapter illustrations. This export
includes the Chapter 11D infographic missing from the other local EPUB.

The subsequent [listed-corrections pass](wonder-compass-plate-fixes.md) changed
exactly **30 plates**. The other **70 bundled files** retain their exact bytes
from that pass's baseline. There are now **37 corrected infographic records** in
the audit, including earlier repairs. The bundle totals **31,858,325 bytes**.
Original pixel dimensions were retained. Only the 30 bundled SHA-256 values
were written to the library. No chapter prose was edited by this pass;
concurrent prose edits were preserved. Anchors, source hashes and ordering stayed
unchanged. See [verification](wonder-compass-plate-fix-verification.md) for the
checks and the repair method. The first-pass figures below are historical.

The appended R1-R11 round made 11 further corrections across 10 of those plates.
The other 90 files stayed byte-for-byte unchanged from that round's baseline.
Only their 10 library hashes changed; no chapter prose was edited. JPEG crops,
local OCR, audit coverage, and the image checker passed.

During the first October 25, 2026 pass, all **53 NotebookLM infographics** were visually reviewed
at readable resolution, along with the **six authored menu/worksheet images**.
**24 NotebookLM plates** received targeted text repairs. The other **29
NotebookLM plates**, all six menus/worksheets, and all remaining images retain
their exact pre-review bytes. This was a targeted gibberish, obvious-error, and
existing chapter-correction pass, not a new complete scientific review.

The corrected plates replace their existing bundle files, keeping filenames,
placement IDs, chapter order, paragraph anchors, and original EPUB source hashes.
Only their bundled hashes and pixel dimensions change in the reference metadata;
chapter prose is untouched. Edited artwork retains its original composition,
illustrations, palette, and NotebookLM attribution. The built-in imagegen edit
tool made the image repairs; JPEG format conversion preserves each reviewed
output's full pixel dimensions and full-color lettering edges.

[`wonder-compass-infographic-audit.json`](wonder-compass-infographic-audit.json)
records every reviewed image, unchanged/corrected status, original bundled and
EPUB hashes, current hash, and exact repair prompts. Repairs include broken
labels, malformed small lettering, the reversed exercise-chart values, and
specific science claims already corrected in the surrounding chapters. The
attention, flow, and awe checks also consulted the original
[attention review](https://pubmed.ncbi.nlm.nih.gov/22524787/),
[flow review](https://pubmed.ncbi.nlm.nih.gov/35926367/),
[awe-walk trial](https://pubmed.ncbi.nlm.nih.gov/32955293/), and
[clinical awe trial](https://www.nature.com/articles/s41598-025-96555-w).

The checker validates complete audit coverage and the reviewed file hashes.
With `--epub`, it still verifies each original source hash and book order, but
does not require a repaired image to reproduce the faulty EPUB's resolution,
encoded size, or color profile. The optimizer preserves reviewed corrections
instead of replacing them with EPUB masters. No build or device deployment is
part of this repair pass.

First-pass repair verification passed: all 101 placements and 100 bundled files validate
against the EPUB inventory/order and original-source hashes; all 59 infographic
audit records match their current files. Exactly 72 metadata values changed
(hash, width, and height for each repaired plate). All prose, anchors, IDs,
chapter order, and the other 76 bundled files are unchanged from the repair
baseline. That pass left the bundle at **29,114,740 bytes**. A temporary-copy
optimizer run changed **0/100 files**, and the checker rejected a deliberately
stale review hash. Final JPEG small-text crops were inspected after conversion.

Read This First's 55 table-of-contents listings are native buttons backed by
`contentsLinks` metadata. The labels retain their manuscript wording and order;
each destination is an existing Wonder Compass reading section. Combined
sections (QuickStart, Epilogue, and the second Playful Mission Menu page) open
their existing combined Page. Navigation uses `CapturePageSheet`'s existing
`onNavigateToSurface` callback and `WonderCompassPageSourceAdapter.readingSurface`,
the same full chapter Pages opened elsewhere in the app. The cover and all
image placements remain in order around the contents block.

`Shared/BookReferenceLibrary.json` records each plate beside its section with an
exact paragraph anchor, before/after placement, source EPUB chapter, full pixel
dimensions, accessibility description, bundled SHA-256, and original-source
SHA-256. The edited chapter prose is
unchanged. Multiple EPUB chapters already share one app section: QuickStart and
Fast Track, the Field Guide introduction and Chapter 11A, Conclusion through
About the Author, and the two Playful Mission Menu pages.

The importer matched every plate to a surviving paragraph in the app. When an
old caption was removed or edited, it used the nearest surviving neighboring
passage. It verified that these boundaries preserve EPUB order. The second
Playful Mission Menu plate follows the first even though its separate title was
not imported into the app's text.

`WonderCompassReadingView` extends the existing deliberate reading surface,
used by Contents and chapter-preview doors. Images fit without cropping and
use the existing asynchronous, bounded image decoding. A native button opens
the full-resolution bundled file in the system Quick Look viewer, using the same
preview mechanism as other app images, with zoom, pan, and dismissal controls.
Short preview quotations and Compass Run activities retain their own layouts.

The Xcode project copies `InsideCoverApp/WonderCompassImages` as a folder
resource. No network fetch or image generation is needed at runtime.

## File size optimization at initial import

At initial import, the 99 in-text files totaled **24,374,779 bytes**, down from **32,616,918 bytes**:
**25.3% smaller**, saving 8,242,139 bytes before application packaging
(31.1 to 23.2 MiB). Pixel dimensions, filenames, chapter order, color profiles,
and PNG transparency are preserved. The EPUB masters remain outside the app
bundle; a full duplicate original set is not shipped.

The cover uses the same compression policy, retaining its 853 x 1280 resolution:
301,571 to 241,830 bytes. Including the cover, that initial bundle had 100 image files
totaling **24,616,609 bytes**. The text repairs above supersede these initial
encoded sizes and resolutions for the 24 corrected plates; the checker reports
the current bundle size.

JPEG photos use progressive encoding at quality 84 with 4:2:0 chroma sampling.
Infographics and emblems use quality 85 with 4:4:4 sampling to retain colored
letter edges. PNG menus use lossless optimization with exact RGBA pixels. A
candidate replaces its master only when it saves at least 5%; 97 files changed
and 2 retained their original bytes. JPEG compression is lossy, with all source
resolution retained for zoom. Representative photo-detail and small-text crops
were visually compared at native pixel size.

To reproduce the compression without generation loss:

```sh
python3 scripts/optimize_wonder_compass_images.py '/path/to/The Wonder Compass EBook.epub'
```

The optimizer checks the original-source hash for every image. Uncorrected
images start from the EPUB master; reviewed corrections retain their current
bytes. Repeated runs do not recompress either output.

To check anchors, file hashes, dimensions, and inventory without building:

```sh
python3 scripts/check_wonder_compass_images.py
```

Add `--epub '/path/to/The Wonder Compass EBook.epub'` to also verify all in-text
source images, source order, original-source checksums, resolution, color
profiles, and lossless PNG pixels. All three scripts require Pillow.
The importer defaults to a placement report; `--write` is for the first import
and refuses to replace an already illustrated manuscript.

Changing text within an anchored paragraph requires updating that plate's
anchor. Changing earlier paragraphs does not move its placement. Ambiguous or
missing anchors are caught by the checker; at runtime they leave the prose
intact rather than placing art against an unrelated passage. Older libraries
without illustration metadata continue to decode and read as text.

Validation covers the complete EPUB inventory, original-source and bundled
checksums, all anchors and ordering, manuscript preservation, resolution,
color profiles, exact PNG pixels, repeatable compression, project-file syntax,
and Swift syntax parsing. No app build or device interaction was run. Phone and
iPad reading layout, full-screen presentation, zoom, and return-to-reading
behavior still need a runtime check.
