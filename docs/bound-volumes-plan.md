# The Bound Volumes — making the weekly issue and the monthly binding worth $249

Written 2026-08-08. Companion to [bound-year-plan.md](bound-year-plan.md), which
proposes selling four printed volumes a year at $249. This plan is what has to
be true of those volumes first.

---

## The finding

The **machinery** is moonshot-grade and largely built: `EditionCurator`,
`BindingRevelations`, the memory spine, `MeaningfulPassageSelector`, the
continuity digest, Gemma's binding-of-bindings, and 3,756 lines of PDF
rendering with composted parchment, torn scraps, tape strips, star charts, foil
stamps and a colophon.

The **editorial layer was frozen early**. It is a well-made book about a version
of the app that no longer exists.

### The audit

| | Finding |
|---|---|
| Page types | **198 exist. ~15 get named treatment.** The rest fall into "Other Kept Pages", capped at 48 — a heavy month silently drops the overflow. |
| Newer systems | **0 of 23 reach the binding.** TaleGrammar, CastAct, CastUndertakings, StandingLedger, InferredReaderSignals, TwinExperiments, ContextWeave, ChosenQuill, Quillquarium, PersonOfTheBook, BookPocket, Feastday, PactVerdict, PactErrand, FaeBargain, RivalryEdge, SemanticKeepEcho, BookAsks, TaughtReading, FirstWagers. (`LivingTale` is the one exception.) |
| Reader identity | `BookForewordWriter.foreword(...)` takes no reader name and no role. The Book performs a naming ceremony with 360 possible identities, then writes a foreword addressed to nobody. |
| Weekly issue | **No sections at all.** Three highlights, ≤2 revelations, a scrapbook count, tales finished. Correct for a retention beat; insufficient for a printed volume. |
| Marginalia | Rendered beautifully by `drawMarginNote` — angled, hand-inked, deterministic. Filled from continuity signals and theme motifs. **Nobody is speaking in them.** |

---

## The structural problem, which is deeper than any missing system

The monthly's sections are **Daily Braids, Souvenirs, Letters, Images, Other
Kept Pages**. That is an archive organised by *filing category*. No book is
organised that way.

A book is organised by **narrative**, with the archive as back matter.

Adding six more type-sections would make the filing cabinet larger. The moonshot
move is to restructure, so kept pages become *evidence inside a story* rather
than *categories in a list*.

---

## The three levers

### 1. Restructure into a book

**Front matter** — half-title, frontispiece plate, chapter heading carrying the
reader's role, dedication page (Bound Year members write their own), foreword
addressed to the person the Book named.

**The movements** — narrative, not categories:

| | Movement | Draws on |
|---|---|---|
| I | How the month opened | continuity, theme, arrival |
| II | What you kept | passage compass leads; pages as evidence beneath it |
| III | What the Cast did | `CastAct`, `CastUndertakings` — currently absent |
| IV | What I noticed | `BindingRevelations` — the Book's claims, with receipts |
| V | What was owed | pacts, fae bargains, `PactVerdict`, `PactErrand` |
| VI | The world that month | feasts, world events, Academy season, weather |
| VII | What finished | tales bound, threads closed |
| VIII | The closing | the Book's last word |

**Back matter** — the complete archive as an appendix (**uncapped**, which
retires the 48-item drop), named constellations, the Pocket, and a colophon
carrying the reader's role, Reader's Mark, founding number and binding date.

The catch-all does not get deleted. It gets **moved to where a catch-all
belongs** and stops pretending to be a chapter.

### 2. Give the marginalia a voice — the biggest jaw-drop per unit of work

The hard part is done. `drawMarginNote` already places hand-inked notes at
deterministic angles in two ink colours, clear of the text column. What is
missing is attribution.

There are 22 canonical Cast members with illustration plates, bespoke
`CastDossier` bios, per-voice accents and glyphs, and `CastAct` records of what
they actually did. Characters annotating the margins of the reader's own life —
in their own voices, with their own glyphs — is the single most striking thing
this product could print, and it is perhaps 80% built.

- `marginaliaLines(for:)` gains cast-attributed lines drawn from `CastAct`
- `drawMarginNote` gains a glyph and an accent colour per speaker
- Cast plates become movement dividers

### 3. Put the illuminated plates on the page

`IlluminatedQuoteCard` has a seed-driven composition engine — palette, border,
layout, marginalia — with content pinned to 904pt so quotes never clip. The 22
cast plates exist. **Neither reaches the PDF.**

Rendering passage-compass selections as full-page illuminated plates, and cast
plates as dividers, is enormous perceived value for close to zero new art.

---

## Phases

**Phase 0 — Identity. DONE 2026-08-08.**
- `BoundReaderRole` — a Codable flattening of `ComposedRole`, frozen at binding
  time so a volume bound in June still reads the way it read in June. Carries
  `fullName`, `signature`, `gloss`, `compassLine`, and the mark with its
  evidence.
- Threaded onto `MonthlyEdition`, `AnnualEdition` and `WeeklyIssue`, through
  `edition(...)`, `annual(...)` and `WeeklyIssue.current(...)`, and out to every
  call site via a `boundReaderRole` helper.
- **The prose knows the difference between the three role strings**, which was
  the whole craft problem: `gloss` is descriptive and can be woven mid-sentence;
  `compassLine` is an *imperative* and would have read as nonsense in a
  paragraph, so it lands last, as a standing charge into the blank month; the
  full three-part `signature` appears exactly once, in the colophon.
- **A mark is never printed without its evidence.** Pinned by test. A mark is
  the Book making a claim about the reader; without the receipt the whole
  naming ceremony is flattery.
- 12 tests in `BoundReaderRoleTests`. Full suite green at 2451.

**Phase 1 — Restructure. DONE 2026-08-08 (model layer).**
- `MonthlyEditionSection.Placement` — `frontMatter` / `movement` / `backMatter`.
  Optional-backed so volumes bound before the restructure still decode as
  movements, which is what they effectively were.
- **Sections reordered into a book.** The month is named, the nights tell their
  story, the reader's own words follow, the Book makes its claims, the world
  turns around it, something ends, and only then does the archive open.
- **The tales moved from first to last.** They used to be the opening section;
  a volume should not lead with its endings, so they now land as the resolution.
- **The Nightly Braids became their own movement**, retitled and framed as the
  month's spine: *"Read straight through, they are a story you were living
  without stopping to call it one."* Gemma's `bindingStory` is the overture to
  that movement.
- **The archive cap is retired.** "Other Kept Pages" is now "The Complete
  Archive", sits in back matter, and has no ceiling. `pageSection` takes
  `limit: Int?`, and only the appendix may pass `nil` — a movement with no
  ceiling stops being edited. A test binds a heavy month past the old 48 items,
  which confirms the cap was dropping real pages.
- 8 tests in `BoundVolumeStructureTests`.

*Still open in Phase 1:* the PDF renderer draws sections in array order, so it
already inherits the new architecture — but it does not yet break pages on
placement, or give front matter and the archive their own visual treatment.
That belongs with Phase 3's plate work.

**Phase 2 — The Cast in the margins. Model layer DONE 2026-08-08.**
- `BoundMarginNote` — a margin note that knows *who said it*: speaker slug and
  name, the speaker's own `accentHex`, their `glyph`, and the text.
- `CastMarginalia.notes(acts:start:end:)` — **the Cast is quoted, never
  paraphrased.** Every `CastActRecord` already keeps "the sentence that reached
  the page… so it can be quoted back exactly", and that sentence has never been
  printed. Conduct is a claim about a character, so it is quoted or it is not
  printed. Ink and glyph come from `KeepMarginalia.voice(forSlug:)`; an actor
  with no voice card speaks under their ledger name with no invented ink.
- **Two notes per speaker per volume**, so a busy month stays polyphonic
  instead of becoming one character heckling from every margin.
- A **"What The Cast Did"** movement reports every act in the window (up to 24)
  in the order it happened, even where the margins only quote two of them.
- A quiet month gets no movement and no spoken margins — silence over filler.
- 9 tests in `CastMarginaliaTests`.

**Phase 2 — renderer. DONE 2026-08-08.**
- `marginNotes(for:)` **interleaves** the Cast's quotes with the Book's own
  observations, rather than stacking them — otherwise the characters crowd the
  opening chapters and then fall silent for the rest of the volume.
- The torn, taped scrap now carries the note in **the speaker's own ink** and
  signs underneath, right-aligned, with their **glyph and name** — `‽ Pippa
  Pilcrow` in `B5382E`. The scrap grows to make room for the signature. The
  Book's own notes stay unsigned and in the volume's ink, which is the right
  distinction: the Book is the narrator, the Cast are guests in the margin.
- `castInk(_:)` — the UIKit twin of `Color(bookHex:)`, since `InsideCoverCore`
  imports neither SwiftUI nor UIKit and the accents live there as plain strings.
- Wired end to end: the monthly volume and **every chapter of the annual**
  receive `vault.data.castActs.records`. Without the annual wiring the hardcover
  — the artifact people actually pay for — would have had silent margins.

*Remaining:* cast plates as movement dividers (folded into Phase 3, same pass
over the renderer).

**Phase 3 — Illuminated plates. Frontispiece DONE 2026-08-08.**
- **The frontispiece is the reader's patron.** `ReaderRole` already carried a
  `patronSlug`; `BoundReaderRole` now carries it through to the volume, and the
  PDF opens with a full-page plate of the cast member who stands for this
  reader, captioned *"who stands for The Magpie of the Blue Hour."* The oldest
  move in bookmaking — a portrait plate facing the title — made personal.
- `patronPlateAssetName` derives the asset from the slug; all eight current
  patrons resolve. The renderer still checks `UIImage(named:)` first, so a cast
  member added without art degrades to no frontispiece rather than a blank page.
- 3 tests added to `BoundReaderRoleTests` (15 total there now).

**Phase 3 — illuminated quote plates. DONE 2026-08-08.**

*The perf decision, and why:* `IlluminatedQuoteCardRenderer` goes through
SwiftUI `ImageRenderer`, which is `@MainActor`, at 1080×1350 a card. Leaning on
`BinderySewingOverlay` to cover the cost was rejected — main-thread work would
freeze the sewing animation itself, so the thing meant to hide the wait becomes
the thing that shows it. Pre-render and cache instead.

- **The renderer is cache-first.** The composition is seed-deterministic, so the
  same line at the same seed always composes the same card; the existing stable
  filename became a cache key. Only the first binding of a given line pays.
  Carries a `designVersion` so a future card redesign orphans stale plates
  rather than serving them forever. The share-card path gets this free.
- **Plates are composed before the PDF pass**, in `illuminatedPlates(for:)`,
  with `await Task.yield()` between cards so the sewing animation keeps ticking.
  `write(_:plates:to:)` takes them pre-rendered, which keeps `@MainActor`
  `ImageRenderer` out of the PDF writer entirely.
- **Drawn as a plate signature** — gathered together after the binding story,
  the way real books gather plates because of how signatures print. The binding
  story is the braids' overture; the plates are the month's own strongest lines
  right behind it.
- Each plate wears `PageVisualStyle.style(for: selection.pageType)`, so an
  illuminated souvenir still looks like a souvenir.

**Phase 3 — cast dividers. DONE 2026-08-08. Phase 3 complete.**
- `CastMarginalia.plateAssetName(forSlug:)` — a voice card is authoritative
  where one exists, because **Pippa's plate is `LabyrinthCharacterPilcrow`, not
  the mechanical form of her slug**, and a guess would miss it. Everyone else
  PascalCases cleanly. The renderer checks the image loads, so a wrong guess
  costs a divider and never a blank page.
- `CastMarginalia.lead(acts:start:end:)` picks whoever was most present in the
  month, ties broken on slug so a month binds identically twice.
- A full-page divider faces the Cast's movement: their plate, their name, and
  *"was in it most, this month."* **Earned, not decorative** — it is whoever
  actually turned up in the ledger.
- 5 more tests in `CastMarginaliaTests` (14 total).

**A bound volume now opens:** cover → the reader's patron, facing the foreword →
foreword addressed to them by the name the Book gave them → the binding story →
the illuminated plate signature → contents → the movements, with the Cast
annotating the margins in their own ink → the complete archive → a colophon
carrying their signature, mark and standing charge.

**Phase 4 — The weekly. DONE 2026-08-08 — and the premise was wrong.**

The plan said the weekly needed "a spine" because `WeeklyIssue` has no
`sections` array. Reading `WeeklyIssuePDFWriter` showed that was a
model-shaped conclusion about a rendering problem: the issue is already a
properly made little magazine — a masthead, torn taped section labels,
illuminated drop capitals, a day-by-day spread with honest lines for quiet
days, a centerfold for the week's strongest page, scrapbook plates, gutter
marginalia and its own colophon. It does not need sections; the writer imposes
the structure directly.

**The actual gap was parity.** The weekly never received the Phase 0 and Phase 2
gains, so:
- The cover printed `readerName`. It now prints the name the Book gave them.
- The margins were Book-voice only. The Cast now speaks there too — quoted,
  signed with their glyph, in their own ink, exactly as in the monthly.
- **The voice cap is lower than a month's: three, not ten.** A week is a narrow
  window; three voices is a conversation, ten inside seven days is a crowd.
- Wired through both the app and `SourceAdapters`, so the issue that surfaces on
  the desk carries the same voices as the one that gets bound.

*Not done, deliberately:* the Pocket. It belongs to a volume that has room for
keepsake plates, not to a seven-day magazine.

**Phase 5 — The seasonal volume. DONE 2026-08-08. All phases complete.**

- **The latent bug is fixed first.** `PhysicalBookVariant.from(_:)` derived its
  id from a binary `coverTreatment == .linenWrap` check, which labelled every
  non-linen spec the illustrated hardcover. That id is what the Worker checks
  against its allowlist, so a mislabel is a *rejected order*. Now an exhaustive
  `id(for:)` switch — adding a binding is a compile error here rather than a
  runtime surprise there. A test asserts every printable variant has a distinct
  identity.
- `PrintSpec.perfectBoundSoftcover6x9` — 6×9, `…FC.STD.PB…`, 32-page minimum.
  **`coverWrapMarginInches: 0.125`, not the hardcovers' 0.75**: a paperback is
  trimmed flush with the block, and a case-wrap allowance would push the cover
  art a full inch off register. `CoverTreatment.wrapsAroundBoard` makes the
  distinction explicit rather than a magic number.
- Adding the enum case broke the cover switch in `MonthlyEditionPDF`, exactly as
  predicted — the good kind of failure. A printed paperback cover is the same
  artwork problem as a case wrap, so they share a branch.
- `ALLOWED_VARIANTS` gains the variant, **deployed** (`8b2aa3ac`).
- `MonthlyEditionBuilder.seasonal(...)` composes three month-chapters into an
  `AnnualEdition` — which is already "a volume of month-chapters with a foreword
  and a closing." The only thing a year had that a season lacked was the word on
  the cover, so that became `coverLine`/`coverSubline`. Annuals bound before
  seasons existed read exactly as they did.
- **The naming rule is enforced by test.** The reader names their own seasons
  and only backwards; if they have named this stretch the volume wears it,
  otherwise the Book titles it by its months — *"March 2026 – May 2026"* — and
  invents nothing. A blank name is not a name.
- 11 tests in `SeasonalVolumeTests`.

*Not wired to UI.* The seasonal volume builds, prints and can be ordered, but
nothing in the app offers it yet — that belongs with the Bound Year membership
flow in [bound-year-plan.md](bound-year-plan.md), not here.

---

## Known hazards

- **`PhysicalBookVariant.from(_:)` derives the variant id from a binary
  `coverTreatment` check.** It silently mislabels the moment a third spec
  exists. Fix before Phase 5, not during.
- **Adding `CoverTreatment` cases breaks an exhaustive switch** in
  `MonthlyEditionPDF.swift:356`. That is a compile error, which is the good
  kind — but it means new cover art paths are required, not optional.
- **Saddle stitch is rejected**, costed and closed: ~$2/year saving, caps at ~48
  pages, cannot carry a 96-page seasonal volume.
- **Do not delete the catch-all.** It is the safety net that guarantees nothing
  a reader kept is ever lost. Promote out of it; never replace it.
- ~~**Telemetry is leaking into the prose.**~~ **FIXED 2026-08-08.**
  `lifecycleSignal` was emitting *"…has become a living thread: one kept page,
  0 events, current Glow 28."* into forewords, closings and margins. Glow is the
  reader's wallet, not a fact about their month, and "0 events" is a clause
  about nothing. Rewritten as seeded prose with no currency, no raw tallies and
  no zero counts; swept the rest of the projector for the same pattern and found
  none. Seeded per-thread so a thread phrases itself the same way every binding
  but two threads in one volume do not chorus.
- **Signals can overclaim on thin evidence.** Surfaced by the fix above: the
  lifecycle signal will say a subject *"has turned into a thread rather than a
  moment"* on the strength of a **single** kept page. That is a warrant problem,
  not a register one — the Book making a claim it has not earned, in the one
  artifact that is supposed to be all receipts. The line needs a floor before
  any volume is printed and posted.

---

## Decisions (locked 2026-08-08)

1. **Restructure before addition.** More type-sections would enlarge the filing
   cabinet. The volume becomes a book first.
2. **The archive moves to back matter, uncapped.** Completeness is a promise;
   it just is not a chapter.
3. **The Cast speaks in the margins.** This is the headline feature of the
   printed volume.
4. **Phase 0 ships first and alone**, as a read on whether identity alone lifts
   the prose.

Everything the Book prints must still be something it can show a receipt for.
