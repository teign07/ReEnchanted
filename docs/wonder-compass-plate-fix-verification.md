# Wonder Compass listed plate corrections

Applied 25 October 2026, using `docs/wonder-compass-plate-fixes.md` as the correction list.

All **30 listed plates** have their requested text, badge, caption, or illustration corrections. The missing Emotional Amnesia signal and antidote were added while retaining the other eleven signals and antidotes. The anthropomorphism steps have one numbered badge each: 1, 2, 3. The armchair replaces the Step 3 lotus pose.

The built-in imagegen editor supplied the repairs. Accepted repair regions were composited onto each plate's saved original pixels, with blended edges, before JPEG encoding at quality 95 with 4:4:4 chroma. This confines the changes to the listed areas instead of accepting unrelated changes from a full generated image. Pixel comparisons verified **zero changed pixels outside the repair rectangles before JPEG encoding**. JPEG encoding is lossy; the edited files are not claimed to preserve every unedited pixel byte for byte.

Edited-region crops were inspected at native resolution after JPEG conversion. Local text recognition checked the finished JPEG text against the requested replacements; visual review checked illustration details, step badges, spelling, and small lettering that OCR cannot reliably distinguish. The twelve-signal plate, tiny snack-bag label, daily-rut caption, and penny inscription received close-up follow-up edits.

The audit at `docs/wonder-compass-infographic-audit.json` records the exact prompts, prior audit values, pass-baseline hashes, final hashes, dimensions, and corresponding correction-list entries. There are now **37 corrected audit records** across both repair passes.

Validation:

- Exactly **30 bundled files changed**; the other **70 retain their exact pre-pass bytes**.
- The library JSON changed only **30 bundled SHA-256 values**. Every pixel dimension stayed the same.
- This pass wrote no chapter prose. The apply-time comparison confirmed that only the 30 image hashes changed relative to the live library immediately before the write. Chapter prose was edited concurrently during the repair session; those edits were preserved. Plate anchors, placement IDs, dimensions, source hashes, contents links, and ordering remained unchanged.
- All unlisted audit records remained unchanged.
- `python3 scripts/check_wonder_compass_images.py` passed: **101 placements, 100 files, 40 sections**, totaling **31,822,936 bytes**.
- No app build or device deployment was run.

Working originals, imagegen masters, exact prompts, repair rectangles, OCR results, native JPEG crops, and pixel-preservation results are saved locally under `output/wonder-compass-plate-fixes/`. They are review artifacts, not additional bundled app resources.


## Appended round two: R1-R11

Applied all **11 appended corrections across 10 plates** on 25 October 2026. Only the newly listed handwriting, wording, punctuation, quotation marks, and caption styles were edited. The existing first-round corrections were retained.

The built-in imagegen tool edited close-up crops. Accepted text regions were composited onto the current plate originals, preserving all pixels outside those regions before JPEG encoding. The two NUMBING caption lines were set together; the Drift phrase now uses one upright style and a comma; literal asterisks were removed from the Neurodivergent Compass; Sense has paired double quotation marks.

Final JPEG crops were visually checked at native resolution. Local OCR verified the replacement wording and confirmed that the closing “safe enough to enjoy” line occurs once. The journal handwriting was also reviewed against its enlarged generated master because native-size OCR misreads its small tilted letters.

Exactly **10 image files and 10 bundled SHA-256 values changed** in this round. The other **90 image files retain their exact pre-round bytes**, and all unlisted audit records remain unchanged. An apply-time comparison against the live library verified that prose, dimensions, anchors, placement IDs, source hashes, contents links, and ordering were untouched.

The image checker passed for **101 placements, 100 files, 40 sections**, totaling **31,858,325 bytes**. The overall audit still contains **37 corrected records**. No app build or deployment was run.

Exact prompts, previous audit values, and current hashes are in `docs/wonder-compass-infographic-audit.json`. Local review artifacts and pixel-preservation results are under `output/wonder-compass-plate-fixes-round2/`.
