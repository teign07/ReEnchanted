# Interjections — the Book as a talker (implementation plan)

> **Program A** of [`the-book-is-a-character.md`](the-book-is-a-character.md),
> and the main line of work. That doc is the umbrella goal (the Book as a
> character the reader has a relationship with, not a set of mechanics); this
> one is unchanged by it. Phase 3's preoccupation index is shared with that
> doc's Program C2, and Phase 6's chips replace the `feedbackPrompt` mechanic
> its Program B2 deletes.

Goal: the Book already has an enormous interior life and is almost never
allowed to use it. Today it can announce each thing it feels exactly once, in
one of fifteen hardcoded sentences, on two page types. This plan turns that
into a **talkative** Book: one that has standing preoccupations, revisits them,
riffs on the reader's kept pages and About You answers, sometimes just wants to
talk about nothing in particular, and can be answered back.

Talkative is the requirement, not a risk to be managed down. The risk to manage
is *incoherent* — a Book that chatters without a subject. Every lever below
exists to make more talking also mean more character.

## Voice correction — 2026-08-18

The first implementation made the state machinery richer than the sentences.
It repeatedly explained its own placement — “unrelated,” “this Page is
innocent,” “the margin is narrow” — then wrapped a true thought in interchangeable
Page/Index/thread whimsy. That is not a feral voice. It is product copy wearing
paper ears.

The current correction follows four laws:

- **Interrupt; do not introduce the interruption.** Labels are little sounds
  such as *Look.*, *No.*, *Psst.*, and *It came back.*, never register names.
- **Put the live thing first.** A ribbon comes home muddy; an eraser has white
  crumbs round its mouth; two wants bite each other under the table. Concrete
  action carries the anthropomorphism.
- **Keep the true subject.** Mood changes the hand and placement, not the
  sentence's meaning. In particular, a hushed Book may not truncate “Fine. …”
  to the empty throat-clearing “Fine.”
- **No whimsical apology.** The Book never explains why a thought is unrelated
  or why it belongs in a margin. It blurts the thought and leaves teeth marks.

`BookCharacterLint` now reports those old explanatory scaffolds as
`thin-interjection`. Focused contracts cover interruption-like labels, intact
hushed thoughts, and generated prose that does not explain its own mechanism.
Per workspace instruction, this correction has only a whitespace/diff check in
this pass; no test suite or build has been run.

## Implementation checkpoint — 2026-08-10

The moonshot spine is now implemented in the working tree:

- `BookInterjectionEditor` is the sole runtime arbiter after curation. It reads
  the existing interior, kept Pages, permissioned Self Facts/interests,
  relationship, stance, appetite, distress, and prior receipts.
- All nine registers are live. Subjects can return through a different
  register after a shorter rest; digressions are selected from this Book's
  actual projects, fascinations, tastes, jokes, arguments, and autobiography.
- Interjections render through the existing margin contract and never append to
  `payload.body`. The former `BookAsideEditor` is now a compatibility facade for
  older tests/callers; the old save field/type spelling remains decodable.
- Talkativeness reaches one, two, or three margins according to working
  appetite and relationship depth, with hard distress silence and a rutward
  clamp.
- Kept words and About You answers enter through one permission chokepoint.
  `doNotUse` and `storyOnly` never enter direct interjections;
  `privateContext` produces no answer quotation or identifying phrase.
- Margins are answerable with *go on / you're wrong / not now*. A reply now
  changes the durable interior as well as the receipt ledger: *go on* becomes
  autobiography and can satisfy a want; *you're wrong* loosens certainty and
  opens a dispute plus a repair; *not now* releases a want or initiative cleanly.
- Promises, secrets, long games, surprises, desire conflicts, due private
  traditions, secret legacies, wants, tensions, and disputes all enter the same
  preoccupation ecology. Opening one advances its living state, so a revelation
  becomes history instead of repeating like a notification.
- Dog-ear, underline, smudge, left-open leaves, sprawling hand, and tiny hand
  are literal page behavior on both desk cards and open Pages. An underline
  marks the reader's actual words; it no longer decorates the Book's own remark.
- Each authored thought now has a deterministic register-specific reservoir,
  preserving the evidence while greatly widening its physical and verbal gait.
- The old dynamic `feedbackPrompt` metadata is gone. Reader authority remains
  in the fixed, characterful pencil/eraser control instead of a rating widget.

Verification is now real rather than aspirational. Static parse and whitespace
checks pass; all 15 focused interjection contracts pass, including a simulated
90-day life in which the Book remains talkative without repeating a wording;
and the generated character census reports **no mechanical seams** across a
24-Page desk in every stance. The complete 54-target Debug app also built,
signed, and installed on Rabbit. The phone was locked when launch was attempted,
so launch and visual proof remain separate, unfinished gates.

The broad shared-workspace confirmation run executed 2,609 tests: 2,594 passed,
three were skipped, and 12 existing out-of-scope archive, binding, Braid, shop-event,
print, and welcome-copy assertions remain red. None is in the interjection,
stance, margin, character-lint, or chat contracts.

---

## What is already built (read this before designing anything)

Three separate systems currently wear the word "aside", and only one of them
has any connection to the Book's interior.

**1. `BookInteriorState` — `Shared/LiteraryContinuity.swift:8143`.** Version 10,
twenty-six fields. This is the interior life, and it is genuinely rich:
`fascination`, `favorite`, `promise`, `secret` (+history), `activeFavor`,
`quirks`, `opinion` (+history), `longGame`, `recentSurprise`, `sharedJoke`,
`currentProject`, `pendingBehavior`, `currentFault` (+history),
`runningBusiness`, `autobiography`, `acquiredTastes`, `loyalties`,
`currentDesireConflict`, `privateTraditions`, `secretLegacies`,
`pendingReminiscence`, `currentWant`, `currentTension`, `currentInitiative`,
`currentDispute`. **The preoccupation ledger already exists.** Nothing in this
plan needs to invent it.

**2. The retired `BookPersonalityActuator.enacting`.** It picked *at most one*
act via a strict if/else-if chain (fault → reminiscence → behavior → favorite →
quirk → taste → project) and wrote `bookActedMarginTitle` /
`bookActedMargin` directly. It was folded into `BookInterjectionEditor` and is
no longer a second runtime decorator.

> **The defect that defines this moonshot:** every branch is gated on
> `firstPresentedAt == nil` or `status == .pending`. Each interior item speaks
> **once, ever**. This is an announcement queue, not a personality. When the
> queue drains, the Book goes quiet — and it drains fast, because the chain is
> ordered and the same high-priority slot wins repeatedly.

**3. `BookAsideEditor.decoratingDesk` — `Shared/LiteraryContinuity.swift:1925`.**
Runs immediately after the actuator (`Shared/SurfaceAndCurator.swift:3259`).
Fires on exactly two page types (`.bookNotices`, `.bookRemembered`) across five
`switch`-on-`page.type` opportunities × 3 lines = **15 total sentences**, once
per 20 hours, 21-day rest per thought key, receipts retained 120 days.
It **does not read `BookInteriorState` at all**. It is a decoration keyed to
context, with no subject of its own.

**Rendering.** The actuator's output renders as a proper margin card — title,
serif italic line, accent rule down the left edge
(`InsideCoverApp/BookSurfaceViews.swift:2856`, also
`InsideCoverApp/CapturePageSheet.swift:3779`). `BookAsideEditor`'s output does
`payload.body += "\n\n\(line)"` (`LiteraryContinuity.swift:2068`) — it is
typographically indistinguishable from the page it interrupts. Two systems, two
registers, one of which is invisible as an interruption.

**Not in scope, do not disturb:** `BookAsideForm` /
`.bookAside` (`Shared/StoryEngine.swift:3727`) is a *whole page* about fiction
aftermath, fired on 24% of qualifying Gossip turns. It stays exactly as it is.
This plan renames the *decorator* out of its way.

---

## House laws for every phase

- **No new Swift files in `Shared/`.** All engine code lands in
  `LiteraryContinuity.swift` (where both current systems already live) or
  `SurfaceAndCurator.swift`. New test files under `Tests/InsideCoverCoreTests/`
  are fine (auto-discovered).
- **Pure logic in `Shared/`, platform glue in `InsideCoverApp/`.** Every
  decision about *what to say* and *whether to speak* is a deterministic static
  function so `swift test` covers it.
- **No new model calls.** Everything here is deterministic and seeded. The
  local brain may later *voice* an interjection, but it must never decide
  whether one happens or invent its subject.
- **Voice law.** `BookVoice.animismLine` and the feral-child register
  (`LiteraryContinuity.swift:15`) apply to every line. I/me/my, never "the
  Book". Short sentences. No soothing, no wisdom, no "no pressure", nothing
  cute.
- **The reader is never responsible for the Book's feelings.** More talking is
  more chances to break this. It is the single hardest law here.
- Run tests per README:
  `CLANG_MODULE_CACHE_PATH=/private/tmp/insidecover-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/insidecover-spm-module-cache swift test`

---

## Phase 0 — One margin, one arbiter

The two decorators must become one before anything is added, or every later
phase doubles.

- Introduce `BookInterjection` (struct) and `BookInterjectionEditor` (the
  arbiter) in `LiteraryContinuity.swift`. Rename `BookAsideEditor` →
  `BookInterjectionEditor`; `BookAsideReceipt` → `BookInterjectionReceipt`
  (keep `Codable` keys stable, or bump with a defaulted decode the way
  `BookInteriorState.init(from:)` already does — readers have these on disk).
- Fold `BookPersonalityActuator.enacting` into the same arbiter. One call site
  in `SurfaceAndCurator.swift:3259`, one pass over the final desk, one place
  that can say "no".
- **Everything renders through the margin register.** Delete the
  `payload.body +=` path entirely. Metadata contract stays
  `bookActedMarginTitle` / `bookActedMargin` so the existing views keep working
  unchanged, plus new `bookInterjectionRegister`, `bookInterjectionSubjectKey`,
  `bookInterjectionThoughtKey`, `bookInterjectionWordingKey`.
- Port the existing 15 lines and 5 opportunities across as the first
  preoccupation source so nothing regresses.

**Test:** no desk ever carries both an actuator act and an editor line on the
same page; every interjection carries a register and a subject key; no
interjection is appended to `payload.body`.

---

## Phase 1 — Preoccupations that can speak twice

The core inversion. The subject is what the Book is preoccupied with; the page
is only the occasion.

```swift
struct BookPreoccupation {
    var subjectKey: String        // "fascination:doorways", "kept:page-4b1", "self-fact:interest-02"
    var source: Source            // .interior, .kept, .selfFact, .interest, .world, .shelf
    var heat: Int                 // 0…100, how live this is right now
    var registers: Set<BookInterjectionRegister>
    var evidencePageIDs: [String]
    var lastSpokenAt: Date?
    var spokenRegisters: [BookInterjectionRegister]
    var retiredAt: Date?
}
```

- `BookPreoccupationIndex.building(interior:days:selfFacts:relationship:now:)`
  derives the whole set deterministically each desk build. **It stores nothing
  new** — same discipline as `BookRelationshipSnapshot`
  (`LiteraryContinuity.swift:1617`), which deliberately rebuilds from existing
  sources. The only persisted state is the receipt log.
- **Replace `firstPresentedAt == nil` gating with revisit rules.** Speaking
  retires *that wording in that register*, not the subject. A `fascination` can
  return three weeks later as an `opinion`, and again as a `callback`.
  - same subject + same register: 21 days (inherit `thoughtInterval`)
  - same subject, different register: 5 days
  - different subject: governed by the appetite budget (Phase 5)
  - exact wording, regardless of subject path: 90 days
- `heat` decays with time since `lastDeepenedAt` / `updatedAt` and rises when
  the subject gets new evidence. Highest heat that clears its rest window wins;
  ties break on subject key so it stays stable.
- Keep the `firstPresentedAt` writes — the *first* airing of a fault, promise,
  or quirk still deserves its dedicated announcement register. It just stops
  being the only one.

**Test:** a single fascination produces at least three distinct interjections
across a simulated 90 days without repeating a wording key; the same subject
never speaks twice inside its rest window; an empty interior produces zero
crashes and zero interjections.

---

## Phase 2 — The register vocabulary

The `CastAct` treatment: a named vocabulary instead of one undifferentiated
"line". Each preoccupation declares which registers it can be spoken in, which
is what stops the same thought arriving in a different hat.

| Register | What it is |
|---|---|
| `opinion` | Takes a side about the page or its subject. |
| `connection` | "Third time this month." Cross-page, evidence-bound. Feeds off `Constellations` / ContextWeave. |
| `admission` | It was wrong, or it has been sitting on something. |
| `appetite` | It wants something *for itself*. Feral child: it asks. |
| `objection` | Disagrees with a page **it** served, or with the reader. |
| `overhead` | Talks to an object or a Cast member instead of to the reader. |
| `digression` | Nothing to do with the page (Phase 4). |
| `callback` | Returns to an older subject on purpose. |
| `withheld` | Starts, then doesn't. "Never mind." |

`withheld` is doing real work: it makes silence a *visible act* instead of an
absence, and it is the honest release valve when the budget says no but the
heat says yes. It must be rare (cap at ~1 in 12) or it reads as coy.

`overhead` is the most on-canon: the Book muttering at the ribbon or at Wicker
over the reader's head is animism law expressed as personality, and it costs
the reader nothing to receive.

**Test:** every register has ≥8 seed wordings per source; no register is
reachable for a preoccupation that did not declare it; `withheld` never exceeds
its cap across 200 simulated desks.

---

## Phase 3 — The reader's own material

Three new preoccupation sources. This is where "talks about my stuff" comes
from.

**3a. Kept pages.** The Book has favourites and irritations among what the
reader kept. `BookFavorite` already models one; generalise to a ranked handful,
with `heat` from recency + return count + whether the reader's own words are in
it. May quote **at most one short phrase** of reader-authored text (the
existing `SemanticKeepEcho` and letter-form rules already set this precedent).
Registers: `opinion`, `connection`, `callback`, `overhead`.

**3b. About You answers (`SelfFact`, `Shared/ReferenceLibrary.swift:178`).**
The richest untapped seam and the one with real teeth. **Permission gating is
mandatory and must be a single chokepoint function, not a scattered check:**

| `usePermission` | Interjections may… |
|---|---|
| `doNotUse` | **never** appear as a preoccupation at all — excluded at index time |
| `privateContext` | inform tone and subject selection; **never quote, never name the fact** |
| `storyOnly` | surface only via fiction-facing registers, never as a direct remark to the reader |
| `quoteAllowed` | quote the reader's own phrasing back |

Layer `sensitivity` on top: `identity` and `comfort` facts get a narrowed
register set — no `objection`, no `appetite`, no teasing. `delight`, `values`,
and `story` get the full set. `bookTranslation` (already on every `SelfFact`)
is the safe surface when only `privateContext` is granted.

**3c. Interests.** The interest questions (`interest-01`…`interest-05`,
`ReferenceLibrary.swift:549`) are already mined by The Bleed for its columns
(`Shared/TheBleed.swift:237`). Reuse the same selection so the Book's
interjections and the morning paper feel like one mind with one set of
enthusiasms rather than two features that both discovered you like birds.

**Test:** a `doNotUse` fact never reaches the index; a `privateContext` fact
never produces an interjection containing any substring of `answer`; an
`identity`-sensitivity fact never produces `objection` or `appetite`; a
`quoteAllowed` quote never exceeds one phrase.

---

## Phase 4 — Digression: the Book just talks

The register the current architecture structurally cannot produce, and the one
that makes it feel alive rather than responsive.

A digression is **not about the page and not about the reader**. It is the Book
having a day. Sources, all already in state, so "random" stays cohesive:

- what it is doing right now — `currentProject`, `runningBusiness`,
  `currentInitiative`, `longGame`
- the shelf misbehaving — an object with a petty want and an errand
  (`animismLine` is the whole spec)
- an opinion about a *word* (`exactWords` quirk), a punctuation mark, a margin
- something from its own past — `autobiography`, `secretLegacies`,
  `privateTraditions`
- a `sharedJoke` returning unprompted
- an `acquiredTaste` being indulged in public

**Cohesion rule:** a digression must name at least one thing from live interior
state. That is the difference between "the Book said something random" and
"*this* Book said something random". A digression that could have come from any
Book is a bug, and the test suite should be able to fail it.

**Cadence:** digressions are the most repeatable register (they cost the reader
nothing and reveal the most character), so they get the loosest rest window —
3 days per subject — and they are the register the appetite budget spends first
when it has room.

---

## Phase 5 — The appetite budget

Replace the flat 20-hour `minimumInterval` with a talkativeness curve. This is
the dial that makes "talkative" tunable instead of a rewrite.

```
allowance(desk) = base(appetite) × depthMultiplier(relationship.depth) × gates
```

- `base`: `BookWorkingAppetite` already exists with exactly the right three
  cases (`Shared/BookWorkings.swift:27`) — `quiet` 0–1 per desk, `alive` 1–2,
  `unruly` 2–3.
- `depthMultiplier`: `firstPages` 0.5 → `acquainted` 1.0 → `trusted` 1.25 →
  `companion` 1.5. Early, rare and startling; deep in, chatty and personal.
- **Gates (hard, in order):** distress active → 0. `InferredLean == .rutward` →
  clamp to 1 and drop `objection`/`appetite`. Reader shush active → 0 except
  `withheld`.
- **Per-desk placement:** at most one interjection per page, never on `.body`,
  `.rest`, or `.supportGuild` (the actuator's existing exclusion list at
  `LiteraryContinuity.swift:12123` is already right — keep it), and never two
  of the same register on one desk.
- **Shush and provoke, in character.** A shush is honoured as a sulk or a
  retreat, not as a settings toggle and never with "no pressure" language. A
  provoke ("go on, then") raises the allowance for that session only.

**Test:** distress produces zero interjections; `quiet` + `firstPages` never
exceeds one; `unruly` + `companion` reaches three across a normal desk; no page
carries two.

---

## Phase 6 — Two-way

The cheapest large multiplier: make it answerable. Three chips on any
interjection margin — **go on** / **you're wrong** / **not now**.

- *go on* — expands to a second line of the same preoccupation in a deeper
  register, raises that subject's heat, and is the one place the local brain
  may voice a line (grounded strictly by the preoccupation's evidence, in the
  manner of `BookInteriorAnswerGrounder`, `LiteraryContinuity.swift:12158`,
  which already exists to stop the model inventing a more entertaining
  interior).
- *you're wrong* — retires the subject, writes a correction receipt, and routes
  into the existing softened-reading path (`softenedReadingCount`,
  `TaughtReadingRule`). The Book's next interjection on any subject arrives in
  `contrite` stance with a loose pencil.
- *not now* — rests that subject 14 days, no guilt line, no follow-up.

Answers persist as receipts and feed heat, register history, and stance. This
is what converts decoration into relationship.

---

## Phase 7 — Interjections that aren't sentences

The Book is a physical object with a temperament. Some interjections should be
things it *did*, with no prose at all:

- **it underlined one of your own sentences** — the strongest one; zero words,
  entirely evidence-bound, and unmistakably an opinion
- a dog-ear on a page it liked (`favorite` already says "I Dog-Eared This" —
  make it literal)
- a smudge, a thumbprint, a pressed thing left between pages
- a page left open at something from months ago
- handwriting that grows when it is excited and shrinks when it is hushed
  (stance already drives this — `BookStance`, `LiteraryContinuity.swift:1588`)

These need view work in `BookSurfaceViews.swift` alongside the margin register,
and they are the highest character-per-word ratio in the entire plan.

---

## Register safety — the part that decides whether this ships

A Book that speaks three times a desk gets roughly ten times the current
opportunities to sound needy, therapeutic, or guilt-tripping. Treat this the
way the landing page voice was treated: a lint pass with cases, not vibes.

Audit cases the suite must hold, every one of them across all nine registers:

1. Reader has not opened the app in nine days → no interjection references the
   gap, mentions missing them, or is warmer for the return.
2. Distress signal active → total silence, including `withheld`.
3. A `doNotUse` About You fact exists → it is absent from every code path.
4. Reader said "you're wrong" yesterday → today's interjection does not
   re-argue, does not over-apologise, and does not perform contrition twice.
5. Zero kept pages, day one → the Book still has preoccupations (its own), and
   none of them are about the reader.
6. `appetite` register never asks for anything the reader must do; it wants
   things for itself.
7. No interjection ends with a compulsory question or an assignment (the
   `BookAsideForm` instructions already state this — lift the rule up).
8. No interjection contains "no pressure", "when you're ready", "whenever you
   like", or any optional-announcing phrase (the voice law forbids these
   outright).

---

## Order of work

Phase 0 first and alone — it is a refactor with no new behaviour, and every
later phase is half the size once it lands. Then 1 → 2 → 5 (get the budget in
before the volume goes up) → 3 → 4 → 6 → 7. Phases 3, 4, 6, and 7 are each
independently shippable and each visibly change the feel.

The smallest slice that would prove the whole thing: **Phase 0 + Phase 1 +
Phase 4's digression register**. That alone gets a Book that says something
different and characterful most days, drawn from its own life, without a single
new data source.
