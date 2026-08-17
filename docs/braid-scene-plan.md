# The braid scene plan

The deterministic system decides. Gemma writes. Provenance travels with it.

Written 2026-08-16, after a day of measuring the existing braid and two
architectures proposed and discarded. Supersedes the renderer half of
`docs/braid-story-moonshot.md`; the decision half of that document — anchors,
beats, the lean, the ask, span shape — is what this promotes.

---

## What the braid is for

**The reader's life turning into a faerie tale, with the braid as part of the
transformation rather than a record of it.**

It takes what the reader noticed, reveals possible relationships between those
things, lets the real and fictional worlds answer, and leaves them able to see
tomorrow differently. That is a transformation of *attention*. It is never a
claim about what their life means.

And it is a **book**. Not a nightly page later collected: the Bound Year is a
printed hardcover somebody paid for. Thirty of these in sequence is the unit of
judgement, not one.

---

## Why the current engine cannot get there

Every ceiling measured on 2026-08-16 has one cause: **the unit of composition
is a sentence about one noun.** Every template takes `\(subject)` and nothing
else.

| measurement | value | what it means |
|---|---|---|
| sentences relating to more than one of the reader's facts | **5%** | the braid does not braid; it lists |
| world-thread strings interpolating the reader's noun | **80 of 81** | the world has no life of its own — structurally, not authorially |
| titles sharing one mould, over 30 nights | **17 of 30** | the table of contents of a book |
| nights with the same paragraph count | **22 of 25** | shape learned by night four |
| blank days producing a byte-identical page | **5 of 5** | five identical pages in a printed volume |
| through-lines in the reader's own month that the Book noticed | **0 of 5** | it invented frost instead |

Three budget cuts moved the Book's self-narration by **zero** sentences, and
raising the word floor bought 98 words of which **none** were the reader's.
That is not a system needing better sentences. It is a system that has said
everything it can say.

Two competent attempts hit this from opposite sides — one subtractive
(removing bureaucracy), one additive (a scene layer). Neither escaped, because
neither changed the unit.

---

## The architecture

**Decide deterministically. Render twice. Verify what comes back.**

### 1. The scene plan

A typed decision. No prose.

- **Atomic evidence** — `ReaderContribution` level, not page level:
  `page-market/contribution-0`. A reader-written sentence, a fiction choice, a
  photograph, an audio recording, each with its permissions.
- **The anchor** — the primary attentional subject.
- **Story form, motion, pressure, register.**
- **The licensed transformation** — juxtaposition, recognition, complication,
  return, refusal.
- **Which relationships are licensed**, and which are not.
- **The cross-night return**, if one exists.
- **The `WorldBeat`**, if one exists.
- **What must remain unresolved.**
- **Earned length**, from substantial receipts and available turns.
- **Shape memory** — the last few nights' title construction, opening posture,
  paragraph movement, closing posture, so this night can deliberately differ.
- **The intended residue.**

**The rule about strings.** The plan needs grounded language: the reader's exact
words, the actual fiction choice, canonical world facts, a prior residue
excerpt, the concrete detail that returned. Those are strings, with source ids
and permissions.

> Strings may carry evidence. They may not secretly carry rendered sentences.

The moment the plan holds "the company arrived" or "the debt noticed", the
template bank has been rebuilt one level up and given a new name.

### 2. The WorldBeat

The fictional world gets its own business, in one of four modes:

- **Independent** — something happens in the Academy whether or not the reader
  supplied a matching noun.
- **Intersecting** — the reader's detail genuinely crosses its path.
- **Counterpoint** — the two worlds do different things beside each other.
- **Echoing** — they resemble one another without any claim of cause.

*Independent* is the mode that answers the 80-of-81 finding. The Academy no
longer waits for a coffee mug before it is allowed to move. The real world gets
the same room: rain, buildings, animals, tools, strangers, physical processes,
noticed for the strangeness they already have.

Its quality test is whether it is canonical, coherent and worth reading — **not
whether it avoids the reader's noun.** A quota would produce Academy filler.

### 3. Two renderers, one plan

**The house writer** is the instant, offline floor. It consumes the plan and
does four things: preserve the facts, realise the primary relation once, carry
the world beat, land the form, stop. It does not need hundreds of sentence
moulds and will not keep them.

**Gemma** receives a compact decided scene instead of twenty thousand
characters of archive and rulebook:

> Drama. Bargain under debt pressure. The extra plums are the anchor. Eddies
> traded the paper crown. The gift at the market complicates the idea of price.
> The cinnamon smell may become residue — do not explain it. The Academy's
> eastern stair has independently refused all tolls tonight. 340–420 words. Six
> locked lived facts below.

That is a task a small local model can actually perform.

### 4. Structured provenance

Gemma returns a composition with sentence roles, stripped before display:

```
LIVED:page-market/contribution-0
BOOK:market,crow
WORLD:academy-toll-strike
COLOPHON
```

**Structural law — the whole draft is rejected on any of:** a missing marker,
an unknown evidence id, a wrong realm, a duplicate or malformed mapping. Only
fully parsed compositions enter the tasting room. A rejected draft costs
nothing; the house page is still standing underneath it.

**Claim law, per realm:**

- **Lived** — one sentence claims one evidence atom. Actor, action, object,
  number, time and **polarity** preserved. No new mundane verb or participant.
  Reordering and rephrasing are free.
- **Book** — may invent reactions and impossible relationships, only within the
  plan's licence.
- **World** — may develop supplied fictional continuity, and may never become
  reader biography.
- **Colophon** — locked.

Every claimed source id must actually support its sentence.

### 5. Residue and the answer loop

The finished braid leaves typed residue — the relationship it opened, the
fictional business it advanced, the real detail that became newly salient, what
stayed unresolved, what the Book may notice differently tomorrow — **persisted
only from what survived into the winning verified page.** Plus shape memory.

Tomorrow answers it:

```
notice → keep → braid → see differently → notice again
```

---

## Sequence

**Phase 0 — contain the live hole. SHIPPED (`4dbb01d`, `198dacd`).**
Free-form Gemma drafts removed from the official pool; the verified
sentence-aligned revision stays. Polarity added to `preservesFacts` — it had
only ever prevented *addition*, so "I did not call Sam" → "You called Sam"
passed. Scene layer retired, `clericalCadence` and the fiction drift check
harvested. `mum`, `saw`, `purpose`. No fake lexical invention detector.

**Phase 1 — define the whole contract.** The typed plan, with `WorldBeat`,
returns, shape memory and residue **in the schema now**, even where their
adapters come later, so it is not redesigned three times. Golden-test the
*plans*, not prose.

**Phase 2 — structured output and verification.** Markers, atomic ids, strict
parser, per-realm claim laws, whole-draft rejection, adversarial tests for
invented actions, feelings, people, places and reversed negation. Only after
this may free-form Gemma re-enter selection.

**Phase 3 — compact plan-driven rendering. HALF SHIPPED.**

*Done:* the brief, and the floor.

The brief hands over a decision instead of the archive: 1,756 characters against
19,286 on the full braid, 887 against 17,298 on a glimpse — about a tenth, and
it can be that short because the verifier enforces afterwards what the old
prompt argued for in prose.

`BraidSceneWriter` is the floor. Four jobs and it stops. It emits the **same
marked claims a model must emit**, so the same verifier reads both, and it
carries no sentence that interpolates the night's noun — which is what stops the
world orbiting a coffee mug, structurally rather than by denial.

*Measured, and the honest part:* the floor is thinner than the writer it would
replace — 46 words against 115 on a plain day, 151 against 307 on a rich one.
Most of that gap is what we spent 2026-08-16 identifying as padding, so losing
it is the point. But a night of listed facts with one comment on it **reads
flat**, because it is scaffolding waiting for a writer.

So the default does **not** switch yet, and the old move families are **not**
deleted yet. You cannot delete what still ships. The switch happens when Gemma
renders from the plan; until then the floor is a floor, and whether a thinner
honest page beats a padded one on a night the brain is cold is a product call,
not a refactor.

**Phase 3b — the switch and the deletion.** When plan-driven Gemma is winning,
the default moves, every move family unreachable from the plan is deleted in one
commit, and the commit message counts the lines. `LiteraryContinuity.swift` is
26,278 today and should end **smaller**.

**Phase 4 — world and continuity adapters. MOSTLY SHIPPED.**

*Cross-night returns* (`71397fe`, `e84538a`). A shared distinctive **noun**
between tonight and an earlier night, rare across the window, at least two days
back, spine past five. Nouns only: matching any content word paired "I have
never been to" with "I have never seen" and "I bought the recorder" with
"Bought apples", which moved precision from 8-in-12 to 11-in-12 on the
simulated month and found all five of its through-lines. One false positive
survives, a true homonym ("a sign saying FINE" / "a good sign"), left alone
rather than special-cased.

It also shipped **inert** the first time and had to be fixed: the archive was a
parameter, the one production call site never passed it, and `carriedReturn` was
nil on every real night while its tests passed on fixtures. The archive now
travels on `BraidPromptBuilder.Context.recentDays`, beside the memory digest it
is derived alongside, so a caller cannot forget it.

*Earned length* (`404186a`). Floor from substantial atoms, ceiling from the
floor. Three fixed bands became five earned ranges across the bench, 40-90 to
294-499. A thin night stays short.

*Shape memory* (`404186a`). Read from the kept braids - what the reader saw, not
what was intended - as a title mould, paragraph count, closing form and opening
posture. When the last few agree the brief says so. A varied history is left
alone.

*The world beat* (`6eee35e`). Sixteen canonical facts with no slot for the
reader's noun. Mode read off the night: `counterpoint` beside hard material,
`intersecting` when the reader kept a piece of the world, `independent`
otherwise. Facts rest on the `braid-claim:world:` stamps of recent braids and
rotate deterministically otherwise.

*Still open here:* Cast undertakings and world events as sources of world facts.
The canon is currently the Book's own house rather than the whole world, and an
`intersecting` beat does not yet know **which** kept fiction it crosses.

**Phase 5 — residue and the answer loop.**

**Phase 6 — literary proof.** Read: the 25 isolated bench nights, a 30-night
sequential artifact, adversarial safety nights, a real archive month, and blind
house-versus-Gemma comparisons. Judge specificity, continuity, transformation,
surprise, Book voice, factual honesty, rereadability, and whether the fictional
world feels alive without hijacking the reader's life.

---

## Gates

**Hard gates — truth, provenance, structure, continuity, safety.** A draft that
invents an event is rejected, every time. A malformed marker rejects the draft.
Polarity is preserved. These do not get negotiated.

**Diagnostics, not gates** — nights in band, repeated openings, share of world
sentences without the reader's noun, taste. Every one of these can be gamed by
optimising the wrong thing, and one of them already was: on 2026-08-16 the
average taste score went **up** while the corpus got measurably worse.

The empty day and the thin, sensitive day must be allowed to stay short.
Literary quality is established by reading the corpus.

---

## What this deletes

Named now so it does not quietly survive: `taleThreads` and `keepingMoves` as
primary generators, `supportingMove`, `crossingMove`, `arcMove`,
`relationalMove`, the settling and filler loops, and the word-band padding
mechanism. They survive only as far as the floor renderer needs them, which is
much less than exists.

Today's rewritten world threads are not wasted. They stop being templates with
a noun slot and become **world canon** — facts the `WorldBeat` draws on. The
paper moth, the bell under a floor that has no bell, the stair that shifts when
it overhears, frost in a straight line. They keep the imagination and lose the
argument.
