# Magical Book Simulator

What the app would have to become to earn the phrase, written against the
codebase as it stands on 2026-09-03 (`feat/reader-role-and-first-door`).

## Verdict

Not yet. What exists is a magical book **correspondent**: it observes, composes,
delivers, and waits for a reply. A simulator is *inhabited* — its world has
extent, ticks whether or not anyone is looking, and can be searched.

The gap is structural, not a content shortfall. The simulation is already here.

## What is already simulation

| System | Where | In game terms |
|---|---|---|
| 20 `CastAct` verbs, `CastMannerCatalog` favours/refuses, `CastActLedger`, two-sided memory | `Shared/CastUndertakings.swift:1919` | A social-sim NPC behaviour model |
| `BookJumpEngine` — `startCost 3`, `advanceCost = min(3, max(1, depth-1))`, `maxDepth 4`, souvenir-gated reward, `coldDays 5`, `borrowedRuleDays 4` buffs bending curation via `surfaceBoosts`/`greyShift` | `Shared/StoryEngine.swift:538` | A complete roguelike expedition loop |
| `BeliefGenerationKind.cost` vs `compassRunReward`/`electiveCompletionReward` | `Shared/WorldSystems.swift:12144` | A closed economy with sources and sinks |
| `GreyPageThreatEngine` — 72h rescue window, 7d cooldown, erasure that removes pages from the living day (`ContentView.swift:1082`) | `Shared/WorldSystems.swift:41` | Permadeath |
| `StoryConsequenceResolver` + conditions + atoms + validator + ledger | `Shared/NarrativeCore.swift:1743` | Scripted consequence with authoring-time validation |
| `DeskJob` (errand/instrument/reprise/play/quiet); `CuratorReturnBeat.answerWindowHours = 72` | `Shared/SurfaceAndCurator.swift:8022` | An encounter table with a debt clock |
| `WorldEventCalendar` / phases / beats / relics / casebooks | `Shared/WorldEvents.swift` | Live-service season structure |

## The one thing wrong: the Curator is a total function

Every path from world state to reader runs through `BookCurator`, whose output
is `surfacedPages(limit: 3)` (`Shared/SurfaceAndCurator.swift:3213`). Nothing in
`ContentView` surfaces around it.

Three consequences:

1. **Nothing exists that must be found.** Everything reaching the reader is
   something the Book chose to hand over. Surprise is possible in content, never
   in discovery.
2. **Nothing happens elsewhere.** No `whileYouWereGone`, no `daysAway`.
   `BGTaskScheduler` is registered (`AppSupport.swift:5654`) but only refreshes
   widgets and whispers. The world does not tick; it is composed at read time.
3. **No model, so no planning.** `StorySceneChoice` names its field
   `hiddenEffect` (`StoryEngine.swift:1360`).

The counter-argument is already in the repo, in `BeliefEconomyPolicy.generationSpendLine`:

> The economy was correct and invisible.

That is this whole document, generalised.

## The moonshot: break the Curator's monopoly

Not by weakening it. By adding a second channel — **space that can be searched** —
so curation becomes one of two ways the world reaches the reader.

### Move 0 — The world tick

A background pass running `CastActMemory`, `WorldEventLifecycleReconciler`,
`PlaceMemoryEngine` and Grey reconciliation *forward* between sessions, writing
a witness log. Cheap: every engine already runs deterministically off ledgers.

**Rule: the Book does not summarise the tick.** It leaves evidence. A summary
turns the second channel back into the first.

### Move 1 — Interior places that hold state

`PlaceState`/`PlaceIncident` (`Shared/PlaceMemory.swift`) already model real
places. Generalise to the Book's own rooms: Bindery, Stacks, Bookshop,
Quillquarium, Academy, Margins. Each carries occupants, pending things, residue
from the last visit, and what changed since.

`GlowMenuSection` (`BookStatusCards.swift:1135`) is already the hub screen; its
subtitles are static strings. Make them live:
*"The Bindery — three things waiting. Mook left the lamp on."*

Highest-leverage move in the list.

### Move 2 — Physical book-verbs as systemic verbs

~40 action callbacks in `CapturePageSheet`, nearly all flat one-shot commits.
The book object supplies a verb set no other app can use:

- **Dog-ear** — a dog-eared page cannot be retired by the Curator.
- **Underline** — the marked phrase becomes a first-class token the braid and
  `SemanticKeepEcho` must consume.
- **Tear out** — permanently destroy a page to buy something. A sacrifice sink
  for an economy that currently only spends Belief.
- **Lend** — give a page to a Cast member; it leaves the desk for days and
  returns annotated.

Scrapbook Studio already renders this vocabulary. It is not yet a system.

### Move 3 — Expeditions, generalised from BookJump

`BookJumpEngine` is the best game system in the app and it is trapped in one
page type. Lift the shape — pay in, escalating depth cost, cooldown,
return-with-souvenir-or-nothing, borrowed rules as timed buffs — into an
`ExpeditionEngine`, and run the Stacks, the Labyrinth, the Academy and the
Grimoire sweep off it.

### Move 4 — Publish the knowable rules

Generalise the `generationSpendLine` precedent into the Colophon: what Belief
costs, what dog-earing protects, how long the Grey's window is. The Book's
*motives* stay arcane; its *physics* become public. Planning is what turns
systems into play.

### Move 5 — Visible clocks on the object

The Grey threat is the only real stake and its 72 hours live in a notice. Put it
on the leaf: the page greys at the edge over three days. Material response, not
UI — the same class as the unfinished full-moon souvenir glow in
`docs/interactive-page-audit.md`.

### Move 6 — The serial consumes and emits

`WorldEventPack.authoringManifests` is declared (`WorldEvents.swift:31`) and
never populated; only two packs exist. Before authoring September's fiction, an
authored beat must be able to:

1. read `NarrativeWorldEntity` / `CastActLedger` for who this reader actually knows;
2. leave a `StoryConsequenceAtom` the deterministic systems carry for months;
3. gate its next beat on a reader-supplied object — a dog-eared line, a kept page.

Otherwise the serial is a magazine bolted to a simulation, and the seam shows.

## First slice

Move 0 + Move 1, on the Bindery alone. Tick the world nightly, give one room
state, and let the reader find one thing there the Curator never showed them.

If that lands, the rest is worth building. If it does not, the cost was a week.

## Constraints this plan must not break

- **No dashboards.** Aliveness and rut stay internal-only gates
  (`permanent-twin-plan.md`). Room state is the *Book's* interior, never the
  reader's metrics.
- **The Book stays a character.** Rooms speak in stance-rendered prose, subject
  to `BookCharacterLint` (`docs/the-book-is-a-character.md`).
- **Self-talk ration.** Rooms are Pages about the Book; the `speaksOfItself`
  ration applies.
- **The Director keeps the only forced slot** (`docs/living-book-director.md`).
  A room may hold something; it may not demand.
