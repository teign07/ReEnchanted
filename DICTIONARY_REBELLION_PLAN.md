# The Dictionary Rebellion — Implementation Plan

*Launch season for ReEnchanted (target: Sept 2026). Self-contained, comedic, teaches the system
stack, and secretly seeds the Feb 2027 "Thorned Bargain" year-arc.*

**North star:** You don't *read* a story about a dictionary rebellion. You become the lexicographer
the runaway words come to — and your rulings permanently rewrite what words mean **in your book.**
By winter, the Book speaks your dialect.

---

## 0. Current state (READ FIRST — much is already built)

The **atmospheric layer exists and works.** Do not rebuild it.

| Already built | Where |
|---|---|
| `dictionaryRebellion` `WorldEvent` — calendar, 3 phases (`peel` → `assembly` → `afterimage`), lexical rules, 4 outcomes, effects, full `EventInfluencePacket` | `Shared/WorldEvents.swift:320–437` |
| Registered as a bundled, free pack | `WorldEventRegistry.bundledPacks` (`Shared/WorldEvents.swift:265`) |
| Resolver + phase progression + outcome tiers | `WorldEventResolver` (`Shared/WorldEvents.swift:523–617`) |
| **Touch counting** — a "touch" = a kept page tagged `event:dictionary-rebellion`; kind inferred from page type | `WorldEventResolver.playerTouches` (`Shared/WorldEvents.swift:619–660`) |
| Packet → surfaces: `bleedInstruction` → The Bleed (`TheBleed.swift:92`), `widgetWhisperLine` → widget (`ReEnchantedWidgetSnapshotWriter.swift:192`, `ContentView.swift:3629`), `bookOfYouInstruction` → braid (`LocalBrainServices.swift:268`) | — |
| `fieldworkPrompt/Placeholder/RewardLine` on the packet (the "give an ordinary word a better definition" loop) | `Shared/WorldEvents.swift:433–435` |

**Current outcomes are an *engagement-depth* ladder** (`unwitnessed` → `witnessed` → `lexical-ally` →
`definition-binder`, gated by `minimumTouchCount`). They measure *how much* the player engaged, **not
*which way* they ruled.** The moonshot adds a separate **directional** axis (the Treaty).

### What is NOT built (this plan's scope)
1. **The Reader's Lexicon** — a persistent personal word collection that grows from play and feeds generation. (`grep readerLexicon` → nothing.)
2. **The Rebellion Page (Word Negotiation)** — the interactive heart: meet a runaway word, rule on it. (`grep RebellionPage` → nothing.) Today the season is atmosphere + a fieldwork text prompt only.
3. **The Treaty** — a directional, player-authored ending (Restoration / Reformation / Secession).
4. **The Bargain seed** — the one "abducted" word that does not come back.
5. **`radioInstruction` wiring** — authored on the packet but not consumed anywhere (the only unwired packet field).

---

## 1. Architecture at a glance

```
            ┌──────────────────────────────────────────────┐
            │  dictionaryRebellion WorldEvent  (EXISTS)    │
            │  phases · packet · touch-tier outcomes       │
            └───────────────┬──────────────────────────────┘
                            │ active? phase? (WorldEventResolver)
          ┌─────────────────┼───────────────────────────────┐
          ▼                 ▼                                ▼
   RebellionPage      Surfaces (Bleed/Radio/         Compass fieldwork
   (NEW, interactive) Letters/Weather/Widget)        "recruit a word" (STRETCH)
          │  player rules (Recall/Pardon/Adopt/Free)        │
          ▼                                                 ▼
   ┌─────────────────────────────────────────────────────────┐
   │  ReaderLexicon (NEW, persisted in InsideCoverState)      │
   │  entries[] + treaty + bargainSeedFlag                    │
   │  .asSentencePack() ──► SentenceBuilder (real, today)     │
   └─────────────────────────┬───────────────────────────────┘
                             ▼
                  Treaty (NEW) ──► Monthly Edition line
                             └───► flag read by Thorned Bargain (Feb)
```

---

## 2. System 1 — The Reader's Lexicon (foundation)

The persistent artifact. **The non-negotiable moonshot kernel: it persists and alters future prose.**

### Data model
Recommended home: **append to `Shared/SentenceBuilder.swift`** (it already owns `SentenceBuilderPack`,
so no new file = no pbxproj/Package.swift dance — see §8). If you prefer a new `Shared/ReaderLexicon.swift`,
you MUST register it in both the Xcode `.pbxproj` and `Package.swift`.

```swift
enum WordRuling: String, Codable, Equatable { case recalled, pardoned, adopted, freed }
enum LexiconOrigin: String, Codable, Equatable { case rebellion, compassRecruit, seeded }
// Maps each entry onto a SentenceBuilderPack list so prose can use it.
enum LexiconCategory: String, Codable, Equatable { case concrete, sensory, animateVerb, crossing, theme }

struct LexiconEntry: Codable, Equatable, Identifiable {
    var id: String            // lowercased word = stable id (one ruling per word)
    var word: String
    var originalSense: String
    var newSense: String?     // player-influenced meaning; nil when .recalled
    var ruling: WordRuling
    var category: LexiconCategory
    var origin: LexiconOrigin
    var ledAt: Date
    var sourcePageID: String?
}

struct ReaderLexicon: Codable, Equatable {
    var entries: [LexiconEntry] = []
    var treaty: TreatyOutcome? = nil          // §4
    var bargainSeedSurfaced: Bool = false     // §5
}
```

### Persistence
Add `var readerLexicon: ReaderLexicon = ReaderLexicon()` to **`InsideCoverState`** (the Codable reader
state root). Additive + defaulted ⇒ **forward/backward-save-safe**, no migration code needed. Loaded/saved
by `InsideCoverStore` with the rest of state.

### The generation hook (this is what makes it "moonshot," not a list)
`ReaderLexicon.asSentencePack() -> SentenceBuilderPack`:
- id `"reader.lexicon"`, `availability "personal"`.
- Distribute entries into `concreteWords` / `sensoryWords` / `animateVerbs` / `crossingWords` / `themes`
  by `category`. Include only `.pardoned` / `.adopted` entries (a recalled word went home unchanged).
- For `.adopted` entries, also emit a `LexicalTheme` so the word becomes a recurring **anchor/motif**.

Inject this pack wherever SentenceBuilder assembles its active packs (alongside `SentenceBuilderPack.core`
+ `userPacks`). **MVP scope = SentenceBuilder only** (immediate, real, low-risk). Broad prose
(`LiteraryContinuity` etc.) consuming the Lexicon is a stretch (§7).

**Open question for Codex (Q1):** inject the derived pack in-memory at pack-assembly time (recommended,
clean) vs. serialize it to a `*.sentencepack.json` in Documents so the existing file loader picks it up
(reuses plumbing, but mixes a runtime artifact into the user-import folder).

---

## 3. System 2 — The Rebellion Page (Word Negotiation)

The interactive heart. A runaway word presents a grievance; the player rules with four verbs.

### Content model
Authored list (bundle ~16–20 words for the season; live beside the event or in a sibling registry):
```swift
struct RebellionWord: Codable, Equatable, Identifiable {
    var id: String
    var word: String
    var grievance: String          // in-voice complaint, e.g. "I've meant 'cold' for 4,000 years…"
    var originalSense: String
    var pardonedSense: String      // meaning if Pardoned (authored — deterministic)
    var adoptedSenseTemplate: String // meaning if Adopted (personal/motif)
    var category: LexiconCategory
    var phaseID: String            // "peel" | "assembly" | "afterimage"
    var isAbducted: Bool = false   // §5 — cannot be ruled normally
}
```

### Surfacing
- **Page type:** add `case rebellionPage` to `BookPageType` (`Shared/PageModel.swift:4`). NOTE: this is an
  exhaustive enum — update every switch (title, shortTitle, icon `sfSymbol`, any analytics map). Grep
  `BookPageType.allCases` and each `switch`-over to find them.
  - **Open question for Codex (Q2):** dedicated `rebellionPage` type vs. reuse the `pactVerdict`
    choice-page pattern (`InsideCoverStore.swift:1672`). Recommend dedicated type — the negotiation is
    novel and wants its own visual, and pactVerdict semantics differ.
- **Adapter:** `RebellionPageSourceAdapter: BookPageSourceAdapter` (model on `WorldEventPageSourceAdapter`,
  `Shared/SourceAdapters.swift:5516`). Surfaces only when `inputs.activeWorldEvents` contains
  `dictionary-rebellion`. Pick a not-yet-ruled `RebellionWord` matching the current `phase.id`,
  **deterministically** (seed by day + already-ruled set). When all phase words are ruled, fall through.

### The ruling (the load-bearing wiring)
Player picks a `WordRuling`. On keep, the page carries metadata:
`rebellionWordID`, `rebellionRuling`, and (for Adopt/Pardon) the resulting `newSense`. In `InsideCoverStore`
(where kept pages/choices are processed — same place pact pages resolve), on a kept `rebellionPage`:
1. **Append a `LexiconEntry`** to `state.readerLexicon` (skip if `ruling == .recalled` for pack purposes,
   but still record the entry for the Treaty tally + history).
2. **Record exactly one event touch**: ensure the page is tagged `event:dictionary-rebellion` so
   `WorldEventResolver.playerTouches` counts it. Add a touch kind `case wordRuled` to
   `WorldEventTouchKind` (`Shared/WorldEvents.swift:165`) mapping to `.keptRelatedPage`, and infer it via a
   `event-word-ruled` page tag in `touchKind(for:event:)`.
3. **Advance the Treaty tally** (§4) — derivable from `readerLexicon.entries`, so no separate counter needed.

### Determinism / AI
`pardonedSense` and the Adopt template are **authored** ⇒ fully deterministic, no model needed for MVP
(matches your Sentence Runner approach). Gemma is an optional later upgrade for richer word "voices."

---

## 4. System 3 — The Treaty (directional outcome)

A second, orthogonal axis to the existing touch-tier outcomes. Tier = *how much*; Treaty = *which way*.

### Computation (pure function of the Lexicon)
```
order  = count(.recalled)
reform = count(.pardoned) + count(.adopted)
chaos  = count(.freed)
```
At season end (event `progress >= 1` or first archived resolution), set `readerLexicon.treaty`:
- **Restoration** — `order` dominates. Words re-bind; the Book is stable, a touch quieter.
- **Reformation** — `reform` dominates. The player's Lexicon is ratified; the Book speaks their dialect.
- **Secession** — `chaos` dominates (or any `freed` + a surfaced abducted word). Rebel words decamp to the
  margins; wildly alive, unstable — **and a margin-crack stays open.**

**Open question for Codex (Q5):** exact thresholds + tie-breaks (suggest: strict plurality, ties → Reformation as the "middle" path; require min 3 rulings or default Restoration).

### Consequences
- **Climactic Treaty page** at the `afterimage` phase summarizing the ruling (reuse `rebellionPage` or a
  one-off variant).
- **Monthly Edition** binding line — the event already supplies `outcome.monthlyEditionLine`; add a
  Treaty-specific line so the bound chapter records the *direction*, not just engagement.
- **Cross-arc flag** for February: persist the Treaty (already on `ReaderLexicon`). The Thorned Bargain
  reads `treaty == .secession` to open the margin-crack the Nothing comes through first. (No Bargain code
  needed now — just guarantee the flag persists.)

---

## 5. System 4 — Surface wiring gaps + the Bargain seed

- **The abducted word (the cold spot):** one `RebellionWord` has `isAbducted = true`. Its ruling buttons
  are inert / it does not respond; surfacing it sets `readerLexicon.bargainSeedSurfaced = true` and leaves
  it "still missing" at the Treaty. This is the single serious beat in a comedic season — the Feb hook.
- **`radioInstruction`:** the only unwired packet field. **Open question for Codex (Q3):** radio is
  prerecorded clip selection (`RadioBanter`), so a free-text generation instruction may not fit. Options:
  (a) author a handful of rebellion `RadioBanter` clips gated to the active event, or (b) consume
  `radioInstruction` only where radio text is actually generated. Recommend (a) for launch polish.

---

## 6. Implementation sequence (each phase independently shippable)

- **Phase A — Lexicon foundation.** Data model + `InsideCoverState` field + `asSentencePack()` +
  SentenceBuilder injection. No UI. Unit-test that a fabricated Lexicon changes SentenceBuilder output.
- **Phase B — Rebellion Page.** `RebellionWord` content (~16–20) + `rebellionPage` type + adapter +
  ruling→Lexicon+touch wiring. The interactive heart.
- **Phase C — Treaty.** Directional tally + outcome + persistence + Monthly Edition line + Secession flag.
- **Phase D — Seed + radio.** Abducted word + `radioInstruction`.
- **Phase E — STRETCH.** Compass word-recruiting (§7), broad-prose Lexicon consumption, Gemma voices,
  exportable dictionary artifact.

**September cut line:** ship **A–D**. They deliver the full loop (negotiate → personal dictionary that
alters prose → authored ending → winter seed). E is post-launch.

---

## 7. Stretch (post-launch)

- **Compass word-recruiting:** the packet already has `fieldworkPrompt`. Route the fieldwork answer
  (real word + new meaning the player noticed in the world) into a `LexiconEntry` with
  `origin = .compassRecruit`, tagged `event-fieldwork` (counts as a touch already). The app's living
  language sourced from the player's real attention — the truest expression of the north star.
- **Broad-prose Lexicon consumption** beyond SentenceBuilder (`LiteraryContinuity`).
- **Gemma word-voices** for richer grievances.
- **Exportable personal dictionary** — a beautiful shareable PDF artifact (marketing + retention).

---

## 8. Integration checklist / gotchas

- **New `Shared/*.swift` files must be registered in BOTH the Xcode `.pbxproj` and `Package.swift`** (known
  project gotcha). Prefer appending Lexicon types to existing `SentenceBuilder.swift` to avoid this.
- **`BookPageType.rebellionPage`** ripples through every exhaustive switch (title/shortTitle/icon/etc.).
- **Codable safety:** all new persisted fields are additive + defaulted ⇒ no save migration.
- **Determinism:** ruling outcomes authored; word selection seeded by day. Keep AI optional throughout.
- **No double-counting:** a single ruling must record exactly one `WorldEventTouch`.
- **One ruling per word:** `LexiconEntry.id == lowercased word`; re-surfacing a ruled word is a no-op
  unless you allow re-negotiation (**Open question Q6**).

---

## 9. Open questions for Codex (consolidated)
1. Lexicon → SentenceBuilder: in-memory injection vs serialize to `.sentencepack.json`? (lean: in-memory)
2. `rebellionPage` new `BookPageType` vs reuse the pactVerdict choice-page pattern? (lean: new type)
3. `radioInstruction`: author rebellion banters vs generated-text-only hint? (lean: author banters)
4. How far should the Lexicon bend *broad* prose at launch vs SentenceBuilder only? (lean: SB only)
5. Treaty thresholds + tie-breaking rules.
6. Are rulings reversible / can a word be re-negotiated later?
7. Does the abducted-word seed risk landing as "broken content" to a player mid-comedy — how heavily to telegraph it?
