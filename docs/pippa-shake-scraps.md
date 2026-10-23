# Pippa's shake scraps

Debug built, signed, installed and launched on Rabbit on October 22, 2026. All seven PippaWordFindsTests passed in an isolated native XCTest bundle linked to the newly built core module. The normal package test target was blocked by an existing duplicate LeafPresentationTests declaration; those unrelated files were left unchanged. The app remained alive during a brief startup observation, with no new diagnostic reports and unchanged app inputs through installation. The reader reports Pippa is adorable. Detailed interaction timing and performance profiling remain unverified. Deployment evidence: /private/tmp/ReEnchanted-Rabbit-Debug-20261022-pippa/deployment-evidence.json.

A deliberate phone shake makes the existing small Pippa fall out of sight, then rise towing one readable paper card. She releases it before landing. The card uses native body text with dark ink on opaque paper and stays until dismissed. It does not become a kept Page or change the reader's writing. Tapping a settled Pippa offers the same scraps. Reduce Motion and VoiceOver present a stationary card; Pippa also has an accessible action. Accessibility text sizes get a scrolling card body.

Her deck mixes authored cheek with observations from the provenance-aware `readerAuthoredTexts` boundary: punctuation counts, six-mark ladders, favourite words, literal repetitions, words returning across a week, and authored associations between actual words on different Pages. Inventories exclude Pages marked `localSensitive`. She does not attribute Book-generated or imported body text to the reader. Source references and the displayed vocabulary are bounded. She remembers her favourite and recent gifts for the current app session; there is no new persistence or model job.

The previous word supply stopped at three eligible words encountered at the start of the archive; the renderer then always chose `carried.first` and drew it at eight points. This change removes that text from the Canvas. Preparation now favours recent writing and the deck avoids immediate repeats. Separate discovery families keep a large vocabulary from drowning out punctuation and connection scraps.

Exclamation detection has moved from the folio's draft setter to the shared Book-writing `inkFeedback` seam, which covers the existing folio, plain writing, first writing and reply fields. Restoring text without an active editor does not summon her. Multiple marks during editing collapse to one pending response, acknowledged after the editor and covering presentation close. Pippa stays still during typing. This does not locate or fly to a typed glyph.

Performance boundaries:

- UIKit shake events; no additional Core Motion stream, polling loop or permanent animation timeline.
- The existing Pippa Canvas and its frame rate remain. Its old per-frame word-text rendering is removed.
- Only one delivery can run; deliberate interactions have an eight-second cooldown. A card in flight does not intercept touches.
- The native card's finite geometry animation changes its transform while preserving text layout. Once dropped it rests without an animation timer.
- Archive replacement schedules debounced background preparation after the Keep reply is quiet. Work runs on a separate actor, hashes actual reader text to reuse unchanged results, and checks cancellation/revision before publication. It never scans the archive during view construction, a shake, or a rendering frame. The reading desk is observed by Pippa, not by the whole ContentView.
- Edits, removals, reloads and failed-save rollbacks all refresh the prepared deck. A changed observation dismisses an obsolete open card. The preparation is asynchronous, so a deck can briefly reflect the preceding archive while it refreshes.
- Editor focus, presentations, backgrounding and size changes dismiss the active delivery. The passive shake receiver never takes focus from a text input.

Validation and remaining device checks:

1. Passed: all seven `PippaWordFindsTests` for provenance, deduplication, recency, counts, real connections, removals and typed exclamation changes, using an isolated XCTest bundle.
2. On the phone, shake repeatedly before and during a card's flight. Check the tow/release timing and card readability, and tap nearby controls during flight.
3. Type `!` in an inline folio field, a plain Page, and a reply; keep/dismiss the editor and verify exactly one visible acknowledgment. Check dictation and a hardware keyboard without focus loss.
4. Keep fresh writing beyond the first six days; confirm it can appear. Edit/delete its Page and verify stale finds disappear after preparation.
5. Check Reduce Motion, VoiceOver, the largest text sizes, landscape and iPad layouts. Inspect dropped-card placement against actual Book geometry.
6. Profile frame times and Keep/page-turn latency against the same archive and device state before and after. Source structure and parsing cannot prove smoothness or zero performance impact.
