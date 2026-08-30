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
firing). Wall-clock ceilings held in CI:

| Path | Ceiling |
|---|---|
| Desk read of standing correspondences | < 2 ms |
| Ingest of one new observation | < 1 ms |
| One sweep chunk (idle) | < 30 ms |
| Full cold rebuild (migration only) | < 3 s, off-main |

Sibling to `DeskBuildBench`. Written **before** Phase 1, and it fails the build if breached.
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

## Acceptance test

- Nobody coded "rainy nights bring the Fae." The Book found it from ordinary receipts.
- It can show the rainy nights **and** the dry-night comparison.
- It says association, not cause.
- It stated, in advance, what would make it wrong.
- It has crossed something out, and the crossing-out was interesting.
- Four years in, it remembers when the correspondence began — and the desk still opens instantly.
