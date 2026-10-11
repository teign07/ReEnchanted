# Public sample editions

The website samples should demonstrate the real app output: a weekly issue and
a monthly issue from the same simulated Reader, with their actual kept Pages,
saved braids, real photographs, and genuinely composed Pagewright sheets.

## Export and publication

The public sample seam is `--public-sample-editions` in the existing DEBUG
edition proof harness. It consumes only explicit QA files, preserves original
simulated keep IDs and saved braid bodies, and writes to a separate
`Documents/public-sample-editions` directory. It does not overwrite a vault.

The source simulation is retained in
`docs/fixtures/october-simulation-kept-pages.json`. Placeholder image references
are fixture URLs; the exporter removes those fake pictures, keeps their original
words as text, and adds separately captioned real photo keeps. The saved braids
remain verbatim in `docs/fixtures/real-braids-october-2026.json`.

Twelve photographs and four Pagewright sheets are described by the isolated
`sample.json` input. The sheets use `PagewrightDraft` and the actual
`PagewrightPDFWriter`, including real selected photos, paper, original text
scraps, and eight distinct app marginalia assets. None is a mock collage.
The October 22–28 issue contains the same October 23 braid as the website.
Its two composed sheets also appear among the month's four sheets.

Photo keeps and Pagewright sheets were added after the saved braids. Explain
that on the website and in the PDF front matter, rather than claiming the added
photos were inputs to the previously generated nights. The simulated Reader's
original sentences and the Book's fiction remain separately labelled.

The website reader is `LandingPage/samples.html`. It provides Page navigation,
a Page picker, larger viewing, extracted Page text, PDF open/download links,
original kept receipts, and composed-sheet previews. `#sample-issues` is a
Contents chapter and the edition introduction has a prominent jump to it.
Do not promise native app import of these PDF files: that is not implemented by
this website reader.

### Reproduce without building

Use the bundled Python runtime with Pillow and pypdf, plus Poppler's pdftoppm.

1. `scripts/prepare-landing-sample-input.py` copies the retained simulation and
   editorial notes, then optimizes selected Photos exports into isolated inputs.
   It excludes all EXIF and GPS from the public image bytes.
2. Install an already-built DEBUG app on a QA simulator, or pass its path to
   `scripts/run-public-sample-editions.py --device UUID --app APP_PATH`.
   This script never invokes a build. It stages only QA input, launches the
   actual export seam, requires an OK status, and collects generated files into
   `output/pdf/public-samples`.
3. `scripts/export-landing-samples.py --proof-directory output/pdf/public-samples`
   copies the actual PDFs unchanged, renders every Page for browser viewing,
   checks saved braid and selected receipt equality, and packages a public
   catalogue with deliberately selected provenance. App-container paths and
   private source metadata do not enter that catalogue.
4. Inspect every numbered review sheet in `output/sample-editions/review`,
   full-size photo and Pagewright Pages, and the browser reader on desktop and
   iPhone-sized viewports. Verify navigation, the last Page, PDF links and
   Contents discovery.
5. Use `scripts/deploy-landing.sh` with an intended-files-only staged mirror if
   the checkout contains unrelated landing changes. Wait for GitHub Pages,
   then inspect the cache-busted public reader and verify PDF hashes.

The user authorized the necessary app build on October 9 with “go ahead!”
after being asked specifically about the standing instruction not to build.
That authorization covers this sample export; future rebuilds still require a
user request.

## Photos selected from the user's library on October 9

The user authorized browsing Photos and selecting pictures, then specifically
suggested boat interiors, Amanda with their pets, and photos of the couple.
Twelve real photos are now collected in the Photos album
`ReEnchanted — Sample photo shortlist` and exported as full-size JPEGs under
`output/sample-editions/photos/`. This output directory is gitignored. No GPS
tags are present in the exported files; library titles, keywords and captions
were excluded. The originals were not edited.

The exact file mapping, dimensions and hashes are in
`output/sample-editions/photo-selection.json`; the review screenshot is
`output/sample-editions/photo-shortlist.png`. The selection contains three
boat interiors, two paired portraits, two person-with-pet moments, two water
scenes, and three cabin/woodland details. Use this actual selection instead of
the earlier requested-subject list below.

The photos were captured across several years. They illustrate a simulated
Reader's example issue; do not claim they were all captured during its October
2026 timeline. Keep the saved braids intact. Match photo captions and Pagewright
notes to the actual scenes rather than forcing a boat interior into a blue-door
or table-for-one caption. Personal identities were not named in Photos' People
groups; confirm the intended identities in the review rather than inferring
them from faces.

The selected photos are the inputs for the authorized October 9 sample export.
Keep the original Photos album and export manifest for subsequent curation.


## Published verification — October 9, 2026

The authorized simulator build succeeded. The app exported a 24-Page weekly
issue and a 128-Page monthly edition, including twelve selected photographs
and four genuine Pagewright sheets. Every numbered PDF review sheet was
visually inspected. Saved braid and selected original receipt equality passed.

Published mirror: `1a8333c` (following the sample-reader publication `2be3686`).
GitHub Pages completed successfully for both. Public catalogue equality and
downloaded PDF SHA256 checks passed. Browser checks covered image loading,
Page navigation, the last Page, source-to-braid links, and phone-sized layout.
Both edition listings include their own reader and PDF links beside the book
image and heading. The sample chapter is also in Contents.

- Weekly: https://reenchanted.app/samples.html?issue=weekly
- Monthly: https://reenchanted.app/samples.html?issue=monthly
- weekly PDF SHA256: `6ee0c6c877afdd10832d0e0f4a75bf6e3d17e0a6338bd6ff837d8ea45f08e6b5`
- monthly PDF SHA256: `ed0b1ec28ced3970201399d3d6292720ac0e51f09fc72903d41604191d004615`

## Published — October 10, 2026

Re-exported at bj's request ("trade out the weekly and monthly example
editions … for these new updated ones"), through the same pipeline: a 24-Page
weekly and a 138-Page monthly with October's commissioned plates (real plates
only, copied from the pack by `prepare-landing-sample-input.py`), the four
hand-laid Pagewright sheets, the twelve photographs (EXIF and GPS stripped),
the year-long Academy coursework, and the simulated Reader's two class
sittings now recording October's lessons. Every review sheet was inspected.

Run the scripts with Codex's bundled runtime: system `python3` is too old
(`zip(strict=)`), and `pdftoppm` isn't on PATH:
`~/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3.12`
and `…/dependencies/native/poppler/bin/pdftoppm`.

Deployed samples-only (`assets/samples/` rsynced into the deploy mirror,
mirror commit `88cc2bb`) so unrelated landing changes stayed unpublished.
GitHub Pages succeeded; the live catalogue and both PDFs matched byte for byte.

- weekly PDF SHA256: `5a93794e01a77d949ae1f3927eed67a3f8c4388f0c9e08b77ea7e32d5fd310df` (19.6 MB)
- monthly PDF SHA256: `3cfa8adf416a216f2e6f6402e9f3984777fd7ad9d458aa47f7874ec8c4aac532` (54.0 MB; plates roughly doubled it)
