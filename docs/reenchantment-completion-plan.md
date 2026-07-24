# ReEnchantment Completion Plan

## North star

ReEnchanted may use the machinery of a strong short-form feed: context, novelty,
selection, audiovisual continuity, and memory. It must reverse the objective.

> A conventional feed uses reality to keep the reader looking at the screen.
> The Book uses the screen to return the reader to reality more awake.

The implementation law for this tranche is:

> Every snack owes a debt to the world.

The Book can be endlessly deep. No encounter should be endless.

## Scope

This tranche closes five structural gaps:

1. A finite visit to the Pages Rising desk.
2. One tiny first act on prose-first Pages.
3. Authored song meaning that can faintly echo in later fiction.
4. One global interruption budget.
5. Magic Moments earned across lived days rather than one in-app burst.

The existing archive, Curator, Reader Aliveness model, Long Game, radio playout,
and native Page rituals remain the foundations. Do not create parallel systems.

## Product invariants

- No infinite scroll, automatic slot refill, autoplayed Page sequence, streak,
  guilt, completion prize, or session-length goal.
- A clean no remains a clean no.
- Opening the app, time in app, listening duration, replaying a song, and
  completing a desk round are not evidence that life changed.
- Native rituals keep their own first move. The generic Snack field must not
  appear on Tarot, Radio, games, Compass runs, Playful Missions, conversations,
  transactions, kept readbacks, or other specialized controls.
- Song meaning is authored atmosphere, not a behavioral listening profile and
  not a claim about what the reader felt.
- Lyrics are never transcribed, reconstructed, continued, or closely
  paraphrased by the model. Only short authored non-lyric meaning hooks enter
  prompts.
- The billing courtesy notification is exempt from the Book's story-whisper
  budget.
- The notification promise is hard. Under the current foreground/when-in-use
  location contract, Anchor arrival remains an in-app proximity event rather
  than an external geofence notification.
- Existing dirty-worktree changes are user work. Use narrow patches and never
  restore whole files.

## Pass 1: A finite desk visit

### Core state

Add `BookDeskRound` beside the desk helpers in
`Shared/SurfaceAndCurator.swift`.

The round contains at most three logical slots, keyed by
`SurfacePage.deskSlotKey`, and tracks:

- `waiting`
- `opened`
- `passed`

Required behavior:

- `begin(with:)` keeps at most three unique logical slots.
- Opening or passing a slot resolves it.
- Repeated opens and passes are idempotent.
- `opened` outranks `passed`.
- Undo returns only a never-opened passed slot to `waiting`.
- A cadence-rotated Page with the same `deskSlotKey` resolves the original
  logical slot.
- A Page outside the round is ignored.
- Round completion is not learning, Belief, aliveness evidence, or a Magic
  Moment action.

### App behavior

In `InsideCoverApp/ContentView.swift`:

- Begin a round when the launch desk is published, after the post-onboarding
  desk is published, and after an explicit whole-desk turn succeeds.
- A non-blocked desk open resolves that Page before routing to its native
  destination. The underlying card leaves the visible desk while the opened
  Page remains readable on its sheet or destination.
- A swipe resolves the Page as passed.
- Keep and dismissal do not refill the retired slot.
- Once a round has been touched, background rebuilds may warm the private bench
  but may not fill holes, reorder survivors, or inject a surprise into the
  visible round.
- Pull-to-refresh does not bypass an incomplete round. It gives a warm status
  line while waiting Pages remain.
- When all three slots resolve, show a resting boundary:
  - Title: `That was the desk.`
  - Body: `The Book will leave the next Pages asleep unless you ask.`
  - Action: `Turn three more`
- The boundary action is the only continuation. It requests a genuinely fresh
  nonconflicting trio. If a fresh trio cannot be formed, leave the boundary at
  rest.
- Preserve dismissal Undo. Undoing an unopened swipe retracts the boundary when
  necessary; undoing an already-opened Page does not make it unread.

Keep the existing atomic retirement machinery for non-round surfaces that still
need it. Do not rewrite or delete it wholesale.

### Tests

Add `Tests/InsideCoverCoreTests/BookDeskRoundTests.swift` for:

- capacity and unique logical slots
- open idempotence
- pass and Undo
- opened outranking passed
- rotated IDs with the same slot key
- completion after three unique resolutions
- ignoring Pages outside the round

Retain the existing Curator, three-lane desk, retirement, and simulation tests.

## Pass 2: The Enchanted Snack first beat

### Core contract

In `Shared/SurfaceAndCurator.swift`, add:

```swift
enum EnchantedSnackFirstBeat: Equatable {
    case momentary(MomentaryActionPrompt)
    case native
}
```

Add `MomentaryAttentionEngine.firstBeat(for:learning:)`.
`prompt(for:learning:)` remains as a compatibility wrapper.

Classification must consider both Page type and specialized metadata. Native
examples include:

- Tarot, Radio, Game Page, Book Jump, Ask the Book, Fae transactions, Academy
  activities, and story play
- Compass runs and standalone Playful Missions
- Anchor offers and interactive Anchor scenes
- mood choices, About You choices, and affirmation countersigns
- kept readbacks, inventory, atlas, calendar, shop, and prepared multi-step
  rituals

Only clearly prose-first Pages receive a momentary prompt.

### Page UI

In `InsideCoverApp/CapturePageSheet.swift`, place one compact first-beat card
immediately after `surface.prompt` and before `surface.detail`.

It must:

- use one single-line field
- say that one word is enough
- allow Return and one explicit button to submit
- never auto-focus the keyboard
- be optional and non-gating
- submit once, then disable
- call the already-wired
  `onMomentaryAction(surface, trimmedText, Date())`
- show exact-word recognition immediately
- show an optional Pocket keepsake line
- copy the submitted words into the main margin text only when that text is
  still empty, so Keep never asks the reader to type twice
- offer `Carry it out` after recognition, using the existing Page dismissal
  request
- contain no mastery label, score, progress meter, or reward tease

The ordinary deeper Page remains available below. Native Pages remain visually
unchanged.

The micro action records `.acted` and `.recognized`, but it does not warm a
Magic Moment under Pass 5.

### Tests

Add `Tests/InsideCoverCoreTests/EnchantedSnackTests.swift` for:

- prose-first classification
- representative native types
- specialized metadata overriding a generic type
- kept readbacks remaining native
- mastery-appropriate prompt copy
- exact-word recognition

Retain `MomentaryEngagementTests`.

## Pass 3: Song meaning as one lingering trace

### Data model

Beside `RadioTrack` in `Shared/WorldSystems.swift`, add:

```swift
struct RadioTrackMeaning: Codable, Equatable {
    var themeTags: [String]?
    var imageTags: [String]?
    var ordinaryLifeCue: String?
}

struct RadioTrackPlayReceipt: Codable, Equatable {
    var stationID: String
    var trackID: String
    var startedAt: Date
}

struct RadioNarrativeEcho: Equatable {
    var stationID: String
    var trackID: String
    var startedAt: Date
    var meaning: RadioTrackMeaning
}
```

Add optional `meaning` to `RadioTrack`. Older user packs must decode without it.
Sanitize user-authored hooks before prompt use:

- at most four themes and four images
- each tag at most 48 characters
- cue at most 160 characters
- one line, with control characters removed

Author all bundled tracks, not a pilot subset. Each receives a short
non-lyric meaning trace based on its intended song world.

Add optional `lastRadioTrackPlay` beside `radio` in `PlayerVaultData`. It is
ephemeral and does not enter sealed exports.

### Honest receipt

Record a receipt only after a real file-backed track successfully starts in
`BookRadioManager.beginTrack`.

Do not record:

- missing assets
- failed playback
- procedural fallback tones
- platform stubs

The receipt proves only that a registered local recording began. It contains no
completion, dwell, skip, replay, favorite, or listening-count signal.

Add `RadioStationRegistry.narrativeEcho(...)`:

- resolve stable station and track IDs
- require authored meaning
- expire after 24 hours
- fail closed for removed or locked packs
- return sanitized meaning

### Later fiction

Wire one optional echo to:

- the nightly Braid context
- Story Page generation

Keep it separate from station atmosphere. The prompt fragment must call it
authored non-lyric atmosphere, never evidence. It may lend at most one image,
motion, or cadence when it genuinely fits lived material. It must forbid:

- quoting or reconstructing lyrics
- naming the song, artist, or station
- inferring what the reader liked, felt, chose, or did
- owning the title, moral, or ending

Do not add the echo to curation weights, `RadioWorldContext`, listening
constellations, Belief, notifications, or rewards.

### Reader-facing radio

The Radio Page may show the short ordinary-life cue beneath Now Playing. Keeping
the Page with the reader's own words is the route by which a song becomes lived
archive evidence.

Add a `readerFacingCaption` fallback for legacy imported DJ clips whose stored
caption contains production text such as `Unscheduled ... banter` or
`Audio-backed clip`. Use the fallback in the Radio Page and system Now Playing
so production language never reaches the reader. Do not pretend the fallback is
a transcript.

Faithful accessibility transcripts for the imported audio remain a separate
listening-and-verification content pass. They must never be fabricated from
filenames.

### Tests

Cover:

- legacy `RadioTrack` JSON without meaning
- user-pack meaning decoding and sanitization
- all bundled tracks having bounded authored meaning
- real recent receipt resolving
- expiry and missing-track failure
- no receipt from fallback playback where testable
- Braid and Story prompt safeguards
- reader-facing captions containing no production placeholders
- vault round trip with and without the optional receipt

## Pass 4: One interruption budget

### Pure planner

Add `Shared/BookInterruptionBudget.swift` to the Swift package target.

The pure planner has:

- `BookInterruptionKind`
- `BookInterruptionWindow`
- `BookInterruptionCandidate`
- `BookInterruptionPlan`

There are two seats per local day:

- Morning: normal prompt, person charge, weather bell, or another time-sensitive
  lived-world hinge.
- Evening: braid, festival, Book-interior return, or one due quest/favor.

Cadence is exact:

- `.inside`: no seats
- `.morning`: one morning seat
- `.evening`: one evening seat
- `.both`: at most one per window, at most two total

Specific expiring context replaces a generic occupant. It never adds volume.
Selection is deterministic and idempotent.

### App scheduler

Replace independently racing Book-whisper refreshes with one atomic
`BookWhispers.refreshAll(context:)` in `InsideCoverApp/AppSupport.swift`.

The reconcile must:

- remove legacy ordinary `book-whisper-*` requests once
- build all morning and evening candidates for a short three-day horizon
- run the pure planner
- add only winners
- use dated one-shot evening requests rather than an immortal repeating braid
- make due elective/favor reminders compete for the evening seat
- make person and weather context compete for the morning seat
- keep the explicit test whisper exempt
- keep `StandingOrderTrialReminder` exempt

External Anchor doorbells are removed from the ordinary notification plan.
`refreshAnchorDoorbells` should clear legacy pending geofence requests and arm
no new external ones. Existing in-app Anchor proximity surfaces remain.

Use the unified refresh at launch, foreground return, notification preference
changes, onboarding cadence save, and elective/favor changes.

Weather fetch work should run only when a morning seat is allowed. A late
weather result submits a candidate to the same budget and replaces any still
pending generic morning request rather than stacking.

### Tests

Add `Tests/InsideCoverCoreTests/BookInterruptionBudgetTests.swift` for:

- every cadence
- no more than one winner per window
- contextual replacement
- deterministic refresh
- day rollover
- consumed-seat suppression
- due favor versus ordinary evening return
- explicit in-app-only Anchor policy

## Pass 5: Magic across lived days

Reuse `BookLongGameEvidence`; do not invent a second classifier.

In `Shared/PageModel.swift`, keep legacy persisted field names but add
`MagicMomentGovernor.reconcilingLivedEvidence(...)`.

Arming requires qualifying Long Game evidence on three distinct `BookDay` IDs
after `lastMomentAt`.

Qualifying evidence includes the existing lived kinds such as spontaneous keeps,
explicit field notes, completed experiments, spontaneous patterns, and reader
declarations. `readerDefinition` does not qualify by itself.

Rules:

- Several receipts on one day count as one lived day.
- Three actions in one app session do not arm.
- Micro actions do not arm.
- A generic short keep does not arm unless the Long Game evidence ledger
  classifies it as lived evidence.
- Compass completion counts only through its resulting evidence receipt.
- Existing already-armed legacy moments remain armed once.
- After consumption, evidence at or before `lastMomentAt` cannot immediately
  rearm the state.
- Import merging uses recency and a grandfathered armed reveal, not obsolete
  `sessionCount`.

Reconcile Magic Moment state at the existing Book-interior/Long Game
reconciliation seam.

Update `MagicMomentTests` for:

- three same-day actions not arming
- three qualifying lived days arming
- duplicate daily receipts
- excluded reader definitions and micro actions
- consumption boundary
- legacy JSON decoding and grandfathering
- import merge behavior

## Verification order

Run focused tests after each pass:

1. `BookDeskRoundTests`, `EnchantedSnackTests`, `MomentaryEngagementTests`,
   `BookCuratorTests`, `ThreeLaneDeskTests`
2. `RadioBanterTests`, `WorldSystemsTests`, `BraidPromptContextTests`, and Story
   Page prompt tests
3. `BookInterruptionBudgetTests`, `MagicMomentTests`, Long Game tests
4. Full `swift test`
5. `git diff --check`
6. Signed app build if the test suite is clean

Phone and iPad manual checks are still required for the desk boundary, Undo,
Snack keyboard behavior, Radio Now Playing cue, and notification scheduling.

## Completion boundary

This tranche can complete the product mechanics. It cannot prove the product
outcome by code inspection.

The Book already asks whether a Page escaped the screen and excludes opens and
time-in-app from its success measure. Longitudinal reader evidence must decide
whether people actually feel more alive, wonder-filled, and attentive over
weeks and months.
