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

The synthetic October edition proof exposed a numeric foreword drop cap that
split “37 pages” across two lines. Monthly and seasonal/annual forewords now
reserve drop caps for leading letters; the regenerated foreword pages were
visually checked. The bound-item composer fits a kept mark inside its existing
86-point pagination allowance. The weekly issue now draws one retained mark
on the corresponding day even if the marked Page was not its selected prose
excerpt.

For a repeatable Count-bearing proof, put the real square and wide PNGs in the
isolated simulator's `Documents/edition-proof-input/`, then launch the Debug app
with `--smoke-edition-proofs`. The harness puts those marks on synthetic October
keeps in the October 8–14 weekly window; it never alters a Reader library. This
pass used `black-cat.png` and `closed-books-loud.png`. Both appeared in the
weekly reading copy and print interior, monthly interior, seasonal interior,
and annual interior. Their pages were rendered and inspected for legibility,
spacing, and no overflow. The five PDFs built at 40, 40, 32, 58, and 238
print pages respectively. This proves retained-art print composition on
synthetic pages, not live October placement or customer paper proof.

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
   is selected by default. Select the synthetic sentence. There is no separate
   quotation permission control: selecting the sentence carries its exact words
   into the supervised Jump. Choosing the ribbon instead clears that selection.
7. Keep a safety-check choice. Relaunch and reopen to verify saved progress.
   If the sentence was selected, verify the active Jump retains its source ID
   and exact anchor. Keep an intervention and reopen the return. Check that the
   return recognizes the selected detail, while the kept story Page still
   distinguishes Reader words from the Book's authored prose.
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
actual app UI, relaunching between nodes. It predates the removal of the
separate quotation control; its off-by-default result below is historical
evidence, not the current expected behavior:

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

### Current-app QA simulator walkthrough — September 25

The current shared worktree built for **ReEnchanted Monthly Reader QA** with
Xcode 26.6 (`/private/tmp/count-unbound-final-qa-build.log`) and installed as
`com.openclaw.enchantify.insidecover`. This build includes concurrent Gemma
worktree edits, so the build result applies to that whole source snapshot.
No issue was uploaded or published, and no payment or print order was made.

An isolated, date-shifted import opened Sunday Book Jump Club through the
Debug smoke route and the ordinary monthly access and scene resolver. The
visible invitation offered Enter/Stay. Enter displayed its inline answer and
Keep advanced to the safety check. The class ribbon was selected by default;
this QA library had no eligible Reader sentence. Selecting “The way home”
displayed its consequence, and Keep advanced to **One verb** in the same
session. Selecting “Tell Wicker to cross it out” showed its consequence; Keep
advanced to **Every named traveller**. A relaunch resumed the return, whose
Keep wrote `nodeCompleted`, `completed`, and `kept` receipts for
`count-unbound:2026`. A further launch did not offer Sunday again.

The same isolated import was shifted to day 27 and opened **A Future Tense**.
The visible page included the truthful East Stacks dependency report. Selecting
Return by Terms showed its answer; Keep advanced to the Terms leaf in the
same session. After shifting only the temporary import to day 30, a relaunch
resumed that saved Terms route. Keeping Terms advanced to **The claim is hers**;
keeping that leaf wrote terminal `nodeCompleted`, `completed`, and `kept`
receipts. A further launch did not offer the ending again. The temporary
import was removed from the simulator; synthetic kept Pages and receipts
remain in its isolated library.

The same simulator then kept a clearly synthetic sentence through Capture →
Text. A day-21 Go Back Once invitation survived the concluded issue. After
acceptance, its return sheet offered that exact kept sentence as the first
visit. A second synthetic sentence enabled Keep; the Book answered that it
would leave the visits facing each other. The same run's ledger contains
`accepted`, `completed`, and `kept` receipts with one evidence Page on the
completed return. This verifies the capture-sheet selector and save path,
not a real-world return or a bound-edition pair.

At the shifted aftermath window, **The First Nightbound Morning** and
**Threshold Protocols** both opened after Future Tense had concluded and were
kept. **The two looks** rendered both synthetic Reader sentences verbatim in
its visible Page, then kept. The October **After the last lesson** Page offered
Soren, Wicker, or an evening of Serenity's own. Choosing Wicker and keeping it
carried exactly that occasion into the residue window; the November entry
offered only the table with Wicker. Its conversation offered two distinct next
steps, and the chosen notice-revision route produced a separate terminal leaf.
The ledger shows completed and kept receipts for the morning, protocols, pair,
October choice, and November scene. The temporary aftermath import was removed.

This verifies those paths on the current app build. It does not yet verify
ordinary discovery without a smoke argument, a Reader sentence carried into
the Jump or climax, the other ending routes, late-reader reporting, audio,
actual nightly braid, bound editions, or physical print. Automated simulator
drag/scroll still did not move the long capture sheet; accessibility activation
of an offscreen choice did bring it into view. Normal finger scrolling remains
unproven and should not be inferred from that accessibility behavior.

The current-worktree targeted core run
`swift test --filter 'CountUnboundOpeningTests|MonthlyIssue|AuthoredFindingInsertionTests|BookDeskRoundTests'`
executed 112 tests: 111 passed, one skipped, zero failures
(`/private/tmp/count-final-runtime-core-tests.log`).


### Aftermath retirement correction — September 26

The isolated Monthly Reader QA library had completed Future Tense and naming.
At live day 29, `count-unbound.radio.protocols` was rejected by the ordinary
Radio eligibility gate. The conclusion receipt closed every live atom without
`survivesConclusion`, including five pieces deliberately authored for aftermath:
Serenity's naming marginalia, Penny's protocols broadcast, the returned-Count
Bleed report, Stonebrook's rest class, and Wicker's letter. Those five atoms now
use the existing survival flag. Their original date windows and then-current
once-per-run policies remained; the Radio policy was revised later below. The
small-media synchronizer preserves the flag on regenerated
aftermath articles, classes, and letters.

The full Count opening suite passed 34 tests with zero failures
(`/private/tmp/count-aftermath-media-tests.log`). The new resolver regression
uses a concluded ledger and completed naming, checks all five media, suppresses
already-delivered content, and rejects them on November 1. Its follow-up checks
both audio `played` and caption-only `delivered` retirement. After updating only
the local draft in the simulator, Penny's protocols clip started and the vault
saved a `played` receipt for the same `count-unbound:2026` run. No scene receipt
was forged or erased.

A fresh **ReEnchanted Count Radio QA** simulator was created for the remaining
checks. The earlier broadcasts were withheld while their required scenes were
unfinished. Sunday Jump was completed through real UI choices (including Call
Permancer), and relaunch resumed each saved node. The Mothlight follow-up then
played and advanced into The Longer Road, with its own `played` receipt. On this
fresh library, skipping onboarding did not give clear in-session continuation;
ordinary discovery and cold-reader continuation still need dedicated review.
The late-reader Nightbound opening showed public return history, without
claiming the Reader attended the ending, and was kept through the UI.

These Radio walkthroughs exposed a separate display defect: opening the Radio
Page during an existing broadcast classified the untouched default 94.1 dial
as static, hiding the active station and DJ caption while audio continued. The
Page now treats genuine tuning noise or a Reader-moved dial as static, allowing
an untouched dial to initialize from current playback. Build and post-install
verification are recorded below when complete.

A new local candidate was signed at
`~/.reenchanted-publishing/releases/2026-09-26-count-unbound-2026-10-candidate`.
All 38 assets passed the publication dry run. The September 24 candidate lacks
this aftermath correction and must not be used for publication. Nothing was
uploaded or published.


The current-worktree simulator build succeeded
(`/private/tmp/count-radio-caption-build.log`) and was installed and launched
in Count Radio QA. With only the local draft's protocols asset name changed to
an intentionally missing file, the normal player showed Fae-Fi at 88.3, `DJ:
Penny Blackletter`, and the full matching caption in the accessibility tree.
It saved `count-unbound.radio.protocols` as `delivered`, not `played`.
Under the then-current once-per-run policy, relaunching the same offer did not
start another broadcast: Radio was cold and only one delivered receipt remained.
Ordinary power-on started a Fae-Fi track;
power-off stopped it. An accessibility slider setter changed its AX value but
not its displayed frequency, so this does not verify finger-controlled tuning.
Normal touch scrolling and dial manipulation remain device checks.
The extra caption-receipt suppression regression passed
(`/private/tmp/count-aftermath-repeat-tests.log`). Regenerating small media in a
temporary folder retained all five aftermath survival flags. `git diff --check`
passed. No new physical-device installation was performed.

Both temporary date-shifted imports and their ten copied audio files were
removed after terminating playback. Synthetic kept pages and real rehearsal
receipts remain in the isolated libraries. Radio receipt evidence is saved at
`/private/tmp/count-radio-caption-receipts.json`. The two remaining recorded
clips (Serenity awake and Wicker's one sentence), ordinary discovery, and the
other interaction/edition release gates remain open. No release upload,
payment, or print order was made.

September 26 provenance check: a fresh Finding QA simulator opened the local,
date-shifted third crossing and kept the synthetic sentence “The latch was
smooth outside and scratched behind the door.” directly from the folio. The
archive stored that sentence as `playerReply` on the private return Page, and
the `completed` and `kept` receipts point to that exact Page. This exposed and
then verified a repair: before it, folio Keep left `playerReply` empty, so
Penny's later callback ignored the sentence even though the Page displayed it.
The Capture-sheet format and plain folio format now have the same Reader
provenance. The focused callback regression uses a completed same-run receipt
and the kept Page to verify the exact sentence is inserted; the optional
Gambit choice had already been exercised with the second crossing in Count
Radio QA. On the fresh simulator the strategy scene initially stayed closed
because the prerequisite Dracula encounter was incomplete. After shifting
only the local draft to day 14, the missed-East-Stacks public report opened
Dracula's question; “Would you do it again?” and its continuation were kept.
The draft was then shifted to day 17. The Gambit route opened, its paper-room
choice was kept, and Penny's final leaf visibly quoted the exact latch sentence.
Penny also made her separate BACK-card check because this Reader had not made
the fourth-crossing pair. The final Gambit leaf has `completed` and `kept`
receipts. This is an app callback proof for the Gambit route; the Terms/Hunt
variants and climax reuse still need their own device pass.

The full Count test group passed (35 tests), as did the 13 Python pack tests.
The current issue now requires runtime 10. A replacement candidate was signed
at `~/.reenchanted-publishing/releases/2026-09-26-count-unbound-2026-10-candidate`;
its runtime asset declares 10, its envelope and all 38 assets passed the
publication dry run, and nothing was uploaded. The preceding runtime-9
candidate was moved aside under the `prior-runtime9-candidate` suffix.
The runtime-10 simulator build passed
(`/private/tmp/count-provenance-runtime10-build.log`), was installed into
Finding QA, and launched to the ordinary Book Today screen. Both temporary
date-shifted imports were removed from their isolated simulators after the
apps were terminated. The synthetic pages and receipts remain in those QA
libraries; no customer data, live subscription, or print order was involved.
The runtime-10 local Worker lifecycle rehearsal also passed all foreshadow,
live, residue, retirement, and December casebook windows
(`/private/tmp/count-runtime10-lifecycle-rehearsal.log`).

Later September 26 prose revision: the creator manuscript and runtime pack now
carry revised Book narration, choice braid lines, November occasions, and the
East Stacks Bleed report. The pre-revision signed candidate was preserved as
`2026-09-26-count-unbound-2026-10-pre-claude-prose-candidate`; a replacement
candidate at the usual `...-candidate` path contains the edited runtime pack
byte-for-byte (`runtime.v1` SHA-256
`b81600c6cb5f6aa78da7bd61bd5239724f267302f32b39bf8922e0a6c3b50e71`).
The new envelope and all 38 assets passed the publisher dry run. The 35 Count
tests, 13 Python pack tests, and local Worker lifecycle rehearsal passed.
`complete_small_media.py` now replaces its authored entries in place: a repeat
sync on a temporary copy leaves the checked-in pack byte-for-byte unchanged.
An isolated, date-shifted runtime-10 simulator import displayed the revised
“I've held open heavier books than this” climax line. That smoke check did not
play the revised ending or inspect its braid. The temporary import was removed
after terminating the app. No upload or publication occurred.

Revised-prose continuation: the existing runtime-10 Count Radio QA simulator
received a fresh, temporarily date-shifted copy of the edited pack. On live
day 27, **A Future Tense** displayed the exact kept porch-lamp sentence and
the revised threshold reply. The previously chosen paper-room preparation
limited the method to Return by Ruse. Its choice, Ruse consequence, and
Serenity's withdrawal were read and kept in order. The receipt ledger records
the revised Ruse braid lines, `completed`, `kept`, and the final evidence Page.
An older public `reported` receipt also remains in this synthetic library
from an earlier date-shift rehearsal; this walkthrough is not a normal
chronological Reader history.

On shifted live day 29, the already-kept Nightbound Morning allowed **After
the last lesson**. The Reader suggested Wicker's conversation. In residue,
the November entry offered only that carried plan; the revised Kitchens scene
offered two second choices. Choosing **Leave the clasp. Give her time.** led
to the revised terminal leaf, which kept Wicker's answer without writing
forgiveness into Serenity's margin. The October and November receipts retain
the selected choice IDs, the revised braid lines, and final `completed`/`kept`
evidence. This is one revised ending and one November route, not a proof of
the alternate routes or an actually generated nightly braid. The temporary
import was removed after terminating the simulator app. No build, upload,
payment, or print order was made in this pass.

The same synthetic library then made a nightly Book of You page through the
normal `--smoke-braid` route. Its saved text carried the exact porch-lamp
sentence and two frozen authored passages; the page tags contain the matching
braid and publication receipt IDs. This was the handcrafted fallback, with
`local-model-missing` recorded. The backlog deliberately takes at most two
committed passages per night, oldest first, so the later Ruse ending and
November receipts remained for later nights in this compressed QA history.
This proves receipt insertion and retention on a real saved braid, not Gemma's
voice or a normal October cadence. A coverage audit found that two braids on
one day could make an earlier braid's receipts look pending again; the check
now reads every saved Book of You page, with a focused regression case.

Gemma 4 E2B's model files are present on the Mac at
`~/ReEnchanted-models/gemma-4-e2b-it-4bit`. The iOS Simulator explicitly
excludes the app's MLX generation path, and the Mac's installed Python
`mlx_lm` cannot load its `gemma4` architecture. Neither environment supplied
a valid app-model rehearsal. A device run with the app's MLX path remains open.
The QA library's pages are dated September 26; the binder only admits closed
months, so it cannot turn that still-open synthetic month into a final edition.
Earlier synthetic October PDF proofs establish layout for the paired Reader
sentences and retained marks, but not this saved braid's appearance in a bound
Reader PDF or a customer print.

Rabbit follow-up on September 26: the full shared-worktree Debug app built for
the iPhone 15, installed, and launched. Rabbit's active local model marker
selected `mlx-community/gemma-4-e2b-it-4bit` at the expected revision, with
the weights and tokenizer present. The isolated `--proof-braid` harness then
ran one synthetic `crossing` brief from `BraidBench` through the same MLX text
generator, sampling, and 224-token ceiling as a device braid. It stopped on
its own after 161 generated tokens; the proof recorded 615 prompt tokens,
2.02 generated tokens/second, 122.3 seconds overall, and serious thermal state.
Its text carried the brass lamp, fox, root bridge, and straight frost line, but
also invented sparks and “tiny tools” for the Reader's rewiring and used the
flat phrase “quite remarkable.” The harness only finishes the raw text and
repairs point of view; it does not run the full braid audit or keep a Page.
This is a successful device-model invocation with literary observations,
not a completed Count Unbound nightly-braid walkthrough. The app's ordinary
Reader-facing braid and a bound October edition still need direct proof.
Additional tale-related changes landed in the shared worktree after that first
device build. The 69 focused Tale/BoundVolume tests passed; a second Debug
device build from the updated complete worktree succeeded and was installed
and launched on Rabbit. iPhone Mirroring showed the Book Today screen after
launch, and the device crash-log listing returned no `InsideCoverApp` report.
The Count suite passed 35 tests, monthly-native suite 23, and `git diff --check`
passed. This confirms compilation, deployment, and opening the Book, not an
October scene on Rabbit or the normal Gemma braid/edition path.

The first follow-up fidelity comparison was unverified: concurrent Claude
processes used Rabbit's same proof directory, and the retrieved result belonged
to the earlier run. After Claude finished, the complete shared-worktree Debug
app rebuilt successfully and was installed on Rabbit. The harness now writes
a run ID, start time, empty result list, and `done: false` before generation.
A device read during generation confirmed that fresh state, followed by a
completed result with the same ID. This directly exercises stale-result
retirement instead of relying on parsing alone.

The isolated stricter-instruction run `crossing-fidelity-fresh-20260926` began
at `2026-09-26T19:39:43Z`, with run ID
`4A7BB30B-D9FA-434F-970A-DB6FF9434DA2`. It stopped naturally after 131 generated
tokens, with 642 prompt tokens, 5.14 generated tokens/second, 39.4 seconds
overall, and fair thermal state at completion (nominal at start). These are
Debug observations, not Release performance claims. The source Reader account
was only “You rewired the brass lamp in the hallway.” The result still added
“Later, you moved to the window.” It also gave the lamp an emerald filament
and changed the supplied “Frost has never once done a straight line” into a
present-tense sentence despite the past-tense commission. The stricter prompt did not eliminate scene embellishment; the production
instructions remain unchanged. The creator clarified after this comparison
that Gemma should have room to merge fiction and reality. The emerald lamp
and a small movement within the telling are therefore literary latitude,
not automatic Reader-trust failures. Review should distinguish those from
contradicting an explicit Reader fact or assigning consequential real-world
experiences or unreported feelings.

The current plain-prose nightly path runs `BraidOutputAudit` and point-of-view
repair, but does not invoke the older marked-draft fact verifier. The four
Reader-trust findings in that audit are limited to shadow-material nights;
they do not establish a general guard against new Reader actions on ordinary
nights. That observation does not justify reinstating the older exact-fact
contract: the creator explicitly permits fictional scene development. No
action-vocabulary blacklist or stricter production prompt was added. Keep
explicit Reader facts authoritative and preserve the existing boundaries
around unwanted consolation, meaning, interiority, and false resolution. The isolated proof saved no Reader Page. Rabbit was relaunched
without `--proof-braid` after the comparison.


### Production Gemma braid through an isolated archive and editions — September 26

The Debug-only `--proof-count-braid` mode uses `Documents/count-braid-proof/input.json`
with a copied QA `day` and actual authored `receipts`. It calls the production
`MLXBookBraider.braid(day:context:)`, the monthly passage binder, source-Page
annotation, and `BookArchiveDatabase.saveDays/loadDays` against a fresh store
inside that proof directory. It never swaps the Reader's BookDatabase, supplies
private vault context, or keeps anything in the Reader's library. Each run has
a unique ID and replaces its status before doing work. Publication-only fixes
can replay an unbound captured Gemma Page through optional `generatedPage`;
status explicitly distinguishes replay from new model generation.

The source was the actual synthetic QA Page containing “The porch lamp lit an
empty chair beside the door.” and the two completed Ruse/withdrawal receipts.
Only the copied source day and Page date were moved to October 28; the original
QA archive and receipt identities/text stayed intact. Gemma used the unchanged
production instructions, planning, point-of-view repair, and audit. Run
`5218E2A5-0755-4004-B24F-7DBB028911E6` started at `2026-09-26T20:08:09Z` and
completed before the 20:13:18 status read. That is a Debug completion bound,
not a Release benchmark or isolated inference timing. The current general
text-generator iPhone ceiling is 420; earlier raw proofs explicitly used 224.

The first result showed exact protected-passage echoes in Gemma's opening,
followed by the publisher inserting those passages again. The binder now
removes exact echoes only for the authored-interlude path before inserting the
authoritative passages. It preserves new connecting fiction; it does not add
an action filter or alter the model's prompt. The regression covers repeated
inline and paragraph copies, preserved Reader opening/Book continuation,
receipt coverage, and idempotence. All 24 monthly-native tests passed.

After a successful full-worktree Debug build and Rabbit install, the captured
unbound telling was replayed through the repaired binder. Run
`CED87473-D465-43E5-A5E3-7D21BD491754` started at `2026-09-26T20:17:37Z` and
completed before the 20:17:54 read. The fresh SwiftData archive read-back
matched braid text and tags. The saved braid contained the exact Reader line
and each full protected passage once, with one lived claim pointing to the
original atomic contribution and two separate publication receipt tags.

The app's production writers exported weekly and monthly reading PDFs plus
monthly, seasonal, and annual print interiors. Text extraction confirmed each
full protected passage once in all three larger print interiors and the
monthly reading PDF. The weekly compositor retains a shortened braid excerpt,
so its withdrawal passage is deliberately incomplete. The source sentence also
appears in other editorial/source sections; these are distinct from duplicate
passages inside the braid. Monthly/seasonal interiors have 32 pages; annual has
24, reflecting print minimum padding on this deliberately tiny fixture.
Poppler renders of the braid, source Page, and relevant editorial sections
were visually inspected; the text was readable without clipping. The seasonal
and annual braid render matched exactly for this one-month fixture.

Evidence stays local at
`~/.reenchanted-publishing/rehearsals/2026-09-26-count-braid` (initial telling)
and `~/.reenchanted-publishing/rehearsals/2026-09-26-count-braid-corrected`
(repaired publication replay). Rabbit was relaunched normally after testing.
This verifies the production braid/binding/archive/writer seams on device;
it is not the ordinary nightly UI save interaction, a full multi-night/month
Reader walkthrough, Release performance evidence, or a manufactured Lulu proof.
No upload, payment, or print order was made.


### Optimized Release build and publication-readiness refresh — September 26

The complete worktree at build start compiled successfully in Release with
`NATIVE_LOCAL_BRAIN` and the opt-in `BRAID_PROOF` flag. The actual app compiler
command was checked for `-O` and both definitions. MLX native code compiled
with its Release optimization settings. The signed bundle's identifier is
`com.openclaw.enchantify.insidecover`; the build log is
`/private/tmp/reenchanted-count-release-20260926-build.log` and the product is
`/private/tmp/ReEnchanted-Rabbit-Debug-20260926-FullWorktree/Build/Products/Release-iphoneos/InsideCoverApp.app`.
The path retains this session's original Debug name so package checkouts and
caches can be shared; it is the Release product, not the Debug bundle.

The compiler spent a long silent interval in Swift optimization; process
samples showed active optimization passes and later changed passes. The two
idle QA simulators were shut down without deleting their libraries to reduce
host load. No optimization was disabled. The 11 Book Today tests passed.
The Count proof harness now reports braider/total seconds and start/finish
thermal state, and releases the model cache at the end of its isolated flow.
That instrumentation compiled; the later device run below establishes its first
Release measurement.

Rabbit disconnected during compilation, and the install attempt failed with
CoreDevice error 1011 (device unavailable). iPhone Mirroring reported that the
phone was in use. Reconnect/unlock was requested; installation and the fresh
Release Count run were pending at that point; the follow-up below completed them.
The bundle also predates a concurrent
`Shared/SurfaceAndCurator.swift` spell-seating edit made after compilation;
it includes the Count fixes, but is not an install of that newest curation edit.

The publisher dry run again verified the signature and all 38 candidate assets
without upload, and Python release preflight passed. While waiting for compile,
an isolated Radio QA attempt at the Serenity-awake clip stayed cold and created
no delivery/play receipt. It is not playback evidence. The temporary draft and
audio copies were removed after terminating the simulator app. The remaining
app route, missed-beat, audio, and ordinary-nightly-save checks continue to bound
publication readiness. No upload, payment, or print order was made.

### Fresh Release device proof and scene-window edges — September 26

Rabbit reconnected, and the signed Release bundle above installed successfully.
Fresh run `F98E4DFF-DBC9-425D-B466-1B51F16D5C00` started at
`2026-09-26T22:59:12Z`. Its input had no captured `generatedPage`: production
Gemma generated a new telling from the same synthetic Reader sentence and
authored Ruse/withdrawal receipts. Generation took 29.6999 seconds; the complete
proof through archive read-back and all PDF exports took 32.2396 seconds.
Low-power mode was off and thermal state was nominal at start and finish.
This is one fresh-process fixture, not a multi-night performance profile.

The saved braid preserved the Reader sentence and each full protected authored
passage once. Text extraction found each protected passage once in the monthly,
seasonal, and annual print interiors. The actual monthly braid page (page 7)
was rendered and inspected: readable, without clipping. The app exported its
weekly and monthly reading PDFs and monthly/seasonal/annual print interiors;
their padded page counts remained 32/32/24. Evidence is local at
`~/.reenchanted-publishing/rehearsals/2026-09-26-count-braid-release`.
Rabbit was then relaunched without a proof flag. The installed bundle contains
the Count fixes but predates concurrent source edits made after its compilation.

An additional fresh simulator, `ReEnchanted Count Window QA`
(`955FB144-3929-4F83-9816-79D9E37C4C1C`), used the compatible runtime-10 app
and a temporary copy of the current canonical issue. Only the calendar start
was shifted to expose each live day; authored text and date gates were retained.
It had no copied Reader library. The existing public East Stacks report supplied
the late-reader dependency without recording attendance. No tested scene was
kept, so completion receipts could not hide a date-window failure.

| Scene | Before window | First day | Last day | After window |
| --- | --- | --- | --- | --- |
| Map-room | October 9: withheld | October 10: opened | October 14: opened | October 15: withheld |
| Man Reading Himself | October 14: withheld | October 15: opened | October 17: opened | October 18: withheld |

The reader-facing scene text appeared on eligible days; outside the windows,
the app returned to The Book Today. Dracula's three question choices were
present. Its four launch results also appear in
`/private/tmp/count-window-edges-20260926.log`; the first map-room launch is in
`/private/tmp/count-window-first-log.txt`. The temporary imported pack was removed
after terminating the QA app. These checks establish scene availability edges,
not every choice path, ordinary nightly UI saving, or Radio playback. No content
was uploaded or published, and no payment or print order was made.

### Late-reader Radio dependency follow-up — September 26

In the fresh Count Window QA library, the Serenity-awake Fae-Fi break started at
live day 8 using its recorded MP3. The Radio Page showed Penny Blackletter and
the exact authored caption, and the saved vault recorded one `played` receipt.
The public East Stacks report from the earlier map-room walkthrough remained a
truthful report, not a completed Reader scene.

The Wicker one-sentence break was withheld at live day 21 and still withheld at
day 22, although the Wrong Castle's public report becomes eligible after day 21.
The native-content selector required an actual completed scene while the final
access check already accepted an available `reportThenContinue` report. It now
uses that same report condition, without fabricating attendance or a scene
receipt. A focused Count regression checks October 21 and 22 withheld,
October 23 and 27 eligible, and October 28 expired; it passed on the host.
The updated simulator app then showed Wicker on Thornwave with the exact caption
and saved a `played` receipt. This exposed a product-policy correction from the
Reader: authored Radio breaks may repeat like regular banter inside their own
windows. The once-per-run assumption above is superseded by the follow-up below.
The local draft and copied MP3s in Count Window QA were test-only and were
removed after the follow-up. Audio listening on Rabbit remains open.

### Radio repeats within its authored window — September 26

The five Count Radio atoms now use the shared `repeatable` occurrence policy
with a one-hour cooldown. Their foreshadow, live-day, phase, and aftermath
gates remain unchanged. The regular Radio picker still uses its usual recent
history and song spacing; a clip is eligible to return after the cooldown, but
cannot start after its allotted window. The player retains a repeatable clip in
its live pool after playout and gives each real play a unique receipt, while
caption-only delivery remains distinct from actual audio playback.

The updated simulator build passed (`/private/tmp/count-radio-repeat-build.log`).
In Count Window QA, Wicker's recorded Thornwave clip displayed the matching DJ
and caption and played again after a test-only two-hour adjustment to its
previous receipt. The next immediate launch withheld it for cooldown. A second
two-hour test adjustment permitted another play; the isolated vault then held
three distinct `played` receipts. At live day 27 (October 28), one day beyond
Wicker's maximum, the clip was withheld despite those previous plays. The
temporary import and copied audio were removed after terminating the app.
These are bounded simulator checks; they do not claim sustained listening or a
physical-device audio quality review.

The full Count suite passed 36 tests, the monthly native suite 24, and 32
Python pack/release tests passed. The local Worker lifecycle rehearsal passed
all five delivery stages. A replacement candidate was signed at
`~/.reenchanted-publishing/releases/2026-09-26-count-unbound-2026-10-candidate`;
the previous candidate was preserved with suffix
`pre-repeatable-radio-candidate`. Its runtime pack matches the checked-in pack
byte-for-byte (SHA-256
`9218d34cbf909ad716332df1fd0a2c8e228b63c4cdca4a61444a81e44f2b4f76`).
The publisher dry run verified the envelope and all 38 assets without upload.
Rabbit's Release app was updated with the repeatable-player code later that
evening. The new app behavior and the signed pack must travel together before
publication; the signed pack is still local and unpublished.

### Ordinary braid save-path smoke — September 26

Count Window QA, still an isolated simulator library, staged a temporary
calendar-shifted Count pack at live day 9. Opening the map-room made the East
Stacks public report available without recording Reader attendance. A separate
`--smoke-braid` launch then used the app's ordinary `braidToday` route: it added
its documented synthetic mood fragment, bound the exact public report once,
and persisted a Book of You Page. `book-days.json` held one `bookOfYou` Page and
one report in its body after a normal relaunch. The Page retained the
publication receipt tag. The temporary imported pack was removed afterward.
The Mac locked before a visual check, so this is archive/save evidence rather
than a witnessed manual tap, rendered Page review, or multi-night proof. It
does not replace the prior fresh production-Gemma proof on Rabbit.

### Updated optimized app build — September 26

The full current worktree, including the repeatable Radio player change, built
successfully for generic iPhone in Release with the opt-in `BRAID_PROOF` flag.
The signed product at
`/private/tmp/ReEnchanted-Rabbit-Debug-20260926-FullWorktree/Build/Products/Release-iphoneos/InsideCoverApp.app`
has bundle ID `com.openclaw.enchantify.insidecover`; its app binary was written
at 20:04 local. The build log is
`/private/tmp/count-radio-repeat-rabbit-release-build.log`. Release optimization
remained enabled. Rabbit became unavailable during compilation; CoreDevice error
1011 initially prevented installation. Once USB and the development tunnel
reconnected, the updated product installed successfully at 20:11 local.
`devicectl` launched `com.openclaw.enchantify.insidecover` at 20:12 and then
listed its `InsideCoverApp` process (PID 56515) and widget extension. This
establishes an installed, running Release app, not a visual or listening review.
The signed content pack remains local and unpublished. No upload, payment, or
print order occurred.

On September 27, iPhone Mirroring connected to Rabbit. The installed Release
app opened to The Book Today and returned to the Book's opening leaf without a
visible launch error. Its Radio sheet rendered on the physical display; Fae-Fi
changed from "The dial is cold" to an active station state and back when
toggled. This is visual playback-state evidence only. The current calendar is
before October, so it does not establish a Count clip, its spoken audio,
caption match, cooldown, or expiry on Rabbit. Existing Reader pages were left
untouched.

A read-only inspection of Rabbit's `MonthlyIssueDelivery` directory on
September 27 found an empty `Content` directory and `installation-state.json`
with zero assets. Its cached published manifest, generated September 23, has
zero issues. No Count import appeared in the app's Documents root or Release
bundle. Thus the October issue is not merely waiting behind a date gate on
Rabbit: the signed candidate has not been delivered. The candidate manifest
would allow foreshadow from September 24, and the installer can prefetch the
next issue after publication for a Reader with monthly access. Publication and
the remaining Reader walkthrough are separate gates.

### Reader-operated nightly save — September 27

In the isolated `ReEnchanted Count Radio QA` simulator, the installed September
26 Debug snapshot opened normally with the prior September 26 synthetic Count
braid still on its Book of You shelf. Using the visible Reader controls, a new
plain Page was kept through Capture → Text → Keep with the clearly synthetic
sentence “QA fixture: A blue paper star waited by the test window.” Glow →
Pages → Book of You opened the Braiding Table, which showed one fragment and
no braid for September 27. Tapping **Braid today** opened the new kept Page.
It contained that exact sentence once, carried previously recorded Count
receipts, and exposed the original kept Page under “What went into this Page.”

After terminating and normally relaunching the app, The Book Today presented
“Tonight's Book of You is illuminated,” and Open returned to the same Page.
Archive read-back found one Book of You Page on each of September 26 and 27,
with the synthetic sentence once in the new telling. This proves the ordinary
capture and UI save path on an isolated two-day library. It does not prove a
new Gemma generation on the simulator, an October multi-night cadence, every
authored branch, or final print quality. No Rabbit Reader page was changed.

### Late-reader Return by Rule — September 27

The isolated `ReEnchanted Count Window QA` simulator received a temporary copy
of the signed-candidate runtime pack (source SHA-256
`9218d34cbf909ad716332df1fd0a2c8e228b63c4cdca4a61444a81e44f2b4f76`)
with only its calendar start shifted so September 27 represented October 28,
live day 27. Its library held public late-reader reports but no prior climax
attendance. The normal monthly resolver opened **A Future Tense** with the
truthful East Stacks report and offered all three return paths. Selecting
**Return by Rule** enabled Keep; the next launch resumed its Rule leaf.
Keeping that leaf advanced to **The claim is hers**, which rendered Serenity's
withdrawal and the shared return. Keeping it saved the selected `rule` choice,
three `nodeCompleted` receipts, terminal `completed` and `kept` receipts in
the `count-unbound:2026` run. Relaunching the same offer returned to The Book
Today rather than repeating the ending. The temporary import was removed after
terminating the app; the isolated receipts remain. This checks the no-finding
Rule path, not a Reader finding callback or ordinary unscripted offer discovery.

### Soren's November occasion — September 27

The same isolated Count Window QA library kept its completed Rule ending. A
temporary calendar shift to live day 29 opened **After the last lesson** with
the truthful public Nightbound report. Its three suggestions were visible;
choosing “Take Soren up on the roof” wrote the `soren-roof` October choice.
Shifting only the temporary draft to residue day 32 then opened **An evening in
November** with just **The glass roof with Soren** available. Its second Page
offered “One line of the map” or “Nothing. Just the rain.” The Reader chose the
map line; the Page answered with Serenity's boundary, then advanced to the
short terminal leaf with the paper bird. Keeping it wrote the carried
`soren-roof` and `soren-map` node receipts, `completed`, and `kept`. A normal
relaunch of the same offer returned to The Book Today rather than repeating
the finished scene. The temporary import was removed; the isolated receipts
remain. This checks one Soren path, not its alternate second choice.

### Serenity's own November evening — September 27

The existing isolated `ReEnchanted Finding QA` simulator received a temporary
copy of the candidate runtime pack, with only its calendar start shifted so
September 27 represented live day 29. **After the last lesson** offered three
suggestions. Choosing **Have an evening that belongs to you** and keeping the
Page saved the October `own-evening` choice. A second temporary date shift made
the same day residue day 32. **An evening in November** then offered only the
greenhouse evening. Its second Page offered Penny in the second chair or the
walk home alone; choosing the latter answered with Serenity's own decision.
After Keep and a normal relaunch, the short closing Page, **A greenhouse
evening**, appeared and was kept. The vault held October `own-evening`, the
November `own-evening` entry, `own-solitude` second choice, terminal
`nodeCompleted`, `completed`, and `kept` receipts for the same run. Relaunching
the same offer returned to The Book Today rather than repeating it. The
temporary import was removed and the QA simulator shut down. This checks one
independent route and one second choice, not all alternate outcomes or an
ordinary unscripted offer discovery.

### Ruse return relic — September 27

The same isolated Finding QA library already held a completed, kept Week Three
finding in `count-unbound.mission.other-side`. A temporary copy of the candidate
pack with only its calendar shifted to live day 27 resumed **A Future Tense**.
The Reader chose and kept **Return by Ruse**, then kept its route leaf and
Serenity's withdrawal. The vault recorded the `ruse` node choice, route and
terminal node completions, and completed/kept ending receipts in the same run.
With the temporary calendar moved to live day 29, the Ruse-specific **Paper
Hinge** relic appeared. Smoke-opening the Terms and Rule relic IDs returned to
The Book Today, so those unrelated traces were withheld. Keeping the Paper
Hinge wrote its terminal, completed, and kept receipts; relaunching the same
offer returned to The Book Today. The test import was removed and the QA
simulator shut down. This is one route-specific app walkthrough with a prior
finding, not a proof of the Terms or Rule relics, unscripted discovery, or
November 1 expiry.

### Ordinary Sunday entry discovery — September 27

A disposable `ReEnchanted Count Discovery QA` simulator used a temporary copy
of the current pack, SHA-256
`7fce1b1ef2bbc4935322c0ffa951db9b567d40c0e8f86b12c42800f88c1056c6`,
with only the event calendar shifted to September 24. September 27 therefore
represented live day 3, the first Sunday Book Jump. The free Book was opened
through the Inscription skip control. The isolated vault then marked the short
opening guidance finished; it contained zero kept Pages and no story outcomes.
No subscription entitlement was required under the current free-monthly policy.

The Debug app launched with `--smoke-curator-report`, a read-only local report
flag that neither opens a scene nor alters curation. Ordinary page turns reached
**Sunday Book Jump Club**, the ninth Page in the initial folio, without using
Explore deeper or a direct scene link. Permancer's ribbon lesson rendered across
five leaves. **Make the choice** opened the native scene with both **Enter the
supervised Jump** and **Stay in the Vault** available; Keep remained disabled
until a choice. No choice or completed/kept story receipt was created in this
discovery pass.

The rehearsal found three placement seams: the introduction ladder blocked
bounded authored narrative for new Readers; any strategy directive anywhere in
the candidate bench suppressed the issue's reservation; and a protected opening
had no fallback story chair in the rest of the published folio. Those seams are
repaired while preserving the sole strategy chair, Reader traces, feast, braid,
and each three-Page act's pressure budget. Sunday Jump now has milestone priority
above the school vignettes. Launch records delivery after publishing the folio,
and enrichment preserves an authored scene already published in its source/type
slot. Reading-only nodes and mission invitations use their actual interaction
capabilities. The related core suite passed 239 tests and the Debug simulator
build succeeded. The new pack hash requires a new signed candidate.

Earlier attempts using a mid-October fresh library did not establish ordinary
discovery: one library already held a catch-up report from a direct scene test.
Those receipts are not counted as this proof. This pass establishes the Sunday
entry after introductory guidance, not all missed-beat dates, repeated-day
cadence, entry continuation, audio listening, or Rabbit behavior. Temporary
imports were removed and the disposable simulator retired after the check.

### Daily unfinished invitation — September 27 (core regression)

The real pack's Sunday Jump passes its native adapter and monthly gates on
October 4, 5, 6, and 7, then is withheld on October 8. Each unresolved story node
now receives a dated automatic occurrence through the existing Curator recurrence
mechanic. A regression records repeated deliveries and openings, including a
high prior show count, and verifies the next day's invitation still passes
novelty. The unchanged node does not automatically reappear again on the same
day. This is core scheduling evidence; the earlier ordinary-discovery app pass
predates this daily recurrence change. No new Rabbit install was performed.

### Missed Sunday, ordinary Monday discovery — September 27

The isolated Count Window QA simulator used the unchanged authored pack text
(SHA-256 `7fce1b1ef2bbc4935322c0ffa951db9b567d40c0e8f86b12c42800f88c1056c6`)
with only its local test calendar shifted to September 23. September 27 was
therefore live day 4, after the first Sunday. This simulator's short first-run
guidance was marked engaged for the test; it held no chosen Sunday outcome.
The app launched with the read-only `--smoke-curator-report` flag. Its report
recorded the Sunday Jump as prepared and visible in the published folio even
though ordinary novelty alone rejected the earlier showing. The Reader desk
was then opened normally; page-turn buttons led through the other Pages to the
five-leaf **Sunday Book Jump Club**. Its final **Make the choice** control
opened the native sheet with both **Enter the supervised Jump** and **Stay in
the Vault** available. Keep remained disabled without a choice. No choice or
story Page was saved. The report is preserved at
`/private/tmp/count-monday-ordinary-discovery-report.txt`; the temporary import
was removed and the simulator shut down. This proves missed-Sunday Monday
discovery, while actual next-calendar-day recurrence after a delivered opening
and later date edges remain core-test evidence rather than a multiday app run.

The same isolated app was then launched with a second temporary calendar shift
making September 27 live day 8 (October 8). Its read-only Curator report marked
the Sunday Jump `prepared=false`; no Jump candidate or visible Page appeared.
That report is preserved at `/private/tmp/count-friday-expiry-report.txt`.
The expiry import was removed and the simulator shut down. This confirms the
closing boundary in the app without treating a shifted QA calendar as a real
Reader's October history.

### Terms/Hunt callbacks and matching relics — September 27

The updated Debug player built and installed into the existing isolated
`ReEnchanted Finding QA` simulator. Build logs are
`/private/tmp/count-remaining-routes-build.log` and
`/private/tmp/count-route-diagnostic-build.log`; the second adds read-only native
candidate/receipt diagnostics to the existing curator report. This build includes
the daily unfinished-invitation change, but this route walkthrough does not
establish ordinary discovery across multiple days.

The library retained its actual kept third-crossing return, “The latch was smooth
outside and scratched behind the door.”, and completed Dracula encounter. Its
previously completed Ruse ending had correctly closed earlier live offers. Before
rehearsing another branch, only this isolated library's strategy, ending, relic,
and issue-conclusion receipts were reset; the source pages and finding receipts
were retained. The pre-rehearsal vault is saved at
`/private/tmp/count-finding-vault-before-route-qa.json`. A temporary copy of the
current source pack changed only its start date to represent live days 17, 27,
and 29 on September 27. No customer library or Rabbit state was changed.

Using the existing gated authored-story rehearsal entry, Terms → Future Jumps
must change advanced through the ordinary folio. The final supper Page visibly
quoted the exact retained sentence. Keep recorded the Terms preparation and
terminal callback. At day 27, the climax offered only Return by Terms, carrying
the preparation choice. Its return and Serenity's withdrawal were read and kept
in the same session. At day 29, The Turned-Down Place Card appeared and was kept.
Relaunching that offer returned to The Book Today. Its terminal, completed, and
kept receipts are retained in
`/private/tmp/count-terms-completed-rehearsal.json`.

After another isolated receipt reset, Hunt → Wicker's sentence advanced through
The Door's Autopsy. The exact same finding appeared on folio leaf 2 of 5, then
its final leaf was kept. The day-27 climax offered only Return by Rule. After
keeping that choice, separate relaunches resumed the Rule leaf and Serenity's
withdrawal, which were kept. At day 29, The Two-Sided Bookmark appeared, was
kept, and stayed retired on relaunch. The snapshot at
`/private/tmp/count-hunt-rule-completed-rehearsal.json` holds the Hunt, Rule,
withdrawal, conclusion, and bookmark receipts.

This library had no completed second-crossing invitation or fourth-crossing
pair. The climax used its empty-place fallback; Penny used her independent BACK
check. Those absences were not represented as lived findings. The separate
second-crossing climax quotation proof remains the evidence for that insertion.
These checks establish two preparation callbacks, carried routes, two relics,
saving, resumption, and retirement in the simulator. They do not establish all
secondary choices, customer print layout, multi-night cadence, or physical-device
behavior. The temporary draft was removed and Finding QA shut down afterwards.
The old QA vault also passed a native decode check, with no data compatibility
failure; that temporary diagnostic test was removed after use.

### Replacement signed candidate — September 27

Staged the current issue with all 38 assets and no missing recordings, then
prepared a new candidate against the September 23 empty-shelf manifest at
`~/.reenchanted-publishing/releases/2026-09-27-count-unbound-2026-10-candidate`.
The current Count native group passed 38 tests, including release validation and
the daily unfinished-invitation regression
(`/private/tmp/count-final-routes-native-tests.log`). The monthly Python tools
passed 17 tests and release preparation passed 15
(`/private/tmp/count-release-python-tests.log`).

The existing publisher key signed the candidate; the publication dry run verified
the envelope and all 38 asset sizes/digests
(`/private/tmp/count-20260927-publication-dry-run.log`). Its runtime-10 world-event
asset equals `opening.reenchantedevents.json` byte for byte, SHA-256
`7fce1b1ef2bbc4935322c0ffa951db9b567d40c0e8f86b12c42800f88c1056c6`.
The production inventory contains 47 authored atoms. Older candidates remain in
separate directories. Signing and this dry run made no upload, payment, or print
order. Final print, missed-beat, physical-device, and listening checks remain
open; this candidate is not published.

### Saved callback/relic print proof — September 27

The existing simulator-only edition harness now accepts optional exported
`[BookPage]` JSON at `Documents/edition-proof-input/authored-pages.json`, decoded
with the content-pack ISO date decoder. It copies those Pages to October 12 in
its synthetic year, creating that fixture day if the invented year left it
quiet. It does not read or modify a Reader vault. This is a reusable print QA
input for future authored packs.

The four actual keeps exported from Finding QA were the Terms and Hunt terminal
callbacks, the Turned-Down Place Card, and the Two-Sided Bookmark. Their original
text, IDs, and publication tags were retained; only copied `createdAt` dates were
moved into the synthetic October. These are two alternate routes combined for a
layout fixture, not a claim that one Reader played both preparations in a run.
The fixture is retained at `/private/tmp/count-relic-callback-print-fixtures.json`.

The first PDF proof exposed four defects. Count Pages printed in Letters And
Voices and again in World Events; the latter now keeps its event summary without
copying a Page already bound elsewhere. The edition regression verifies one
binding per Page and a retained event summary in monthly, seasonal, and annual.
The 33 related edition tests passed (`/private/tmp/count-print-dedup-tests.log`).
Narrow 6x9 backgrounds no longer place anonymous gutter scraps beneath the prose;
measured cabinet marginalia remains available. Long item bodies reuse the existing
measured text-leaf splitter and continue rather than running beyond the trim.
Weekly alongside scraps use word-boundary excerpts measured against their share
of the remaining leaf, rather than assigning every keep 420 characters regardless
of paragraph height. The original archive text is not shortened by these repairs.

The final Debug simulator build passed
(`/private/tmp/count-print-layout-final-build.log`), installed, and ran the app's
weekly/monthly/seasonal/annual builders and PDF writers again. The final proof
folder is `output/pdf/count-callback-relic-proof/`. Interiors have 24 pages for
the October weekly issue, 32 monthly, 68 seasonal, and 204 annual. The four keeps
appear once in the longer bindings. Weekly uses the matching daily lead,
alongside excerpts, and a strongest-page feature; its repetition is an editorial
selection rather than the removed duplicate monthly sections.

Rendered and visually inspected all 15 relevant final interior pages: monthly
16–19, seasonal 34–37, annual 163–166, and weekly 11, 12, and 15. The Hunt callback
continues on the final page of each longer group and retains its closing sentence.
The relevant extracted word bounds stay inside their PDF pages, including the
previously overflowing weekly Page 12 and annual Page 165. Final contact sheets
are temporary QA renders under `tmp/pdfs/count-callback-relic-proof/`.
This verifies these saved Pages in actual app PDF output, not every page of a
customer volume, sustained October play, or Lulu-manufactured paper. No payment,
order, or upload was made. The explicit fixture was removed from the simulator
after copying the outputs, and the simulator was shut down.

### Combined Release player on Rabbit — September 27

After the shared-worktree map changes finished compiling in Claude's simulator
build, a fresh optimized Release iOS build passed at
`/private/tmp/count-sept27-rabbit-combined-release-build.log`. The signed bundle
identifier was `com.openclaw.enchantify.insidecover`. Rabbit reconnected; the
577 MB app bundle installed successfully and `devicectl` launched it normally.
This establishes build, install, and process launch separately. After Rabbit was
locked, iPhone Mirroring showed the new Release app on The Book Today. That is
visible launch evidence, not a timed Count interaction or audio listening check.
The signed October issue was still unpublished at this install and no local
test pack was imported into Rabbit's Reader library.

### Signed monthly shelf publication — September 27

The user explicitly requested publication. The candidate still matched the
authored source byte for byte. Fresh focused gates passed: 240 native tests,
36 Python authoring/release tests, 22 Worker monthly tests, and the local
publisher → signed manifest → Worker/KV/R2 delivery rehearsal. A free session
on the deployed Worker served the existing signed empty manifest, confirming
that the live monthly shelf policy was open to every installation.

`scripts/publish_monthly_release.sh` published the prepared September 27 release:
all 38 immutable asset keys first, then its signed envelope. The script's live
manifest comparison passed. The served envelope SHA-256 is
`110cdd0c1bbc4620d6bd570d4c49804eb87a78c91fa062f3a7790c7d57f84cc5`.
An independent free Reader session downloaded all 37 currently available
assets (1,102,365 bytes); every size and digest matched the manifest. The
December casebook correctly returned unavailable before December 1; a separate
R2 read-back matched its stored digest. Logs are
`/private/tmp/count-20260927-publication-live.log` and
`/private/tmp/count-20260927-live-readback.json`.

This publishes `count-unbound-2026-10` to the remote monthly shelf. Foreshadow
is already eligible from September 24; the main story begins October 1 and
the Sunday Jump begins October 4. It does not publish the app to the App Store,
enable live Stripe/Lulu billing, order a book, or charge an account. Rabbit's
normal managed download still needs a device receipt, and device listening,
repeated-day ordinary invitation behavior, and sustained October cadence remain
open Reader follow-up. The prior signed empty envelope is retained at
`~/.reenchanted-publishing/releases/2026-09-23-empty/manifest.envelope.json`
for rollback; its SHA-256 matched the pre-publication live shelf. Future changed
asset bytes must use new asset IDs rather than overwrite this release's keys.


## October 3: generated seasonal art publication

The twenty month-long October illustrations were replaced with transparent
1254px ink-and-watercolour cutouts generated from the existing pixie and goblin
style references. The eight directed handwritten story notes retain their
original bytes. Prompts are recorded in `seasonal-art-prompts.json`.

The revision changes only the page-archetype asset (`count-unbound.margins.v2`)
and twenty media IDs (`count-unbound.seasonal.v2.*`). Compared with the live
prior manifest, the other sixteen asset entries and the issue lifecycle are
identical. Thirty-six Python authoring/staging/preparation tests passed.
The signed candidate passed the local Worker lifecycle rehearsal at foreshadow,
live, residue, and after-residue windows; every delivered file matched.

`scripts/publish_monthly_release.sh` uploaded assets before the signed manifest,
then verified that the live envelope matched. A separate free Reader session
verified its Ed25519 signature and the byte count and SHA-256 of all 37 live
assets, including every replacement illustration. The saved release is
`~/.reenchanted-publishing/releases/2026-10-03-count-unbound-2026-10-generated-art-candidate/`;
`published.json` records the check, and `rollback.envelope.json` and
`rollback.manifest.json` preserve the previously live shelf.

The complete app worktree separately built, installed, and launched on Rabbit,
with the new art also installed through its existing local user-pack seam.
That device run does not establish a signed download or rendered marginalia
inspection on Rabbit. Other readers receive the revision through the normal
monthly shelf refresh; existing kept Pages preserve the art already bound into
them. No backend code or landing-page changes were deployed for this release.
