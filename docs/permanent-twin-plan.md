# The Permanent Twin

**Goal:** give the Book a durable, correctable, evidence-denominated model of the
reader that persists across sessions, accumulates over years, and can be compared
against itself — so the Book can notice *change*, find *connections it currently
cannot see*, and eventually run humane experiments about when this particular
person is most alive.

**Not the goal:** a personality profile. No traits, no archetype inference, no
adjectives about who the reader *is*. Fairy tales are made of roles, vows, debts,
and scars — things that were *earned by something that happened* — not of
dispositions. Every line the twin can speak must be able to name the day it came
from and the observation that would kill it.

---

## 0. Where we are today

The twin already exists, briefly. `BookSourceInputs` (`Shared/SourceAdapters.swift:13`)
is ~130 fields assembled in `InsideCoverApp/ContentView.swift:693` — body, weather,
place, calendar, self facts, faculty entries (inner weather + fuel), belief,
aliveness model, state pulses, attention probes, reader story, people, world state.

Three facts shape everything below:

1. **It is a computed property.** Rebuilt on every access, used for one desk
   build, discarded. Nothing persists.
2. **The only persisted time series are keep-conditional.**
   `BookPageContextSnapshot` (`Shared/PageModel.swift:1889`) is written *only when a
   page is kept* (`ContentView.swift:14366`). `ReaderStatePulseLedger` holds 730
   reader-answered pulses. `ReaderAlivenessModel` holds 1,200 observations.
3. **Every pattern is therefore conditioned on the reader having shown up.**
   `ContextWeave`'s out-group is *other kept pages*, never *other days*. The
   `RelationalLoom` (`Shared/LiteraryContinuity.swift:55–320`) has 23 feature
   families and a real candidate-pair engine, and it is starved of rows.

The missing thing is not inference. It is a **denominator**.

---

## Architecture: three layers

The layers map onto the actual accounting metaphor, which is also the right
engineering separation:

| Layer | Name | What it is | Where it lives | Mutability |
|---|---|---|---|---|
| 1 | **The Daybook** | Raw daily observations, one row per calendar day, kept or not | SwiftData (archive DB) | Append-only, upsert by dayID |
| 2 | **The Standing Ledger** | Derived baselines, deltas, streaks, patterns | Vault (small, bounded, cached) | Recomputed off-main, cached |
| 3 | **The Reader's Sheet** | Who the reader is *in the story* | Assembled at read time | Derived — **never stored** |

Layer 3 is deliberately not persisted. Its inputs (`readerStory`, `taleScars`,
`roleTransformations`, `chosenQuill`, `relationshipField`, `people`, `pocket`)
are already sources of truth. Storing an assembled copy would create a second
one that drifts. Only the *assembly* is new.

---

## Layer 1 — The Daybook

> A daybook is the accounting record written as things happen, before anything is
> posted to the ledger. Raw, chronological, uninterpreted. That is exactly the
> contract here. (`AlmanacModel` is taken — it is the calendar grid.)

### The row

```swift
struct DaybookEntry: Codable, Equatable, Identifiable {
    var id: String { dayID }
    var dayID: String              // "2026-08-03"
    var date: Date                 // start of that day, local
    var timeZoneIdentifier: String
    var utcOffsetSeconds: Int
    var fidelity: Fidelity
    var writtenAt: Date            // when this row was actually recorded

    // — World —
    var weatherTags: [String]
    var temperatureBand: String?       // "cold" | "mild" | "hot"
    var daylightMinutes: Int?          // from coarse coordinate
    var placeLabel: String?
    var nearbyAnchorID: String?
    var distinctPlaceCount: Int?       // how many named places the day touched
    var travelled: Bool?               // left the usual set

    // — Calendar —
    var calendarEventCount: Int?
    var firstEventHour: Int?
    var lastEventHour: Int?
    var longestOpenBlockMinutes: Int?

    // — Body (expanded past today's single score) —
    var bodyScore: Int?                // existing 0–100
    var sleepHours: Double?
    var steps: Int?
    var restingHeartRate: Int?
    var heartRateVariability: Double?
    var workoutMinutes: Int?
    var bodyObservedAt: Date?

    // — Reader-reported. nil when unanswered. NEVER interpolated here. —
    var alivenessScore: Int?
    var wonderScore: Int?
    var hiddenMagicScore: Int?
    var capacityScore: Int?
    var innerWeatherEntryID: String?
    var innerWeatherTone: String?      // ContextWeave.InkTone, if resolvable
    var fuelEntryID: String?

    // — Rut, snapshotted. Reader-evidence-derived only (see doctrine below). —
    var rutPressure: Int?              // NothingTide 0–3
    var rutMayName: Bool?
    var rutEvidence: [String]

    // — What the Book and reader actually did. Counts, not judgements. —
    var deskWasSeen: Bool
    var sessionCount: Int
    var keptPageCount: Int
    var keptPageTypes: [String]
    var openedCount: Int
    var dismissedCount: Int
    var medianWordsWritten: Int?
    var dayInkTone: String?            // bright | heavy | nil (strict majority)
    var beliefScoreAtClose: Int?

    enum Fidelity: String, Codable {
        case live           // written while the day was current, sensors live
        case reconstructed  // backfilled; only retro-queryable fields are real
        case absent         // day passed with the app never opened; skeleton only
    }
}
```

### Fidelity is load-bearing

HealthKit and EventKit answer retroactively. Weather and location do not. If the
reader is away nine days and we backfill, those rows have real sleep and real
calendar density and **no honest weather**. A reconstructed row must never
counterweight a live one in any pattern. Concretely:

- `.live` rows count fully.
- `.reconstructed` rows count only in the families whose fields were actually
  recoverable, tracked per-field via nil.
- `.absent` rows exist to make the denominator honest (the day happened) and
  contribute to nothing but day counts.

Any pattern that would flip if reconstructed rows were dropped is not promotable.

### Storage — SwiftData, not the vault

New `@Model final class StoredDaybookEntry`, added to the `Schema([...])` list at
`Shared/BookArchiveDatabase.swift:845`; bump `schemaVersion` 6 → 7.

This must **not** go in the vault. `PlayerVault.data` is a single `@Observable`
JSON blob — every write re-encodes the whole thing and rebuilds the desk. An
unboundedly growing daily array there would tax every save in the app forever.
The archive DB is already the home for append-only history and already has an
off-main read path (`BookDatabase.detachedDatabase()`).

**Budget:** ~400 bytes/row encoded → ~150 KB/year → ~1.5 MB over a decade.
Negligible. Storage is not an argument against this.

### When the tick fires

- **Foreground**, in the existing `scenePhase == .active` handler
  (`ContentView.swift:2005`) — which already carries the comment about crossing a
  day boundary while suspended.
- **On keep**, to update counts (upsert, same row).
- **At backgrounding**, to close the day's counts and belief.
- Idempotent: upsert by `dayID`, always. Never append a second row for a day.
- **Backfill on foreground**: walk from the last recorded `dayID` to today,
  writing `.reconstructed` or `.absent` rows. Cap the walk (e.g. 90 days) so a
  reader returning after a year doesn't stall launch; older gaps stay unrecorded
  rather than fictional.

All of it off the main thread. The desk build never touches the Daybook.

---

## Layer 2 — The Standing Ledger

Small, bounded, cached in the vault as `standingLedger: StandingLedger?`
(optional, matching the existing backwards-compatible-decode convention in
`PlayerVaultData`). Recomputed off-main beside the continuity digest; the desk
build reads only the cached summary. Desk build is currently 31ms and must stay
there.

### Baselines

For each numeric Daybook field, over trailing 28-day and 90-day windows:

```swift
struct StandingBaseline: Codable, Equatable {
    var field: String
    var window: Int              // days
    var median: Double
    var medianAbsoluteDeviation: Double
    var sampleCount: Int         // days with a real value, not window length
    var lastComputedAt: Date
}
```

Median + MAD rather than mean + σ: robust to the one 18-hour-sleep day, and
honest at small n, which is where this will live for months.

### Minimum-n gates

Nothing is speakable below these. They are deliberately conservative — the cost
of a wrong claim here is trust in everything else the Book says.

| Claim | Minimum |
|---|---|
| Any single-field delta | 14 real values in a 28-day window |
| Any 90-day trend | 45 real values |
| Any two-family connection | 8 in-group *and* 8 out-group day-rows |
| Any lagged (day+1) connection | 12 in-group pairs, plus a holdout confirmation |
| Anything at all | ≥ 21 days since the first Daybook row |

### What the Ledger computes

- **Deltas** — current value vs own median, in MAD units, banded (`well below` /
  `below` / `usual` / `above` / `well above`). Never a raw number in prose.
- **Streaks** — consecutive days on one side of the median, both directions.
  *"Eleven days the ink has run brighter."*
- **Firsts and lasts** — first day above/below a band since a dated day; days
  since last visit to a place; days since a page type was kept. Cheap and
  extraordinarily evocative.
- **Drift** — lexicon, ink tone, page-type mix, median words, compared window
  over window.
- **Rut trajectory** — the `rutPressure` series over months, which is currently
  entirely invisible. Rising, easing, or standing.
- **Pulse trends** — `ReaderStatePulseLedger.metrics` already does a weighted
  180-day trend; the Ledger folds it in rather than duplicating it.

### The sentences this unlocks

All are currently unsayable, and each carries its own receipt:

- *"Something has changed. Your sentences have run short for nine days; before that they ran long for a month."*
- *"You've slept under six hours four nights running. The last time that happened you wrote the page about the harbour."*
- *"You haven't written at the kitchen table in forty days. For a year it was where you wrote."*
- *"Third bright day in a row. That hasn't happened since March, which you named the Long Thaw."*

---

## Layer 3 — Connections, which is where this pays off

The `RelationalLoom` already has 23 feature families, a candidate-pair enumerator
that only considers dimensions that have actually met in a receipt, three
evidence tiers (`glimmer` / `gathering` / `established`), and two-sided
in-group/out-group counting. It is a good engine. Daybook rows extend it three
ways.

### 3a. Day-rows as observations — the absence axis

Emit a `RelationalLoomObservation` per Daybook row, not just per page. The
evidence tier machinery works unchanged. This makes **"days you did not write"**
a first-class row for the first time, and therefore makes absence patterns
findable:

- *"You write on open days. Of your last eleven days with a clear calendar, you wrote on nine. Of your last fourteen crowded days, two."*

Today this sentence is impossible, because crowded days on which nothing was
kept do not exist in any data structure.

### 3b. New feature families

Added to `RelationalLoomFeature.Family` with `conditionRank` values slotted
alongside the existing condition families (`weather: 10`, `dayPart: 15`,
`place: 25`, `body: 30`, `tempo: 35`):

| Family | Values | Rank |
|---|---|---|
| `sleep` | short / usual / long | 28 |
| `daylight` | shortening / lengthening / long / short | 12 |
| `travel` | home-set / elsewhere / moving | 26 |
| `rutBand` | quiet / edges / margins / desk | 6 |
| `pulseBand` | aliveness low/usual/high | 4 |
| `streakPosition` | first-day / mid-streak / breaking | 8 |

Each new family multiplies the candidate-pair space, which is a benefit and a
hazard — see guardrails.

### 3c. Lagged connections — the genuinely new capability

Every connection today is same-receipt: features that co-occur in one
observation. A daily series permits **lag-1 and lag-2** relationships:

- *"The day after a long walk, your sentences run longer."*
- *"You ask questions the day after a short night."*
- *"Two days after you write about your brother, the ink runs brighter."*

These are causal-*shaped*, checkable, and falsifiable — and nothing in the
current architecture can find one. This is the material of Vellum's stated brief
in the lore, "one humane experiment," and it is the direct on-ramp to Layer 5.

Lagged pairs get the strictest gate: 12 in-group pairs **and** a holdout — the
pattern must be found on the first 70% of history and then confirmed on the
remaining 30% before it may rise past `glimmer`.

### Multiple comparisons — the real risk

With 29 families and two lags, spurious correlations are not a possibility, they
are a certainty. Mitigations, most of which already exist:

- Two-sided evidence (existing house rule) — in-group *and* out-group counts.
- Minimum support tables above.
- Tiered promotion (`glimmer` → `gathering` → `established`), existing.
- A `falsifier` string on every pattern, existing on `ReaderAlivenessPattern`.
- Holdout confirmation for lagged claims (new).
- **Cap the spoken surface**: at most one connection per notice, and the reflective
  de-repetition rest (14-day `spoke:` tags) already prevents drumming.
- Reader correction is content: `ReaderAlivenessPatternFeedback` already carries
  `confirmed` / `contradicted` / `forbidden`. A contradicted pattern is not just
  suppressed, it is *material* — the Book being wrong and saying so is a better
  page than the Book being right.

---

## Layer 4 — The Reader's Sheet

Assembled at read time from existing sources. Two consumers.

```swift
struct ReadersSheet: Equatable {
    // Name & standing
    var role: ReaderRole?              // role × epithet × hand
    var transformationClause: String?  // second half a tale earned
    var seasonName: String?            // reader-named, current
    var tenureDays: Int
    var beliefTier: String

    // Vows & debts — things that bind
    var pacts: [Pact]
    var openBargains: [FaeBargain]
    var outstandingWagers: [BookWager]
    var entrustings: [Entrusting]

    // Scars — laws left by finished tales (TaleScarBook)
    var activeScars: [TaleScar]

    // Company
    var quill: ChosenQuill?
    var closestBonds: [RelationshipTie]      // top N from relationshipField
    var peopleThreads: [PersonThread]

    // Marks
    var pocketKeepsakes: [PocketItem]
    var constellations: [Constellation]

    // Weather — explicitly labelled state, not identity
    var currentState: ReaderCurrentState     // existing
    var rutBand: Int?
    var recentDeltas: [StandingDelta]

    // What the Book is watching, and might be wrong about
    var openThreads: [OpenThread]
    var livePatterns: [ReaderAlivenessPattern]   // with tier + falsifier
}
```

**Consumer A — a prompt section.** A compact rendering handed to Gemma so every
generated page knows who it is writing to. Today prompt context is assembled ad
hoc per surface; this is arguably worth more than the reader-facing page.

**Consumer B — a reader-facing page.** "What I have of you." Every line shows its
evidence and carries a correction affordance. This is not a nice-to-have: a
permanent record of someone that they cannot inspect or amend is the bad version
of this whole project. The page is simultaneously a privacy artifact, a trust
artifact, and content.

---

## Layer 5 — Experiments (later, but this is what it's all for)

With a persisted twin and lagged patterns, the twin stops being read-only.

1. The Book holds a hypothesis: *this reader is most alive on open mornings after
   a long night's sleep.*
2. It can **see the conditions arrive** — the Daybook tick knows tonight's sleep
   and tomorrow's calendar.
3. It can **arrange a page** for that moment rather than waiting for one.
4. It can **check** via the delayed-outcome pulse, which already exists as a
   dimension and already weights 1.6× in the metrics.

That loop — hypothesis, condition, arrangement, receipt — is the only honest
mechanism for *more alive more often* rather than merely *more observed more
often*. It is also, structurally, what a fairy godmother does.

---

## The two scores, and why they stay behind the scenes

Aliveness and Rut are both wanted as **internal signals only** — never rendered,
never shown as a number, never a gauge the reader can watch. Two reasons, and
the first is mechanical rather than aesthetic:

- The aliveness pulse is **reader-answered**. Show it as a score and the reader
  begins answering to protect the number, which corrupts the one input the whole
  twin rests on. It is the single measurement in the system that cannot be
  displayed without changing it.
- The Rut doctrine's rule 2 is that it *makes story, not shame*. A visible rising
  rut number is a shame gauge with a lamp on it.

### What exists today

| | Daily | Longitudinal |
|---|---|---|
| **Aliveness** | `ReaderStatePulseLedger.currentState` (latest pulse within 18h) | `ReaderReenchantmentMetrics` — 7-day averages, 30-day change, brightening/holding/dimming |
| **Rut** | Snapshotted per row since Phase 0 | **Nothing** |

Two limits on the aliveness trend: it counts only days the reader *answered a
pulse* (the denominator problem again), and it is uncached — `metrics()` walks
180 days of records per call, which is too expensive for a curation gate.

### The flaw a private baseline fixes first

`delayedOutcomeSuccessRate` counts success at `score >= 6` — **absolute**. A
reader whose usual is 4 answering 5 reads as failure; a reader whose usual is 8
answering 6 reads as success. The first improved and the second declined.

Every outcome measure in the app has this shape. A private baseline converts them
all from absolute to relative, which is what lets the Book tell a good *page*
from a good *week*. Without it, Phase 5's experiments measure noise.

### What the private trends gate

1. **Claim boldness** — `BookClaimTier`'s ceiling, not just its evidence count. The
   same sentence is a delight on a bright week and a presumption on a dark one.
2. **Interruption spend** — `BookInterruptionBudget.plan`. Leaning in hardest
   exactly when someone is depleted is the classic failure of this genre.
3. **Desk composition** — `greyLevel` already favours perspective-changing pages,
   but from a standing prior. A trend makes it responsive.
4. **When to ask for the pulse** — the Daybook shows which conditions this reader
   actually answers under. This one compounds: it improves the input everything
   else rests on.
5. **Resurfacing choice** — a page from a dark season is comfort in one stretch
   and salt in another.
6. **Rut trajectory as tale shape** — a months-long rise and fall *is* a tale
   shape. `TaleGrammar` can recognise it once it is over and bind it whole, which
   is the "seasons named only backwards" principle exactly.

### Enforcement

"Behind the scenes" must be structural, not a convention that erodes. The trend
types expose only coarse enums (`.brightening` / `.holding` / `.dimming`) to
general callers; raw scores stay reachable only by the curation layer. Plus a
test asserting no twin score ever reaches page metadata or prose — precedent:
the test asserting `hiddenMagicLens*` metadata never ships.

## Phase 2b — inferring the two scores from more than self-report

Both should also move on evidence the reader did not have to type. The seam
already exists: `rutAssessment` returns `pressure` (private curation weight) and
`mayNameRut` (permission to speak) as separate fields. **Inferred signals may
move `pressure` and may never touch `mayNameRut`.** The Book gets to respond
without ever getting to accuse, which is what rule 3 is actually protecting.

### Rut — measured as flattening, never as heaviness

The in-world definition is the useful one: the Rut is *the grey loss of
particular life*. That is not a mood, it is flattening, and flattening is
measurable in prose the reader has already written.

1. **Specificity loss** — fewer proper nouns and concrete objects, more
   abstraction. *"Work was fine"* against *"Marcus brought the wrong coffee
   again."* The strongest signal, because it is not a proxy for the Rut; it is
   the thing itself.
2. **Self-similarity rising** — semantic distance between consecutive keeps
   shrinking (`NLEmbedding` is already in use for `semanticNoticePairing`). Days
   becoming interchangeable is the definition.
3. **Lexical narrowing** — type-token ratio against the reader's own baseline.
4. **Sentence-length collapse** — `ContextWeave` already has `brisk`.
5. **Variety collapse** — same page types, hours, places, week over week. The
   Daybook has all four.

### Aliveness

1. **Spontaneous keeps** — pages written without a surfaced page prompting them.
   Far stronger than responding well to a prompt.
2. **Novelty** — new places (`distinctPlaceCount`, `travelled`), new subjects,
   new people entering the prose.
3. **Question-asking** — `ContextWeave` already has `asking`.
4. **Concreteness density** — the inverse of the specificity signal above.
5. **Lived receipts** — already half-built: `ReaderAlivenessEvidenceKind`
   distinguishes `livedEvidence` / `followed` / `keepsake`, and `authority`
   already ranks `livedReceipt` above `interaction`.

### Four traps

- **App engagement is not aliveness.** The most seductive and most wrong: a
  thriving reader may use the app *less*. Rule 3 already forbids this on the Rut
  side; the same discipline has to hold on the aliveness side, or the Book
  simply learns to reward its own use.
- **Grief is not Rut.** Someone writing heavily about a dying parent is intensely
  alive. Heavy ink plus *specificity* is aliveness; heavy ink plus *flatness* is
  Rut. Every signal above keys on flatness and none on heaviness, deliberately.
- **Sleep and steps are conditions, not moods.** Good loom facets, bad direct
  inputs — a newborn or a marathon confounds them entirely.
- **One day is a Tuesday.** Trend-only, against the reader's own baseline, under
  the Phase 2 minimum-n gates.

### The rule held hardest

**Do not score yourself with the signal you optimise.** If inferred aliveness
both drives curation and measures whether curation worked, the loop closes and
the Book grades its own homework — it will reliably discover it is doing well.

- Inferred signals **inform**: curation, claim tier, interruption spend, timing.
- Reader-answered pulses and lived receipts remain the **scoring**. The
  delayed-outcome check stays reader-answered, always.

Inferred contribution is capped: it may move `pressure` by at most ±1 and can
never reach the top band alone — the top band still requires the reader to say
so. Inferred `evidence` strings carry an `inferred:` prefix so the two lanes stay
separable in any audit.

## Doctrine and guardrails

These are non-negotiable and several already exist in code:

1. **The Rut doctrine survives intact.** `NothingTide` rule 3: app silence,
   weather, seasons, and story activity are never Rut evidence. The Daybook
   *records* that the reader was absent; it may never *conclude* anything about
   the Rut from it. `rutPressure` on a row is a snapshot of the reader-reported
   assessment, nothing more.
2. **Under distress, all of it goes quiet.** Existing doctrine; the twin adds no
   exception.
3. **Shadow permission outranks everything.** `ReaderStory.ShadowPermission` is a
   ceiling, and a delta or connection is not an excuse to breach it.
4. **No trait vocabulary, ever.** Ship a test asserting no Big-Five / MBTI /
   disposition adjective appears in any twin-derived prose — precedent exists in
   the test that asserts `hiddenMagicLens*` metadata never ships.
5. **Cite or stay silent.** Every spoken line names its dates and counts
   internally, even when the prose doesn't show them.
6. **State is weather, not biography.** The pulse types already say this in their
   doc comments. The Sheet must keep state and identity visually and verbally
   separated.
7. **Correction is a first-class outcome**, not error handling.
8. **Performance:** desk build stays at 31ms. Ledger computes off-main and
   caches; Daybook is never read on the desk path; vault writes batch through
   `vault.mutate {}`.

---

## Phasing

| Phase | Scope | Reader-visible? |
|---|---|---|
| **0 — SHIPPED** | `DaybookEntry` + `StoredDaybookEntry` + schema 6→7 + tick + backfill + fidelity | No |
| **1 — SHIPPED** | Expand body capture (sleep / steps / HRV as separate fields), wire into Daybook *and* `BookPageContextSnapshot` | No |
| **2 — SHIPPED** | Standing Ledger — baselines, deltas, streaks, firsts, rut trajectory, widened aliveness denominator, cached for curation gates | Internal |
| **2b — SHIPPED** | Inferred Rut/aliveness signals feeding `pressure` only, capped, `inferred:` tagged | Internal |
| **3 — SHIPPED** | Loom extension — day-rows, absence patterns, 6 new families, lagged pairs with holdout | Yes |
| **4 — SHIPPED** | Reader's Sheet — assembly, prompt section, reader-facing page with corrections | Yes |
| **5 — SHIPPED** | Experiments — condition-watching, arrangement, delayed-outcome check | Yes |

Phase 0 is foundational and invisible; every later phase is much weaker without
it. Phases 2 and 3 are where the user-visible payoff concentrates. Phase 1 is
tiny and disproportionately valuable — `bodyScore` currently collapses sleep,
steps and heart rate into one number banded at ≤40 / ≥70, and splitting sleep out
alone opens a whole class of connection.

---

## Phase 0, as built

- `Shared/Daybook.swift` — `DaybookEntry` (+ `Fidelity`) and `DaybookRecorder`,
  all pure and directly testable: `live(inputs:day:)`, `reconstructed(day:)`,
  `absent(...)`, the gap walk, and reconciliation.
- `Shared/BookArchiveDatabase.swift` — `StoredDaybookEntry` (`dayID` unique, with
  the row itself stored as an encoded payload so later phases can add fields
  without a store migration each time), schema **6 → 7**, and fetch/upsert.
  `mayReplace` enforces live > reconstructed > absent, so a gap walk can never
  overwrite what the Book actually watched happen.
- `InsideCoverApp/BookDatabase.swift` — `tickDaybookDetached`, which writes
  today's row, fills the gap behind it, and reconciles the trailing window. All
  archive work is off-main; a failed tick returns 0 and stays silent.
- `InsideCoverApp/ContentView.swift` — `tickDaybook()`, called on foreground and
  on backgrounding.

**Two deliberate departures from the spec above:**

1. **No tick on the keep path.** `sourceInputs` is expensive and `persist` is the
   hottest path in the app. Instead, `DaybookRecorder.reconciliations` corrects
   the trailing 7 days against the archive on the next tick, which is exact,
   costs nothing on the hot path, and also handles the case the spec missed — a
   row written at breakfast on a day the reader kept writing into, which the gap
   walk would never revisit because the day already had a row.
2. **Backfill reconstructs from the archive, not from retro sensor queries.**
   Kept pages carry a `BookPageContextSnapshot`, so weather, body, calendar
   density and place are genuinely recovered for past days — an existing reader
   gets real history on first run rather than an empty Daybook. Retroactive
   HealthKit and EventKit queries belong with the expanded body capture in
   Phase 1.

## Phase 1, as built

`BodySourceSignal` already carried sleep, steps, resting heart rate and HRV — as
*display strings*, under two naming conventions at once (base metrics use short
ids like `stepCount`; the richer ones use `HKQuantityTypeIdentifierRestingHeartRate`).
So Phase 1 needed no HealthKit changes at all, only typed extraction:

- `BodySourceSignal.metricValue(_:)` + `normalizedMetricID` in `Shared/Daybook.swift`
  — normalises both conventions, strips grouping separators, and reads a zero as
  "nothing recorded" rather than "measured as zero".
- Split fields on `DaybookEntry` **and** on `BookPageContextSnapshot`, so both the
  day and the page can later be related to the night behind them. The snapshot
  clamps impossible readings (40-hour sleep, negative steps) to nil.
- `workoutMinutes` was dropped from the spec'd field list — HealthKit is not
  queried for it. `activeKilocalories` and `distanceMiles` replace it, because
  those are metrics the app actually collects.

## Phase 2, as built

`Shared/StandingLedger.swift`. Takes `[DaybookEntry]` and nothing else, which
keeps it pure and directly testable, and gives the widened aliveness denominator
for free — every day has a row, so unanswered days are visible as unanswered
rather than silently dropping out of an average.

- **`StandingField`** — 18 numeric series. Adding a case is all it takes to give
  a field a baseline, a delta and a streak. Each declares `countsOnAbsentDays`,
  so a week away contributes zeroes to "pages kept" and *nothing* to "hours
  slept" — otherwise absence would teach the Book the reader sleeps zero hours.
- **Baselines** — median + MAD over 28 and 90 days, `isTrustworthy` gated on
  sample count, not window length.
- **Bands, not numbers.** `StandingBand` is the only thing callers get. A field
  with zero spread still registers its first move, so a departure from a flat
  line isn't swallowed by a division that never happens.
- **`RutTrajectory`** — the Rut's first trend ever. Reports levels and how long
  they have held rather than a slope, because the series is stepped. It carries
  `mayName` forward from the reader's own evidence and **never widens it**.
- **`AlivenessTrend`** — direction plus its own `coverage` and an `isThin` flag,
  so a caller can discount it honestly. Below the threshold the right move is to
  *ask* for a pulse, not to guess.
- Cached in the vault (`standingLedger`), computed off-main in the same detached
  tick that writes the Daybook, since the Ledger is only ever as current as the
  last row and walking 90 days twice would be work for nothing.

**Enforcement is structural.** No type in the file carries prose, a
`description`, or any speakable string — a page that wanted to show a number
would have to add the means to do it first. A test asserts none of them conform
to `CustomStringConvertible`.

**A test caught a real bug.** Sharpening the coverage test to hold the answer
count fixed while varying the denominator exposed that the early-return path
computed confidence from answer count alone, ignoring coverage entirely — so
eight answers in eight days and eight scattered across four weeks scored
identically. Confidence is now computed once, from coverage and count together,
and used on every path.

## Phase 2b, as built

`Shared/InferredSignals.swift`. Seven measures over two fourteen-day windows,
each comparing the reader only against their own prior fortnight.

**Deliberately asymmetric.** Each measure declares what a *rise* means and what a
*fall* means, and either may be `neutral`. A collapse in sentence length is a
flattening; a burst of long sentences is not therefore an aliveness. A move in a
direction that means nothing carries no weight at all.

| Measure | Falling | Rising |
|---|---|---|
| specificity | rutward | aliveward |
| variety | rutward | aliveward |
| lexicalRange | rutward | neutral |
| sentenceLength | rutward | neutral |
| selfSimilarity | neutral | rutward |
| questionAsking | neutral | aliveward |
| novelty | neutral | aliveward |

**Lived receipts are deliberately absent.** They were on the Phase 2b list and
were cut on the rule: reader-answered pulses and lived receipts are the
*scoring*, and the Book must not score itself with a signal it also optimises.
Prose features are observations of behaviour and belong in the informing lane;
receipts of real-world change are the judging lane and stay out.

**The caps, all tested.** Inferred weight moves `pressure` by at most ±1, never
below the ordinary-life floor of 1, and never into the top band of 3 — but the
inferred ceiling never drags a *reported* pressure down either. `mayNameRut` is
not a parameter of anything in the file, by construction, so there is no route
from behaviour to permission to speak.

**Grief is not Rut, with a test that says so.** The suite includes mirrored
fixtures: heavy, particular writing about a parent in hospital leans *aliveward*
on specificity, while cheerful, unparticular writing about a fine day leans
rutward. Every measure keys on flatness and none on tone.

**A second zero-baseline bug, same family as Phase 2's.** Relative change was
computed against the prior window, which silently swallowed the most meaningful
move a measure can make — the one away from zero. A fortnight with no
particulars followed by one full of names read as "no change". Change is now
taken against the larger of the two windows, which is symmetric, bounded, and
well defined at zero.

## The four gates, as built

`TwinCurationGates.resolve(ledger:signals:)` in `StandingLedger.swift` is the
only door between the twin's arithmetic and the rest of the Book. Callers take a
ceiling, a lean, or a boolean, and never a number — which is what makes
"internal only" a property of the design rather than a habit.

1. **Claim boldness.** `BookClaimTier.capped(by:)`. Evidence proposes a tier; the
   twin lowers the ceiling — never raises it. One dark lane (dimming, deepening
   Rut, or a rutward behavioural lean) drops `established` to `gathering`; both
   lanes agreeing drops it to `glimmer`.
2. **Desk composition.** Wired at the *source* rather than at nine call sites:
   `NothingTide.rutAssessment` now returns `pressure` (working, may carry one
   step of behavioural lean) alongside `reportedPressure` (reader evidence
   alone). All nine existing `greyLevel` sites pick it up unchanged. The Daybook
   stores the **reported** figure, so a behavioural lean can never accumulate
   into apparent testimony.
3. **Interruption spend.** `BookInterruptionBudget.narrowed(_:lean:)` gives up
   the morning knock and keeps the evening, where the ember lives. The Book never
   goes fully silent from this gate — distress is a separate one.
4. **Pulse timing.** When the aliveness trend is thin, the fresh-weather pulse
   gets a score boost: the right move is to *ask* rather than lean on almost
   nothing. Sized so it can never outrank a delayed-outcome question.

A thin trend is deliberately **not** treated as a dark one. One answer in four
weeks is not evidence of a dark month; the ceiling stays up and the Book asks.

## Phase 3, as built

**3a — absence became a row.** `DaybookEntry.loomObservation(ledger:)` emits a
`RelationalLoomObservation` per *day*, carrying a `writing:kept` or
`writing:silent` outcome. That single feature is what makes the absence axis
exist: until every day had a row, a day the reader did not write was in no data
structure at all. A test now demonstrates the loom finding a tempo→writing
relationship across ten open days and twelve crowded ones.

**3b — six new families.** `sleep`, `daylight`, `travel`, `rutBand`, `pulseBand`,
`writing`, slotted into `RelationalLoomFeature.Family` with condition ranks
beside their neighbours. `rutBand` and `pulseBand` join `innerWeather` and `body`
as `isSensitiveInterpretation` — all four are the reader's condition rather than
the world's. `writing` replaced the spec'd `streakPosition`, which was the less
valuable of the two by a wide margin.

Bands are drawn against the reader's **own** Ledger baselines, with a test
showing the same five-hour night reading as `sleep:short` for an eight-hour
sleeper and `sleep:long` for a four-hour one.

A row can only offer features it genuinely observed, so an `.absent` day
contributes its weekday and its silence and nothing else — there is no route for
it to smuggle in a weather it never saw. That is self-enforcing rather than
policed.

**3c — lagged connections.** `LaggedDaybookLoom` pairs each day's *conditions*
with a later day's *writing outcome*, which is the first thing in this
architecture that can reach across a night. Only the writing outcome crosses the
gap: relating one day's weather to the next day's weather would be meteorology.
The earlier day's own writing is dropped from the condition side, since "you
wrote yesterday therefore you wrote yesterday" is bookkeeping.

Because these are causal-*shaped*, they get the strictest gate in the system: a
**holdout**. Candidates are discovered on the earlier 70% of paired history and
kept only if the relationship still leans the same way on the later 30%, which
the discovery pass never saw. Lagged conditions carry an `after:` prefix so a
finding across a night can never merge with a same-day one. Both directions are
tested — a real relationship survives, and one that reverses on unseen days is
discarded.

## Phases 4 and 5, as built

**The Reader's Sheet** (`Shared/ReadersSheet.swift`) gathers what was scattered
across seven unrelated fields — role, transformation clause, named season, vows,
scars, quill, bonds, written-in people, keepsakes, threads, shadow rule — into
one thing that can answer "who am I writing to?". Derived, never stored.

Its main consumer is `promptSection`, and two rules govern it. The reader's
shadow permission **leads**, because it is a ceiling on everything after it. And
no twin number crosses over — not belief, not tenure, not the Rut band — because
those are gates, not material, and a number in a prompt is one sentence away
from the reader. Tests assert both, plus that the Witness Law travels with any
named person and that a rested thread is never named.

**Experiments** (`Shared/TwinExperiments.swift`) close the loop: hypothesis →
watch the conditions arrive → arrange → check.

- Beliefs are proposed **only** from lagged findings that already survived their
  holdout. A same-day connection says what goes together, not what follows what,
  and only the second is something the Book can arrange for.
- The cue is *yesterday's* conditions, which is what lets the Book see it coming.
- Two beliefs at once, six days' rest between attempts. An experiment that runs
  every day is a schedule the reader never agreed to.
- Spent beliefs (3 contradictions) are abandoned; established ones (3
  confirmations) stop being tested — there is nothing left to learn, and
  continuing would just be the Book arranging someone's days.

**Consent reuses `BookWorkingAuthority`** rather than inventing a new moment.
It is sealed by default, reader-pausable, and its own doc comment says it exists
"because the result can cause an unexpected real-world act" — which is precisely
what arranging conditions for someone is. Tests cover sealed, paused, and
distress, all of which return nil quietly.

**The Book does not mark its own homework.** Verdicts come from the
reader-answered delayed-outcome pulse and are judged against the reader's *own*
baseline. Tested both ways: a usually-8 reader answering 6 is a decline, and a
usually-3 reader answering 5 is a success — an absolute threshold reads both
backwards, which was the original flaw a private baseline existed to fix.

Verified: 2,404 package tests pass (105 new across Phases 0–5), and the iOS app
target builds.

## Still to do

- **The Sheet's reader-facing page.** The prompt-section consumer is built; the
  "what I have of you" surface with correction affordances needs a new
  `BookPageType`, a source adapter, and a view. It is the trust artifact, so it
  should not be skipped — but it is UI work, not model work.
- **Arranging is proposed but not yet consumed.** `TwinExperimenter.arrangeable`
  returns the belief to act on; nothing yet raises a page's score because of it,
  and no `causalOpportunityID` is minted to tie the arrangement to its later
  delayed-outcome pulse. That wiring is the last mile of Phase 5.

## Tests worth writing

- Tick is idempotent: two foregrounds on the same day yield one row.
- Backfill produces `.reconstructed` with nil weather and real calendar/sleep.
- `.absent` rows contribute to day counts and to nothing else.
- No pattern promotes below its minimum-n gate.
- A pattern that flips when reconstructed rows are excluded is not promotable.
- Lagged pattern fails promotion without holdout confirmation.
- Daybook rows never raise `rutPressure` or `mayNameRut`.
- Distress silences every twin-derived surface.
- `knowButNeverWrite` shadow permission suppresses twin prose touching that material.
- No trait adjective appears in twin-derived prose (lint-style, mirrors the
  hidden-magic-lens test).
- Desk build with a 5-year Daybook does not regress past 31ms.

---

## Open questions for bj

1. **Names.** Daybook / Standing Ledger / Reader's Sheet are placeholders chosen
   from the accounting metaphor (daybook → ledger is the real posting flow). The
   reader-facing surface might want in-world names — "The Front Matter" for the
   Sheet reads nicely, since front matter is where a book states what it is.
2. **Backfill cap.** 90 days proposed. A returning reader after a year gets a
   truthful gap rather than a reconstructed fiction.
3. **Does the Daybook enter the sealed backup / export?** It is arguably the most
   personal object in the app. Leaning yes for the reader's own sealed copy, no
   for anything shared.
4. **Phase 5 consent.** The Book arranging conditions for the reader is a
   meaningful step past observing them. That probably wants its own explicit
   opt-in moment, in the register of a pact.
