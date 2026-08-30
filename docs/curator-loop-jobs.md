# The Curator curates the loop

Status: in progress (started 2026-08-23)

## The loop we are curating for

> A prompt sends the reader into their life. They write one sentence about what
> happened. The Book takes that sentence and makes it content in the fiction.
> The fiction sends them back out again — mixed with enough other kinds of Page
> that the desk reads as a life, not a chore list.

The Curator has never been told this. It balances the desk by **lane**
(`outward` / `fiction` / `other`), which is a taxonomy of subject matter. The
loop is a sentence, not a taxonomy, so lane balance can produce a perfectly
"balanced" desk that never once sends the reader anywhere.

## What we measured first (14 days × 3 sessions, 42 desks, 126 slots)

- **273** distinct Pages were offered on the ranked bench; only **88** ever
  reached a desk. The material exists; the selection is narrow.
- 74 of those 88 showed exactly once. The other **14 Pages took 52 slots**.
- Tarot showed **14 times — the identical card copy every time**, once a day for
  fourteen days, because a daily `automaticRecurrenceSlot` bypasses the exact
  content cooldown entirely.
- Tarot + Quotes + I Believe took **40 of 126 slots (32%)**: spice ate a third
  of the desk.
- Anything Wonder Compass reached the desk **6 times in 42 sessions**, and the
  playful-mission card — the errand that sends the reader outdoors — scores
  **64 against the field-guide quote card's 66**, competing for the same single
  Wonder Compass slot. There are **184 missions in the catalog** and the adapter
  offers exactly **one** per candidate build.

## The rule

**Recurrence belongs to the job. Rest belongs to the individual Page.**

Tarot's failure was not that Tarot recurred; it was that the *same card*
recurred. Missions want the opposite: the errand kind should appear nearly every
session while any single errand rests for weeks.

## The five jobs

Every `BookPageType` has exactly one `deskJob`, and any individual Page may
override it with `metadata["deskJob"]` — necessary because one type can hold two
jobs (a Wonder Compass card is an `errand` when it is a mission and `play` when
it is a field-guide quotation).

| Job | What it does in the loop | Recurrence | Rest |
|---|---|---|---|
| `errand` | Sends the reader into their life **and takes the sentence when they come back**. Most are the whole round trip on one card. | near-constant: 1–2 a day, different ones | long per errand (weeks) |
| `instrument` | The tools the reader reaches for: the logs, the journal, a loose page. | several a day, clock-spaced | none — a tool is not a repeat |
| `reprise` | The Book hands back what the reader wrote. | evidence-timed, not scheduled | long per exact Page |
| `play` | The spice: sentence runner, tarot, quotes, radio, letters, gossip. | rotate hard | long, and widening |
| `quiet` | The Center Page. A surprise quiet moment is a gift, so it **is** in rotation — rare, and boosted when the day is hard. | rare | long |

## Phases

1. **The taxonomy** — done. `DeskJob`, `BookPageType.deskJob`, and
   `SurfacePage.deskJob` with a `metadata["deskJob"]` override.
2. **Unstarve the errand** — done. `PlayfulMissionRegistry.missions(…)` offers
   five ranked errands per build instead of one (the first is exactly what
   `mission(for:)` returned, so no existing caller changed); per-errand rest
   widened from 48 hours to 21 days; the field-guide quotation declares itself
   `play` so it stops taking the errand's chair.
3. **A floor under the way out** — done, and deliberately *not* the pre-emptive
   claim the plan first described. See "What the floor is not" below.
4. **Rest ladders by job** — done. Instruments and composition prompts are
   spaced by the clock (3.5h) instead of rested by content; everything else
   rests on a doubling ladder off the already-persisted `recentShowCount`,
   capped at 60 days; a ritual may declare `automaticRepeatRestDays` alongside
   its recurrence slot; desk injections no longer bypass eligibility.
5. **The return beat timed to keeps** — done. A kept sentence opens a debt
   (`CuratorReturnBeat`), live for 72 hours, and while it is open a `reprise`
   gets the same kind of floor the way out has — preferring a Page that actually
   cites the keep. Nothing new is persisted: the debt is the comparison between
   the reader's most recent keep and the last time any return reached a desk,
   and serving one settles it, because serving stamps that kind's history
   forward past the keep. In the fortnight run every keep was answered within
   three sessions, most in the same day.

## What the floor is not

The first implementation claimed the door slot for an errand *before* the role
composition ran. It worked, and it cost something that did not show up in the
variety numbers at all: `CompoundingCurationTests` caught the Book's measured
rate of learning collapsing to exactly its null run. Pre-empting composition on
every desk takes the choice away from the machinery that learns which families
work, and a claimed slot that records no causal receipt is a slot the Book is
blind on.

So the floor runs **after** composition and only when the finished desk offers
no way out at all; it seats the errand in the spice's chair, never a
milestone's; it inherits that chair's session role; and it records the same
causal receipt any composed slot would. Two further rules came out of the same
work:

- **A claim promotes; it does not resurrect.** An errand that has dropped its
  own score to the floor is the adapter asking not to be seated (a closed
  pressure budget, a tired reader). The floor ignores errands scoring below half
  the best candidate.
- **Spice may take all but one chair, never all of them.** A cap of one starved
  the entire Academy — letters, gossip, the cast, the Bleed and the faculty all
  share the `play` job, and squeezing them into a single chair measurably
  stopped the Book learning which of them work.

## Phase 6 — the block, not the trio

The folio publishes **nine turnable leaves**, and every density cap in the
Curator had been written against the opening *three*. Six of the nine leaves the
reader actually turns through were arranged by rank and role alone: no spice
cap, no ask cap, no lane balance, no loop floor.

The block is the unit now, and every cap is a density over it — one blank-page
prompt per three leaves, one debut per three, spice in at most two of every
three. At `limit` three that arithmetic *is* the old rule, so the three-card
desk is unchanged; at nine it lets the block breathe. The loop floors run per
trio, so a block reads as **three turns of the loop** rather than one turn and
six leftovers.

Measured over the same fortnight, at the block rather than the trio: **265
distinct Pages across 377 leaves**, no Page above 4% of them, a return in 38 of
42 blocks, and a way out in 70 of 126 trios. That last number is capped by
something structural rather than by taste — one Page per type per desk means
only four to six errand *kinds* can be eligible at once, so "a way out in every
trio" is an aspiration the material cannot always meet.

## The maps of the reader

The Margins Atlas was three cards — the Loom, the Constellation, the Company —
and all three drew the *world*. `ReaderAtlas` adds four that draw the reader,
out of nothing but their own kept Pages and the context snapshot each one
carries:

- **The Words That Keep Coming Back** — their vocabulary, joined wherever two of
  their words arrive on the same Page.
- **The Hours You Keep** — what they bring to each part of the day.
- **The Weather You Write In** — the sky their words keep arriving under.
- **The Ground You Wrote From** — where they were standing.

Every edge is something the reader actually did. Nothing infers a mood or a
cause, each map refuses to draw below its evidence bar (three lines, two
conditions, and every word has to recur), and the shared vocabulary comes from
`KeepMarginalia.loadBearingWords` so the maps are drawn in the same words the
margin voice would quote back.

## Rest as long as the deck can afford

The last of the invented constants. Rest is now scaled by how many distinct
Pages a family is actually offering (`deckSize`), because a flat interval
quietly punished small decks and indulged large ones — the three-card Atlas and
a hundred-and-eighty-errand catalogue rested each Page for the same eighteen
hours. Deck size may only *extend* the wait, never shorten it below the
discovery-law minimum. A family that deliberately samples can declare its true
size (`metadata["deckSize"]`), which the compass does.

## Does it still curate for aliveness?

The question every rule added here has to answer, because floors, caps, rations
and densities all decide a slot *by rule* rather than by what the Book has
learned makes this reader feel alive.

Measured over a simulated fortnight of blocks: **354 of 377 leaves were composed
by the aliveness-weighted draw, and 23 were placed by a floor.** The rules catch
the desk; they do not compose it. `CuratorStillCuratesTests` holds both halves of
that line — the floors must place less than a fifth of the block, and they must
place *something*, since a net that never catches anything is not a net.
`CompoundingCurationTests` remains the sharper guard: it measures whether the
Book's learning still compounds, and it is what caught the first version of the
loop floor flattening the reader's learning rate to its null run.

## What was tried and deliberately reverted

Only ~3 errand *kinds* are eligible in a given session (against 5 eligible
errand *sources*), so the block can offer a way out in about 60% of its trios
rather than all of them. The obvious fix — relax one-Page-per-type from
per-block to per-trio, on the reasoning that a rule written for a three-card
desk seen at a glance is too strict across nine turned leaves — was built and
A/B'd on the same simulation:

| | distinct Pages | trios with a way out |
|---|---|---|
| one type per block | 249 | 71 of 126 |
| one type per trio | 248 | 75 of 126 |
| floors only may repeat a type | 244 | 71 of 126 |

Four more trios looked free until the wider suite showed the real cost: two
Pages of one kind crowd a third family off the block entirely, and two standing
contracts (`aboutYou` and `lore` reaching a twelve-deep desk) broke. That is the
felt repetition the whole exercise began with, so it was reverted.

The honest conclusion: **the ceiling on how often the loop turns is errand
supply, not the dedup rule.** Several errand kinds are gated on a calendar, a
place, or an active pact that the simulation does not have, so a real reader
with those enabled sees more. Widening it belongs in the adapters.

## Where the fortnight landed

Same simulation, after the work:

| | before | after |
|---|---|---|
| distinct Pages reaching a desk | 88 | 101 |
| shown exactly once | 74 | 89 |
| most-repeated single Page | 14× (identical tarot) | 8× (the loose page, a tool) |
| desks offering a way out | 6 of 42 | 36 of 42 |
| tarot | 14× | 4× |
| keeps answered within 3 sessions | not scheduled at all | 12 of 12 |

`CuratorVarietyOverAFortnightTests` keeps the measurement as a regression, with
thresholds looser than these numbers so ordinary content changes do not fail the
build.

## The desk got slow, and why

Measured on a 90-day archive (270 kept Pages), the desk build cost **2383ms**,
of which the Curator's own ranking was 110ms. The other 95% was building the
candidate pool — every adapter, every time.

Probed with `sample` rather than guessed at, in two rounds:

| | before | after |
|---|---|---|
| `candidatePool` | 2105ms | 631ms |
| whole desk build | **2383ms** | **924ms** |

Three fixes, all of them the same shape — *stop recomputing what has not
changed*:

1. **`AttentionFingerprintMemo`.** `AttentionFingerprint.make` tokenises a
   Page's whole text, and `resolvedAttentionFingerprint` recomputed it on every
   access for any Page kept before fingerprints were stored. Five adapters walk
   the whole archive per build. This was the single hottest thing in the app.
2. **`ArchiveMemo`.** The noticing passes ask questions that range over the
   entire archive — which connections recur, how the reader's seeing has
   changed, what the Book has already said. They are pure functions of the
   archive, recomputed on every build. Bisected: three of them cost 310ms of the
   notices adapter's 386ms.
3. **The resurfacing choice.** Picking which kept Page to return scores the
   whole archive and cannot change until the archive does or the day turns.

The keys are cheap fingerprints — identities and lengths, no tokenising — so an
edited Page produces a fresh answer rather than a stale one. Nothing is
persisted.

## More kinds of Notice

Fifteen kinds of Book Notice already existed; four ever fired in a simulated
fortnight, because almost all of them wait on an optional subsystem — a person
thread opened, a connection found, a wager sealed, an aliveness trace left.

`ReaderVocabularyNotice` adds three gated on nothing but the reader having
written something twice, which is the one thing an archive always has:

- **A Word Came Back** — a word used long ago and just used again, with the
  silence measured and both sentences shown.
- **A New Word** — a word that appears in none of the earlier Pages, in an
  archive old enough for a first to mean something.
- **Two Words That Travel Together** — a pair that keeps arriving on the same
  Page.

Each states a fact, shows the sentences it came from, and interprets nothing: a
returning word is not a returning feeling, and the Book does not know which it
was. They share the vocabulary index the reader's maps are drawn from, and it is
memoised, so three new Notices cost nothing per build.

Ideas deliberately **not** built, and why: *The Vanishing* (a subject that used
to recur and has stopped) is the strongest remaining one but needs a register
pass — it can read as an accusation rather than an observation. *The Hour That
Changed*, *The Shorter Sentence*, and *The Same Day Last Year* are all cheap
from the same index and worth doing once the register question above is settled.

## Self-tuning: the reader's own tempo

Every clock in the Curator was somebody else's. Instruments rested 3.5 hours, a
kept sentence stayed owed an answer for 72, a Page waited 6–10 hours per sibling
in its deck — all of it written for an imagined reader who opens the Book about
three times a day. The bursty reader in the fortnight simulation is exactly who
those numbers fail.

`ReaderTempo` measures the rhythm instead, from the Book's own record of being
opened: distinct sittings (45-minute buckets) over the last 21 days. Three
clocks now scale by it:

| clock | was | now |
|---|---|---|
| instrument spacing | 3.5h flat | 0.6 × this reader's gap between sittings |
| answer window for a kept sentence | 72h flat | 4 of this reader's own sittings |
| appetite per sibling in a deck | 6–10h flat | one of this reader's sittings |

Below three sittings there is no rhythm to read, so a new reader keeps the old
assumed constants and a first week behaves exactly as before. Twelve Pages
served inside twelve minutes is one sitting, not twelve.

## Six more kinds of Notice

Added to the three vocabulary findings, all still gated on nothing but the
reader having written:

- **The Hour Changed** — they used to write in the morning; lately it is the
  night. Both halves of the archive have to actually lean somewhere, or it is
  noise with a winner in it.
- **You Are Writing Longer / Shorter** — average Page length has moved by a
  third or a quarter. Reported without a verdict: shorter is not worse.
- **This Day, Before** — a Page kept on this date in an earlier year.
- **A Word Went Quiet** — the delicate one. Said plainly, "you stopped writing
  about this" is an accusation the Book cannot support, so it fires only after
  a word was a genuine habit (four or more Pages, over a stretch shorter than
  the silence that followed) and speaks only as an inventory fact: the count,
  never the meaning. It is ordered last and scored lowest of the set.

## Still outstanding: the arbiter

Not done, and now measurable. With `candidatePool` down to 381ms and ranking at
~110ms, roughly **300ms of the 789ms desk build is the six post-composition
rewrite stages** — the same stages that need one arbiter rather than six
victim-selectors. The prune and the next optimization are the same work.
