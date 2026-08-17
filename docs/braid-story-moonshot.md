# The braid story moonshot

The braid is the nightly payoff, the spine of every bound volume, and the one
page that decides whether the reader believes the Book read them. It is
currently none of those things well. This plan says why, and what it becomes.

Written 2026-08-16, from three real braids off the reader's phone and the
23-night bench (`Tests/InsideCoverCoreTests/Golden/braid-bench.txt`).

The decision this plan encodes: **recognise, lean, and ask.** The Book notices
the shape a life is making, lets it bias what it looks at, and occasionally
puts it to the reader as a question they can confirm or refuse. It never
announces what their life means.

---

## The finding

`Shared/TaleGrammar.swift` is a story-recognition engine: nine beats, ten
shapes, confidence scoring, refusal on thin evidence, titles drawn from the
reader's own words. It is 1,434 lines and fully tested. Bound tales already
reach `MonthlyEdition` and already surface as pages.

`Shared/LiteraryContinuity.swift` is the braid: 25,559 lines. It references
`TaleShape` **once**, at line 17456, in a Gemma prompt block that begins
*"SOMETHING IS RUNNING (do not name it, ever)"*. `DeterministicBraidwright` —
the default writer, and the one that produced every braid the reader has
actually seen — has no access to it at all.

Every night, from the same receipts, a tale is quietly recognised into
`boundTales` while the braid writes about the Registry growing a column for
the diner. The two never meet.

The moonshot is not to build a story system. It is to connect the one that
exists to the page the reader reads.

---

## What is wrong today, measured

From an 11-page night (mixed lived and fiction) that produced
"The Diner Answered the Air":

- **One** sentence of the reader's life reached the page.
- **Twelve** sentences were the Book describing its own handling of it.
- The anchor noun "the diner" appeared **14 times**.

Across the 23-night bench: the single most-repeated noun occupies **51%** of
every braid's sentences, and **38%** of all sentences are the Book filing.

### The causal chain

**1. Material starvation.** Two caps stand between kept pages and the page.
`livedBeatAllowance` (`LiteraryContinuity.swift:15251`) admits 2/3/5 lived
pages by scale. `fictionBeat` (`:16532`) takes `.first` of the sorted
candidates — **exactly one fiction page, at every scale, forever**. The same
flat-cap bug was found and fixed for lived beats (see the comment at `:16451`)
and never applied to fiction. Ceiling on a small night: 3 lived + 1 fiction.
Seven of eleven pages never entered the prose.

**2. The scale gate under-reads the night.** `taleReading` (`:16896`) branches
on `storyPages.count <= 3 || storyCharacters < 620`. The `||` lets a low
character count override an 11-page night. Worse, `storyCharacters` sums only
`userInput + playerReply` — **what the reader typed**. A kept Fae Bargain or
Story Page contributes zero. A night that is half fiction reads as thin.

**3. So it pads.** `:20264` runs `while bodyWordCount < targetWordBand.lowerBound`,
spending tale moves and settling moves until the floor is cleared. With three
pages of material and a quota to fill, that loop runs and runs, on the one
noun it admitted. **The archive chatter is padding.** It is a symptom of
starvation, not a taste failure.

**4. And the guardrail does not cover the body.** `settlingAllowance` — *"How
many times the Book may talk about its own handling of the page. Two is a
rhythm and three is a tic"* — budgets 2 on a small night. The diner braid has
twelve. The split budget at `:20264` governs **only the filler loop**; moves
emitted in the main body are counted against nothing.

**5. The tale layer is the wrong material.** All seven `taleThreads` (`:21122`)
are one joke: the archive processes the noun. Stacks gossip about it, the Index
wants a purpose for it, the Registry grows a column, three hands catalogue it,
a list downstairs adds it. There is no event, no character with a want, nothing
that happens to anyone. Continuity inherits this — a thread advancing from
"a door has started keeping X in mind" to "it made up its mind" is a filing
status changing, not a tale getting a second chapter.

### Sequencing constraint

**Fix 1 must land before fix 2.** Raising the scale without raising the
material makes the page worse: a bigger word band with the same three pages
means the filler loop runs *harder*. Material first, band second.

---

## Discrete bugs

Independent of the design, and cheap:

| # | Bug | Where |
|---|---|---|
| B1 | Weekday names pass the anchor filter → "the thursday kept watch and would not look away" | `unsafeMagicNouns:22022` bans *morning, lunch, week, year* but no weekdays |
| B2 | Plural anchors break agreement → "the beers **was** there at the end and **is** pretending" | hardcoded singular verbs, `:21346` |
| B3 | Raw tokens leak into prose → "You chose sliceoflife." | `PageModel.swift:3726` builds it from an unhumanized rawValue; `:3291` already documents that reader sentences exclude choices |
| B4 | Story scaffolding leaks → "Turn 1 You step in." | `CapturePageSheet.swift:13480` |
| B5 | Truncation lands mid-sentence → "They fronted you the..." | `clippedText:18246` cuts on character count |
| B6 | The role stamp repeats verbatim night to night | "I wrote The Maker of the Repeating Tuesday in the margin…" in 2 of 3 braids |
| B7 | Anchor selection has no notion of *interesting* — it takes `atom.nouns.first` past a denylist, and picked "the beers" out of a calorie log over "The mug is sulking about being empty" | `safeMagicSubject:21891` |

---

## The architecture: three clocks

The braid cannot support weekly/monthly/seasonal/annual volumes because it has
one time-scale: tonight. Give it three.

| clock | what it is | how it ends |
|---|---|---|
| **The curse** | The Rut. Permanently open. `TaleBeat.lack` already documents it: *"A lack, a curse, a need, or a prohibition. The Rut is the standing one."* | Never. The Thorned Bargain gives it one descent and one turn a year. |
| **Tales** | Recognised shapes. Weeks to a month. Several may run at once. | Bound, scarred, named in the reader's own words. |
| **Nights** | The braid. Most are a good page about a real day. | Nothing continues, and that is correct. |

### Three registers of night

This is where "not every braid needs to reference the days before" becomes
architecture rather than a dial.

- **Plain night (most).** A well-made page about what happened. No callback,
  no thread. **Silence is the default**, and a page that does not reach for
  continuity is not a lesser page.
- **Leaning night (some).** The day landed on a beat. The Book's *attention*
  shifts — `taleAttention` already has the vocabulary for this — without
  naming anything.
- **Binding night (rare).** A tale closes. The Book names it, using the
  reader's words, and the page is a genuine event.

Today every night is a bad version of register two, because `continuityBeat`
fires on thread mechanics rather than on whether anything happened.

### The ask

Option three. On a leaning night, occasionally, the Book puts the shape to the
reader as a question — *"does this keep happening?"* — which they confirm or
refuse. Rationale:

- A Book that asks can be **wrong without being presumptuous**. Announcing is
  the horoscope failure mode; asking is not.
- A reader confirming "yes, that keeps happening" is the **strongest evidence
  available**, better than anything `recognize()` can score unaided.
- The pattern is already house style: Pact War went reader-driven, People of
  the Book is confirm-on-suggest.

The affordance already exists — the "Teach me" card on the braid. Its question
changes; its plumbing survives.

---

## Feeding the volumes

Today `EditionCurator` scores a page up if `usedInBookOfYou`, and
`MonthlyEdition` collects `.bookOfYou` pages into the spine. **Editions
reprint braid prose.** A monthly edition is thirty braids each saying *the
diner, the diner, the diner*; an annual is 365 of them. The nightly weakness
compounds by volume instead of averaging out.

The fix: **the braid emits structure, not only prose.** `BookOfYouResidue`
already carries 24 tagged fields (motifs, arc movement, fiction thread,
continuity kind). Add the beat and its receipt. Then each rung composes from
the structure of the rung below:

- **Week** → the beats of seven nights. Sometimes a shape is visible; usually
  it is just a week, and the issue should say so.
- **Month** → tales opened, closed, still running.
- **Season** → named backwards by the reader (existing canon).
- **Year** → the curse: one descent, one turn.

That is what makes a 365-page volume readable: a table of contents that means
something.

---

## The road

Each phase ships on its own and is measured against the bench.

**Phase 0 — feed it. SHIPPED 2026-08-16.**

Three changes, all additive: `fictionBeatAllowance` (1/2/3 by scale) with
overflow beats carried in `additionalFictionBeats` and their own paragraphs;
`storyCharacters` now counts a kept Labyrinth receipt's `promptText`, matching
what the atom builder already reads; the `small` branch of the scale gate is
`&&` instead of `||`, so a low character count can no longer veto a page-rich
night. The `glimpse` branch stays `||` — a thin night must stay thin, which is
what the earlier measurement was defending.

**The bench could not see any of this.** Six of the 23 nights carried a
Labyrinth receipt and *no night carried two*, so the flat fiction cap was
invisible to its own arbiter. Added `rich-mixed-night`: eleven kept pages, six
lived and five fiction, three of them Book-written/reader-kept
(`unansweredLabyrinth`, scene in `promptText`, empty `userInput`) — which is
what a generated receipt actually looks like on the device and the condition
the `storyCharacters` bug needed.

Measured on that night:

| | before | after |
|---|---|---|
| scale / words | small · 203 | **full · 308** |
| provenance | authored 23 · receipt 7 | **authored 16 · receipt 11** |

Receipts up 57%, authored prose down 30%, and two fiction receipts that were
previously discarded now hold paragraphs. The extra words are the reader's
night, not padding. No existing night's prose changed; 2,794 tests pass.

Still visibly wrong on that page, and deliberately left for later phases: the
anchor noun "the mug" appears 13 times (phases 2–3), `choice:front-the-cost`
leaks as *"It was front the cost that you chose"* (B3), and a sentence splits
into the fragment *"And would not give the diner a vote."*

**Phase 1 — the bug batch. MOSTLY SHIPPED 2026-08-16.**

- **B1 weekday anchors — done.** Weekdays, months and the remaining calendar
  labels joined `unsafeMagicNouns`. The corpus's one weekday-anchored night
  improved by its own scoring: taste 84 → 87, repeated openings 2 → 1.
- **B2 plural agreement — done.** `anchorIsPlural` / `agreeing(_:_:with:)`,
  applied at the five templates where the anchor is the grammatical subject.
  Handles irregulars and singulars that merely end in `s` — "the bus were
  there" would be worse than the sentence it fixed. Three tests.
- **B3, B4, B5 turned out to be one bug — done.** Not three leaks in the braid:
  composed page bodies carry scaffolding, and the braid quotes bodies verbatim
  as receipts. `DeterministicBraidwright.strippedScaffolding` now removes
  `---` field separators, `Turn N` markers, upstream mid-sentence clips, and a
  leading page-type header (`"A Fae Bargain: Book Sprite --- …"`), the last
  only when the label is a real `BookPageType` so a reader who writes "My
  sister said: …" keeps every word. Stripping happens at the point of quoting,
  not writing, because pages already in the archive carry these bodies. Six
  tests.
- **Choice grammar — done (found in passing).** The `taggedChoice` branch used
  an allowlist of fifteen verbs, so any verb outside it produced "You chose
  front the cost", which `cleave` then faithfully rewrote as "It was front the
  cost that you chose." Replaced with a determiner test: a multi-word choice
  that does not open on a determiner is an action and takes "to". Cannot go
  stale the way a verb list does.

**Reverted, deliberately:** a sentence-aware `clippedText`. That function feeds
only the prompt, never the page, and shortening its lines let the evidence
packet seat more pages — pushing a heavy night from 19,060 to 20,320 characters
against a 21,090 allowance, leaving under 800 characters of headroom before
`LocalBrainPromptBudget.fit` clips the middle of the prompt. The mid-sentence
fragments it was meant to fix came from page bodies and are handled above. The
hard character cut stays, now with a comment saying why.

**Still open in phase 1:** B6 (the role stamp repeats verbatim night to night),
B7 (anchor selection has no notion of *interesting* — "the day" is the honest
fallback but a bland one), the squashed `sliceoflife` token (needs an upstream
fix in the Story Page composer; the case is already lost by the time the braid
sees it), and a new one: sentences splitting into fragments that open on "And"
("The air in the long room slammed the door. And would not give the diner a
vote.").

**Phase 2 — budget the whole body. TRIED AND REVERTED 2026-08-16. The premise
was wrong.**

The plan said: extend `settlingAllowance` past the filler loop and the
archivist voice dies on its own. It does not. Measured, in order:

| change | Book narrating itself |
|---|---|
| session start | 123 / 286 sentences (43%) |
| decouple tale budget from `livedBeatAllowance` (5 → 3 on a full night) | 123 (41%) |
| also cut `settlingAllowance` 2/2/3 → 1/1/2 | 123 |
| also budget `supportingMove` (was one per lived beat, unbudgeted) | **123** |
| instead: lower the band floors ~18% | **105** (39%) |

The absolute count did not move by a single sentence across three separate
budget cuts. Cutting the tale budget did not remove archive lines; it *swapped*
them for settling lines — "Downstairs, the thing that collects unfinished
business…" became "Twice I read the line around the mug…". Same voice,
different family.

**Why: the word band is the only real constraint.** The filler loop runs
`while bodyWordCount < targetWordBand.lowerBound`. The volume of Book-talk is
set by `band − material`, and every allowance is just a preference about *which*
filler gets bought. Starve one family and the loop buys another.

Only two levers actually exist, and phase 0 already pulled the first:

1. **More material** (phase 0 — worked: receipts 7 → 11 on the rich night).
2. **A lower band** — the only thing that reduced Book-talk, and it removed no
   receipts at all: 18 fewer self-narrating sentences, 3057 → 2985 words.

Lowering the bands is a product decision — it makes every braid shorter — so it
is bj's call, not a refactor. Everything in this phase was reverted; the bench
is byte-identical to its phase-1 state.

**And the deeper reading:** even the band cut only reached 39%. Getting to a
page that does not sound like an archivist is not a counting problem. Nearly
half of every braid is the Book talking about itself, and the fix is to change
what those sentences *are* — a beat about the reader's day rather than a note
about filing. That is phase 3, and this experiment is the evidence for it.

**Phase 2a — connect the feedback buttons.** Let `BraidLearningGuidance`
re-weight `BraidTastingRoom.Score` inside `BraidGenerationSelector.bestUsable`.
The dimensions already match exactly; today "I loved this one" reaches only the
Gemma prompt and does nothing on the default path. Also fix the button styling:
the negative option currently renders as the dominant one.

**Phase 3 — the world stops doing paperwork. SHIPPED 2026-08-16.**

Two corrections to this plan's own diagnosis, both found by reading the code
rather than the bench:

1. **`DeterministicBraidwright` already sees the recognised tale.**
   `plan.context.openTale` is live — `PlayerVault.shared.data.livingTale` feeds
   it at four call sites — and five beat-gated threads (`price`, `donor`,
   `crossing`, `test`, `taken-in`) already existed, firing on
   `tale.witnessedBeats`. The claim earlier in this document that the writer
   had no access to TaleGrammar was wrong.
2. **The good prose was already written, and gated behind the bad prose.**
   `taleThreads` had sixteen threads, not seven. Six of them — a paper moth
   eating a careful hole, a stair that shifts when it overhears, a pocket that
   grows under the back cover, a bell under a floor with no bell, a dust circle
   that bites, something crossing the roof with the news in its teeth — were
   unreachable until `oldWorldIsFamiliar` confirmed that *all ten* clerical
   threads had already been spent. A new reader met ten nights of Registry and
   Index before the Book was permitted to be strange. `keepingMoves` had the
   identical gate, and its comment said the quiet part out loud: the held-back
   set were "six less clerkly ways to touch the paper".

So phase 3 was smaller than written: rewrite the ten clerical threads into the
register of the six good ones, and merge both gated pools into one.

Kept (already alive): `lamps`, `doors`, and the unruly six.
Rewritten: `stacks` (shelves turn to face it), `door` (opens onto nothing and
waits), `index` (climbs out of its own alphabet).
Replaced outright: `registry` → `frost`, `catalogue` → `echo` ("Someone in
another room said it out loud a moment before I wrote it down. There is no
other room."), `unfinished` → `ribbon`, `rumour` → `birds`, `ledger` → `rain`
("It rained inside the Stacks over it and nowhere else.").

`serialFictionThreadIDs` and `fictionMarkers` both had to learn the new keys —
they still listed the retired ones, which broke continuity verification on 15
nights until updated. The continuity pool also widened from ten to all sixteen,
so a continued thread can now be the moth or the bell.

**Measured across the corpus, session start → now:**

| | before | after |
|---|---|---|
| archive/clerical references | **50** | **2** |
| Book narrating itself | 123 / 286 (43%) | **89 / 313 (28%)** |
| repeated openings | 13 | 12 |
| nights in band | 23/23 | 24/24 |

No band change was needed. 2,804 tests pass.

**Caveat on taste.** Average taste fell 90 → 87. `concreteMagicScore` rewards a
fixed `strangeAgency` verb list — *wanted, refused, remembered, guarded,
waited, asked, followed* — and the retired prose hit it constantly ("The Index
*wanted* a purpose"). The new prose expresses agency through action instead
(*climbed out of its own alphabet*, *turned to face*, *moved on its own*),
which the list does not recognise. The scorer was **deliberately not tuned** to
match: changing a measurement after it disagrees with you is how a bench stops
being an arbiter. Worth revisiting as its own decision.

**Phase 3b — the nine beats, and the lean. SHIPPED 2026-08-16.**

All nine beats now have threads. Added `lack`, `transgression`, `consequence`,
`transformation` and `return`; rewrote `crossing`, which was still doing
paperwork ("the Labyrinth's favourite paperwork, and it has just been filed
under one" → "There is a threshold under it now. I did not put it there and I
cannot lift it"); gave `price`, `donor` and `test` the resolutions they lacked.

Each beat thread speaks about what has **not** happened yet — *"No line has
been crossed around the boxes yet. I keep checking the chalk, which tells you
what I expect."* That is the whole register: the Book leaning toward a beat it
has not witnessed, without ever naming the shape.

**The tale now leans.** `taleMove` prefers a beat thread until one has been
spoken, then falls back to the house pool, so a leaning night is still mostly
the ordinary world. Two bugs found doing it, both of which made the feature
ship inert:

- Gating the lean on `index == 0` meant it only ran on nights with no thread to
  continue, because the continuity serial always takes index 0. Now keyed off
  whether a beat has been spoken this night.
- Move keys carry a `tale:` prefix and continuity marks its stage with a
  trailing `+`/`!`. Comparing raw keys against bare beat names matched nothing,
  so `beatPool` was always empty and the lean did nothing at all.

`fictionMarkers` gained entries for all ten beat keys; without them the
verifier falls back to the key itself, which no beat thread's prose contains,
so every beat continuation would have failed its own check silently.

**New bench night `open-tale-night`.** Every other night in the corpus carries
`openTale == nil`, so the beat threads — the entire point of wiring TaleGrammar
to the braid — were unreachable, unreadable and untested. Two beats witnessed,
the rest open: the ordinary mid-tale state.

Three contract tests pin the behaviour: a running tale reaches the page it was
recognised from; it is **never named** on that page (neither shape nor title);
and a witnessed beat is not offered back.

25 nights, 25 in band, 24 audit-clean. **2,807 tests pass.**

**Phase 2a — the feedback buttons reach the deterministic writer. SHIPPED.**

`BraidTastingRoom.Score.total(guidedBy:)` tilts the total toward whatever
dimension the reader's feedback names, and `BraidGenerationSelector.bestUsable`
now spends it. The dimensions already matched one for one; nothing had ever
been attached to them, so on the default path "I loved this one" trained a
writer that was not writing.

Deliberately a nudge: the bonus is capped at `maximumGuidanceBonus` (12) so
guidance can break a tie or lift a close second and can never rescue a page the
audit is penalising. Inert when there is no feedback — the bench is unchanged.
Three tests: it tilts, an unscored dimension earns nothing, and the cap holds.

**B7 — anchor selection. PARTIALLY SHIPPED, one half reverted.**

Ranking was `preferredWords` first and **document order** for everything else,
which is the whole reason a calorie log anchored a night on "the beers": it
merely appeared first.

*Kept:* a `vagueNouns` demotion — *thing, way, part, place, point, reason,
side, sort, stuff* and friends lose to any noun that names an actual thing.
Not a ban; a day with nothing else may still anchor on one.

*Reverted:* promoting nouns the reader had put a modifier in front of. It
sounded principled and it broke a real guarantee. In the thirty-night
simulation every day says "I mended the {gate|kettle|hallway…} in the back
room" — "back room" is modified and the rotating subject is not, so every night
anchored on "room" and the month collapsed from six distinct closing lines to
**two**. A modifier says the reader distinguished something; it does not say
the sentence is *about* it, and position still carries that better. The test
that asserted the promotion was removed with it.

The remaining weakness is real and unfixed: on a night whose only concrete
nouns are banned (a weekday, a person), the anchor falls back to "the day".
Honest, but bland.

**Phase 4a — the ask. CORE SHIPPED 2026-08-16; UI not yet wired.**

`BraidTaleAsk` in `Shared/TaleGrammar.swift`. Derived at render time from the
vault's `livingTale` rather than stored on the page, because the app already
holds the tale and a braid page carries tags, not metadata.

The question never names the shape or the title, carries the Book's own doubt,
and counts nothing out loud (house law 3):

> More than once now you have written your way toward the same thing. This was
> one of them: «…» Does that keep happening, or am I making a shape out of too
> little?

Every gate is a reason not to speak: never on a night holding shadow; the tale
must be open, at least a week old, and carry at least two lines in the reader's
own hand; once per tale ever; and three weeks' rest between any two asks. It
returns nil far more often than not, which is the point — scarcity is what
makes being asked mean anything.

**A refusal closes the tale** (`ending: .abandoned`) rather than pausing it.
Continuing to lean toward a shape the reader has denied is exactly the
presumption asking exists to avoid. A confirmation is recorded as a witness in
the reader's own hand, which is stronger evidence than the recogniser can score
unaided.

13 tests, including that a reader line containing the Book's own quotation
marks cannot close the quote early.

**Also fixed:** the "Teach me" card had `.borderedProminent` on *"This missed
me"*, so the loudest control on a finished page was the way to reject it. The
prominence moved to "I loved this one".

**Phase 4a UI — SHIPPED.** The ask renders on the kept braid page above the
"Teach me" card, derived from the vault rather than stamped on the page. Both
answers use the same button weight: a "no" that looks like the lesser option is
not a real offer to be wrong. Vault gained `lastTaleAskAt`, `askedTaleIDs` and
`refusedTaleShapes`; the answer is written in one batched `vault.mutate`.

**A refusal bars the shape, not the tale.** Closing the one `LivingTale` was
not enough: after the rest window the same receipts recognise the same shape
again under a fresh id, so the Book would lean on it — and could ask about it —
having already been told it was wrong. `TaleGrammar.tend` now takes
`refusedShapes` and stays quiet on any of them, permanently. A denied tale is
also **not bound**: binding it would hand the reader their own "no" back as a
finished story.

Confirming: *"Then I will keep watching it, and I will not say what it means."*
Refusing: *"Good. I have put it down and I will not pick it up again."*

**B6 — the role stamp. SHIPPED 2026-08-16.**

`rememberingMove` was the only move family with no resting at all. Every other
one records a move key and consults `recentMoveAges` and `braidStyleMemory`;
this one did `options[variant % options.count]` and recorded nothing, so
nothing *could* rest it and consecutive nights printed the role stamp word for
word — "I wrote <name> in the margin where the page number goes. That is whose
this is." — which is what the reader saw in two of three screenshots.

Now every option carries a key, is recorded as `remember:<key>`, and goes
through the same ladder the other families use: rotate, prefer what the prose
memory has not just heard, prefer what is outside the rest window, fall back to
least-recently-used. The role pool went from two lines to four, because a
two-deep pool repeats however good the resting is.

A six-night consecutive test pins it. With the resting removed, all five
consecutive pairs are identical; with it, none are. The one bench night
carrying a role improved: taste 87 → 90.

**The `sliceoflife` token. FIXED 2026-08-16 — and not where B3 above says.**

`BookPage.readerContributions` has always mapped the squashed forms correctly.
The leak was the braid's own route, which humanised a choice tag with
`replacingOccurrences(of: "-", with: " ")` — a no-op on a token containing no
hyphens. That is how `choice:sliceoflife` reached a finished page verbatim.

`BookPage.humanizedChoice` now names the squashed forms (a token that has lost
its word boundaries cannot be recovered by any rule, only named) and handles
camelCase, kebab and snake on top. Three tests, including an end-to-end one
that braids a day carrying `choice:sliceoflife` and asserts no candidate
contains it. The path in `PageModel` was deliberately left alone: it was never
broken, and rewriting working code to match a wrong diagnosis is how a fix
becomes a regression.

Roughly ten other `replacingOccurrences(of: "-", with: " ")` sites remain in
`Shared/` and `InsideCoverApp/`. Those are the character doctrine's Program D
("no slug reaches prose") and are out of scope here.

**Phase 5 — editions compose from beats. SHIPPED 2026-08-16.**

`BoundSpanShape` reads a span into the beats its nights carried, the tales that
opened, and the tales that closed. It needs no new storage: the braid already
names its moves in tags, so this works on braids kept before it existed.

Volumes now open on **What This ⟨span⟩ Was**, the only part of a volume
composed from structure rather than reprinted prose, and the annual foreword
opens the same way — before it counts anything. One builder makes every rung,
so the span word is read off the date range: week, month, season, year.

Three registers, and the quiet one is not the lesser one:

- **quiet** — "Nothing in this month arranged itself into a story, and I am not
  going to invent one. It was a month. You were in it. That is already more
  than most things manage."
- **bound** — the tale is named, because its title came out of the reader's own
  words.
- **running** — reported, never named. Same law as the nightly page, applied at
  the scale where over-claiming would be worst.

A refused tale is never counted as finished. A span with no pages gets no
section: a season with nothing in it is still not a book.

**Also fixed here: the braid could not see kept media.** The writer read
`userInput ?? playerReply ?? promptText`, so a page whose whole content was a
photograph or a voice note counted as a page with no words — scored last, cut
first by the lived-beat allowance, and contributing zero to the scale gate, the
same bug as kept fiction in a second place. `mediaEvidence` (transcript, then
caption — always the reader's own words; the Book still never describes an
image) is routed through the five atom sources, the lived atom **and** the
scale gate. Fixing any subset made it worse: a media page reached the page as a
bare "?", its own prompt printed as prose. PageWright leaves were fine
throughout; they carry typed text.

---

## Phase 5b — scenes, not receipt/reaction forms. SOURCE COMPLETE; TESTS ADDED, NOT RUN.

The rich planner still produced a thin kind of prose because the renderer's
unit of composition was wrong. Every later lived atom opened its own paragraph
and immediately received a `supportingMove`:

> You did this. I put it beside the bakery. You did this. I kept both lines
> open. You did this. I put it after the bakery.

Those sentences were sourced, varied, and often individually charming. Their
sequence was still a filing system. Rewriting the move pool could only make the
clerk prettier because the renderer still called the pool once per receipt.

The renderer now groups later receipts into form-shaped scene movements. Each
sentence keeps its own receipt provenance, so the revision verifier loses
nothing, but the Book does not answer each atom. The per-receipt
`supportingMove` family and its allowance were removed. Rich nights get no
settling filler at all; a one-receipt Glimpse may take one. A night also gets
one Book-world disturbance, rather than borrowing the lived receipt allowance
and growing several unrelated marvels merely to reach the word band.

The grouping is now Story-Form-aware rather than universally paired. Slice of
Life keeps a modest sequence; Mosaic makes adjacent fragments visible;
Portrait lets its details orbit one centre; Drama and Crossing divide pressure
from turn; Vigil holds its material in one sustained movement; Return makes
then and now separate movements; Comedy saves a beat for timing. Receipt order
remains chronological in every form. Story Form therefore changes
deterministic composition as well as the Gemma prompt, residue, and tag.

The one disturbance now carries an explicit scene spine:

1. the disturbance enters;
2. the selected Faerie Pressure establishes the strange law;
3. the Narrative Motion turns the scene;
4. the Story Form decides how the consequence lands;
5. on a Full Braid, the same pressure receives an aftermath instead of clerical
   filler.

On rich nights, receipt nouns may enter one ensemble movement inside that same
impossible room. They enter once as a company, never as a procession of facts
followed by Book reactions. All ordinary-life assertions remain attached to
their receipt sentences; ensemble actions are authored Book-world fiction.

A kept Labyrinth scene now suppresses a *new* unrelated house-fiction opening.
An already-open continuity thread may still return, but the night no longer
grows a fox, a painted door, and a fresh moth or bell at once. When continuity
does open on an ordinary night, its opening thread has a same-night turn and a
form-shaped consequence instead of one decorative strange sentence.

The same law now reaches both Gemma prompt paths and the repair prompt:
receipts are material, not cues for replies; several facts must inhabit one
movement under one faerie pressure; before the ritual ending, the Book may
explicitly handle or keep something at most once. `clericalCadence` audits the
old repeated handling verbs as a weighted craft failure, so a beautiful but
clerical draft pays for the miss and is sent through repair instead of winning
on surface fluency.

The nearby arc, relational-lens, archive-return, and evidence-rhyme lines were
also moved out of mark-and-margin diction. They now report what changed rather
than what the Book did with its stationery.

Regression coverage uses the actual shape that exposed the bug: bakery, atlas,
heron photograph, leek soup, brother's call, rain, and the fox. It requires all
six lived facts to survive, at least two receipt IDs to share a movement, and
no clerical cadence. It also requires the Full Braid to reach its promised word
band and verifies that its kept fiction prevents an unrelated continuity
opening. A separate form regression requires Mosaic and Vigil to assemble the
same receipts differently; a separate audit fixture pins the rejected
three-pair filing pattern.

Full local-model output grew from 560 to 680 tokens so the 450-word upper band
plus title and ritual sentence is physically reachable. `underBand` now carries
a ten-point selection tax instead of six: the emergency floor remains available
when the model fails, but a vivid fragment no longer cheaply beats a complete
scene. Source parsing and whitespace validation passed; tests and builds were
not run in this pass.

## Phase 6 — the curse layer. NOT STARTED, and deliberately.

`docs/thorned-bargain-arc.md` is not a phase. It is a year-long feature with
four acts, and the braid work is not a foundation it is waiting on.

What it actually requires: extending the grey scale past its clamp; an
admissible-evidence detector spanning `PlaceMemory`, `AnchorRegistry`,
photograph cadence, calendar emptiness, archive type-token ratio and
ContextWeave habit-breaks, with two-source corroboration against the reader's
own sworn lines; a refusable bargain whose refusal is permanent; real-world
challenges with deadlines and irreversible prices; a visible Ledger of the
Thorn; five talismans whose loss **removes real capabilities** — one of them
switches off braids entirely; Cast withdrawal; progressive degradation of the
Book's own voice; an Act III with no exit by design; and an Act IV that scores
the entire archive retroactively as banked mercy.

Half-building that is worse than not starting. The talisman losses disable
working features, the grey scale is the difference between a faerie tale and a
streak counter, and Act III is explicitly required to have no path out — none
of which can be safely left in a partial state in a shipping app six weeks
before launch.

It should be planned and built on its own, against its own document.

**Phase 4 — wire TaleGrammar into the braid.** Both paths, deterministic
first — it is the default. The braid records its beat and receipt into the
residue. Attention leans; nothing is named until a tale binds.

**Phase 4a — the ask.** The confirm/refuse question on leaning nights,
rate-limited hard.

**Phase 5 — editions compose from beats.**

**Phase 6 — the curse layer.** Year-arc descent and turn, per
`docs/thorned-bargain-arc.md`.

---

## Risks

**The file.** 25,559 lines holding the deterministic writer, prompt builder,
audit, verifier, tasting room and residue. Phases 3–4 will be painful in it. A
split is warranted but is its own job and should not be bundled into these
phases.

**Over-claiming.** The moment the Book says *"you are in a Forbidden Door
story"*, it does the thing `TaleGrammar`'s own comment forbids: *"a wrong shape
is worse than no shape, because it would make the Book a thing that tells you
what your life meant."* The discipline is that the reader sees attention, and
sees a name only when a tale binds, in their words. Get this wrong and the
whole feature reads as horoscope.

**The recogniser's floors are untuned for this use.** `minimumWitnesses = 4`
and `minimumDistinctDays = 3` were set for a surface that binds tales rarely.
Driving nightly attention off the same thresholds may fire far more often than
intended. Measure before trusting.

**Bench churn.** Phase 0 changes scale selection, so nearly every golden night
moves at once. Re-record deliberately and read the diff rather than accepting
it — the bench is the arbiter and this is the one change that can silently
recalibrate it.
