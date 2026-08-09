# The Literary Compiler

Turning `DeterministicBraidwright` from an honest house cut into the writer that
authors the nightly braid — with Gemma demoted from rival to reviser.

Status: planned 2026-08-03. **All six phases are built and wired** as of
2026-08-04.

Bench baseline before final-prose recurrence memory:

```
23 nights · 14 in band · 22 audit-clean · average taste 78 · 6 repeated openings
9 of 23 nights fall short of their band; worst gap 26 words.
```

The nine short nights are thin days — one or two kept sentences — where the
material genuinely is not there and padding would be worse. The bench reports
the gap rather than hiding it.

---

## North star

One page per night, authored by a compiler that cannot hallucinate and cannot
forget, then given its music by a language model that is not allowed to change
a single fact.

**Decisions taken (2026-08-03):**

- **Cooperative, not competitive.** The compiler writes the page. Gemma revises
  it under per-sentence verification. This supersedes the earlier "keep the
  ensemble as two rivals" decision — though free-Gemma stays in the tasting
  room as a third entrant until the bench proves cooperation wins.
- **Cross-night memory lives in the archive database.** Not `PlayerVault` —
  every vault write rebuilds the whole desk. *(Built as tags on the kept braid
  pages rather than a new table; see Phase 6 for why.)*
- **Length varies by night**, adopting the band already stated in
  `BraidScale.promptLine` — the same spec Gemma is held to.

## The honest theory of advantage

A deterministic compiler will never beat a language model at inventing a fresh
sentence, and it should not try. It wins where a small local model structurally
cannot compete:

| Axis | Why the compiler wins |
|---|---|
| **Fidelity** | It cannot hallucinate. Every noun on the page came off a Page. |
| **Consistency** | No bad-draft nights, no temperature lottery, no reload stall. |
| **Long memory** | Gemma sees one night through a prompt already at 21k chars and clipping. The compiler can see every page the reader ever wrote. |
| **Structural control** | Exact rhythm, exact length band, guaranteed non-repetition across nights. |
| **Cost** | Instant, and it does not hold Gemma's weights resident — the jetsam risk. |

And a language model will always beat a template bank at sentence-level idiom,
cadence, and surprise. So: **the compiler owns structure, evidence and memory;
the model owns music.** Neither is asked to do the other's job.

## The architecture

```
  receipts ─→ COMPILER ─→ page + provenance map ─→ shippable, always
                              │
                              ├─ (if the brain is warm)
                              ▼
                         GEMMA revision pass  ── one call, whole page
                              │
                              ▼
                     PER-SENTENCE VERIFIER
                    accept ─┤          ├─ reject → compiler's original
                              ▼
                        tasting room ─→ kept page
```

Three properties make this work:

1. **The compiler's page is always complete.** Revision is an upgrade, never a
   dependency. Worst case — cold brain, failed call, every sentence rejected —
   the reader gets the page they would have got anyway.
2. **The page carries a provenance map.** The compiler does not merely emit
   text; it emits text plus a sentence-level map of where each sentence's
   authority comes from. This is the source map of the literary compiler, and
   it is what makes safe revision possible at all.
3. **Verification is per sentence, not per page.** A page-level accept/reject
   throws away good work; a sentence-level one keeps every revision that earned
   its place.

### Provenance and license

| Provenance | What it is | Revision license |
|---|---|---|
| `.receipt(pageID)` | Carries the reader's own facts | **Strict.** May add no content word. Must retain every noun, proper noun and numeral. Function words free. |
| `.authored` | The Book's own voice — bites, moves, settling beats | **Free vocabulary**, subject to the register audit. The Book may say anything about itself. |
| `.colophon` | The ritual closing line | **Locked.** Never revised. |

This is the load-bearing distinction. Invention about the Book is voice;
invention about the reader's life is a lie. The compiler already knows which is
which as it builds the page — it just has to say so.

## Where we start

Post-bug-fix baseline on the standard fixture night:

- 16 distinct candidates, all audit-clean, 139–153 words, tasting 81–88
- Reads: `[reader's sentence, verbatim, pronoun-swapped] + [canned move]`,
  repeated, then a canned colophon
- Consumes 4 of the 25+ fields on `BraidPromptBuilder.Context`

The sharpest gap: **the compiler ignores most of the context it is scored
against.** `priorEchoScore`, `themeAndChapterScore` and `souvenirSpineScore` are
three of nine tasting components, and it forfeits all three by construction.

A second gap worth naming: today's audit checks register and coarse score
drift, but nothing checks *"did you invent a noun."* A Gemma page can currently
win the tasting room carrying specifics that came from nowhere. The verifier
closes that hole.

---

## Phase 0 — Measurement and the length contract

Nothing after this is meaningful without it; "beats Gemma" is otherwise
unfalsifiable.

1. **`BraidScale.targetWordBand`** — glimpse 100–180, small 180–300, full
   280–450. `promptLine` derives its numbers from the band so they cannot
   drift, and the compiler aims at the band rather than the audit floor.
   *The audit floor stays deliberately lower and separate:* the band is what a
   good page aims at, the floor is what makes a page not a braid at all.
   Raising the floor to the band would newly fail large numbers of Gemma
   drafts, which is a different decision from this one.
2. **`BraidBench`** — ~20 fixture nights spanning the real spread: one-receipt
   glimpse, labyrinth-only, shadow/plain, multi-beat full braid, arc, relational
   lens, souvenir anchor, Cast member, grief day, matched subjects, adversarial
   reader prose.
3. Per night: tasting score **by component**, audit issues, word count,
   paragraph contour, and the full text.
4. **Golden output file**, re-recordable via `BRAID_BENCH_RECORD=1`, so prose
   regressions arrive as a reviewable diff rather than a number.
5. A seam for model drafts, so the app target can feed Gemma pages through the
   same reporting code.

**Acceptance:** one command prints the per-night table and writes the golden
file; every night lands inside its band.

### Measured baseline (2026-08-03)

`swift test --filter BraidBenchTests` over the 20-night corpus:

```
20 nights · 10 in band · 17 audit-clean · average taste 78
10 of 20 nights fall short of their band; worst gap 61 words.
```

The gap is worst exactly where it should worry us: `full-braid`, the heaviest
night, is 61 words under a 280-word floor. The compiler emits one paragraph per
beat with one canned move and has no way to expand, so it scales *down* as the
day gets richer. Phases 2–5 are aimed at that number.

Two audit findings the first run surfaced, both since fixed, and both cases of
the audit or the compiler being wrong rather than the prose:

- `supportingLogsTookOver` fired on a diary entry *about the rain*. The check
  counted weather words lexically, so a reader writing about their own weather
  convicted the page. It now only counts weather words the page could not have
  got from a story receipt.
- `missingTruthAnchor` fired because the compiler picked a different supporting
  log than the reading had anchored on. One anchor owns the prose; the compiler
  now honours the supplied one.

A third, found while reading the output: `relationalMove` emitted "When the rain
sets in for the afternoon." as a standalone sentence. A condition opening with a
subordinator now keeps the clause it governs.

The bench earned its keep on the first run: it surfaced a pervasive defect where
the compiler enchanted the *modifier* of a compound noun rather than its head —
"the brass" for a brass lamp, "the yellow" for a yellow bowl, "the corner" for a
corner shop, "the tomato" for tomato soup. Fixed by walking to the compound
head; the golden diff shows six nights improving and nothing regressing.

## Phase 1 — Provenance and the verifier

Moved to the front, because the verifier now guards two things at once: the
compiler's own transforms *and* Gemma's revisions.

1. **Provenance map** — `render` tags each emitted sentence `.receipt(pageID)`,
   `.authored`, or `.colophon`, carried alongside the page.
2. **`BraidRevisionVerifier`** — aligns a revised page against the original by
   sentence, applies the license table above, and returns an accepted page plus
   a per-sentence decision log.
3. **`voiceRevisionPrompt`** — sibling of the existing `qualityRepairPrompt`.
   One call, whole page, "keep every fact, change the music."
4. Wire into `MLXBookBraider` alongside the existing repair path.

**Acceptance:** on an adversarial corpus, zero verification escapes — no
accepted sentence adds a content word to a `.receipt` line or drops one of its
nouns. Revised pages only ship when the tasting room scores them **higher**
than the compiler's original, so blandness loses.

### Built (2026-08-03)

- `BraidSentence` / `BraidComposition` in `Shared/LiteraryContinuity.swift`.
  `DeterministicBraidwright.composition(for:context:)` is now the way in;
  `page(for:context:)` is a thin wrapper over it.
- `BraidRevisionVerifier` with the licence table, per-paragraph alignment
  (shape drift rejects that paragraph rather than guessing), inflection-aware
  word matching, and the tasting-room gate.
- `BraidPromptBuilder.voiceRevisionPrompt` — hands the model the numbered page
  with each sentence's licence inline.
- Wired into `MLXBookBraider`: the house writer composes, one revision call
  goes out, the verifier accepts per sentence, and free-form Gemma stays in the
  tasting room as a third entrant. A cold or failing brain costs nothing — the
  composed page was always complete.
- The sentence polisher is now skipped for composed pages. It works by deleting
  whole sentences, which is safe on a free-form draft and destructive on a page
  whose every sentence was signed off against a specific receipt.

One rule worth remembering: **the bench asserts that the house writer passes its
own verifier.** If a sentence the compiler wrote cannot survive the rules we
hold the model to, the rules are wrong, not the sentence.

## Phase 2 — Syntactic transformation

The compiler's offline quality floor. Today the reader's sentence is pasted
with pronouns flipped, which is what makes the page read like a template when
the brain is cold.

A shallow chunker over `NLTagger` lexical classes (NP/VP/PP boundaries — no
dependency parse needed) and a transform bank:

| Transform | "I tightened the loose screw on the blue kitchen chair." |
|---|---|
| identity | You tightened the loose screw on the blue kitchen chair. |
| fronting | On the blue kitchen chair, you tightened the loose screw. |
| cleft | It was the loose screw you went after. |
| fragment | The loose screw. Tightened. |
| nominalize | One loose screw, tightened. |
| subordinate | Before you called Sam, you tightened the loose screw. |

Every transform is *attempted, then verified* by the Phase 1 verifier — same
machinery, same license. A transform either type-checks or it does not fire.

**Acceptance:** ≥60% of lived sentences take a non-identity form; zero
verification escapes; golden diff read by hand.

### Built (2026-08-04)

`BraidProseTransform` with four transforms — identity, `frontedPhrase`,
`cleft`, `splitAtConjunction` — each attempted then gated by
`BraidRevisionVerifier.preservesFacts`. Transforms became a fourth candidate
axis, so the tasting room chooses among rearrangements rather than the compiler
committing to one.

Two bugs the bench caught immediately, both the same class of error — a
transform producing *confident nonsense*:

- Fronting hoisted phrases that belong to a noun, not the clause: "You found
  the spare keys under the seat of the car" became "Of the car, you found the
  spare keys under the seat". Fixed with a whitelist of adjunct prepositions.
- The cleft swallowed temporal adjuncts into the object: "It was the blue door
  before breakfast that you painted". Fixed by cutting the object at a temporal
  preposition and reattaching the coda after the verb.

Also fixed here: the on-device tagger reads "You swam" as a pronoun followed by
a *noun*, so the page was enchanting "the swam". A word directly after a bare
subject pronoun is the verb whatever the tagger calls it.

## Phase 3 — Prosody

Structure is what reads as authorship; lexical variety over a fixed shape reads
as a template within a week.

- Deliberate sentence-length contour (a short sentence after two long ones
  lands; three mediums in a row is prose sludge).
- No two consecutive sentences may open with the same word — today most of the
  page opens with "I".
- Paragraph and word count aim at `targetWordBand`.
- Settling beats placed for rhythm, not appended blindly.

### Built (2026-08-04)

`BraidComposition.Prosody` counts adjacent repeated openings and the longest
run of same-length sentences, and breaks ties between candidates the tasting
room already rates equally. Two authored pools gained non-"I" openings — the
settling beats, and a second phrasing for every crossing law, because both
halves of a crossing naturally open on their subject and put two "The …"
sentences side by side in the page's most important paragraph.

Repeated openings across the corpus: 6 in 22 nights, down from a page whose
every authored sentence began "I".

## Phase 4 — Spend the whole context

Directly recovers three forfeited tasting components.

- **Souvenir anchor** in the opening *and* echoed in the colophon —
  `souvenirSpineScore` rewards exactly this and currently returns 0.
- **One theme motif**, once, below the level of announcement.
- **Reader role and epithet** — the Book named this reader on night one and has
  never once used the name in a braid.
- **Standing tale laws** and `roleTransformationClause` — the reason a bound
  tale keeps mattering is that the Book writes differently afterwards.
- **Open tale** colours what the compiler reaches for without naming it.

### Built (2026-08-04)

- The souvenir anchor is promoted to the **primary lived atom**, so the
  reader's own chosen line sets the magic subject and therefore owns the title,
  the voice and the colophon together. One change, three tasting components.
- `rememberingMove` — one beat per page, in its own paragraph, spending the
  reader's role, a theme motif, a standing tale law, or the role
  transformation clause. It reads as the Book looking up from the page rather
  than as another detail of the day.
- Suppressed entirely on uncleared-shadow nights. That is not the moment to
  show how much the Book has been noticing.

Still unspent: `recentBraids` (the echo scorer explicitly allows silence, so
forcing one would be worse), `openTale`, and `chapter`.

## Phase 5 — The archive corpus

The phase Gemma cannot follow, and the reason cooperation beats competition:
this sentence now survives into the final page instead of losing a coin flip.

An index over the whole archive, off-main via `detachedDatabase()`, cached:
every content noun with first- and last-seen dates, what the reader wrote the
last time each appeared, co-occurrence with season, weather and hour
(`ContextWeave` already computes much of this).

> You wrote about the blue chair in March. It was a different chair then.

One callback per page, real two-sided evidence only, never significance
manufactured from a single prior mention.

**Acceptance:** callbacks on ≥30% of nights for an archive older than 60 days,
each citing a real prior page ID.

### Built (2026-08-04)

`BraidPromptBuilder.Context.subjectHistory` — built in the context builder from
the weavable archive (capped at 400 prior days), counting **days not mentions**,
because a word written six times in one evening is one occasion of caring about
it and calling that six would be a lie.

`archiveEchoMove` then writes the sentence the model cannot:

> That is the seventh time I have kept the river. The first was in May.

Two rules keep it honest. It reports on the Book's **own keeping**, never
re-narrating what the reader wrote months ago — an old quotation would also slip
past the register audit, which only strips quotes matching *tonight's* receipts.
And significance has to be earned on both axes: at least three prior occasions
**and** at least 21 days of distance. One prior mention is a coincidence; a
subject last seen yesterday needs no announcing.

Suppressed entirely on uncleared-shadow nights.

## Phase 6 — Cross-night memory

**Acceptance:** across 30 consecutive simulated nights, the Book never closes
two nights running the same way.

### Authored move rest built (2026-08-04) — and a deviation worth knowing about

The plan called for a new archive table at `schemaVersion` 8. It is instead
recorded as **`braid-move:` tags on the kept braid page**, which already
persists in the archive database.

This keeps the intent of the decision — durable, in the archive, queryable by
date, no `PlayerVault` churn — while avoiding a migration that would collide
with the in-flight Daybook work holding version 7. It also buys a property a
parallel table would not have had for free: a braid the reader removes stops
constraining tonight, because the ledger *is* the pages.

`BraidPromptBuilder.recentMoveAges(before:in:)` reads those tags off the last
ten nights. Two design notes:

- It stores **ages, not a set**. A plain "already rested" set can only say "all
  options are spent" and then falls back to whichever sorts first — so on a
  month of near-identical days the Book closed every single evening the same
  way. With ages, the fallback is the option used longest ago, and a two-deep
  pool alternates instead of sticking.
- `keeperLine` no longer discards its `variant`. Each faerie pressure now has
  two closing phrasings rather than one, on the most-read line of the page.

The 30-night test runs a month of near-identical evenings — the hardest case,
where the pressure never changes and the pool is only as deep as that pressure
— feeding each night's kept braid back into the next night's context.

### Final-prose performance memory added (2026-08-06)

The move ledger prevents the deterministic writer from selecting the same
labelled closing move too soon. It cannot know what the reader actually saw
after revision, and it covers only moves the compiler happened to tag. That
left a larger machine visible across nights: the same suspicion, the same Index
objection, the same sentence pair, or the same paragraph turn with a different
ordinary noun tucked into it.

`BraidStyleMemory` therefore reads the **final prose on kept Book of You Pages**
from the last fourteen braid nights. It remembers five kinds of recurrence:

- exact sentences;
- sentence shapes with changing lived nouns replaced by `[thing]`;
- opening shapes;
- ending shapes; and
- adjacent sentence transitions inside a paragraph.

Only structural fingerprints enter the model prompt; an old lived noun is not
carried forward as material. The full and compact generation prompts and the
voice-revision prompt tell the writer to rest those performances. The same
memory supplies a bounded craft penalty in `BraidTastingRoom`, so an honest
fresh candidate beats an honest repeated one. It is not a register rejection:
truth, provenance, and the only faithful telling of a thin night still outrank
novelty.

Like the move ledger, this is derived from the kept archive rather than a new
table. Removing or sealing the Page removes its influence, and accepted Gemma
revisions are remembered instead of the compiler draft they replaced.

### Retired: clause banks

An earlier draft of this plan proposed expanding the authored inventory from
~130 sentences to ~1,000 via combinatorial clause banks. The revision pass
solves that problem properly, so the slog is unnecessary. The inventory should
still grow opportunistically, but it is no longer a phase.

---

## Invariants — never break these

The current design gets these right. Every phase must preserve them and the
bench must assert them.

1. **`Proof`** — receipts stay a subset of eligible pages; the page is capped at
   one licensed impossible relation; a stale score whose receipt was sealed
   keeps failing closed.
2. **The register audit is absolute.** `exposedRealitySeam`,
   `bookSpokeFromOutside`, `servantVoice` and the four shadow failures never
   enter selection. Craft misses stay a bounded tax.
3. **Shadow law.** Uncleared shadow means no magic, no fiction, no arc, no lens
   — verbatim quotation and a plain colophon. Shadow receipts are never revised.
4. **No invention about the reader's life.** Every external claim traces to a
   lived receipt. Transformation and revision rearrange supplied words; they
   never add one.
5. **The floor is deterministic.** The compiler's page is byte-identical for a
   given day and context. The revised page is not, and cannot be — same as
   today's Gemma path, so not a regression, but the guarantee is now explicitly
   about the floor.

## Risks

- **Bland paraphrase.** Small models asked to preserve all facts tend to sand
  down deliberate weirdness — "I stole the line before it cooled" becoming
  competent mush. Mitigation: only accept revisions the tasting room scores
  higher.
- **Latency.** One call for the whole page, verified by alignment. Never N calls
  per sentence.
- **Goodharting our own scorer.** The tasting room is ours; optimizing against
  it alone is a trap. The golden file and periodic hand-reading are the check.
- **Concurrent work.** The Daybook feature is in flight in the same files and
  took `schemaVersion` 7.
