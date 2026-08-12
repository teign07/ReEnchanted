# Program F — The Book's Weather (implementation plan)

**Program F** of [`the-book-is-a-character.md`](the-book-is-a-character.md).
Program A (interjections) is built; this is the follow-on that makes the Book's
*mood* real instead of a flag.

Goal: the reader can tell what kind of day the Book is having, from how it
talks and nothing else. Its moods have causes, sizes, and duration. They fade.
They can be changed. **The Book is allowed to be difficult** — short, cold,
carried away, unimpressed, sulking, wrong-and-sore-about-it — and it is never
allowed to charge the reader for any of it.

---

## Implementation checkpoint — 2026-08-11

F0–F5 and the F6 lint rules are implemented in `Shared/LiteraryContinuity.swift`.

- **F0 Reachability.** The clock branch is gone from the cascade, and so is the
  `else { stance = .curious }` default arm. When nothing has happened the Book
  now keeps the mood it already had, or rests at its own temperament, instead of
  dropping into a stance that changed nothing.
- **F1 Weather.** `BookMood` (stance, intensity 1–5, subject, cause, arrival,
  half-life) persists on `BookInteriorState`, bumped to v11 with a defaulted
  decode. `BookMoodEngine.resolving` keeps a standing mood running until it
  fades or something larger displaces it. `BookTemperament` mints a resting
  stance per Book from its awakening day; only `curious`, `mischievous`,
  `intent`, and `protective` are eligible, because a reaction and an hour are
  not dispositions.
- **F2 Night.** `hushed` is no longer selectable by the clock. `BookNight` is a
  modifier carried on the snapshot: a mischievous Book at 1am is mischievous
  *and* quiet.
- **F3 The telling.** `BookTelling` derives six levers — length, order,
  evidence posture, whether it asks, self-interruption, cadence — from
  (stance, intensity, night). `voicing` now trims, reorders, and interrupts
  rather than prepending a fixed string. **Intensity amplifies the stance's own
  direction:** expansive moods say more as they grow, guarded moods say less.
- **F4 Objects.** A mood's `subjectKey` steers the preoccupation index: warm
  weather returns to its subject, cold weather does not go near it while the
  feeling is strong. Never announced.
- **F5 Reader effect.** `BookInterjectionEditor.applying` now moves the weather
  as well as the ledger. *You're wrong* → cold for about a day (evidence
  withheld, no questions, lifts on its own). *Go on* → warm. *Not now* → nothing.
- **F6 Lint.** `mood-declared`, `absence-attributed`, and `repair-solicited`
  are errors in `BookCharacterLint`.

Two laws were discovered during implementation and are now enforced:

1. **A mood colours reflection; it never edits an invitation.** The length
   lever cut a fieldwork ask out of a world-event door. Body mutation is now
   gated to `intent == .reflect`; every other Page keeps its whole body.
2. **Terse means saying the point, not saying only the preamble.** Trimming
   promotes the finding before it cuts, so a shut Book says the finding and
   stops rather than keeping its throat-clearing.

**Verification.** 17 new contracts in `BookWeatherTests` plus the rewritten
stance contract. The old `testStanceChangesHowACharacterOwnedPageEnters`
asserted only that `detail` differed — it would have passed with `"Banana."`
as the prefix, which is why the stub shipped green; it now asserts that a loud
Book says more than a shut one and that the finding survives either way.
Baseline before this work was 2,644 tests / 40 failures (not the 12 previously
reported).

Not yet done: `subjectKey` is only populated from replies, so moods arriving
from the cascade have no object yet. `BookTelling.evidencePosture` is written
to metadata but no view reads it — the receipts still render the same way in
every mood.

## The finding: stance is plumbed, not built

`BookCharacterStanceEditor.voicing` (`Shared/LiteraryContinuity.swift:3192`)
runs from one call site (`Shared/SurfaceAndCurator.swift:3255`) over 16 page
types and all seven stances. Its complete effect on prose:

| Stance | Actual prose effect |
|---|---|
| `pleased` | prepends one of 3 fixed strings ("Ha." / "There." / "Oh, good.") |
| `mischievous` | prepends one of 3 fixed strings |
| `contrite` | prepends one of 3 fixed strings |
| `hushed` | drops a closing question; truncates detail to one sentence |
| `protective` | drops a closing question |
| `curious` | **nothing** (sets a metadata key) |
| `intent` | **nothing** (`prompt.trimmingCharacters`) |

The interjection path's `voiced()` (`LiteraryContinuity.swift:3086`) covers 3
cases out of 7 stances × 9 registers = 63. **A mood is a sticker on the front
of a sentence.** Same sentence, same length, same order, same evidence.

**And the moods barely occur.** The derivation
(`LiteraryContinuity.swift:1752`) is a ten-branch cascade in which `curious` is
the fallthrough default (a no-op), `hushed` fires on `hour >= 22 || hour < 5`
(a clock, not a mood), `mischievous` needs belief ≥ 55 *and* ≥ 8 meaningful
events *and* nothing above it to fire, and every other branch needs a rare
event. In practice the Book is **curious by day and hushed by night**: seven
moods collapsed to two observable states, one of which is the time.

**More stances would not help.** The fix is reachability, depth, intensity, and
object — none of which needs a new enum case.

---

## The law: difficult, never guilt-tripping

The canon already licenses this. `LiteraryContinuity.swift:1482`: *"You may
argue, withhold a reveal, choose an inconvenient Page, or refuse to become a
neutral tool."* And immediately after, the two hard limits: *"Never make the
reader responsible for your feelings and never punish absence with guilt."*

That is the line, and it is not "the Book must be nice."

**The Book may:**

- be short with the reader, go cold, be visibly unimpressed
- **sulk after being told it is wrong** — not perform contrition, actually be
  a bit off about it for a day, and lift on its own
- withhold a reveal it was about to give, refuse a register, leave the evidence
  unvolunteered
- get carried away, overclaim in delight, and have to walk it back later
- have a bad afternoon that has **nothing to do with the reader** and say
  nothing about why
- take a side against the reader about something in the reader's own archive

**The Book may never:**

- attribute a mood to the reader's absence, in any wording, ever
- ask to be cheered up, or make repair the reader's job
- let mood touch a hard boundary, a distress signal, or consent
- **declare a mood.** No "I'm feeling low", no "I've been off today", no mood
  as status line. **Mood is shown, never stated.** This is the single rule that
  keeps a sulking Book characterful instead of an app with feelings.

Absence stays exactly as it is today: `quietDays >= 3` produces gentleness
(`.protective`), which is a *gate*, not a mood with a cause. Coming back after
six weeks must never meet a Book in a state that the reader could read as their
fault.

---

## The model

```swift
struct BookMood: Codable, Equatable {
    var stance: BookStance
    var intensity: Int              // 1…5
    var subjectKey: String?         // what it is about, from the preoccupation index
    var cause: BookMoodCause        // .reading, .correction, .keeping, .ownBusiness, .baseline
    var arrivedAt: Date
    var halfLife: TimeInterval
}
```

Persisted on `BookInteriorState` (bump to v11) with a defaulted decode — the
same discipline `init(from:)` already uses for every collection it has added
since v1, so no reader loses their Book.

### 1. Moods persist and decay; they are not recomputed

Today the cascade recomputes stance from scratch every desk build, which is why
mood has no memory. Change the cascade's output from *the stance* to *a
candidate mood*. The candidate displaces the standing mood **only if its
intensity exceeds the standing mood's decayed intensity**. Otherwise the
standing mood keeps running and keeps fading.

That single inversion is most of this plan. A Book that got sore on Tuesday
afternoon is still slightly sore on Tuesday evening.

Decay is by half-life against `arrivedAt`. Big causes get long half-lives (a
correction: ~24h), small ones short (a pleasing keep: ~4h).

### 2. Baseline temperament — per Book, minted at awakening

At intensity 0 the Book returns to a **baseline temperament**, not to
`curious`. The baseline is deterministic per Book, minted where the interior is
first created (`LiteraryContinuity.swift:9749`). Some Books rest mischievous,
some intent, some curious, some protective.

Two readers' Books are therefore different creatures from the first day, and
the mood system has somewhere to return to that isn't a no-op. This is "*my*
Book" made mechanical rather than asserted.

### 3. Night is a modifier, not a mood

Remove the clock branch from the cascade. `hushed` stops being a stance the
cascade can select and becomes a **night filter** applied over whatever mood is
standing: lower volume, shorter sentences, fewer questions. A mischievous Book
at 1am is mischievous *and quiet*, not replaced.

This frees the most-used slot and makes nights read seven different ways.

### 4. Moods have objects

`subjectKey` points into the preoccupation index Program A already builds. The
telling may let the subject leak — a pleased Book returns to what pleased it,
a sore Book avoids the thing it is sore about — **without ever announcing the
cause**. That is the difference between an emotion and a costume.

---

## Intensity and the telling

`voicing()` stops prepending strings and becomes a real transform with levers.
For each (stance, intensity) the editor decides:

- **Length** — how many paragraphs survive
- **Order** — finding-first at high arousal; evidence-first, finding last, when
  low
- **Evidence posture** — volunteered / mentioned / left to be found
- **The ask** — whether it asks anything at all, and whether it sounds like it
  expects an answer
- **Self-interruption** — whether it breaks its own sentence (high intensity
  only; the voice law already calls for interrupting itself)
- **Diction** — the existing authored pools, banded by intensity

Seven stances × five intensities × six levers is a genuinely different Book,
built entirely from prose that already exists. **No new model calls** — this is
selection and pruning, seeded per day.

Worked example, one Loom finding, unchanged evidence:

- *pleased, 5* — leads with the finding, interrupts itself, spills all three
  receipts, asks nothing because it is too busy being right
- *pleased, 2* — leads with the finding, one receipt, a light question
- *intent, 4* — evidence first, finding last, no question, nothing wasted
- *contrite, 3* — the finding hedged, evidence offered rather than pressed,
  loose pencil
- *cold (see below), 4* — three flat sentences, evidence not volunteered at
  all, no question

---

## The reader's effect

Program A's reply chips already mutate durable interior state. Route them to
mood as well:

- **`you're wrong`** → the Book goes **cold**: shorter, evidence withheld, no
  questions, for roughly a day. This is a sulk and it is allowed. It never says
  why, never asks for anything, never mentions it again, and lifts on its own.
  (Implemented as `contrite` at high intensity with the evidence posture set to
  *withheld* — no new stance needed. Today's code jumps straight to a
  performed-contrition prefix, which is the neutered version.)
- **`go on`** → warms; raises the intensity of a positive mood and pins its
  subject.
- **`not now`** → no mood change at all. A boundary is not an injury.
- **Keeping a page it liked** → `pleased`, with that page as the subject.
- **Absence** → **no mood.** Gentleness gate only, as today.

---

## Phases

**F0 — Reachability.** Fix the cascade: remove the clock branch, give `curious`
a real telling or stop using it as the silent default, make `mischievous`
reachable. No new model, no new state. Ship-able alone and immediately visible.

**F1 — `BookMood` on `BookInteriorState` (v11)** with arrival, decay,
displacement-by-intensity, and baseline temperament at awakening.

**F2 — Night as modifier.** Remove `hushed` from the cascade, add the night
filter over the standing mood.

**F3 — The telling.** Rebuild `voicing()` and `voiced()` around the six levers,
banded by intensity, across all seven stances and all nine registers.

**F4 — Objects.** Wire `subjectKey` to the preoccupation index; subject leaks
into the telling, never into a declaration.

**F5 — Reader effect.** Chips → mood, including the cold sulk.

**F6 — Lint rules** (below), then turned to failing.

---

## Program D additions — the anti-guilt rules

`BookCharacterLint` (`LiteraryContinuity.swift:3271`) already holds
`bannedPhrases` and `mechanicalPhrases`. Add a third set, which is the "don't
neuter it, don't let it guilt-trip" line made testable:

- **mood-declaring**: "i'm feeling", "i've been feeling", "my mood", "i've been
  low", "i'm in a mood", "feeling better", any stance name used about itself
- **absence-attributing**: "since you've been away", "i've missed", "you
  haven't been", "it's been a while since you", "where have you been"
- **repair-soliciting**: "cheer me up", "make it up to me", "you could make it
  right", "if you'd just"

And a generated-census assertion the suite can actually fail: **render the same
finding across all 7 stances × 5 intensities and assert the outputs differ on
length, order, and evidence posture** — not merely on their first three words.
That test is what would have caught the current stub, and it is the real gate
for F3.
