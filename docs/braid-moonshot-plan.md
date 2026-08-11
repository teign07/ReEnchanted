# The braid moonshot

The braid is the nightly payoff the whole app builds toward. It is the moment a
reader decides whether the Book actually read them. Three things were wrong with
it: the wrong page could become official, the page ran thin, and it started the
same way too often. A fourth turned out to be the root of the second: on almost
every night there is no fiction in it at all.

The bench (`BraidBenchTests`) is the arbiter throughout. Every claim below was
measured, and one whole idea was measured and thrown away.

---

## Phase 0 — the better braid wins. SHIPPED

`BookDay.bookOfYou` is `pages.last { $0.type == .bookOfYou }`. Official meant
*most recent*, not *best*. A reader who asked for another page and got a thinner
one silently lost the page they preferred, and "Braid a new one too" — which
promises to keep the last braid — demoted it just the same.

`BraidRecoveryState.dayByAdoptingBraid` now decides adoption with
`BraidGenerationSelector.bestUsable`, the same selector that already picks
between candidates inside a single generation. Between generations it does the
same job.

- **Re-braid the last**: the rewrite replaces the incumbent only if it wins.
  A worse rewrite is discarded and the Book says so. Unravelling is a request
  for a better page, not a promise to accept whatever comes back.
- **Braid a new one too**: both pages stay; the winner is re-seated last so it
  remains official.
- `openWhenComplete` opens the *official* page, so a rewrite that lost cannot
  open over the page it lost to.

Covered by four tests in `BraidRecoveryStateTests`.

## Phase 1 — length becomes a quality signal. SHIPPED

The band and the floor had drifted into different jobs and nothing occupied the
space between them:

| scale | band (aspiration) | floor (rejection) |
| --- | --- | --- |
| glimpse | 100–180 | 60 |
| small | 180–300 | 110 |
| full | 280–450 | 180 |

A 74-word grief-day braid cleared the floor, so nothing in the system ever
mentioned that it was twenty-six words under the page it promised.

- New audit finding `underBand`: above the floor, below the band.
- `tooShort` raised from **5** to **13**. It had been the cheapest failure in
  the table, below `tooFewParagraphs`; a missing ritual line cost 14.
- New `amplitude` term in `BraidTastingRoom.Score`, graded by shortfall, so the
  tasting room can prefer the fuller of two otherwise equal cuts.

The `underBand` rule immediately caught a test fixture named
"AcceptsFullMultiThreadBraid" that was 205 words against a 280–450 band. The
fixture was extended rather than exempted.

## Phase 2 — scale by weight, not volume. MEASURED AND REJECTED

Scale is chosen from `storyPages.count` and `storyCharacters`. Because those are
joined by `||`, the character test dominates: a terse reader is capped at
glimpse for ever, and "my sister called about the funeral arrangements" — 48
characters, an enormous day — asks the Book for a hundred words. 21 of 23 bench
nights are glimpses.

Changing `||` to `&&` so a night must be thin in *both* senses was tried. The
bench went from **14 nights in band to 4**, and the worst gap from 24 words to
106.

The lesson is worth keeping: **a braid's length is bounded by its evidence, and
that is correct discipline.** A two-receipt night cannot honestly fill 180–300
words of the reader's life. Granting room and then asking the writer to find
filling for it is how a Book learns to pad. Reverted, with the reasoning left in
the source so it is not retried.

## Phase 3 — the world acts instead of the Book filing. SHIPPED

This is the real fix for thinness, and it is also the answer to "are we braiding
real life with fiction?"

Today the braid *can* braid fiction, and the machinery is good:

- `plan.labyrinth` carries a kept Labyrinth/Academy receipt into its own
  paragraph, joined to lived material by a `crossingMove`.
- Two cameras, `livedFirst` and `trespassFirst`, decide whether the day or the
  fiction opens the page.
- `FaeriePressure` licenses exactly one impossible relation
  (`licensedImpossibleRelations: 1`).
- `magicSubject` lets one ordinary supplied thing take tale form.
- All of it is withdrawn on uncleared-shadow nights, correctly.

But the fiction lane only draws from Labyrinth pages **the reader kept that same
day**:

```swift
let fictionCandidates = eligible.filter {
    isLabyrinthReceipt($0) && !isSupportingLog($0)
}
… .first
```

One beat, same-day only. In the bench corpus, **1 of 25 nights has a fiction
page**. On the other 24 the braid has no fiction in it whatsoever — and those
are exactly the nights that come in short.

This is why Phase 2 failed and Phase 3 should work. More words cannot come from
a life that only offered two sentences. They can honestly come from the Book's
own world, because a sentence about the Labyrinth is not a claim about the
reader.

### What was actually wrong

The authored budget was already large — a typical page ran `authored:8 receipt:1`.
It was being spent on the Book describing its own filing:

> "I circled the bowl once." · "My pencil went down beside the bowl and did not
> improve it." · "The Index wanted a tidier version." · "Twice I read the line
> around the bowl, and kept the second reading to myself."

Every entry in `keepingMoves` is a pencil-and-margin sentence. Read three nights
running it stops sounding like a book with a will and starts sounding like a
clerk. The `settlingAllowance` cap ("two is a rhythm, three is a tic") was being
honoured — but only over `keepingMove`, while the same clerical register leaked
in through `voiceBite`, `crossingMove`, and the rest.

### The change

A new `taleMoves` family: the Book's world doing something, with tonight's real
object as the thing the world reaches for. Ten base moves, plus beats drawn from
the open tale's un-witnessed `TaleBeat`s, the Labyrinth visitor, and the
Academy chapter.

The filling loop now spends two budgets in order — the world may act up to
`livedBeatAllowance` times because a tale beat is *material*; the Book may talk
about its own pencil only `settlingAllowance` times because that is *seasoning*.

Constraints held: nothing in `taleMoves` says the reader did, felt, or
understood anything; the pool returns empty when `allowsNewMagic` is false, so
plain-shadow nights stay plain; no move opens on the subject word, because the
receipt sentences around them already do.

### Measured

| | before | after |
| --- | --- | --- |
| nights in band | 14 / 23 | **21 / 23** |
| worst shortfall | 26 words | 24 words |
| typical glimpse | 74–120 w | 116–134 w |
| audit-clean | 15 | 20 |
| cross-night recurrence | 456 | **423** |
| repeated openings | 7 | 9 |

Two nights remain under band: `grief-day` and `tender-shadow`. Those are exactly
the nights where `taleMoves` correctly returns nothing. See Phase 5.

### Bugs this surfaced

- Three tale moves assumed a singular subject ("keys has", "keys was"). There is
  no plural helper in the house writer; the convention is to avoid inflecting a
  verb on the subject at all. Rephrased.
- **The colophon was stored as one `BraidSentence` even when its text is two.**
  Several closing variants end "...beside the tuesday. I left it." Stored whole,
  the paragraph claimed one sentence where re-reading the page finds two, and
  `BraidRevisionVerifier` correctly refused the entire paragraph as shape drift
  — meaning no model revision of those nights could ever be adopted. Pre-existing;
  changing which variant won is what exposed it.

## Phase 3.5 — consecutive Pages. SOURCE COMPLETE; TESTS ADDED, NOT RUN

The braid now decides one typed `ContinuityBeat` before either Gemma or the
house writer begins. It extends `BookOfYouResidue` and `BindingMemorySpine`
rather than creating another persistence ledger.

- Book-world incidents use stable thread IDs and preserve the exact object from
  the Page that opened them. They open, advance once, and land on a third beat.
- “Still” is licensed by one to four elapsed calendar days, not by the prior
  Page's position in an archive array.
- Tonight's supplied object may change the old incident but may never silently
  replace yesterday's object.
- Gemma and the house writer receive the same continuity brief. The winning
  Page persists the state only when its prose actually carries the required
  thread and anchors.
- A reader-life rhyme requires a concrete prior braid, evidence Page IDs, and
  an older line the reader can recognise. Once spoken, this move rests 28 days.
- `BraidOutputAudit.missingContinuityBeat` requests repair when a generated
  candidate ignores the selected return.

Focused regression coverage was added for next-night continuation, original
anchor preservation, three-beat landing, long absences, Gemma-winner residue,
ignored-continuity refusal, compact-prompt wiring, and rhyme cooldown. Per the
workspace rule, no Swift build or test command has been run yet.

## Phase 4 — opening variety by construction. PARTLY DONE

`braidStyleMemory.recurrencePenalty` already penalises repeated opening shapes,
and it is applied at selection. That cannot help when every candidate shares the
same house scaffold: penalising all of them equally changes nothing, which is
why 7 repeated openings survive across 23 nights.

Openings have to differ *before* the tasting room sees them:

- Feed `openingShapeAges` into `makeCandidates` as a generation constraint.
- Require the pool to cover at least two distinct opening moves — a different
  `NarrativeMotion`, or the other camera — so there is a real choice to make.

### What is done

`BraidStyleMemory.openingFreshnessPenalty(of:)` now asks the ledger how recently
the Book last opened a braid the way a candidate opens, and selection runs it as
the **top** freshness axis, ahead of the general echo and ahead of taste. The
reader meets the first line first, every night, and it is the line they learn to
predict.

Selection order is now: fewest audit issues → freshest opening → least overall
echo → fewest within-page repeated openings → taste → prosody → stable hash.

### What is left, with a number to beat

Across the golden's twenty-three consecutive nights:

```
distinct opening words: 10 / 23
   'You': 8    'The': 4    'On': 2    'It': 2    'I': 2    'Through': 1
```

A third of nights open "You <verb>...". Selection cannot fix this on its own: it
can only choose among candidates the plan produced, and if a night's four prose
transforms all render the primary receipt starting on "You", every candidate
opens the same way and the freshness filter has nothing to pick between.

The next move is at generation, not selection: make the prose transform chosen
for the *primary* unit answer to `openingShapeAges` directly, so a night whose
natural rendering starts "You" is steered to a fronted, cleft, or
labyrinth-first opening when "You" is still warm. `Camera.trespassFirst` already
exists and opens on the fiction instead — it is currently gated on having both a
labyrinth receipt and lived material, which is exactly the gate Phase 5 loosened
elsewhere.

Target: no opening word used more than twice in any fourteen-night run.

## Phase 5 — shadow is the engine, not the exception. NEXT

**The claim to build on: shadow material is where the magic comes from. Never
let the magic go.**

This is not a new idea bolted onto the braid. It is what the shelf system
already says about itself, in `ReaderShelf.promptLine`:

> **LIGHT:** may become the world: setting, weather, small magics, the texture
> of a place.
>
> **SHADOW:** may become **plot**: what someone carries, why the errand exists,
> the thing not said. Never decoration.

Light is scenery. Shadow is the engine. Every fairy tale worth the name is built
out of loss, debt, absence, and the thing nobody will say aloud: the dead
mother, the vanished brother, the bargain someone regrets. A grief day is not
the night the Book should have least to offer. It is the night it has *most* —
and going quiet on it is not restraint, it is absence, and absence reads as
"I don't know what to say to you."

### What the code actually does instead

```swift
let hasUnclearedShadow = (lived + [supporting].compactMap { $0 }).contains {
    $0.shelf == .shadow && !$0.mayTakeTaleForm
}
if hasUnclearedShadow {
    effectiveScore.fictionBeat = nil
    effectiveScore.relationalLens = nil
    effectiveScore.arc = nil
}
```
`Shared/LiteraryContinuity.swift`, in `plan(for:context:score:)`.

One shadow page **anywhere on the day** kills fiction, the relational lens and
the arc for the whole night, and `taleMoves` returns empty. The result on the
bench's `grief-day`:

| receipt | shelf |
| --- | --- |
| "I walked to the corner shop for bread." | light |
| "My sister called about the funeral arrangements." | shadow |

There is an ordinary loaf of bread sitting right there and the Book is forbidden
from noticing it. The page comes in at 77 words and says almost nothing.

### The gate is blunter than the law it is enforcing

The real harms are named exactly, and they are already enforced separately as
register failures in `BraidOutputAudit`:

- `consoledUnbidden`
- `resolvedTheUnresolved`
- `assignedMeaning`
- `spokeForTheReader`

Those four are absolute and must stay absolute. **They are also sufficient.**
`hasUnclearedShadow` is a crude proxy for them that throws out the Book's
presence entirely in order to avoid four specific sentences it already knows how
to refuse.

The distinction to build on is **attending vs interpreting**. A door that keeps
the bread in mind makes no claim about a funeral. "The Labyrinth understood your
sorrow" does. The first is company; the second is the violation. Only the second
is what the four failures forbid.

### The bench is not testing the permitted path at all

`tenderShadowDay()` in `Tests/InsideCoverCoreTests/BraidBench.swift` is noted as
*"Hard material the reader has since let take tale form"* — and passes
`context: .empty`. With an empty `readerStory` the permission is false, so it is
treated as **uncleared** shadow and gets the plain treatment. The fixture does
not test what its own note claims.

The permission model it should be exercising (`ReaderStory.shadowMayTakeTaleForm`):

| mode | tale form allowed |
| --- | --- |
| `knowButNeverWrite` | never |
| `askEachTime` | not without an explicit yes |
| `mayUse` | always |
| `onlyWhenOld` | after `shadowTaleFormDays` |

There is currently no bench night covering `mayUse` or a matured `onlyWhenOld`.
The single case where the reader has explicitly invited the Book to make a story
of hard material is the case with no coverage.

### The work

1. **Fix the fixtures first, so the change is measurable.** Give
   `tender-shadow` a real `readerStory` with `shadowPermission: .mayUse`, and add
   an uncleared twin so both paths are covered. Add an `onlyWhenOld` night either
   side of `shadowTaleFormDays`. Expect the bench to get *worse* before it gets
   better: that is the point.

2. **Replace the night-wide kill with a subject restriction.** Do not null
   `fictionBeat`, `relationalLens` and `arc` because a shadow page exists.
   Instead constrain what magic may take as its subject.
   `primaryMayCarryMagic` already knows how to choose a non-shadow subject; the
   machinery exists and is simply being bypassed.

3. **Let shadow be plot, per the canon.** On a permitted shadow night the
   material may drive *why the errand exists* — the weight under the page —
   without being named, explained, or resolved. The Book may know something is
   being carried and let the world respond to the weight. It may not say what
   the weight is or what it means.

4. **A vigil register for unpermitted shadow.** Where permission is absent, the
   world may still attend the *light* objects of the day and stay in the room.
   Presence without commentary. Only when a night is entirely shadow with no
   light object should the page go plain, because then there is genuinely
   nothing to attend that is not the wound.

5. **Then the band question dissolves.** `grief-day` and `tender-shadow` are
   currently the only two nights under band. They will not need a lowered band
   once they have honest material to reach it with, drawn from the bread rather
   than the funeral. Do not lower the band first: that hides the symptom.

### Guardrails that do not move

- The four register failures stay absolute, and stay as `isRegisterFailure` so
  they never enter candidate selection.
- Never name, explain, resolve, or draw a conclusion about shadow material.
- Never console unbidden. Company is not consolation.
- `knowButNeverWrite` means exactly that, forever, with no cleverness around it.
- The reader can always check any claim the Book makes about their life. Nothing
  in this phase produces an unfalsifiable statement.

## What is deliberately not in scope

- Padding a thin night with more of the reader's life. The register discipline
  that forbids inventing about the reader is the most valuable thing in the
  system; length is never worth spending it.
- Asking the reader to choose between two braids. The system should know which
  page is better. That is what Phase 0 is.

---

## Starting cold

Everything a fresh session needs that is not obvious from the code.

### Where the numbers stand

`swift test --filter "BraidBenchTests/testReportTheStandingShortfall"` prints the
table. Current standing, from 14/23 in band when this work started:

```
23 nights · 21 in band · 20 audit-clean · average taste 90 · 12 repeated openings
2 of 23 nights fall short of their band; worst gap 24 words.
Cross-night recurrence pressure: 560 isolated baseline; 540 with archive memory.
```

The two short nights are `grief-day` and `tender-shadow`. They are Phase 5.
Recurrence *with* memory must stay below the isolated baseline: that inequality
is asserted by `testConsecutiveNightsRestTheGoldenCorpusMachine` and it is the
single best signal that the Book is not developing a house refrain.

`swift test --filter "Braid|Deterministic|TaleGrammar"` runs 300 tests. One
fails: `TaleGrammarTests.testManualBoundTaleHandsOverTheFinishedTaleWhole`,
which is a newly added test with no implementation behind it yet — another
session's test-first work, not braid.

### The instrument

`Tests/InsideCoverCoreTests/Golden/braid-bench.txt` is the artifact to read, and
it now has two halves:

- **23 isolated specimens** — the right tool for "is this a good page".
- **Consecutive nights** — the corpus read straight through with the archive
  carried forward. Continuity beats can only appear here. If a change touches
  the serial and this section does not move, the change did nothing.

Re-record with `BRAID_BENCH_RECORD=1 swift test --filter BraidBenchTests`, then
*read the diff*. That is the whole point of the file.

### The one structural fact that explains most failures

Three separate improvements failed the same way before being fixed, and a fourth
still might: **the tasting room can only choose among candidates the plan
produced.** Every candidate comes from one `plan`, varying only by camera, voice
variant, realization and prose transform — so they are all the same length, and
they share an opening family.

Consequences observed:
- Scoring length (`amplitude`) moved only 4 of 23 nights, because no candidate
  was longer than another.
- Penalising repeated openings at selection cannot work when every candidate
  opens the same way.
- `priorEchoScore` hands out its best score for a light callback that nothing
  generates, so it can only ever reward an accident.

**Rule of thumb: if the taster rewards it and the prompt asks for it but nothing
appears on the page, the generator cannot make it. Fix the generator.**

### Measured and rejected — do not retry

- **Promoting thin nights to a larger scale** (`||` → `&&` in the scale rule).
  Bench went from 14 nights in band to **4**, worst gap 24 → 106 words. Braid
  length is bounded by evidence and that is correct discipline. The reasoning is
  in the source at the scale rule so it is not retried.
- **Lowering the band for shadow nights.** Hides the symptom. Phase 5 gives
  those nights material instead.
- **Asking the reader to choose between two braids.** The system should know
  which page is better; that is what Phase 0 is.

### Things that bit, and will bite again

- `narrativeRegister == .plain` is **not** a shadow flag. It is derived from
  content and is the default fallthrough. The shadow signal is the plan's
  `hasUnclearedShadow`, which the audit cannot currently see — it needs lifting
  into a helper both can call.
- There is **no plural helper** in the house writer. The convention is to never
  inflect a verb on the subject: `"keys has"` and `"keys was"` are caught by
  `testPluralAnchorDoesNotFallBackToSingularPronouns`.
- No authored move may open on the subject word. The receipt sentences around it
  already do, and a run of sentences opening on the same noun is exactly what
  the prosody penalty counts.
- Every move family must rest. `keeping`, `tale`, `colophon` and the voice bite
  all consult prose memory now. A new family without a rest ledger becomes a
  house refrain within a week of real use.
- Multi-sentence text stored as a single `BraidSentence` breaks
  `BraidRevisionVerifier` with `unalignedParagraph`, which silently means **no
  model revision of that night can ever be adopted**. Split with
  `splitSentences` when building any paragraph.
- Paragraph bands are as binding as word bands. A beat that opens its own
  paragraph on a Glimpse turns a 2–3 paragraph page into 4.

### Register safety, in one line

The Book may be strange, unfair, withholding and feral. It may never console
unbidden, resolve what the reader left unresolved, assign meaning to their life,
or speak for them. Those four are `isRegisterFailure` and never enter selection.
Everything else is craft, and craft is negotiable.
