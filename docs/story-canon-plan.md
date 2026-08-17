# Story Pages: carry the canon, not the paragraph

The reader's report: *"it isn't accepting first longer generations, and is
falling back to a second shorter one — when we go into the second round, it has
nothing to do with the first round, like it doesn't narratively continue in a
logical manner."*

Four causes. Two are fixed. Two are this plan.

## What was wrong

**1. The better draft was thrown away.** *(fixed, `356d4e0`)* When neither
attempt cleared the rail, `result = acceptable(retry) ? retry : landed(retry)`
kept the **second** draft and bolted the landing onto it. A long, nearly-right
beat lost to a short, equally-wrong one purely for arriving second.

**2. The retry was a blind re-roll.** *(fixed, `356d4e0`)* The outer rail
answered a rejection by calling the writer again with an identical context — a
second sample of the same request, with no reason to fix what broke and no
reason to resemble the beat the reader was about to read. The writer already had
a correction channel for its own inner repair pass and the outer rail was not
using it. Worst case: four model calls per beat, in two unrelated pairs.

**3. Canon is precommitted and then dropped.** `StoryDramaticChoiceEffect`
carries `changedFact`, labelled in the prompt as *"Changed fact that becomes
canon."* The result prompt demands it. The validator checks it. Then the
dramatic contract, which belongs to the **draft**, is replaced when a
continuation builds a fresh draft — and the previous turn's changed fact never
reaches the next prompt. Canon is not canon. **This is the main cause of the
reader's complaint.**

**4. Continuity travels as clipped prose.** The continuation prompt carries
`bookPreviewSentenceLimit(4)` of the latest scene and `(3)` of its result;
earlier turns get one sentence each. That compression is deliberate — the code
says so:

> Prior turns arrive COMPRESSED: the model never sees full earlier prose,
> because whatever it sees, it echoes.

Which is true, and it is the trap. Show prose and the model parrots it; clip
prose and the story loses its own history. **Both branches lose because prose is
the wrong currency.** Facts cannot be echoed as prose, so a ledger of facts can
be shown in full without teaching the model to repeat sentences.

## The shape

A vignette is small: `StoryVignetteBeats.maximumInteractiveTurns == 2`, so an
opening scene and at most two resolved turns. A ledger holds at most two entries.
This is not a large build.

The raw material already exists per turn and is simply never accumulated:

```
StoryDramaticChoiceEffect
  requiredReactorName    who moved
  requiredReaction       what they visibly did
  readerChoiceEffect     what the reader's choice changed
  changedFact            the canon
  memorySummary          the one-line memory
  warmth/tension/familiarityDelta
```

## Phases

**Phase 0 — the ledger.** `StoryCanonLedger` in `Shared/`: accumulate the
resolved effect of each completed turn into established facts, who reacted and
how, what the reader's choices have changed, and the running warmth/tension/
familiarity. Pure and testable, no UI. Includes a *spent images* list (nouns and
phrases already used) so the anti-echo contract can be stated from data rather
than by starving the model of context.

**Phase 1 — feed it forward.** The continuation prompt and the result prompt
both receive the ledger as facts. Clipped prose stays for voice and last visible
state, but it stops being the only carrier of what happened. The prompt can then
say *"these are already true, do not re-establish them"* instead of hoping four
sentences imply it.

**Phase 2 — verify against canon.** A beat that contradicts an established fact
is rejected with a correction naming the contradiction, through the channel
Phase 2 of the retry fix opened. This is the braid's law applied one level in: a
story page may invent freely inside the fiction, and may not contradict what the
reader has already been shown.

**Phase 3 — fix the budget honestly.** `maxTokens: 280` against a prompt asking
90–150 words in 5–8 sentences is tight, and a beat truncated before its landing
fails `asserts` for lacking an ending it was never allowed to write. Detect a
truncated draft (stopped without terminal punctuation) and treat it as a
*budget* failure rather than a content failure, then raise the cap. bj on the
280: *"a desperate attempt to make the model behave"* — so raise it only once
the rail is honest, and watch what happens.

**Phase 4 — persist the leaf.** Stamp the ledger onto the kept page, the way a
braid night now leaves `braid-plan-*`. A later Story Page on the same thread can
then continue from established canon instead of starting over. Deferred until
Phases 0–3 have met a real week.

## Raising the ceiling

Phases 0–4 remove *reasons the prose is bad*. That raises the floor and leaves
the ceiling where it was, because every rail was negative — no atmosphere, no
echo, no invention, no contradiction — and negative rails asymptote at "not
bad". A beat cleared the gate by not failing, so a merely adequate paragraph and
a genuinely good one were indistinguishable to the machine.

**Phase 5 — `asserts` demands the landing, not a vocabulary.** One word from a
forty-verb list, anywhere in the passage, used to pass the whole check: a beat
could contain "admits" while admitting nothing. It now requires the landing's
own content on the page, stem-matched and scaled to what the landing can afford.

Two flaws surfaced while building it, both of which had been quietly setting the
ceiling:

- The landing's words were filtered by *length* (≥5 characters), which discarded
  "key", "door", "cup" — the short concrete nouns a landing is usually about —
  and kept whatever happened to be polysyllabic. Now content words.
- `changeVerbs` is a list of **telling** verbs (admits, confesses, realizes), so
  a beat that enacted its landing physically — *"she put the second key on the
  table and left her hand on it"* — contained none of them and failed, while a
  slack beat announcing *"she realized that trust mattered"* passed on one word.
  **The rail was rewarding the worse habit.** Carrying most of the landing's
  substance now counts as enacting it, whatever verbs it used.

**Phase 6 — taste, not just rails.** `StoryBeatTaste` scores what a beat can
*earn*: landing enacted, promise paid off, an object doing something of its own,
dialogue where the recipe wanted it, both people on the page, staying concrete —
against hedging, banned abstractions, assistant voice, and an ending that
explains itself. It is a comparator, never a gate: the rails still decide what
may ship.

**Phase 7 — an ensemble with a fast path.** The nightly braid has always chosen
between candidates; Story Pages generated one and checked it against a floor.
A second telling is now requested when the first is unacceptable *or* merely
adequate, and the better of the two wins. An already-good beat still costs one
call, which matters on-device.

**Phase 8 — the promise is checked.** `promiseSeed` was handed to the writer —
*"plant now, pay off at the end"* — and verified by nobody, which is exactly how
a vignette ends up evocative and hollow. The closing beat now earns points for
returning it, and only the closing beat: holding a seed open is what a seed is
for.

## Rules this inherits

- **Detected, never inferred.** A fact enters the ledger because a turn resolved
  and committed it, never because prose seemed to imply it.
- **A marker, never the material**, where the reader's own life is involved. A
  Story Page is fiction, so its canon is quotable — but anything sourced from the
  reader's archive follows the braid's rule and travels as an id.
- **Keep the better draft, never merely the later one.**
- **Say what broke.** Every rejection produces a correction naming the failure.
