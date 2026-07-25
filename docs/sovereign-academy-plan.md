# The Sovereign Academy Plan

## North star

The narrative simulation already exists. Characters have goals, faults, and
voices; gossip moves Belief; relationships warm and tense; alliances and
rivalries emerge; world events reach across Radio, the Bleed, widgets, letters,
and braids. `CastAgencyState` already advances the cast on a four-hour clock
whether or not a Gossip Page ever reaches the desk.

This tranche does not add a simulation. It makes the one that exists feel
sovereign.

> The reader should not feel that the Academy generates reality for them.
> They should feel they are receiving reports from a reality that continued.

A world feels alive when the reader senses three things:

1. Something happened without them.
2. It would have happened differently under other conditions.
3. It will keep having consequences whether or not they engage.

The Book already has the machinery for all three. Today its presentation
contradicts all three: world motion only advances one slot, only on days the
reader supplied material, and then announces itself in a status toast.

## The implementation law for this tranche

> More consequence per event. Never more Pages.

The desk is finite. The interruption budget has two seats. Nothing in this plan
is allowed to spend either. Every pass below must express itself through
surfaces that already exist.

## Product invariants

- **Keeping decides witness, not occurrence.** Dismissing a Page does not
  unhappen the event it reported. Silence means the reader did not witness
  something, never that the Academy froze.
- **World motion is never a notification.** No toast, no badge, no unread
  count, no "while you were away" changelog. The world does not report its own
  diligence.
- **World motion is never reader evidence.** It must not enter
  `ReaderAlivenessModel`, Long Game evidence, Magic Moment arming, the
  re-enchantment measure, or any causal receipt about the reader. The Book's
  own simulation cannot be allowed to prove that the reader's life changed.
- **Missing history is not a penalty.** Unwitnessed events never surface as
  loss, cost, missed reward, or a thing to catch up on. A clean no stays clean.
- **The world ledger is bounded and lossy by design.** The reader recovers
  fragments and testimony, never a complete record. Depth is implied, not
  enumerated.
- **The Witness Law holds.** Real people from People of the Book never act,
  speak, or appear in world simulation. The Academy is fiction; they are not.
- **No new page types in passes 1–5.** Pass 6 adds edition sections, not Pages.
- **Existing dirty-worktree changes are user work.** Narrow patches only.
- Foreground local-model calls stay user-initiated. Nothing heavy runs on a
  rendered view. World advancement is deterministic code, never a model call.

## Pass 1: Make the sovereignty we already own behave sovereign

The smallest, highest-leverage pass. Mostly deletion.

### The three defects

In `InsideCoverApp/ContentView.swift`, `runCastAgencyTurnIfNeeded`:

1. It resolves only the current four-hour slot. Away three days, the reader
   returns to one move rather than accumulated history.
2. `guard hasStoryMaterial else { return }` requires today's captured pages or
   weather/body/narrative tags. On a quiet day the Academy freezes — the exact
   failure this tranche exists to fix.
3. `statusMessage = "Cast turn: …"` and `isCastLedgerExpanded = true` announce
   the move. The one mechanism built to prove things happen without the reader
   interrupts the reader to say so.

### Core state

Promote `CastAgencyState` (`Shared/WorldSystems.swift`) into a bounded world
ledger. Keep the existing persisted field names so old vaults decode.

Add to `CastAgencyMovement`:

- `witnessed: Bool` — did a Page carrying this movement ever reach the reader?
- `discoveredAt: Date?` — when the reader later found it, if ever.

Add a pure planner beside the state:

```swift
enum CastAgencyCatchUp {
    static func slots(since last: String?, now: Date, maximum: Int = 6) -> [String]
}
```

Rules:

- Resolve missed slots oldest first, at most `maximum` per return.
- Never resolve more than 12 slots of history regardless of absence length. A
  two-week absence and a two-month absence both yield a bounded handful.
- Deterministic and idempotent: the same absence resolves the same slots.
- Backfilled movements are born `witnessed: false`.
- The ledger ring stays bounded (raise 12 → 40 movements; it is now history,
  not a debug list).

### App behavior

- Delete the `hasStoryMaterial` guard. Replace it with world-seeded material
  (Pass 2 supplies the seed; until then, fall back to thread and relationship
  state, which exist on every day).
- Delete `statusMessage` and `isCastLedgerExpanded` assignment. World motion
  becomes silent.
- Keep `gossipBeliefMovesAlreadyResolved` exactly as is. Double-application
  protection is what makes the ledger honest.
- Keep the distress guard. A hard day still stops the world from acting on the
  reader's Belief.

### Belated discovery

Going silent is only half the pass. Without a discovery route the ledger
becomes an elaborate machine no reader meets.

Unwitnessed movements become findable through surfaces that already exist:

- **Search the Stacks** indexes world movements as fragments, so a reader who
  searches a character or place can reconstruct what happened.
- **Gossip Pages** may open on an older unwitnessed movement rather than the
  current slot, phrased as belated: *You missed the argument in the West
  Stairwell.*
- **The Book's Pocket** may hold one object whose provenance line begins after
  the fact — "Left after the hearing."

Discovery marks `discoveredAt` and never re-offers the same movement.

### Tests

`Tests/InsideCoverCoreTests/CastAgencySovereigntyTests.swift`:

- catch-up bounds: 3 days absent, 2 weeks absent, 2 months absent
- oldest-first ordering and idempotence
- a quiet day still advances the world
- backfilled movements are unwitnessed
- distress still suppresses
- ledger ring stays bounded
- world movement produces no reader-aliveness evidence
- legacy `CastAgencyState` JSON decodes without the new fields

## Pass 2: Cast undertakings — the non-reader seed

### The real defect

`GossipSimulationBuilder.contextTags(for:inputs:)`
(`Shared/StoryEngine.swift`) builds gossip's tag set purely from the reader's
last eight captured pages. `rankedActors` and `rankedThreads` then score
candidates with `overlap * 9` and `overlap * 10` against those tags, and turn
count is `1 + day.capturedPages.count / 3`.

The reader's archive does not merely get referenced. It **casts the scene and
sets its length.** The Academy is a projection of the day the reader had.

Undertakings are the alternative seed that makes decoupling possible. This is
why they must land before the decoupling, not after.

### Core state

Add `Shared/CastUndertakings.swift` to the package target and the pbxproj.

Model on the existing `BookProject` and `BookRunningBusiness`
(`Shared/LiteraryContinuity.swift`) — the Book already has exactly this shape.

```swift
struct CastUndertakingStage: Codable, Equatable, Identifiable {
    var id: String
    var line: String          // what happens at this stage
    var trace: String         // the visible residue it leaves
    var tags: [String]
}

struct CastUndertaking: Codable, Equatable, Identifiable {
    var id: String
    var actorID: String
    var title: String
    var pursuit: String       // what they are trying to do
    var why: String           // why this character in particular
    var stages: [CastUndertakingStage]
    var stageIndex: Int
    var status: CastUndertakingStatus  // active, stalled, concluded, abandoned
    var startedAt: Date
    var lastAdvancedAt: Date
    var nextEligibleAt: Date
}
```

Rules:

- **One active undertaking per character.** Never a quest chain.
- Undertakings advance on the same four-hour world clock, at a much slower
  cadence (day-scale, with jitter). Most slots do not advance one.
- A stage advance is a world movement and enters the ledger.
- An undertaking can **stall** and an undertaking can **fail**. A concluded
  undertaking rests before that character starts another.
- Undertakings advance whether or not the reader ever sees a stage. Most
  stages will be unwitnessed. That is the point.
- The reader is assigned nothing. An undertaking never becomes a quest, an
  invitation, or an ask.

### Authored ladders

Author one undertaking ladder per major cast member. Five stages each. From the
existing discussion:

- **Penny Blackletter** — prove somebody is altering archived headlines:
  notices inconsistent punctuation → quietly interviews witnesses → accuses the
  wrong person → prints a retraction → discovers the alterations are made by a
  word trying to avoid recall.
- **Wicker Eddies** — get into a sealed room without technically entering it.
- **Serenity Brown** — establish an unofficial detour that becomes more useful
  than the official corridor.

Author the remainder in the same voice for Zara Finch, Professor Mook, Pippa
Pilcrow, Orion, Dr. Inkrest, Vellum, and Headmistress Thorne. Thorne's
undertaking must respect her Unseelie canon without exposing it.

Ladders live in a `CastUndertakingRegistry`, keyed by cast slug, in the same
authored-catalog style as `WickerDareRegistry`.

### Decoupling gossip

In `GossipSimulationBuilder`:

- Add an `undertakingSeed` path. When an undertaking is due to advance, it
  supplies the actor and thread directly, bypassing tag overlap entirely.
- Target **30% of world slots** seeded by the world's own business rather than
  the reader's tags. Deterministic per slot, not random per call.
- On a world-seeded slot, the reader callback is **omitted entirely**. No
  constellation, no kept-page reference, no invitation. Proudly irrelevant:

  > A committee has formed to decide whether ladders count as corridors.
  > Penny has refused to cover it. Wicker is therefore covering it.

- Decouple turn count from `day.capturedPages.count`. A quiet day gets the same
  amount of world as a loud one.

### Tests

`Tests/InsideCoverCoreTests/CastUndertakingTests.swift`:

- one active undertaking per character, enforced
- stage advance is day-scale, not slot-scale
- stall, conclude, and rest-before-next
- undertakings advance with zero reader material
- world-seeded slots carry no reader callback
- the 30% proportion holds deterministically across a simulated month
- turn count no longer scales with captured pages
- every authored ladder is well-formed (five stages, trace on each)
- an undertaking never emits a reader ask or assignment

## Pass 3: Consequences that escape their surface

The world-event envelope already proves the pattern: one event alters the
Bleed, Radio, whispers, widgets, braids, story packets, letters, and framing.
Generalize it from authored world events to *emergent* cast state transitions.

### Core state

```swift
struct WorldPressure: Codable, Equatable, Identifiable {
    var id: String
    var origin: WorldPressureOrigin   // rivalry, alliance, undertakingStage, placeRefusal
    var subjectIDs: [String]
    var fingerprints: [WorldFingerprint]
    var beganAt: Date
    var expiresAt: Date               // ~7 days
}
```

A single state transition mints one bounded pressure with several small
fingerprints. When Penny and Wicker cross into open rivalry:

- Penny's Bleed copy becomes more aggressively sourced.
- Radio Free Margin broadcasts an anonymous correction.
- Wicker's letters acquire suspicious footnotes.
- A class description mentions attendance being "unexpectedly audited."
- Their portraits take temporary marginal marks.
- A shop item appears: *Officially Unrelated Red Pencil.*
- An uninvolved character complains about collateral inconvenience.

Rules:

- At most **two active pressures** at once. This is seasoning, not weather.
- A fingerprint modifies existing copy, framing, or catalog availability. A
  fingerprint may never mint a Page or claim a desk slot.
- Pressures expire on their own and leave no residue the reader must clear.
- The uninvolved-bystander fingerprint is required, not optional — collateral
  inconvenience is what makes a dispute feel like it happened in a society.

### Tests

`Tests/InsideCoverCoreTests/WorldPressureTests.swift`: minting from a real
transition, the two-pressure cap, expiry, no Page creation, no desk slot, no
interruption seat, bystander presence, legacy decode.

## Pass 4: Places with memory and temperament

Currently absent — no `PlaceMemory`, no incidents, no disputed purpose. But
`coreLocations` (`Shared/NarrativeCore.swift:2369`) already gives each location
traits, quirks, faults, beliefs, and goals. They are authored characters with
no durable state. This pass layers state on them exactly as `BookInteriorState`
layers state on the Book.

```swift
struct PlaceState: Codable, Equatable, Identifiable {
    var id: String                 // matches the .location entity ID
    var condition: String
    var incidents: [PlaceIncident]
    var favoredOccupantIDs: [String]
    var disputedPurpose: String?
    var slowChange: String?        // one physical detail, changing across seasons
    var refusal: String?           // something it has begun refusing
}
```

- A corridor that repeatedly hosts arguments earns a reputation and starts
  appearing in gossip **as an actor, not a setting**.
- The Kitchens become loyal to Serenity after the cinnamon incident.
- The Great Hall stops amplifying speeches and amplifies only interruptions.
- The Library Stacks misplace the same category of book three times and deny
  involvement.

**Ambiguity is required.** Never adjudicate literal sentience. Characters must
be able to disagree about whether the building is behaving strangely, and the
Book must stay agnostic.

Places accumulate state from world movements that name them, so place memory is
downstream of Passes 1 and 2 rather than a parallel system.

### Tests

`Tests/InsideCoverCoreTests/PlaceMemoryTests.swift`: incident accumulation,
reputation threshold, place-as-actor in gossip, favored occupant from repeated
association, refusal never resolving into a rule, ambiguity preserved (no
surface asserts sentience), bounded incident list, legacy decode.

## Pass 5: Imperfect knowledge

Structured state protects continuity. The reader-facing world should not
therefore sound omniscient.

One event, several accounts, allowed to contradict:

```swift
enum WorldAccountKind: String, Codable {
    case filed        // Penny's version of record
    case rumor        // corridor talk
    case selfServing  // a participant's own letter
    case trace        // a physical residue
    case cautious     // the Book's own hedged reading
}
```

- The underlying ledger movement stays single and consistent.
- Accounts are views of it, generated deterministically from the movement plus
  the account kind.
- Accounts may contradict each other without corrupting world state.
- No canonical answer is required, and the Book must be willing to never
  resolve one.

> Wicker challenged the staircase.
> Later: Wicker insists the staircase challenged him.
> Much later: the maintenance ledger records no staircase on that floor.

This is the pass that makes the world feel larger than the Book's ability to
explain it.

### Tests

`Tests/InsideCoverCoreTests/WorldAccountTests.swift`: multiple accounts from
one movement, permitted contradiction, underlying state unchanged, determinism,
the Book never claims to have resolved an open contradiction, accounts never
fabricate a movement that did not occur.

## Pass 6: The Academy had a season too

Bind the world's own history into monthly and annual editions — not as a status
report, as literary matter: notices, clippings, correspondence, annotations,
crossed-out records.

An edition section drawn from the world ledger:

- Who changed their mind
- What remained unresolved
- Alliances formed
- Rumors Penny withdrew
- Projects that continued without witnesses
- Where everyone was last seen
- **One event the Book still cannot explain**

The last line is the most important. An edition that explains everything is a
report; an edition with one admitted mystery is a chapter.

Build from archive and ledger structures, never by scraping UI. Reuse
`EditionCurator` selection rather than binding every movement.

### Tests

`Tests/InsideCoverCoreTests/AcademySeasonEditionTests.swift`: section builds
from ledger, unwitnessed events appear, the unexplained event is always
present, empty-season graceful behavior, no reader-evidence contamination.

## Verification order

Focused tests after each pass, then:

1. `CastAgencySovereigntyTests`, `WorldSystemsTests`, `BookCuratorTests`
2. `CastUndertakingTests`, story and gossip prompt tests
3. `WorldPressureTests`, world-event tests
4. `PlaceMemoryTests`, `WorldAccountTests`
5. `AcademySeasonEditionTests`, `MonthlyEdition` tests
6. Full `swift test`
7. `git diff --check`
8. Signed app build if the suite is clean

Device checks required for: silence on return after an absence, belated
discovery reading as discovery rather than backlog, pressure fingerprints
appearing without a new Page, and edition section tone.

## Completion boundary

This tranche can make the simulation sovereign. It cannot prove the simulation
feels magical.

The measurable outcomes are structural: the world advances on quiet days, a
proportion of it is unrelated to the reader, consequences outlive their
originating surface, and no world motion becomes reader evidence.

Whether the reader ever thinks *wait — when did this happen?* is a question
only real use over real months can answer.
