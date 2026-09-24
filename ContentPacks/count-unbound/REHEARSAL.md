# Opening walkthrough

## September 23: delivered Radio and shelf rehearsal

The five delivered Count clips decode as MP3, were converted to 64 kbps mono at
44.1 kHz, and are leveled to about -18.4 LUFS. Offline speech recognition
matched the main spoken copy in four clips. It exposed that the Mothlight file
contains the earlier “The listed names are home … Hold on” take; the Reader
chose to keep that take, so the pack caption and recording sheet now match it.
The recognizer heard Penny's final “Kitchens door” as “kitchen store”; that
homophone still needs a human listening check. Speech recognition does not prove
character voice, sound effects, or device intelligibility.

`python3 scripts/monthly_issue.py rehearse ContentPacks/count-unbound` prepared
and signed all 36 assets with a throwaway key, then served the exact bytes through
the local Worker at foreshadow, live, residue, after-residue, and casebook edges.
No asset was uploaded or published. In the isolated Monthly Reader QA simulator,
a temporary date-shifted Count import selected the foreshadow Thornwave clip
through the normal radio player. iOS Now Playing showed “DJ: Wicker Eddies” for
7.99 seconds, the player advanced to the next Thornwave track, and the vault
saved a `played` receipt for `count-unbound.radio.thornwave-corners` in the
`count-unbound:2026` run. The two temporary simulator files were removed;
the existing QA library was preserved. This proves one clip's player and receipt
path, not all five date gates or a complete Reader playthrough.

The focused native suite passed 75 tests with one skipped (Count opening,
monthly rehearsal, mark shelf, and edition quality). The skipped optional test
requires an external prepared fixture. The real October date windows, full
choice flow, caption fallback, and rendered October art still need app review.

Use the isolated **ReEnchanted Monthly Reader QA** simulator. Do not copy a real
Reader's library into it. This is an unpublished, locally imported draft, not a
signed delivery or billing rehearsal.

1. Build the current app for that simulator after build authorization.
2. Copy the opening JSON to a temporary file and change only the event calendar
   start date to three days before today. This rehearses October 4 without
   changing the Mac clock or the canonical October content.
3. Put that copy in the simulator app's Documents directory with the suffix
   `.reenchantedevents.json`. Never put it in an app resource directory.
4. Save a clearly synthetic ordinary sentence using Capture → Text.
   Monthly stories are currently free, so no local StoreKit purchase is needed.
   The shortcut does not grant access; it still uses the current monthly-access
   policy and the imported pack's ordinary date gate.
5. Launch the Debug simulator app with
   `--smoke-authored-story count-unbound.scene.sunday-jump`. This opens the
   eligible imported scene through the normal authored compositor. It does not
   reset receipts, seed attendance, grant entitlement, or bypass Keep validation.
6. Enter, Keep, and reopen the same scene. At the safety check, verify the ribbon
   is selected by default. Select the synthetic sentence; quotation must start
   off, and choosing a different sentence must turn it off again.
7. Keep a safety-check choice. Relaunch and reopen to verify saved progress.
   Keep an intervention and reopen the return. Check that the return recognizes
   the detail without putting its exact words in the kept return leaf.
8. Keep the return. Verify no active Jump remains and the completed invitation
   no longer surfaces. Inspect receipts separately from visual observations.
9. Remove only the temporary imported draft after testing. The synthetic kept
   pages remain evidence in this isolated simulator; they are not actual life.

For a native class, letter, or residue Page, launch the same isolated Debug
simulator with `--smoke-world-event-beat` followed by an eligible beat ID. The
shortcut asks the ordinary event resolver for that Page, so its calendar window
and saved disposition still apply. It does not grant access or reset receipts.

September 23 small-media check: a shifted local draft opened the roster class
and Permancer letter on their eligible days. The first pass caught the generic
classroom and sealed-letter renderers replacing the authored text. After the
presentation fix, both showed the pack's exact prose with ordinary Keep/Wait
controls and no invented class exercise or Belief cost. The simulator build and
30 focused core tests passed. The shifted import was removed afterward; no
Reader choice or monthly release was published.

The same QA simulator then opened the map-room Page through Penny's public
East Stacks report. Keep returned to the desk; relaunch did not offer that Page
again. The Dracula question Page initially printed manuscript `*` and `>`
markers literally. The rebuilt authored-prose renderer now shows the book
title in italics and the pencilled quote as an inset; a simulator screenshot
verified the final leaf. The question and consequence buttons still need a
hands-on walkthrough. The shifted import was removed after this pass.

Separate core tests cover ribbon fallback, private wording, mismatched visits,
late reports, declined invitations, unfinished-visit expiry and braid choices.
They do not replace this walkthrough. The preview clock is shifted; the real
pack remains scheduled for October 2026.

## September 19 checkpoint

The simulator rendered the Sunday invitation and its choices. The initial
rehearsal lacked monthly entitlement; the shortcut now applies the same runtime
access gate before opening a draft as choices and Keep use.

After access was established, choosing Enter still closed the sheet. A visible
choice tap recorded the acted/recognized learning events, confirming that the
callback ran. Source tracing found `publishStoryResultLeaf` publishing a generic
result leaf, whose insertion dismisses the open sheet. Authored scenes now skip
that insertion and retain their inline result until Keep commits the node.

Xcode's local transaction manager showed a purchased, nonrenewing test
subscription, while the simulator StoreKit log returned zero transactions to
the app's update query. Restarting the isolated simulator did not establish
access. This does not establish a production billing failure or a successful
subscriber rehearsal. Debug-only query counters now distinguish no results,
unverified results, and granted packs without logging receipts or account data.

The rebuilt app reported `received=0, unverified=0, granted=0`, confirming an
empty response rather than failed verification. After restarting the simulator,
the normal in-app purchase displayed the explicit no-charge Xcode sheet and
completed successfully; the app saved `standing-order` in its shared vault.
Use that purchase flow rather than relying on a transaction-manager insertion.

The story sheet initially opened at the medium detent, leaving its choices
below the visible prose. Authored scenes now request the large detent at the
presentation boundary as well as the capture view; the full-height layout was
visually verified. Touch/scroll automation did not move the content. A read-only
UIKit inspection confirmed enabled scrolling, content taller than its viewport,
and hits reaching its content container. Debugger positioning brought the
choices into view; this does not prove normal finger scrolling.

Still required: normal finger scrolling and ordinary discovery/continuation
without the launch shortcut. The app walkthrough below used accessibility
activation; it does not establish those gesture and discovery behaviors.

Validation at this checkpoint: the simulator build succeeded after the access,
diagnostic, and presentation changes. The existing core test binary was rerun
with `swift test --skip-build --filter 'CountUnboundOpeningTests|MonthlyIssue'`:
60 passed, one skipped, zero failures. No core source changed during this
checkpoint. These results do not complete the interactive walkthrough.

September 20: the corrected choice remained selected, displayed its inline
answer, and enabled Keep. Keep saved a `nodeCompleted` receipt with `enter`.
Relaunch resumed the safety-check node with the class ribbon selected. The
signed app library then received a synthetic cup sentence through Capture → Text.

The September 20 walkthrough then completed the supervised route through the
actual app UI, relaunching between nodes:

- Selected the synthetic cup sentence. Quotation was off, could be enabled,
  and reset to off after selecting the ribbon and reselecting the sentence.
- Kept `check-list`. The persisted active Jump contained its source ID,
  `authoredAnchorMayQuote: false`, and `anchor: "the detail you gave me"`.
- Relaunch opened the intervention. Chose and kept `call-permancer`; the node
  receipt persisted and the real Jump advanced to depth 2.
- Relaunch opened the return. Keeping it cleared the active Jump, recorded one
  returned visit, and wrote terminal `nodeCompleted`, `completed`, and `kept`
  receipts. The kept return contains "I still have the detail you gave me";
  none of the kept story pages contains the synthetic cup sentence.
- Another relaunch logged no eligible Sunday scene while the verified Standing
  Order remained active (`received=1, unverified=0, granted=1`).

The final choice fix built successfully in `/private/tmp/count-choice-keep-build.log`.
The temporary scheme argument was restored and the clock-shifted draft removed
from this simulator's Documents. Kept test pages and receipts remain in the
isolated QA library. No content was published, real account charged, or Rabbit
installed. The local Xcode test subscription remains available for further QA.

## Continuation follow-up

Source tracing found that post-Keep continuation preparation used unresolved
`sourceInputs`, whose monthly scene and manifest lists are empty until installed
packs are merged. The lookup now resolves world events first, applies authored
marginalia, and checks the runtime access/lifecycle gate. Keeps on deeper folio
leaves now replace the outgoing leaf in place (or remove a terminal leaf), rather
than leaving its successor only on the desk's candidate bench. A leaf also in
the opening desk is handled by the existing desk retirement path to avoid a
duplicate successor. Only newly admitted deeper successors record delivery.

This patch still needs an ordinary in-session continuation walkthrough. The
completed Jump walkthrough above predates it and used relaunches between nodes.

The first continuation build passed, but the classroom Keep was followed by an
unrelated souvenir in the visible slot. The follow-up now preserves a validated
same-scene successor directly in its opening slot, reconciles the desk, records
its delivery, and avoids the generic replacement ranking. This final slot
change requires its own runtime check; the first build does not prove it.

The slot build passed. In the wrong-way classroom walkthrough, choosing “Class first. Roof after.” displayed the authored consequence and Keep logged `Authored continuation prepared: true`. The folio did not visibly settle on the follow-up. Console evidence also showed launch enrichment publishing after the smoke scene opened. The simulator-only smoke setup now invalidates that pending build token and begins its temporary desk explicitly, instead of duplicating the scene in deeper pages. This last rehearsal correction passes Swift parsing and diff hygiene but has not been rebuilt or walked through. Same-session continuation remains unverified. The temporary launch argument and clock-shifted draft were cleaned up; saved choices remain.

## September 20: same-session East Stacks continuation

The stable-desk build passed (`/private/tmp/count-stable-rehearsal-build.log`).
Using a simulator-only day-nine draft and the existing Xcode test subscription,
selected `move-map`: the sheet showed “Her hand closes on its edge.” Keep
persisted that choice, its frozen braid text, and the next-node ID. Without
relaunching, the folio visibly rendered the after-node beginning “His fingers
were coming apart,” and advanced through its first three leaves.

A later refresh replaced that scene with the unfinished onboarding ceremony.
This isolated library deliberately enters the story before completing onboarding;
the simulator-only authored smoke route now prevents that ceremony override.
The follow-up build passed (`/private/tmp/count-rehearsal-ceremony-build.log`).
Release onboarding behavior is unchanged. The existing compiled core suite
was rerun with `--skip-build`: 61 executed, one skipped, zero failures. No core
source changed during these UI fixes.

The follow-up run resumed the saved East Stacks after-node with its full authored
text. Keeping it wrote the terminal `nodeCompleted`, `completed`, and `kept`
receipts; the debug log correctly reported no further continuation. The
same-session choice-to-after transition was visually verified before this
restart; the restart separately verifies resume and final disposition.

A final relaunch logged no eligible East Stacks scene while entitlement verification still reported one verified grant. The temporary calendar draft was removed and the scheme restored to its disabled default argument. No billing charge, publication, Rabbit installation, or saved-choice reset occurred. Remaining visual checks include ordinary touch scrolling and a complete uninterrupted long-scene read after the debug ceremony fix.

## Background refresh protection

Source review found that all authored narrative scenes share a source/type desk
slot. Ordinary survivor refresh used the first newly ranked candidate in that
slot, allowing a different scene to replace the admitted passage. The refresh
path now retains authored scene snapshots; explicit Keep/Trash and the existing
monthly access/expiry cleanup still control removal. Ordinary survivors retain
their previous refresh behavior. This adds one metadata check per published
page and no additional archive scan or content generation.

Freshly compiled regression tests cover the shared-slot collision and ordinary
survivor updates. `swift test --filter 'BookDeskRoundTests|CountUnboundOpeningTests|MonthlyIssue'`
executed 80 tests: one skipped, zero failures (79 passed).

The app build containing survivor protection passed (`/private/tmp/count-survivor-build.log`). A temporary five-passage layout fixture rendered in the classroom ending sheet, but automated drag and scroll did not visibly change its position. Touch scrolling remains unresolved: this does not establish whether app gesture handling or automation is responsible. No fixture text was kept. The temporary draft was deleted and the scheme restored to its disabled default.

## Runtime 5 continuity checks

The climax now uses a reusable carried-choice mapping and an authored finding
insertion. The selected preparation persists into the final method; without a
prior selection the Reader chooses among all three. A completed finding supplies
only its actual Reader sentence, scoped to issue and run. Missing/deleted evidence,
acceptance-only receipts, generated prose, and a different run use the fallback.
Construction interpretations affect only the authored threshold.

The selected core suite executed 71 tests: 70 passed, one skipped. It includes
all ending routes, relationship suggestions, cross-run isolation, missing evidence,
Reader-versus-generated provenance, and carried-choice checks. The new runtime
requires a fresh app build and visual climax walkthrough; core results do not
establish those UI checks. No issue was published.

The fresh simulator app build passed (`/private/tmp/count-runtime-five-build.log`), including removal of the extra sentence permission controls. Runtime-5 climax visual verification is still pending.

Catch-up core tests cover a Reader arriving October 29: prior return is reported, naming can complete, no return participation or romantic choice is invented. The third-crossing independence persona explicitly dismisses unrelated story offers. Untouched-offer starvation remains tracked in IMPLEMENTATION.md.

Offer-fairness regression: third crossing is accepted and completed by a late Reader who leaves unrelated stories unresolved. Same-run opening history rotates the candidate opportunity; absent or other-run history preserves ordinary priority. Published content and ledger state remain intact. Reservation selection honors the fair candidate while retaining its existing daily claim limit. Core tests pass; no fresh app build or device walkthrough was run for this patch.

### Fourth crossing window and source validation — September 20

The fourth invitation is placed in climax (October 22–28), with accepted returns available through October 31. The model rehearsal verifies acceptance, an October 31 completion without earlier scene attendance, and no fresh invitation for an October 29 arrival. This models scheduling; it does not prove the capture-sheet selection UI.

The selector remains bounded to 32 recent Reader contributions. Save-time resolution now looks up the selected source page and contribution directly, so newer entries do not invalidate an already selected source. Regression checks cover deletion, sensitive source pages, invalid contribution indices, and generated prose with no Reader contribution.

`swift test --filter 'CountUnboundOpeningTests|MonthlyIssue|AuthoredFindingInsertionTests|BookDeskRoundTests'`: 95 executed, 94 passed, 1 skipped, no failures. Log: `/private/tmp/count-fourth-crossing-verification.log`. Printed facing-page pairing, older-observation search, and device verification remain outstanding.

### Publication and older-observation rehearsal — September 22

The synthetic monthly interior rendered at `output/pdf/observation-pair-monthly-proof.pdf` (24 pages, 450 × 666 pt), and the chaptered seasonal interior at `output/pdf/observation-pair-seasonal-proof.pdf` (32 pages). In both, the short pair faces across pages 8–9. A long first sentence continues through page 14, with its final page facing the second sentence on page 15. Text extraction found all 64 repetitions of the long phrase and its final clause once in each PDF. Visual inspection caught a paper scrap overlapping a heading; the dedicated pair pages now use a clear background and were rendered again. These are synthetic interiors, not a full October issue or Lulu proof. Annual shares the chaptered renderer but was not separately rendered.

The first synthetic print attempt exposed an edition-curation bug: two Reader replies sharing the Book's prompt were deduplicated by `userInput`, so no pairs reached the PDF. Curation now preserves distinct Reader contributions and authored scenes with a shared frame. In the synthetic 40-page weekly issue, exact paired sentences appear together once on their day page (page 16), rather than repeating in the fixed binding slots. Pages 4 and 16 were visually inspected.

The fourth-crossing selector now searches the complete eligible kept-page inventory, returning at most 32 visible matches. A selected sentence remains visible if the query changes; save-time source validation remains authoritative. Core tests cover an older sentence beyond the recent window, case/diacritic-insensitive search, result bounds, and exclusion of sensitive and Book-only material. `swift test --filter 'CountUnboundOpeningTests|EditionCuratorTests|BindingStoryPromptTests|MonthlyIssueNativeContentTests'` passed 64 tests (`/private/tmp/count-search-tests.log`), and the simulator app build passed (`/private/tmp/count-search-build.log`). An interactive capture-sheet walkthrough, complete October literary review, and customer print remain open.

### Four-phase production gate — September 22

The authoring manifest now identifies all four phase openings and has production-count requirements for the story spine, four crossings, temporary marginalia, radio, Bleed, letters, class responses, and November residue. The phase event's reader-facing `scene` fields no longer expose the placeholder instruction “Use only encountered authored scenes”; those scenes use the authored Book openings. The generator-facing packets distinguish phase atmosphere from Reader attendance and choices. The global event logline no longer reports a Jump outcome before October 4. This follows the final `WorldEventPageSourceAdapter` path, which uses `scene` for reader copy and `packetLine` for generation context.

Working validation has no structural errors and warns for the six unproduced media/residue groups. A ready native Story Page now satisfies the validator's authored phase-beat requirement; this avoids requiring a duplicate World Event beat. Release validation remains invalid for those six groups, and a missing native phase opening remains a release error. `swift test --filter 'CountUnboundOpeningTests|MonthlyIssueAuthoringTests'` passed 34 tests after this validator change (`/private/tmp/count-phase-native-opening-tests.log`). No fresh app build or live screen capture was used to claim phase-copy visual quality. Interruption recovery and full media production remain open.

The completed Future Tense terminal node now marks the issue concluded. The same receipt closes earlier live offers, while Nightbound Morning, After the Last Lesson, and an already accepted Go Back Once return retain their own dated windows. All three ending-route simulations still reach the aftermath; their tests assert the conclusion receipt, prior-offer closure, and survivor policy. The focused 34 tests passed again (`/private/tmp/count-conclusion-tests.log`). The October 28 scene still needs a separate rule for a Reader who opens it but cannot finish before midnight; its public report must not spoil that unfinished route.

### Interrupted ending continuation — September 22

An October 28 opening now authorizes only that issue/run's unfinished Future Tense to resume through October 31. The shared monthly resolver, Story Page curation, and use-time access check all resolve the separate follow-up window from the existing opened/node receipts. The current node and chosen route remain in the same ledger. A never-opened Reader cannot start the ending in aftermath. While the route is unfinished, the Nightbound dependency cannot substitute the public outcome report, so naming waits; an unstarted late Reader may still receive that truthful report. The resumed Terms route was walked through its final node on October 31 in the core test; completion releases Nightbound Morning without injecting the public report. Trash closes the continuation. The pack requires runtime 7 so older builds reject the new field. The broader monthly/binding suite passed 89 tests, one skipped, zero failures (`/private/tmp/count-continuation-broad-tests.log`), including curation, use-time access, no-access denial, November 1 expiry, late-reader report, and unsupported runtime 6. It initially exposed nondeterministic JSON key order in frozen publication tags; the serializer now uses sorted keys, and the rerun passes. This is core rehearsal, not a device walkthrough or full October playthrough.
