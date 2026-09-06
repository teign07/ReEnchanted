# The Private Grimoire

*A moonshot plan. The Book accumulates its own body of private correspondences —
the reader's laws, not universal ones — and is willing to be wrong about them out loud.*

---

## Thesis

Not `rose = love`. For **you**, parking lots after rain keep opening something.

The Book should end up knowing things no other Book could know, having learned them
from ordinary receipts, and should be able to show its work: how many times, when it
started, what would make it take the claim back, and every time it has already been wrong.

## Two decisions that shape everything

**1. No confirmation gate.** The Book asserts. The reader corrects afterwards.
A Book that asks permission before each belief is a coward, and that is not this character.

The honesty budget therefore moves from *pre-registration* (say nothing until proven) to
**post-hoc accountability**: claim freely, but every claim ships with a falsifier the Book
committed to in advance, and the Book publicly crosses out what fails. A practitioner's
grimoire is full of crossings-out. That is what makes it look used.

**2. The desk never computes correspondences.** It reads standing rows from a ledger.
All discovery is incremental, off-main, cursored, and bounded. This is not a late
optimisation — it is the load-bearing wall, and it is also, conveniently, the same change
that makes correspondences durable in the first place.

---

## Phase 0 — Put a number on "buttery"

`LoomBench`: a synthetic four-year archive (~1,500 days, ~4,000 kept Pages, every projector
firing). These were the design targets written before implementation:

| Path | Ceiling |
|---|---|
| Desk read of standing correspondences | < 2 ms |
| Ingest of one new observation | < 1 ms |
| One sweep chunk (idle) | < 30 ms |
| Full cold rebuild (migration only) | < 3 s, off-main |

The implemented regression ceilings are looser: 20 ms for a desk read and 150 ms for a
sweep chunk. The measured real-projector figures are recorded in the status below; the original
2 ms / 30 ms targets remain performance work, not achieved guarantees.
Per the archive-loads-off-main rule, every whole-archive read goes through
`BookDatabase.detachedDatabase()`.

---

## Phase 1 — The Ledger

The single highest-leverage change. Everything else compounds off it.

### The row

A persisted, sparse table keyed by `conditionID | outcomeID | shape`:

```
correspondenceKey
condition: FeatureDescriptor        outcome: FeatureDescriptor
shape: .conditional | .sequential | .seasonal | .absence | .returnInterval | .drift | .sibling

conditionDays: DayBitset            outcomeDays: DayBitset       jointDays: DayBitset
inHits / inCount / outHits / outCount

firstObservedAt   lastObservedAt   distinctYears   distinctSeasons
evidence: bounded reservoir sample (8 page IDs, reservoir-sampled so year one survives)

claimState: unspoken | spoken | standing | crossedOut | forbidden
falsifier   counterReading
revisions: [Revision]               readerStance: none | confirmed | notQuite | questioned | doNotRead
lastSpokenAt   spokeTag
```

Copy the record shape that already works: `ReaderAlivenessPattern` +
`ReaderAlivenessPatternFeedback` (`Shared/LiteraryContinuity.swift:5506`) already carry
supporting/contradicting IDs, first/last observed, confidence, counterReading and falsifier.
That silo is the prototype; this generalises it.

Reservoir sampling on evidence matters: it is what lets the Book say *"eleven Pages across
four years"* and show one from the first year instead of the eleven most recent.

### DayBitset — the technical key

Each feature's day-set is a bitmap indexed by days-since-archive-epoch.
Four years = 1,461 days = **23 `UInt64`s = 184 bytes**.

Every statistic the engine needs is then a word operation:

- distinct days → `popcount`
- joint days → `AND`, `popcount`
- condition-without-outcome → `AND NOT`, `popcount`
- "within 3 days after" → **shift the bitmap**, then `AND`
- seasonal recurrence → `AND` a precomputed season mask
- drift over time → the same test run against two half-range masks

The entire statistical core becomes popcounts over bitmaps. Cost scales with **years, not
Pages** — and it is incremental: a new observation sets bits and never rescans.

### Why the table does not explode

The pair table is **sparse because it is built from observed co-occurrences, not from the
cross product**. Each incoming observation carries ~8–15 features; it touches only the
role-eligible pairs *within its own feature set* — on the order of 50–100 cell increments,
bounded regardless of how many projectors exist.

### The sweep

On idle, off-main, cursored, chunk-bounded:

1. Visit cells whose joint popcount changed since the last sweep.
2. Cheap floor (≥ 3 distinct days) before any real work.
3. Full contrast test on survivors — lift, rate gap, exposure denominator.
4. Re-evaluate falsifiers on `standing` rows.
5. Advance cursor. Stop at budget.

### Cut the live recomputes

`LiteraryContinuity.swift:16398` (braid context) and `:11093` (dispute evidence) currently
call `RelationalLoom.connections` over the whole archive on user-facing paths. Both become
ledger reads. This is a perf win *today*, before a single new source is added.

---

## Phase 2 — The Registry

Make adding a source a file, not surgery.

```swift
protocol LoomProjector {
    static var id: String { get }
    static var domains: [FeatureDomain] { get }
    static func observations(from slice: ArchiveSlice, calendar: Calendar) -> [LoomObservation]
}
```

`FeatureDomain` carries its own metadata so the engine has **no switch statements to edit**:

- `conditionRank`
- `role: .conditionOnly | .outcomeOnly | .either`
- `sensitivity` (extends today's `isSensitiveInterpretation`)
- `provenance: .readerAuthored | .observedContext | .systemEvent | .generatedFiction`

**Role eligibility** roughly halves the pair space for free and kills nonsense pairs — weather
is a condition and never an outcome; *kept a Diary Page* is an outcome and never a cause of rain.

**Provenance** mechanically enforces the existing law: a `.generatedFiction` domain may be a
condition, never an outcome about the reader.

Port the two existing extractors (`observation(for: BookPage)`, `observation(for: ReaderLearningEvent)`)
onto the protocol. Behaviour-identical; `weaving()`'s fixed argument list dissolves.

Keep `RelationalLoomFeature.Family` as a convenience — the engine reads the descriptor.

---

## Phase 3 — The Batch

Variety of *claims* comes from variety of *sources*. So: many at once, not three.

**Conditions** — Fae species present · Working family · Compass Run kind (indoor/outdoor) ·
world event · moon · place memory · quill · Cast act · tale-grammar move · radio track ·
weather compound · feast day · season · travel · pocket object.

**Outcomes** — the keep decision · souvenir quality · returned-to-a-Page later ·
`ReaderAlivenessObservation.impact` (with its authority tier) · specific words used ·
page length · photograph taken · a thread answered · a bargain accepted · a rule broken.

Note the asymmetry Codex's audit quietly exposed: every "not yet" in its table failed on the
**outcome** side. Conditions are free — the world hands you weather, hour, place, moon.
Honest outcomes must be things the reader *did*, and those need projectors written.

One free win: keeping is weak evidence for *you felt alive* and strong evidence for
*this one mattered to you*. **"Water Pages get kept more often than your average"** is honest,
lovely, and needs zero new instrumentation.

---

## Phase 4 — Seven shapes, one storage structure

All of these are bitmask operations on day-sets that already exist. No new scans.

| Shape | Yields |
|---|---|
| `conditional` | *Fae come out more when it rains at night* |
| `sequential` (shift + AND) | *A Wicker invitation is followed by a photograph within two days* |
| `seasonal` (season mask) | *You answer the Sentence Salamanders every spring* |
| `absence` (AND NOT) | *…every spring but one* |
| `returnInterval` (gap distribution) | *The harbor goes quiet for months, then comes back under fog* |
| `drift` (half-range masks) | *This held in the first two years. It has been loosening* |
| `sibling` (family-internal contrast) | *Wicker's unnecessary routes return better souvenirs than his object hunts* |

`absence` and `drift` are what make it a grimoire rather than a correlation list. They are
cheap to build and will be quiet for a year — build them anyway, so year two is already paid for.

---

## Phase 5 — Interestingness, and a reserved wager

Ranking by strength alone produces boring true things (*"you write more in the evening"*).

```
interest = strength × unexpectedness × specificity × novelty
```

- **unexpectedness** — domain distance. Weather→writing is expected. Voice cadence→Fae species is not.
- **specificity** — inverse base rate. *Parking lots after rain* beats *outdoors*.
- **novelty** — decay from `lastSpokenAt`, reusing the existing spoke-tag rest machinery.

`strength` is a **multiplicand, not an addend** — nothing weak gets interesting enough to speak.

Then reserve one slot per week for a **wager**: the highest-unexpectedness row that clears the
minimum bar but not the standing bar, framed openly as a bet. Surprise becomes structural
rather than hoped for.

---

## Phase 6 — The crossing-out

What licenses the confidence in Phase 5, and the real answer to dropping the gate.

Every claim records a **machine-checkable falsifier** at the moment it is first spoken
("if the joint rate over the next ten opportunities falls below *x*"). The sweep evaluates it.
On failure the row moves to `crossedOut`, a `Revision` is appended, and **the reversal is itself
surfaceable content**:

> I thought this belonged to rain. Two dry nights have objected. The pencil is back out.

The Book earns the right to say *"Fog is one of your doors"* flatly, because it committed in
advance and in public to what would take it back.

---

## Phase 7 — Surfacing, and the register pass

Book Notices · Margins Atlas (inspectable home, including crossings-out) · Book Today ·
Remembered Pages (a correspondence explains the return) · Ask the Book · nightly braid
(one, never a dump) · editions · private traditions · Workings that act on a correspondence
and then learn whether it was right.

**Register.** Drop the throat-clearing. Today's tiers stack hedges —
*"A small thing kept happening:"* / *"One more Page could knock this over."*
Replace with the claim stated flat, and the falsifier carried as a dare rather than a hedge.

Two hard floors remain. These are correctness, not kid gloves:

- No health, diagnosis, or personality inference. Ever.
- Extend `isSensitiveInterpretation` to `.person`. Correspondences about real people, and any
  correspondence implying the reader failed at something, get the care the Witness Law already requires.

---

## The known risk, stated once

No gate × many sources = compounding false discovery. The failure mode is not *wrong once* —
it is *confidently wrong often enough that nothing lands*. Three mitigations, all already in
the plan: strength as a multiplicand, a hard rate limit on claims per week, and Phase 6 doing
its job visibly. Accepted deliberately, not overlooked.

## Status — foundation implemented 30 August; surface reach expanded 1 September 2026

Six dedicated files in `Shared/`, fourteen Grimoire/Loom test files, and integrations through
the Book's existing source, continuity, edition, and vault seams. The full suite and device
build are verification receipts, not a claim that every planned shape and source below is
finished. Last numbered full-suite receipt, before the newest edition pass:
**3,476 tests, 3 skipped, 0 failures.**

The grimoire persists, thinks on idle, puts a Page on the desk, takes the reader's answer,
crosses out what it gets wrong, and forgets what it will never need.

| | State |
|---|---|
| **Ledger** | `DayBitset`, `GrimoireLedger` — bitmaps, sparse pair table, incremental ingest, cursored sweep, falsifiers, revisions, reader stance |
| **Registry** | `LoomProjectors` — 22 projectors over **49 domains**. A new source is one file plus one registry line |
| **Shapes** | **Five of seven first-class shapes**: `conditional`, `sequential`, `seasonal` (with seasonal misses), `sibling` (names its rival), and `returnInterval` (a thing leaves for a long while and comes back). Plus compound conditions and a drift annotation. General `absence` and first-class `drift` remain open |
| **Interest** | strength × unexpectedness × specificity × novelty, wager slot, 14-day rest |
| **Crossing-out** | falsifiers committed when the Book speaks, checked every sweep, the reversal is its own Page and is owed only once |
| **Voice** | no-hedge and no-dashboard rules enforced as tests |
| **Persistence** | `PlayerVaultData.grimoire`, optional so older vaults open empty |
| **Lifecycle** | `GrimoireKeeper` — ingests every 6h, sweeps 250-pair chunks in a 1.5s budget, prunes weekly, on a detached task behind the other launch chores |
| **Surfacing** | `GrimoirePageSourceAdapter` — a `.bookNotices` Page under its own `the-grimoire` source, carrying `observationKey` so correction works with no new UI |
| **Forgetting** | `prune()` drops single-day features nothing stands on and compacts the index. **61 KB → 4 KB** on a long-tail archive |
| **The folio** | `The Rules I Worked Out` — a fifth face of the **Margins Atlas**, not a new destination. What it holds, what it is betting on, what it crossed out, each with counts, a start date and the promise that would break it |

### Measured, four years, through the real projectors

| | |
|---|---|
| Desk read | **2.4 ms** |
| Longest idle sweep chunk | **75 ms** |
| Ingest one day | **0.13 ms** |
| Whole-archive project + ingest | 288 ms + 748 ms, once, on idle |
| On disk | **479 KB** |
| Standing and watched rows | **164** |

The synthetic bench (hand-built observations, no projectors) reads in 0.4 ms and saves 222 KB;
the numbers above are the honest ones because they include context blends. The stricter seasonal
contrast removed rows whose feature occurred all year and had previously been assigned an
arbitrary season; the real-projector ledger fell from 297 rows to 164 for that reason.

### Sources: 22 projectors, 49 domains

Added since the legacy-Loom parity pass, all with dated receipts that already existed:

| | Kind | Why it earns its place |
|---|---|---|
| Moon | condition | A function of the date. No receipt, no instrumentation, and the most on-theme condition a Book about enchantment could have |
| Talisman errands | **outcome** | Paying one means leaving the Book and noticing something real. Settled on a different day from the ask, so the resolution day carries both halves, like a Working |
| Answered asides | **outcome** | The Book speaking is not evidence about the reader; the reader *answering* is |
| Pocket objects | condition or outcome | A private object kept in the pocket is a reader-owned fact, not decorative inventory |
| Returned Book Jumps | condition and **outcome** | The exact book and whether the reader came back are one linked episode rather than two nearby dates |
| Private observances | condition or outcome | A tradition the reader actually kept can become evidence without the Book inventing a universal meaning for it |
| Almanac days | condition | The wheel of the year is a date function like the moon; it costs no reader surveillance |
| World events | condition | The event and its canonical phase describe the authored weather around the reader, never an outcome the reader caused |

Outcomes are the half worth counting, and there are still only nine outcome-role features
against a large and cheap supply of conditions. That ratio is the real measure of how much
is left.

### Coverage: legacy Loom complete; moonshot registry open

The grimoire covers **all 29 existing Relational Loom families**. That proves the registry can
carry the old Loom's vocabulary; it does not complete the broader Phase 3 source and outcome
list. Moon, world events, almanac days, pocket objects, linked Book Jumps, answered asides, and
return intervals now have honest lanes. Radio tracks, answered story or continuity threads,
and comparable new receipts remain open.

The last legacy gaps closed were the sensory
lanes (photographic palette, light, composition; voice cadence and energy), semantic threads,
compound conditions, and daylight. The remainder were vocabulary, not capability — `dayPart`
is `hour`, `character` is `cast`, `activity` is `pageKind` — and the coverage check now maps
those synonyms so it reports gaps somebody can act on.

### The old Relational Loom

| Archive | Before | After | Connections |
|---|---|---|---|
| 180 days | 174 ms | **135 ms** | 11 |
| 730 days | 712 ms | **484 ms** | 6 |
| 1,460 days | 1,335 ms | **829 ms** | **1** |

38% faster, identical output. Three fixes, each located with `sample` rather than guessed
(the first two hypotheses were both wrong): the comparison universe memoised per family
pairing; `inside`/`outsideHits` derived per feature-and-family rather than per feature pair,
with `outside` never materialised; and `NarrativePackRegistry.entities` — a *computed*
property that flatMaps every enabled pack — resolved once per weave instead of once per tag
per page.

**All four braid-context builds now run off the main actor.** Three were `@MainActor` and
stalled the UI for ~0.8s on a mature archive: the nightly braid, "this missed me", and retell.
Every argument is resolved on the main actor and the build itself is handed to a detached
task. Safe because everything crossing is a value type, and the one shared thing — the
sentence-embedding scorer — is a struct around an immutable `NLEmbedding` whose distance call
is already `NSLock`-guarded and whose own comment asks to be touched off the main thread.

**The cut-over is deliberately not done, and no longer needs to be.** Coverage is complete and
the stall is gone, so the only remaining argument was never made: the braid weaves a
*privacy-filtered* archive (`weavableDay`) that the desk cache does not match, and handing that
cache over would weave Pages the reader had forbidden. The desk keeps its own cache; the braid
recomputes, off-main.

One measured oddity worth keeping in view: **the old Loom finds less the longer the Book is
used** — 11 connections at six months, 1 at four years. The grimoire goes the other way
(297 rows). That, not speed, is the eventual argument for retiring it.

### Where the accumulated body lives

Not a new folio object — **the Margins Atlas already was one.** `ReaderAtlas` draws four maps
of the reader from their own kept Pages (lexicon, hours, skies, places); the laws are a fifth
face of the same Page type, same source, same anchor. Three reasons that is the right home and
not merely a convenient one: the book-object law wants every trigger on the book and the Atlas
already has one; the Atlas exists because *"the Book needed more to draw"* and this is more to
draw; and the crossings-out only become the point when they are kept beside the standing laws
rather than met one at a time.

It carries no `observationKey` on purpose. Correcting a reading is a conversation about **one**
claim and belongs on the Notice that made it, not on the page listing them all.

The first draft read as a report and bj rejected it: ALL-CAPS section headers, the Book
defending its own methodology, and a closing aphorism — which the character doctrine forbids
outright. Headers are spoken fragments now, counts are spoken rather than tabulated, and the
page ends with an object having an opinion instead of a moral.

Prose bugs found by reading the output rather than the tests:

- Every line opened `"Here is one of your own rules:"`. `claim` varies its framing so a Notice
  never reads as a template; down a list that is exactly wrong, because the eye stops reading
  the part that differs. `plainClaim` gives lists one uniform frame.
- The same rule appeared under both **WHAT I HOLD** and **CROSSED OUT** — two shapes finding
  the same pair. Deduping on the finished sentence missed it, because the renderings differ
  once counts and reasons are attached. A claim's identity is its pair, not its wording.
- The promise read *"If you wrote the word lantern stops following"*. `outcomeClause` is a
  finished past-tense statement and cannot stand where a noun belongs. It is referred to as
  "it" now, and a test forbids embedding it. The same trap with plurals: a `label` cannot be
  the subject of a verb either — *"the Sentence Salamanders does not"*.
- The bet claimed *"I have been sure since December"* about the very thing it was still
  betting on. `law(settled:)` splits held from wagered, with a test.

### The Book does not arrange its own evidence

Two contaminations, not one, and a promise is judged on neither:

- **Said.** `promptedDays` plus a week's shadow — tell somebody rain brings out a word and they
  notice the word in the rain.
- **Arranged.** `LoomObservation.bookAsked` → `bookAskedDays`. A Working the Book set, an errand
  a talisman demanded, a jump through a door it opened, an aside it spoke first. The reader
  really did those. Doing what you were asked is not independent evidence the asking was right.

Arranged days still count for *finding* things — they happened, and the Book may notice them.
They simply cannot sit on the jury.

### The Book does not mark its own homework

A falsifier is measured *only* on the days after the Book spoke — precisely the stretch its own
telling has coloured. Tell somebody rain brings out a word and they notice the word in the rain.
Judged on all of it, a belief the Book talked the reader into confirms itself and passes its own
honesty test, which is worse than having no test.

`promptedDays` records every day the Book raised a correspondence. `promptedWindow` shadows
those plus the week after. `promiseEvidence` counts chances only on clean days after the promise
— and counts them **directly** rather than differencing a baseline, because the baseline spans
the whole archive while the verdict spans a narrower set; subtracting them can go negative, and
a negative count reads as "not enough chances yet", which would leave every promise silently
unfalsifiable forever. The Book also says so out loud: *"I will not count the week after I told
you — those days heard me."*

### The Thought Cabinet, half taken

From bj's game-inspiration thread. The state machine was already one — `watching → spoken →
standing → crossedOut`, with the falsifier as the un-taking. Two halves taken, one refused:

- **Visible working-out.** `.watching` was never surfaced anywhere, so the Book chewed for weeks
  and showed only conclusions. The folio now has a *Turning this one over* section — how often,
  never how long, because a day count off `firstObservedAt` reads as "258 days now".
- **Finite convictions.** `Bars.maximumHeld` is seven. A Book holding three hundred laws is a
  database; one that can hold seven is a character. Getting in means being steadier than the
  weakest thing already there, and that one is let go *on record*.
- **Refused: the reader internalising a claim into a slot.** That is the reader-confirmation
  gate, already rejected, in a costume. And Disco's payoff — a thought changing what you are
  *capable of* — means the Book acting on its own belief, which is the contamination problem
  above and needs intervention marking to land first. It has now landed.

### Where it speaks

| Surface | What it says |
|---|---|
| Its own Notice | one correspondence, with counts, evidence and the promise that would break it |
| The Atlas folio | the accumulated body: held, betting, turning over, crossed out |
| The quiet leaf | what the Book got done while nobody was here |
| Book Today | a marginal mark, and two drawers of the accumulated life |
| Ask the Book | standing laws handed to the answer — including when the search found nothing |
| Private traditions | a standing seasonal correspondence founds an observance |
| The nightly braid | a rule the Book already holds outranks a relationship computed tonight |
| Remembered Pages | a Page may return because it is one of the days that taught the Book a committed law |
| Monthly editions | a dated, capped record of standing laws and crossings-out, bound among the Book's other claims |
| **Its own experiments** | the Book sets the Working itself, says what it expects first, and reports either way |

Each of these has its own mouth, and they are not interchangeable. The Notice's title carries
**no feature labels at all** — the rule is in a sentence directly underneath, where the reader
can check it. Joining two registry labels into a title gave "evening and clear and “bread”",
which is a filing system talking, and it forced a frame onto shapes with only one side: a thing
that goes quiet and comes back was announced as happening every year. The bound volume has its
own caption voice ("“bread” kept turning up") because the full condition is already printed
below it.

The private-traditions row closes something the original pitch named: *"the first snow has
become one of your private observances."* Every other tradition in the Book is founded on
something that happened **to the Book**. This is the first founded on something **the reader
keeps doing** — and the Book is careful to say so: *"Do it again. It is yours. I only wrote it
down."*

The braid change is additive by construction: `nightlyStoryScore(grimoire:)` defaults to an
empty ledger, so every existing caller and every golden test keeps the braid it had. The new
lens only fires when tonight's Pages are among the days a *standing* rule rests on — the Loom
is still looking, and the grimoire has already decided and named what would take it back.

**Remembered Pages are wired.** The evidence table is computed once per visitation, and only a
committed rule may explain why an old Page returned. The correspondence id rides on the surface
only when that rule actually won the reason; a louder Long Memory or owed-evidence reason does
not spend it. Every served surface that says a law is recorded, so the Book's own telling cannot
quietly confirm the falsifier it promised to obey.

**Monthly editions are wired.** Section IV binds a dated snapshot of standing laws and a short
tail of crossings-out beside the Book's other claims. The entries carry the claim, its count,
and its falsifier, capped so the physical book never turns into an appendix of rules. Their
titles use a separate bound-volume mouth — “Bread kept turning up,” not “evening and clear and
bread” — because the full condition is already printed underneath.

### The Book runs an experiment

The last thing in Phase 7, and the only part of the grimoire that *acts*. Everything else
watches: the Book counts what a life already does, which leaves one question permanently open —
the reader chose every one of those days, so a rule may only ever have been a description of
when the reader felt like doing the thing.

So the Book picks a rule whose condition it can actually cause (a `working:` condition maps to
a Working recipe it can ask the planner for by name), writes the prediction down **before**
anything happens, sets the errand, and reads the answer. `GrimoireExperiments.swift`.

Four verdicts, and the fourth is the important one:

| | |
|---|---|
| `held` | the reader went and the thing followed — *"the first time I have known it instead of counted it"* |
| `missed` | the reader went and it did not — a `standing` rule is demoted to `spoken`. Not crossed out: one arranged day is not proof of a negative, and the passive promise still owns the crossing-out |
| `unanswered` | the reader never went. **Never counted against the rule.** A reader who ignores an errand has told the Book about their week, not about its rule, and scoring it would quietly turn the grimoire into something that punishes you for disobeying it |
| `waiting` | still out there; patience runs out after 14 days rather than the same evening |

The epistemics were already in place before this existed: `bookAskedDays` bars a day the Book
arranged from ever judging the passive falsifier, so the two kinds of evidence cannot
contaminate each other. An experiment is the *only* place the Book finds out whether it was
describing a life or predicting one.

Restraint, because this is the part that can be unfair: one test at a time, 21 days between
them, a rule needs six hits of its own before it is worth an errand, and a test never buys an
extra Working — it only names the one already on offer. While a test is out the Page carries no
confirm/correct chips, because asking the reader to grade an open test is the Book collecting
its own result.

**Voice: contractions by default.** The register is an independent child — short sentences,
concrete, never explaining itself. The first draft of the experiment prose said things like
*"Every one of those days was your idea, so I have never known whether it is a rule or just
you"*, which is an adult explaining epistemology. It says *"But you picked every one of those
days, so I don't know if it's a rule or if it's just you"* now. `testTheBookUsesContractions`
holds the whole grimoire voice to it, with a short hand-listed set kept long on purpose: "I will
say so out loud" is a vow and is heavier in full, and "I've to" is not English.

**The prediction is committed word for word and never rewritten.** `outcomeClause` is a
finished statement in the past tense, so rather than teach every projector a future tense the
Book writes the entry before the day happens: *"I am writing it down before it happens: you
used the word lantern. Then we find out."* That is true to what it is doing, and it puts the
receipt the reader is holding it to on the page.

### Traps worth remembering

- `BookPageSourceRegistry.source(for:)` resolves a type to the **first** source declared with
  it. Declaring `the-grimoire` above `the-book-notices` silently reassigned the Notices
  adapter's own source.
- `markSpoken` guarded on `isAlive`, and a crossed-out row is not alive — so announcing a
  reversal never recorded that it had been announced, and the Book would have apologised for
  the same claim every day forever.
- Several Loom families **share a `conditionRank`** (`pageKind` and `activity` are both 70), so
  a rank-keyed memo hands one family another's universe. Key on the families themselves.
- Page attribution was stored for every feature on every day — 229 KB of a 499 KB save — when
  almost all of it repeated the day's default. Only the exceptions are kept.
- Blends at six per observation were **80% of the whole feature table** and blew the idle sweep
  budget. Three, substantial × substantial or substantial × hour only. Two ambient facts
  ("a weekday in spring") describe nothing.
- **A green test can prove the engine and not the wiring.** The sibling comparison had a
  passing test built on an outcome id no projector emits, so "Wicker's routes beat his object
  hunts" could not fire on real data. `GrimoireWiringTests` now checks declared-vs-emitted
  domains per projector, id/metadata conflicts, and shape reachability.
- **`Array(Set<UInt64>)` is hash order, and Swift seeds it per process.** The candidate queue
  was rebuilt that way on every ingest, so the sweep examined pairs in a different order every
  launch. The conviction cabinet holds seven and a newcomer must beat the weakest thing already
  in it — so *which* rules the Book ended up sure of depended on the order it happened to look.
  Same archive, different launch, different Book. `dirtyPairs` is sorted now.
- **A fixture where everything scores the same tests nothing.** Every rule in the cabinet
  fixture was perfect and scored exactly 100, so `strength > weakest` was never true and nothing
  was ever displaced. The displacement tests "passed" only because the hash order above
  sometimes let a weak row in first. Tiered strengths, then assert.
- A bench that builds observations by hand does not measure the projectors. The real-pipeline
  bench exists because the synthetic one reported no change after a change that doubled everything.

## Acceptance test

- Nobody coded "rainy nights bring the Fae." The Book found it from ordinary receipts.
- It can show the rainy nights **and** the dry-night comparison.
- It says association, not cause.
- It stated, in advance, what would make it wrong.
- It has crossed something out, and the crossing-out was interesting.
- Four years in, it remembers when the correspondence began — and the desk still opens instantly.
