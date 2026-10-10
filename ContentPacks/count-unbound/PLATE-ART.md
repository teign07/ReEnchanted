# October 2026 plates

All 24 assets from `plate-art-prompts.json` were generated sequentially with
the built-in `image_gen.imagegen` tool on October 10, 2026. The optimized JPEGs
in `plates/` retain the exact commissioned filename stems (`.jpg` instead of
`.png`). `issue.json` registers them
through the existing monthly publication-media mechanism.

## Dimensions and originals

Portrait exports are 1500 x 2250; landscape exports are 2400 x 1600.
These are resampled exports, not native generation at those dimensions.
The generator returned 1024 x 1536 portraits and 1536 x 1024 landscapes
(the unfinished map was 1535 x 1024). Enlarging them adds no native detail.
Assess a physical print proof before treating them as approved print masters.

`plate-generation-2026-10-10.json` records the effective prompts, supplied
references, original generation paths, native/export dimensions, file sizes,
and SHA-256 hashes for the original PNG exports. Native generation originals
remain in Codex's generated-images folder. The full-size PNG exports are
archived at `output/monthly-plate-masters/count-unbound-2026-10/` in the repository,
outside the delivery folder. `plate-optimization-2026-10-10.json` maps every
PNG master to its JPEG, with dimensions, quality, byte sizes, and both hashes.
HEIC references for Ambrose and Soren were converted to temporary PNG files
without changing the app's originals. For the two five-Cast scenes, the tool's
five-reference limit meant supplying all five Cast portraits and describing
the goblin's rendering style in the prompt.

## Implementation

The optimized JPEGs preserve the full export dimensions. They use quality 90
unless a lower quality is needed to meet the phone's publication limit.
JPEG compression is lossy; the PNG masters remain recoverable for print or
future exports. The existing release script accepts these JPEGs directly
through `monthly_issue.py`, without another compression pass.
The `count-unbound.v2.plate.` prefix puts the version before `.plate.` so the
existing book compositor recognizes the frontispiece, scene and Cast slots.
For later artwork revisions, use a new immutable prefix before `.plate.`;
keep the semantic filenames in `plates/` the same.

Generation and local authoring checks do not publish a shelf or install art
on a phone. No app build was run for this artwork task.
