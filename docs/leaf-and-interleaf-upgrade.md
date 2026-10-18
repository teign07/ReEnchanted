# The living Book: presentation upgrade

Status: first implementation slice added on October 11, 2026 (local time),
with a permanent-artwork slice on October 18. Swift syntax and asset-authoring
checks pass. Build, installation, and runtime visual proof remain pending.
No monthly content was published by this work. Never build unless the user asks.

This is the master presentation brief. It includes leaves and interleaves,
physical actions, destination transitions, the Braiding Table,
recognizable shared history, the Book's character in composition, and
the reveal of a real fragment becoming part of a lasting volume. Implementation
extends the established seams and preserves unrelated work already in the checkout.

Scope update: the Bookshop is deferred at the user's request. Its presentation,
entrance, shared Bindery surfaces, commerce, and routes stay untouched in this
upgrade. The Bookshop ideas below are retained only as future design notes.
Volume reveals use existing edition readers and routes without redesigning the shop.

## Work log and next step

### October 18: illuminated photographs coalesce together

Photo interleaves now reveal their complete prepared image with the same
ink-emergence effect as illustrations. Photograph, frame, scraps and marginalia
share one reveal, replacing the paper-first layer and delayed pigment decode.
Preparation no longer renders or caches duplicate pigment/clock images. Late
delivery starts a complete reveal when ready; prewarmed leaves wait for their
visible arrival, and turning away settles the reveal for return visits.
Accessibility bypasses remain in the shared modifier. Swift syntax parsing and
whitespace checks pass; no build or device verification performed.

### October 18: illuminated photographs use the full leaf

Photo interleaves now share the illustration layout: the full stored leaf
dimensions, navigation overlaid at the foot, and no inset media frame. The
complete illuminated composition remains fitted without cropping its marginalia.
Swift syntax parsing and whitespace checks pass; no build or visual QA performed.

### October 18: balanced personal-photo encounters

The independent six-slot draw is replaced with a stable two-photo,
three-illustration, five-other rhythm, with the added quieter slots going to
marginalia. Photo selection reuses the existing
scorer, adds album/nearby-Page relevance and persistent recent-photo exclusion,
and avoids neighbouring captures. Preparation prefers local candidates, permits
one bounded iCloud attempt, then falls back to local candidates. Photo work no
longer gates touch. Metadata queries, lookahead, decoded images and
retry state are bounded. Transient interleaves do not write preview files.

See `docs/interleaf-photo-curation.md` for limits, fallbacks and verification.
Five Swift regression methods were added and syntax-checked, not executed.
No build or device validation was performed.

### October 18: illustrated leaves with their own marginalia

Seven permanent portrait illustrations join the existing interleave selector:
the growing shelf, the goblin under the Kitchen table, the Book's sleeping
place, the quiet window, a Book Jump, a word duel and the forgotten stacks.
Pippa Pilcrow's illustrated dossier is the style reference. Subjects have
their own small studies and handwritten notes; character continuity uses
the existing goblin, Penny and Permancer artwork.

The folio gives illustration interleaves the full leaf's stored dimensions;
navigation floats at the foot rather than reserving a separate strip. Whole
plates fit without cropping their marginalia. Only optimized native-size JPEGs
enter the asset catalogue; full PNG masters remain outside the app bundle.
See `docs/permanent-interleaf-art.md` for the inventory and provenance paths.
This is generated-art and source evidence, without a build or device preview.

### October 12: ink moving through the leaf

Implemented in the existing folio, shared writing control, and Keep paths.
Tabs, Contents, navigation, pagination, artifact inspection, and dismissal
destinations retain their existing structure. **Rip It Out** replaces both
folio **Trash it** labels and calls the same tear/dismiss action.

- Printed sentences have independent, deterministic, overlapping arrival
  clocks, including multiple sentences within one paginated text fragment.
  Masks use the label's actual attributed typography and text measure. The
  glyph masks are removed once settled, leaving normal sharp text.
- Illustrations, interleaf media, marginal handwriting, cabinet marks, and
  reverse-page ghost ink surface through uneven, feathered pockets of ink.
  Arrivals finish within 1.7 seconds rather than extending with page length.
- The interaction store remembers the first visible arrival of each leaf.
  Prepared curl neighbors wait for actual visibility; recreated hosts catch
  up to the same clock. Revisits and keyboard redraws do not replay the reveal.
- Shared writing controls use transparent paper, serif writing, a faint
  baseline, and a visible invitation. Native editing, selection, dictation,
  sentence tools, attachments, tabs, and existing Keep actions remain.
- Explicit Keep makes typed Reader ink (and direct iPad Pencil ink) feather,
  sink, and disappear over 0.88 seconds. The original text and attachments are
  snapshotted before animation and handed to the existing save flow. The plain
  Input page and shared editors in Capture pages use the same absorption.
- The capture-page Keep seal follows absorption. Dictation stops during the
  handoff, duplicate Keeps are guarded, and sheets cannot be dismissed in the
  middle of that confirmed operation. A specialized folio Keep reports its
  existing handoff to the presentation layer, so cancelling that sheet leaves
  the original folio draft editable. No draft is erased by a visual mask.
- Reduce Motion and VoiceOver skip the reveal and absorption delay. Controls
  never wait for printed prose or artwork to appear. No continuous animation
  timer is added to settled leaves.

Validation: Swift frontend syntax parsing passed for all six touched app files;
`git diff --check` passed. Task-only diffs were reviewed against pre-edit copies
in `/private/tmp/reenchanted-journal-ink-20261012/`, preserving the already-dirty
checkout. **No build, typecheck, executed Swift tests, installation, or rendered
visual QA was performed**, following the instruction not to build unless asked.

Pending visual proof: phone and iPad spread; multiple sentences within one
fragment; illustration/photo/map interleaves; rich marginalia; large text;
keyboard/selection/paste/dictation; typed and Pencil Keep; attachment-only Keep;
specialized-sheet cancellation; rapid/cancelled curls and return visits;
Rip It Out; Reduce Motion and VoiceOver. Go/no-go: writing stays immediately
editable and legible, words disappear before the existing Keep transition,
overlapping arrivals feel like ink moving through paper, and normal navigation
and preserved submission data pass the same encounter end to end.

The starting slice is **readable ink and lively paper**. It establishes the
composition rules before adding motion or touch discoveries.

- [x] Ordinary prose and continuation leaves use a continuous, leading-aligned
  reading column. Brief authored arrangements and short quotations retain their
  special regions; Dynamic Type accessibility uses continuous prose.
- [x] Replace the seven-name boundary illustration list with the existing
  41-image bundled catalogue. All 41 imagesets and their declared image files
  have been checked in source. Prefer literal subject matches and avoid the last
  four shown illustrations when another eligible image exists.
- [x] Add optional `interleafIllustrations` to the existing Page Pack model.
  Reuse enabled-pack entitlements, managed monthly paths, and subject/month/year/
  event/phase gates. Missing managed files and unresolved delivery references
  are excluded. Monthly publishers must explicitly opt art in; the staged
  October print plates have not been installed or published by this work.
- [x] Add stable quiet, ordinary, rich, and overdone density ceilings of 1, 2,
  5, and 9 marks. Packs can direct density with `leafMarginaliaDensity`.
  Interleaves favor richer densities; most prose leaves remain quiet or ordinary.
  These are ceilings, not guaranteed counts: empty space decides what fits.
- [x] Primary artwork attempts placement before support scraps and handwriting.
  Richer recipes draw distinct companions through the existing marginalia cabinet.
  Rotated footprints avoid measured ink, interactions, footer, and other marks.
  Handwritten text is measured at its displayed size before it is accepted.
- [x] Correct Book-residue attribution, remove unsupported photo-selection claims,
  and repair the unreachable place-plate media branch.
- [x] Include the illustration catalogue in the binding cache key so newly
  installed or removed art can produce a fresh binding.
- [x] Add six Swift regression tests for density, selection, backward-compatible
  pack decoding, and seasonal eligibility. Syntax checked; **not executed**.
- [x] Extend the Page Pack authoring validator; four Python checks executed and
  passed. Swift parser and whitespace checks passed. Shop and shared Bindery
  presentation files match the saved task baseline.
- [ ] Render quiet/rich/overdone, short/long, quotation/map/photo, and accessibility
  fixtures. Counts and composition still need visual judgment; source checks do
  not prove that the leaves look good on a phone.
- [ ] Curate monthly opt-ins and any new evergreen illustrations after that proof.
- [ ] Next interaction slice: fold one authored note and reveal one creature's
  concealed scrap, using existing artifact inspection and Reader agency.
- [ ] Continue the wider presentation stages below: physical actions, destination
  openings, the actual scraps on the Braiding Table, recognizable history, and
  lasting-volume reveals. Bookshop/Bindery stays deferred.

Implementation files: `Shared/Illumination.swift`, `Shared/ReferenceLibrary.swift`,
`Shared/PagePacks.swift`, `Shared/SourceAdapters.swift`,
`InsideCoverApp/PagesRisingFolio.swift`, `scripts/validate_page_pack.py`, and the
two new regression files `Tests/InsideCoverCoreTests/LeafPresentationTests.swift`
and `scripts/tests/test_leaf_presentation_pack.py`.

The pre-edit copies and diffs live in
`/private/tmp/reenchanted-leaf-upgrade-20261012/` for this shared dirty checkout.
Unrelated work was preserved; no commit was created.

### Monthly authoring seam

An existing `.reenchantedpack.json` can carry this optional member (illustrative
IDs only). The normal signed delivery materializes `{{asset-path:...}}` into the
installed managed-media path before decoding the pack:

```json
"interleafIllustrations": [{
  "id": "example.interleaf.door.v1",
  "assetName": "{{asset-path:example.door.media.v1}}",
  "title": "The door that kept a corner",
  "tags": ["door", "threshold"],
  "placementTrigger": {
    "months": [10],
    "issueYear": 2026,
    "activeWorldEventIDs": ["example-event"],
    "worldEventPhases": ["BUILDUP"]
  }
}]
```

An archetype can additionally declare `"leafMarginaliaDensity": "overdone"`.
Old packs omit both fields and keep decoding. Extra creatures still have to fit.

## The intended experience

The Reader turns through readable, individually composed leaves. Between Pages,
they encounter their own returned words, illustrations, illuminated photographs,
maps, and the Book's marginal life. Some paper is nearly bare. Some looks as
though several creatures have been arguing on it. A few discoveries reward a
touch; every leaf remains satisfying when the Reader simply keeps turning.

The Book speaks like a feral child: direct, physical, selective in its
anthropomorphism, never babyish. Real Reader writing stays authoritative and
private. A fictional interpretation never becomes a fact about the Reader.

The same physical world continues when the Reader takes action or opens a
destination. A kept scrap changes its place. A letter unfolds. The Braiding
Table holds the actual scraps.
The Book's history becomes recognizable in particular repairs, bindings, and
returned objects. Every gesture has an intelligible result.

### The signature encounter

Build one complete encounter early, using explicitly synthetic proof material:

1. A true fragment rests on a readable leaf. Its marginal companion responds
   to one literal subject in it; the rest of the page leaves the words room.
2. The Reader presses **Keep** on a physical seal. Once the keep has succeeded,
   the seal takes an impression and the fragment settles into the Book. Sound,
   pressure, and movement agree on that single event.
3. The Braiding Table opens at the actual fragments available today. The Reader
   recognizes their own words immediately. A small thread links the scraps that
   the existing braid process actually uses.
4. The finished braid arrives as written paper. One original line is available
   beside its new context, with real provenance. The Book lets the Reader read
   before it asks for another act.
5. Between later Pages, an eligible return brings that fragment or its motif
   back. Any claim that it has returned is supported by actual history.
6. In the existing edition reader, the fragment can be located in the real volume.
   The volume opens at that passage; the series on the shelf carries the same
   identity across digital and paper presentation.

This is the first connected proof of the ambition. It must remain understandable
without explaining the Curator or showing an internal graph. Ordinary visits
need not perform the whole sequence, and every step allows the Reader to leave.

### Art direction across the whole Book

- Make ink, paper, fabric, thread, leather, metal, and light behave consistently
  across the folio and its destinations. A gold accent has a material job; the
  weather and sky already implemented remain the environmental foundation.
- Give different places different working materials: loose correspondence,
  pinned charts, stacked scraps, and a volume opening at its remembered passage.
- Use a broad expressive range: a plain sentence, a magnificent plate, a tiny
  rude note, an overworked specimen sheet, an almost empty letter, a densely
  inhabited margin. Avoid giving every encounter the same emotional volume.
- Reserve rare movement for something happening. A creature may shift once when
  disturbed; a seal compresses under a finger; a folded leaf opens. Reading is
  allowed to be still.
- Let the Reader's chosen destination and ribbon win over spontaneous staging.
  The Book can suggest, juxtapose, and occasionally interrupt; it cannot make
  deliberate navigation unreliable.
- Source every personal detail from live, permissioned evidence. Authored fiction
  may have its own autonomous business, clearly separate from the Reader's life.

## Verified starting points

- `Shared/ReferenceLibrary.swift` registers 41 bundled illustration asset names;
  all 41 corresponding imagesets exist. These are catalogue candidates, not 41
  visually approved interleaf plates.
- `ContentPacks/count-unbound/plates/` contains 24 staged October JPEG plates.
  Local staging is not evidence that those bytes are installed or currently
  delivered to every Reader.
- `PagesRisingFolio.interstitialKind` currently chooses illustration leaves from
  seven fixed asset names. This is a selector restriction, not an art shortage.
- `IlluminationPackRegistry` already brings enabled content-pack marks into the
  shared cabinet used by folio leaves, Pagewright, and illuminated photographs.
- There is one interleaf at each Page-document boundary. Its kind is chosen
  from six seeded slots, with a special priority for actual grimoire residue.
- Reader quotations draw from up to 32 recent eligible passages; image selection
  indexes into the authorized Photos library. Neither selector currently ranks
  its content against the surrounding reading.
- Text recipes can split a paragraph across separate fields. Decoration placement
  rejects collisions, but its budget can be spent on support and handwriting
  before the primary mark is placed.

## Stage 1: establish the reading contract

Work in the existing paginator and compositor in `InsideCoverApp/PagesRisingFolio.swift`.

1. Keep continuous prose continuous by default, including continuation leaves.
   Use separated regions for actual separate content: evidence, quotation,
   postscript, annotation, or authored section. Seeded geometry must not invent
   a semantic division within an ordinary paragraph.
2. Preserve paragraph order, intentional short passages, whole titles, and
   meaningful paragraph breaks. Apply widow/orphan protection without treating
   every short complete thought as an error.
3. Select density and reserve its paper before text measurement. On phones,
   preserve a comfortable reading measure; move large compositions onto an
   interleaf rather than shrinking prose or turning it into a thin column.
4. Fix attribution: grimoire residue must not carry the Reader quotation label
   `YOUR INK, COME BACK UP`.
5. Replace photograph-template claims of contextual recognition unless the
   selection has actual evidence for that claim. A chance discovery may be
   presented honestly as a chance discovery.

Acceptance: an ordinary paragraph does not jump across an ornamental gap;
postscript space contains actual postscript matter; title/body order and
attribution remain correct at phone, tablet, and accessibility sizes.

## Stage 2: open the illustration pool through existing catalogues

Extend `LabyrinthIllustrationPlate` / `BookReferenceCatalog` and the existing
content-pack path. Do not create an independent folio art cabinet or scan every
image into eligibility just because it exists.

- Curate suitable evergreen plates from the registered 41 assets and other
  existing artwork. Record stable identity, image reference, title, subject tags,
  aspect ratio, composition suitability, and any character/story restrictions.
- Add optional backward-compatible interleaf illustration entries to the existing
  Page-pack contract. They join the same catalogue query as evergreen entries;
  a pack is provenance and eligibility, not a separate picker.
- Reuse installed managed monthly media and release validation. Extend the
  existing delivery contract where a print-only plate is not yet eligible for
  app use. Never assume a staged file is a delivered asset.
- Give monthly plates explicit eligibility: active month/event, canonical phase,
  and required scene progress when an image could reveal a story outcome.
  Use the canonical `SETUP -> BUILDUP -> CLIMAX -> AFTERMATH` phases.
- Favor this month's eligible art while keeping evergreen art in circulation.
  Avoid immediate repeats of an exact plate or the same subject when alternatives
  exist. Freeze the chosen identity for a composed boundary so repainting or
  reopening it does not shuffle the picture.
- Already encountered or kept material retains its identity and supported asset
  resolution when a monthly eligibility window closes. Changed bytes require new
  immutable asset IDs; new eligibility must not rewrite an old encounter.

Acceptance: the pool exceeds seven with reviewed assets; current monthly entries
participate when installed and eligible; unavailable, expired, locked, or
spoiler-bearing entries cannot leak into selection; ordinary evergreen fallback
always exists.

## Stage 3: give density its own composition decision

Add a shared, pack-authorable density preference to the existing leaf art-direction
contract. Resolve it using Page purpose, text length, available paper, surrounding
leaves, accessibility, and stable identity. These are internal terms, not Reader
controls.

| Density | Initial foreground allowance | Composition intention |
| --- | --- | --- |
| Quiet | 0–1 marks | A held sentence, intimate letter, image, or uninterrupted reading |
| Ordinary | 1–2 marks | One relevant companion and perhaps a small annotation |
| Rich | 3–5 marks | A coherent cluster, specimen collection, or correspondence with history |
| Overdone | 6–10 marks, where space allows | A rare inhabited margin, argument, nest, or overworked study sheet |

Counts are initial allowances to tune in proofs, not quotas or guarantees.
Material grain and wear do not count as foreground content. Large authored art
can be sufficient by itself.

- Let both ordinary leaves and interleaves be rich or overdone. Text-heavy leaves
  concentrate abundance in genuine margin space; text-light interleaves can use
  almost the whole sheet.
- Put the most relevant primary mark first, then compose companions around it.
  Do not let an incidental scrap displace the intended visual subject.
- Use relationships among marks: a creature leaning against a label, a scribble
  answering another scribble, a fastening holding a scrap, tracks leading to a
  sketch. Abundance has an arrangement and a reason.
- Permit intentional overlap among compatible decorative objects. Protect
  Reader prose, controls, and readable annotation text. Test rotated visual bounds
  and touch bounds, not only unrotated asset rectangles.
- Measure handwriting at its real rendered font and available frame. Longer
  notes need more paper or deliberate omission, not an unreadable reduction.
- Prevent runs of overdone leaves; follow a crowded encounter with breathing
  room. Preserve the existing Page-boundary contract in the first implementation;
  vary the encounter and its density rather than changing navigation topology.

Acceptance: a proof sequence visibly includes lean and lavish paper; lavish
leaves look intentionally crowded, preserve reading order, and remain usable on
a small phone. Accessibility sizes retain coherent content and navigation.

## Stage 4: choose encounters with local context and memory

Extend the current boundary resolver rather than inventing another feed.

- Rank eligible art and quotations against actual subjects from both neighboring
  Pages, relevant characters/places, canonical event state, and available return
  evidence. Use literal matching and authored relationships first; no new model
  inference is required for the initial upgrade.
- Carry Reader quotation source identity and date alongside the exact excerpt.
  Allow deliberate return to the original kept Page. Do not rewrite the excerpt
  into a fictional interpretation or assign it meaning the Reader did not supply.
- Keep chance encounters eligible. They provide otherness, but do not receive
  captions that claim a personal inference.
- Reduce adjacent repeats of kind, illustration, motif, and quotation within the
  composed sequence. Use actual exposure history for claims such as "again" or
  for a changed recurring motif; never infer that a Reader saw a queued leaf.
- Freeze a boundary's chosen encounter for its life in the current binding.
  Store only the state needed for actual continuity and respect existing source
  deletion/privacy behavior.

Acceptance: meaningful returns can explain their source; chance remains possible;
sequence variation survives reopening; a recognizable repeated motif has actual
continuity rather than random recurrence.

## Stage 5: add a small vocabulary of optional discoveries

Start with three interactions on existing leaf/inspection seams:

1. A folded annotation that opens to reveal a short second line.
2. A creature or scrap that moves to reveal something authored underneath.
3. A Reader quotation that opens its original kept Page through the established
   archive route.

Reuse the folio's host-level identity and inspection state so recycled page-curl
views do not reset discoveries. Persist reveal state where revisiting the same
object should remember the touch. Keep page-edge gestures available, make each
action accessible, and provide a still equivalent for Reduce Motion.

Most interleaves remain complete without a touch. Reveals provide literary pleasure,
not tasks, progress bars, collectibles that demand completion, or hidden required
story evidence. A rare short movement is more effective than every mark idling.

Acceptance: every new action is discoverable and optional; turning still works;
revisiting respects the object's state; no reveal falsely claims a real-world
Reader action.

## Stage 6: curate and then commission art for actual gaps

First make a contact sheet of eligible existing illustrations and identify which
work at full-leaf and marginal sizes. Use those references for any new generation.

Proposed first brief: 12 evergreen interleaf scenes, followed by 6–8 dedicated
plates per monthly issue where existing issue art does not cover the need.
These are proposed quantities, not artwork commissioned by this plan.

Evergreen subjects can include margin creatures occupied with their own business,
an impossible library detail, an ordinary object under close observation, and
quiet windows onto places in the Book. Monthly art adds actual event business and
phase-specific changes. Some images should leave space for live marks; some should
be finished dense compositions; some should remain almost bare.

Production brief requirements: house-style references, role, full-leaf aspect
ratio, safe focal area, whether live annotations will surround it, subject tags,
eligible phase/scene, title/provenance, and delivery filename. Keep masters and
publishable derivatives separate; preserve required monthly implementation stems.
Do not bake Reader text or personal facts into generated artwork.

## Stage 7: make leaf actions physical

Extend `FolioLeafPage`, the existing leaf commands and keep/trash callbacks,
`FolioSavedPageRibbon`, `BookFeedback`, and `BookMotion`. Existing tearing,
ephemera handling, and ribbon behavior are foundations to refine, not replace.

| Act | Proposed presentation | What makes it true |
| --- | --- | --- |
| Keep | A labeled seal receives a fingertip impression; the scrap settles and gains its kept mark | The existing keep operation succeeds once |
| Open | A fold, envelope, or attached slip opens toward its own destination | The existing Page-specific route opens |
| Answer | The printed instruction and writing area feel like part of the actual leaf | The Reader's draft survives leaf recycling |
| Tuck deeper | A loose object slides beneath the binding | The visiting scrap leaves the current setting through the existing action |
| Trash | The current tear/release treatment follows the correct action semantics | The existing trash operation and recovery rules remain authoritative |
| Bookmark | The real saved ribbon slips between these particular leaves | The existing saved reading position changes |

Preserve clear labels and comfortable targets. Material gestures complement an
ordinary accessible button; the Reader never needs to decipher a wax symbol or
perform a drag to complete a basic action. Do not introduce a confirmation step
for an ordinary Keep.

Pending, succeeded, and failed are distinct states. A press can indent a seal
immediately; the permanent impression waits for actual success. Failed writes
retain the draft and show a clear retry. Never let animation call a mutation
twice or make an uncompleted operation look complete.

Acceptance: a Reader understands each act on sight; the material response is
specific to its result; rapid taps, interruption, and recycled leaf hosts cannot
duplicate or lose the operation; Reduce Motion retains the result as a still mark.

## Stage 8: travel through the object

Extend `BookPresentationGate` in `ContentView.swift` with destination-specific
presentation intent, composed with the current sheet and division routes.
Reuse the established folio, inspection, and motion infrastructure. Do not add
another navigation system.

| Destination | Opening gesture | Resting state |
| --- | --- | --- |
| Letter | An addressed fold opens | Readable correspondence |
| Academy map | A chart unrolls or opens at its crease | The existing live parchment atlas |
| Stacks | A filing slip parts the leaves | The existing search and archive surface |
| Braiding Table | The held scraps spread onto the work surface | The actual available fragments |
| Bound volume | Its cover opens at the selected passage or saved place | The real edition reader |

Keep each gesture brief and interruptible. Preserve the original reading position
on return. Transition geometry has to work on phone and tablet without pulling
the Reader through an empty screen. Present prepared content immediately when it
is available; replace the unconditional generic settling delay with the actual
destination's readiness and an honest resting state during work.

If content is slow, the object remains useful: a legible title, a real outline or
available scraps, and clear status. Moving ink is not a fabricated progress meter.
Back and close stay visible. Sound follows the material gesture once; reuse
`BookFeedback` events and avoid stacking several effects on one tap.

Acceptance: the Reader can identify where they went from the presentation;
opening and returning preserve position; slow, cancelled, failed, and still
presentations remain legible and responsive.

## Stage 9: put the actual day on the Braiding Table

Extend `BraidingTableSheet` in `BookSurfaceViews.swift` and its existing
`ContentView` presentation. Pass lightweight previews and identities of the
actual source fragments rather than only `fragmentCount` and `braidCount`.
Reuse the established braid/re-braid/open callbacks and existing composition
provenance; do not invent a parallel braid engine.

- Lay out the available words, photographs, and scraps as a small working set.
  The surface must be readable and navigable even when several fragments overlap.
  A simple ordered view remains available for accessibility and narrow layouts.
- Let touching a scrap show its exact source. The table makes private life
  recognizable rather than turning it into decorative placeholder text.
- Show the real existing braid as bound paper at one side. Later keeps wait as
  loose scraps. This makes the difference between opening, re-braiding, and
  making another braid visible before the Reader acts.
- Give the action a physical handle with a plain verb, such as **Braid today**.
  Do not make the Reader manually connect every fragment to invoke the engine.
- If the engine reports which fragments were used, their threads can meet in
  the resulting paper. Otherwise use a general joining gesture and leave exact
  participation claims to inspectable provenance.
- For an empty day, the table has honest empty paper and one small invitation.
  It does not fabricate scraps to fill the composition.

Acceptance: the Reader recognizes today's real fragments, understands the three
existing braid actions, and can trace a finished braid back to its sources.
Generation remains cancellable where the current engine supports it, and all
states retain clear text.

## Stage 10: Bookshop and Bindery — deferred

This stage is excluded from the current implementation order and acceptance
scope. Retain these ideas for later; do not change `BookShopSheet`, its entrance,
or its Bindery destinations. Shared transition upgrades must preserve the current
Bookshop behavior. The following paragraphs describe future work only.

Extend `BookShopSheet` and its existing destinations, stall state, clerk banter,
wares, publication candidates, preview URLs, and order/membership callbacks.
Preserve the functional routes and existing commerce semantics.

- Stage the shop around the first available wares, the clerk's actual line, and
  the counter ledger. Shelves can carry objects and labels, small notes can be
  pinned nearby, and a shuttered stall changes the scene using real `stall.open`
  state. Remove decorative dependence on a generic storefront tile.
- Let the clerk have business already underway, drawn from authored stall/Cast
  state. Occasional motion and asides should respond to that business or an
  actual haggle outcome, rather than firing on every visit.
- Give the Bindery a work surface and a legible shelf of real prepared editions.
  Covers, thickness, cadence, dedication, and readiness come from publication
  data. An unprepared volume is visibly waiting for composition, not a fake
  finished book.
- Bring the selected volume forward. Let the Reader see its actual cover and
  representative pages, then open the complete existing proof. Private excerpts
  remain inside the Book's private presentation.
- Express digital binding, print preparation, checkout, and fulfillment as
  distinct real states. Thread or a wrapper may celebrate a completed operation;
  it never claims that payment or printing happened before confirmation.
- Keep price, currency, recurring cadence, shipping, status, and cancellation
  explicit at the decision point. Use the existing native payment flow.
  Magical staging should make the chosen object clearer.

Acceptance: a Reader can enter at Market, Bindery, a membership, gifts, or Print
Studio and reach their chosen destination directly; the presentation is inhabited
without making purchases, proofs, or membership management harder to understand.

## Stage 11: make this Reader's Book recognizable

Use existing reading wear, saved ribbon, kept Page identities, Book relationship,
interjection records, Tale scars, canonical relic/history, and bound-volume
records as the authority. Begin by tracing which records already reach visible
composition; wire underused records into those seams before creating new state.

| Evidence | Possible material expression |
| --- | --- |
| A genuinely frequented division | The existing worn edge and tendency to fall open |
| A particular kept fragment returning | Its same identifying scrap, mark, or thread, with live source access |
| A recorded Book disagreement or correction | A small amended annotation tied to the actual exchange |
| A completed canonical event and earned relic | Its particular impression, attached object, or repair |
| A prepared or bound volume | A recognizably related cover, spine, and page identity |

These changes accumulate selectively. A repair should have one cause and one
recognizable form; it should not randomly appear everywhere after the Reader
reaches an arbitrary usage count. Reader refusal, distress, and absence never
become damage to the Book or a debt they must repay.

Extend current dog-ear, smudge, left-open, underline, ephemera, and wear vocabulary
where applicable. The Book's feral character can appear in a juxtaposition, a
crooked insistence, a short correction, or its choice of an inconvenient true
return. Readability and the Reader's actual choices stay authoritative.

Acceptance: a mature Book differs recognizably from a fresh Book for traceable
reasons; the Reader can inspect meaningful sources; deleting a source removes
dependent private detail through the existing lifecycle; navigation and archive
access are not withheld as a literary punishment.

## Stage 12: compose the moments of transformation

Coordinate existing keep, braid, remember, and edition presentation around the
signature encounter. The main wonders deserve a clear beginning and result.

- **A fragment kept:** one completed material act, then room to continue.
- **A braid completed:** the actual composed writing becomes the focus. A real
  source excerpt can sit beside it; progress furniture gives way to reading.
- **A meaningful return:** the original and its new context meet visibly. Explain
  only the relationship supported by evidence, then let the Reader respond.
- **A volume bound:** the actual prepared edition is revealed with its cover,
  date span, dedication, and real page count. It can open at a recognizable
  passage and later join the existing series shelf.

Ordinary operations remain quick. Larger staging is reserved for earned firsts,
actual changes, and chosen binding moments. The reader can skip or dismiss a
reveal, and repeat visits open the useful object rather than replaying a ceremony.
Apply the same source identity and house materials across these moments so the
connection is felt without a system explanation.

Acceptance: the Reader can tell what changed and recognize its origin; no reveal
manufactures personal meaning, delays access to their writing, or claims a
finished artifact that does not exist.

## Stage 13: verify the reading, then release

Review source and content contracts first. When the user explicitly asks for a
build, perform focused logic tests and generate a representative on-device or
simulator proof sequence. Do not equate parser checks with typechecking, tests,
rendering, or Reader proof.

Required proof coverage:

- A long uninterrupted Page, a short question, a letter with actual postscript,
  an illustrated Page, and a Page with input and choices.
- All interleaf kinds, all density levels, and adjacent crowded/quiet examples.
- Phone and tablet, ordinary and accessibility text, VoiceOver and Reduce Motion.
- Empty quotation pool, absent photo permission, unavailable iCloud photograph,
  unavailable monthly bytes, old pack versions, and expired event eligibility.
- Correct Reader/Book attribution, canonical scene gating, stable selection,
  no inappropriate repeat, honest fallback, rotation/ink collisions, and page turns.
- Keep, answer, bookmark, tuck, and trash through real success/failure states.
- Each destination opening and return, including cancelled or slow preparation.
- The actual Braiding Table with empty, sparse, and abundant days; opening,
  re-braiding, and creating another braid with real source provenance.
- Verify that shared presentation changes preserve the existing Bookshop entrance
  and behavior. Bookshop and Bindery redesign remain outside this upgrade.
- A fresh Book, a month-old Book, and a mature Book with evidence-backed history.
- The complete signature encounter, including interruption and later reopening.

Inspect full sequences as well as individual leaves. The product test is whether
a Reader wants to pause, touch, revisit, or turn ahead, and can explain what caught
them. Only rendered and Reader review can establish that the leaves look good.

Build, install, launch, monthly publication, and hands-on visual review remain
distinct gates. Publishing new monthly assets is a separate release operation,
using existing signing/delivery/rollback machinery.

## Suggested implementation order

1. Reading and attribution repairs, expanded catalogue, monthly eligibility,
   density range, and primary-mark-first composition.
2. The physical Keep act and actual-fragment Braiding Table; compose the first
   signature encounter around the real keep and braid callbacks.
3. Destination-specific openings and returns, using existing routing and motion.
4. Relevant returns, sequence memory, and evidence-backed personal material history.
5. The three optional interleaf discoveries and a first overdone margin scene.
6. The actual-volume reveal in existing edition readers, extending the signature
   encounter into the Reader's series without changing Bookshop or Bindery surfaces.
7. Commission missing art after inspecting what existing material achieves.
8. Full-sequence visual and Reader review; then the separately authorized release.

The first slice should already improve the everyday Book materially. Later slices
deepen its character without replacing the established folio or content systems.
Completion means the whole sequence sustains the Book's identity: opening,
reading, touching, keeping, making, returning, and binding all belong to the
same odd artifact.
