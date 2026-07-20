# The Open Window — pointing the Book back out at the world (implementation plan)

Goal: the app's purpose is to re-enchant the reader's *life* — to change how the
street looks when the phone is back in the pocket. The lens mechanics (missions,
compass, souvenirs, sky) are strong but outnumbered by the world-sim on the
3-slot desk, the daytime practice hangs entirely on three fixed-clock
notifications, and the Book never shows the reader their own eyes changing.
Six levers, each independently landable, ordered smallest-first:

1. **The Three-Lane Desk** — the home shelf always holds one *outward* page
   (the lens: real-life noticing), one *fiction* page (the living Academy
   world), and one *other* page (play, reference, returns), with milestone
   pages pinned above the lanes and never evicted.
2. **The World Rings the Bell** — whispers triggered by the actual moon, actual
   places, and actual weather instead of only the clock.
3. **How You See** — receipts that the reader's own perception is changing,
   quoted from their own archive.
4. **One-Way Currency** — the world-sim spends real noticing; it never mints it.
5. **Desk Retirement** — door-duplicating surfaces rest longer so the lens is
   never crowded out.
6. **The Overflow** — *nothing interesting happens at full Belief.* High Glow
   already settles overnight; make the burn steeper and route the excess
   visibly into the cast, so a full wallet is heat to spend, not a trophy.

House laws that must hold across every phase:

- **No new Swift files in `Shared/`** — all engine code goes into files already
  listed in `Package.swift` sources (`WorldSystems.swift`,
  `SurfaceAndCurator.swift`, `LiteraryContinuity.swift`, `PageModel.swift`,
  `StoryEngine.swift`, `SourceAdapters.swift`, `MonthlyEdition.swift`). New
  *test* files under `Tests/InsideCoverCoreTests/` are fine (auto-discovered).
- **Pure logic in `Shared/`, platform glue in `InsideCoverApp/`.** Anything that
  decides *what* to say or *whether* to fire must be a deterministic static
  function in the core so `swift test` covers it. `UN*`/`BG*`/`CL*` calls live
  only in `InsideCoverApp/AppSupport.swift`.
- **No new model calls.** Everything here is deterministic. No streaks, no
  counters, no guilt. Distress-safe where noted.
- **All prose below is final — transcribe it verbatim, do not re-author.**
- Lane membership lives in exactly ONE place (`BookPageType.deskLane`, Phase 1);
  `pointsOutward` (used by Phases 4 and 5) is derived as `deskLane == .outward`.
- This plan assumes the current working-tree Wonder Compass changes (standalone
  `wonder-compass-notice` / `wonder-compass-playful-mission` sources,
  `compassFamily` variety key, `suppressesCastBeliefRipple`) are committed first.
- Run tests per README: `CLANG_MODULE_CACHE_PATH=/private/tmp/insidecover-module-cache
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/insidecover-spm-module-cache swift test`
  (or `scripts/swift-test-resigned.sh <TestClass>`).

---

## Phase 1 — The Three-Lane Desk

The home shelf (limit 3) is repartitioned into three guaranteed lanes so the
Book stays balanced between *looking at your life*, *the living world*, and
*everything else* — instead of letting the loudest-scoring world-sim pages take
all three slots. On a calm desk the result is exactly one page per lane;
milestone pages (First Reading, a constellation naming, an opened seal) are
pinned above the lanes and are never evicted.

### 1a. Lane classification — `Shared/SurfaceAndCurator.swift`

Add beside the existing `extension BookPageType` block (which already holds
`isCompositionPrompt` / `suppressesCastBeliefRipple`):

```swift
/// The three balancing lanes of the home desk. Every page kind belongs to
/// exactly one, so the shelf can guarantee one of each.
enum DeskLane: String, CaseIterable {
    case outward   // the lens: reading your real life, body, and day
    case fiction   // the living Academy world: story, cast, faculty, fae, war
    case other     // play, reference, returns, images, utility
}

extension BookPageType {
    /// The single source of truth for lane membership. `default` is `.other`
    /// so any future page kind (e.g. the coming quotation pages) lands in the
    /// grab-bag lane until it is deliberately reclassified.
    var deskLane: DeskLane {
        switch self {
        // Outward — the reader attends to the actual world / their own day.
        case .wonderCompass, .diary, .mood, .souvenir, .body, .fuel,
             .todaysSky, .location, .anchor, .pactErrand, .rest, .plainPage:
            return .outward
        // Fiction — the Academy world performs, corresponds, or contends.
        case .narrativeOS, .letter, .gossip, .facultyResearch, .supportGuild,
             .inkrestOfficeHours, .faeBargain, .bookFae, .academyClass,
             .elective, .festival, .twoReadings, .castBond, .bookJump,
             .wordNegotiation, .theBleed, .pactDispatch, .pactVerdict,
             .bookOfYou:
            return .fiction
        // Other — everything else: games, reference, returns, images, tools.
        default:
            return .other
        }
    }

    /// Retained for Phases 4 and 5; derived so lane membership has one home.
    var pointsOutward: Bool { deskLane == .outward }
}
```

Notes on the judgement calls (safe to tune later — edge kinds are rare):
- `festival` and the two fae kinds (`faeBargain`, `bookFae`) are **fiction**,
  per the product owner's grouping ("festivals, and Fae Parleys" are the
  living world). This differs from an earlier draft that put them outward.
- `pactErrand` stays **outward** (it sends the reader to do/report something
  real), while `pactDispatch`/`pactVerdict` are fiction (war news).
- `elective` (clubs) is **fiction** even though electives can ask real-world
  favors — the owner grouped "Classes and Clubs" as fiction.
- `weather`, `calendar`, `aboutYou`, `askTheBook`, `enchantment`,
  `illuminatedPhoto`, `bookRemembered`, `bookNotices`, `radio`, etc. fall to
  **other** via `default`.

### 1b. Milestone marking — `Shared/SourceAdapters.swift`

Milestone pages are the Book's rare must-see moments. Mark them explicitly so
the concept is first-class and future milestones just set the flag. Add
`"milestone": "true"` to the `metadata` of these four existing `SurfacePage`
constructions (search each anchor string):

- First Reading (`"firstReading": "true"`, ~line 1740).
- The constellation **naming** page (headline `"The Book Names: …"`, metadata
  `"constellationName"`, ~line 1960).
- The **opened** seal page (metadata `"wagerMoment": "opened"`, ~line 2003).
- The **sealed-today** page (tag `wager-sealed:…`, ~line 2012 block).

Then, on `SurfacePage` (in `Shared/SurfaceAndCurator.swift`, near `varietyKey`):

```swift
/// A rare, must-see moment the Book has earned the right to show: the
/// first reading, a constellation naming, a sealed or opened wager. These
/// are pinned above the desk's three lanes and are never evicted.
var isDeskMilestone: Bool { payload.metadata["milestone"] == "true" }
```

### 1c. Lane-balanced selection — `Shared/SurfaceAndCurator.swift`, `rankedPages`

`rankedPages` currently score-sorts, dedups (`unique`), then fills `limit`
slots under three structural rules (one source family, one type, one
composition prompt). Keep **all** of that as the fallback path, and add a
lane-balanced path for the home desk. The trigger:

```swift
let laneBalanced = limit <= 3 && !mood.distressActive
```

Under **distress** the Book stays quiet and gentle — do **not** force fiction or
"other" onto a hard desk; fall through to the existing loop (which is already
distress-aware, and milestone pages like First Reading already self-defer).

When `laneBalanced`, replace the final pick loop with:

1. Compute `deduped = unique(sortedPages)` exactly as today.
2. **Pin milestones first:** iterate `deduped`, and for each page with
   `isDeskMilestone`, append it (respecting the same `pickedTypes` /
   composition / debut guards) until `picked.count == limit`. Milestones count
   toward their type's lane coverage (a `bookNotices` milestone covers the
   `.other` lane), so a milestone day becomes `[milestone, outward, fiction]`
   rather than dropping a lane twice.
3. **Fill lanes in priority order** `[.outward, .fiction, .other]`: for each
   lane not yet represented among `picked`, take the highest-scoring `deduped`
   page in that lane that passes the existing guards
   (`!pickedTypes.contains(type)`, composition limit, debut limit) and a slot
   remains.
4. **Fill remaining slots** from `deduped` in score order (any lane), same
   guards — so a desk with no fiction candidate at all still fills three slots
   rather than starving.
5. Order the final `picked` by original score rank (stable), so desk display
   and `stabilizedDeskOrder` behave as before.

Extract this into a private helper
`laneBalancedPicks(from deduped:limit:mood:now:) -> [SurfacePage]` and call it
from `rankedPages` when `laneBalanced`, else run the existing loop. Reuse the
existing `compositionLimit` / `debutLimit` / `isManagedDebut` logic verbatim
inside the helper — do not duplicate the guard math.

### 1d. Milestone-safe overrides — `Shared/SurfaceAndCurator.swift`, `surfacedPages`

The sovereign-shelf and braid injections (~line 1026–1056) currently replace
`picked[picked.count - 1]`. Make them lane-aware and milestone-safe:

- Never choose a victim where `victim.isDeskMilestone`.
- **Braid** (`bookOfYou` is fiction lane): replace the current fiction-lane page
  if one exists (keeps the desk balanced — the braid *is* the fiction slot),
  else the last non-milestone slot.
- **Sovereign:** replace the current page in the sovereign type's own lane if
  present, else the last non-milestone, non-`bookOfYou` slot.

Add one helper and use it in both:

```swift
/// The slot a guaranteed injection may claim: prefer a page already in the
/// injected page's lane, otherwise the last non-milestone, non-braid slot.
/// Never returns a milestone slot.
private static func injectionVictimIndex(
    in picked: [SurfacePage],
    preferringLane lane: DeskLane
) -> Int? {
    if let sameLane = picked.lastIndex(where: {
        $0.type.deskLane == lane && !$0.isDeskMilestone && $0.type != .bookOfYou
    }) { return sameLane }
    return picked.lastIndex(where: { !$0.isDeskMilestone && $0.type != .bookOfYou })
}
```

(For the braid injection, pass `preferringLane: .fiction` and allow the braid to
replace an existing non-braid fiction page.)

### 1e. Tests — new file `Tests/InsideCoverCoreTests/ThreeLaneDeskTests.swift`

Build a candidate-rich fixture the way `BookCuratorTests` does (fixed calendar
day per the repo's determinism convention). Assert:

1. **Coverage:** with candidates in all three lanes and world-sim (fiction)
   pages scoring highest, the returned 3 pages contain exactly one `.outward`,
   one `.fiction`, one `.other` (by `type.deskLane`). Repeat at `hour: 7`,
   `hour: 13`, `hour: 20` — the partition is all-hours.
2. **Milestone pinned:** with a First Reading (`isDeskMilestone`) candidate plus
   a full slate, the milestone is always present, and the other two slots are
   `.outward` and `.fiction`.
3. **Milestone never evicted by braid/sovereign:** with a milestone plus an
   evening braid guarantee, the milestone survives and the braid takes the
   fiction slot.
4. **Distress bypass:** with `distress.isActive`, no fiction/other is forced —
   the desk matches the pre-change gentle ranking (assert an existing
   distress-desk expectation still holds).
5. **No starvation:** with candidates in only one lane, the desk still fills up
   to `limit` from that lane (no crash, no empty slots).
6. **Composition rule intact:** never two composition prompts on the desk even
   when both the outward lane (diary) and other lane (aboutYou) offer one.
7. **Wide query unchanged:** at `limit: 6` the result equals the pre-change
   ranked behavior (lane balancing is home-desk only).
8. **Determinism:** identical inputs yield an identical desk.

---

## Phase 2 — The World Rings the Bell (condition-triggered whispers)

Three independent sub-steps, smallest first. All reuse the existing prompt
whisper reply-to-keep pipeline: category `BookWhispers.promptCategoryIdentifier`
(`"book-whisper-prompt"`), `userInfo` shape from `schedulePromptWhispers`
(`InsideCoverApp/AppSupport.swift:3021`), which already gives headless keep.
All are gated behind the existing `promptWhispersEnabled` flag.

### 2a. The Moon Slot (pure local, do first)

The moon is deterministic — we can schedule moon whispers days ahead with
perfect honesty.

**Core (`Shared/StoryEngine.swift`, inside `PlayfulMissionRegistry`):**

1. Add a full-moon mission to `naturalPhenomenonMissions` beside the existing
   waning-gibbous one, keyed on `moon.name == "Full Moon"`:

```swift
mission(
    "moon-full-face",
    "Full Moon Errand",
    "Step somewhere the full moon can see you tonight. Stand still until you can tell what color its light actually is — it is never quite white.",
    "Write the moon's true color, or what stood between you and it.",
    ["natural-phenomenon", "moon", "full-moon", "light", "night", "outside"]
)
```

2. Add a public helper so the scheduler can ask for a moon mission for a
   *future* date without a `BookDay`:

```swift
/// The moon mission for a given night, if that night has one. Pure —
/// safe to call for future dates when scheduling whispers ahead.
static func moonMission(on date: Date) -> PlayfulMission? {
    let moon = MoonPhaseCalendar.phase(on: date)
    switch moon.name {
    case "Full Moon":
        return missions/naturalPhenomenon lookup for "moon-full-face"
    case "Waning Gibbous":
        return ... "moon-waning-gibbous-shadow"
    default:
        return nil
    }
}
```

(Implementer: refactor the two moon missions into `static let` constants so
both `naturalPhenomenonMissions` and `moonMission(on:)` reference the same
values — no duplicated prose.)

**App (`InsideCoverApp/AppSupport.swift`, inside `schedulePromptWhispers`):**

After the existing three-slot loop, for each of the same 3 days: if
`PlayfulMissionRegistry.moonMission(on: date)` is non-nil, schedule one more
notification at **21:30** that night, identifier
`"\(promptIdentifierPrefix)\(scheduledDay.id)-moon"`, same category and
`userInfo` shape (build the `PromptWhisper` via
`PromptWhisperRegistry.promptWhisper(from: mission)`).

**Tests (`Tests/InsideCoverCoreTests/`):** `moonMission(on:)` returns the full
moon mission on a known full-moon date (pick one with `MoonPhaseCalendar` in
the test, don't hardcode blind), nil on a quarter-moon date, and the two moon
missions carry the `natural-phenomenon` tag.

### 2b. Anchor Doorbells (location-triggered missions)

When the reader physically arrives at one of their own anchored places, the
place itself taps the glass. `UNLocationNotificationTrigger` fires without the
app running and needs only the when-in-use location permission the app already
uses for anchors/weather.

**Core (`Shared/WorldSystems.swift`):** add near `AnchorRegistry`:

```swift
/// Decides which anchors get an armed doorbell and what each says.
/// Pure so the core tests cover it; the app layer only converts the
/// plan into UNLocationNotificationTriggers.
enum AnchorDoorbells {
    struct Bell: Equatable {
        var anchorID: String
        var anchorName: String
        var latitude: Double
        var longitude: Double
        var radiusMeters: Double
        var title: String
        var body: String
        var keepPrompt: String
        var tags: [String]
    }

    static let maxArmed = 4
    static let rearmDays = 3

    static func plan(
        anchors: [AnchorRecord],
        lastArmed: [String: Date],
        now: Date
    ) -> [Bell]
}
```

`plan` rules:
- Sort anchors by `visitCount` descending, then `belief` descending, take
  `maxArmed`.
- Skip any anchor whose `lastArmed[anchor.id]` is within `rearmDays` days of
  `now` (a `repeats: false` location trigger fires at most once per arming, so
  the arm date is the honest cooldown).
- Radius: `max(anchor.radiusMeters, 150)`.
- Mission choice: reuse the place-matching logic from
  `PlayfulMissionRegistry.naturalPhenomenonMissions` — extract its water/altitude
  keyword matching into a public
  `PlayfulMissionRegistry.placeMission(matching text: String) -> PlayfulMission?`
  and call it with `"\(anchor.name) \(anchor.kind.rawValue) \(anchor.playerWords)".lowercased()`.
  When nothing matches, fall back deterministically (seed on `anchor.id`) to one
  of the `public`-tagged core missions.
- Bell prose (verbatim; `{place}` = anchor name, `{prompt}` = mission prompt,
  `keepPrompt` = the mission's `proofPrompt`):
  - title: `The {place} door is lit`
  - body: `You're near a page the Book keeps open. {prompt}`
- Tags: the mission's tags plus `"anchor:\(anchor.id)"` and `"doorbell"`.

**App (`InsideCoverApp/AppSupport.swift`):** add
`BookWhispers.refreshAnchorDoorbells(enabled:anchors:now:)`:
- Remove pending requests with prefix `"book-whisper-doorbell-"`.
- If disabled, or `CLLocationManager.authorizationStatus` is not
  when-in-use/always, stop there.
- Read/write `lastArmed` from `UserDefaults.standard` key
  `"anchorDoorbellArmed:<anchorID>"` (a `Date`).
- For each `Bell` in the plan: `CLCircularRegion` (`notifyOnEntry = true`,
  `notifyOnExit = false`), `UNLocationNotificationTrigger(region:repeats:false)`,
  content with the same category and `userInfo` shape as prompt whispers so the
  reply-keeps a page. Record the arm date.

Call it from `ContentView` right where `BookWhispers.refreshPromptWhispers` is
already called on foreground refresh (`ContentView.swift:1546`), passing the
loaded anchors and `promptWhispersEnabled`.

**Tests:** `AnchorDoorbellsTests.swift` — plan caps at 4; sorts by
visitCount/belief; respects `rearmDays`; radius floor 150; water-y anchor names
select the water mission; prose matches the templates verbatim; a bell's tags
contain `anchor:<id>`.

### 2c. The Weather Bell (live-weather background check — hardest, do last)

A rain mission delivered *while it is raining* is worth ten scheduled ones.

**Core (`Shared/StoryEngine.swift`, `PlayfulMissionRegistry`):** add

```swift
/// The mission that matches live weather, if the sky is doing something
/// worth interrupting for. Pure; the background task supplies the text.
static func weatherBellMission(weatherText: String) -> PlayfulMission?
```

Matching (reuse the private `containsAny`; check in this order, first hit wins):
- storm/wind words (`"pressure drop", "dropping pressure", "falling pressure",
  "storm", "thunder", "squall", "front", "gust"`) → the existing
  `storm-wind-shift` ("Wind Change Watch") mission.
- rain words (`"rain", "drizzle", "shower", "downpour"`) → the existing
  `sky-rain-stage` ("Rain Journey") mission from `attentionMissions`.
- snow/fog words (`"snow", "fog", "mist"`) → the existing `weather-scent`
  ("Weather Has A Smell") mission.
- otherwise nil (bright/ordinary skies do not interrupt).

(Implementer: the named missions already exist — reference them, don't copy
their prose. If they are array literals, hoist them to `static let` constants
first, same refactor style as 2a.)

**App (`InsideCoverApp/AppSupport.swift`):** new enum `WeatherBell`, modeled
line-for-line on `OvernightScribe` (same file, ~line 3201) except:
- `taskIdentifier = "com.openclaw.enchantify.insidecover.weather-bell"`.
- Use `BGAppRefreshTaskRequest` / `BGAppRefreshTask` (not processing; no
  external-power requirement), `earliestBeginDate = now + 2.5 * 3600`.
- Handler: `scheduleNext()` first, then:
  1. Bail (success) if `promptWhispersEnabled` is false (read the same
     `UserDefaults` key the `@AppStorage` uses) or a bell already rang today
     (`UserDefaults` key `"weatherBellLastFired"` is within today).
  2. Fetch current weather with the same reader the app already uses
     (`WeatherLocationReader`) wrapped in a ~15-second timeout `Task`; on
     failure/timeout, complete without firing. **Honesty guard: never fire from
     stale or missing weather.**
  3. `PlayfulMissionRegistry.weatherBellMission(weatherText:)` on the fetched
     phrase+forecast (lowercased, joined). Nil → done.
  4. Schedule an immediate notification (trigger `nil`), prompt-whisper
     category/userInfo shape, identifier `"book-whisper-weather-bell"`, and
     record `weatherBellLastFired`.
- Register next to `OvernightScribe.register()` at launch
  (`InsideCoverApp/InsideCoverApp.swift` — find the existing call).

**`InsideCoverApp/Info.plist`:** append
`com.openclaw.enchantify.insidecover.weather-bell` to the existing
`BGTaskSchedulerPermittedIdentifiers` array (line ~11).

**Tests:** `weatherBellMission` — storm text → Wind Change Watch; rain text →
Rain Journey; fog → Weather Has A Smell; `"sunny and bright"` → nil; storm wins
over rain when both words present.

---

## Phase 3 — How You See (perception receipts)

The Book proves it is learning the reader (`TaughtReading`,
`Shared/LiteraryContinuity.swift:1187`). This phase proves the reverse — the
reader's eyes are changing — using scoring that already exists:
`SentenceBuilderEngine().analyze(_:) -> SentenceBuilderAnalysis` with
`memoryStrength: Int` (count of present craft marks) and `isVivid`
(`memoryStrength >= 3`).

**Never shame.** If the archive is young or the delta isn't real, the feature
stays perfectly silent. Quiet over rerun (house style — see reflective
de-repetition).

### 3a. Engine — `Shared/LiteraryContinuity.swift`, add after `TaughtReading`

```swift
/// Receipts that the reader's own seeing is changing: an early plain
/// sentence beside a recent vivid one, both quoted from the archive.
/// Deterministic, and silent unless the improvement is real.
enum HowYouSee {
    struct SeeingReceipt: Equatable {
        var earlierQuote: String
        var earlierMonthName: String   // "March"
        var recentQuote: String
        var earlierStrength: Int
        var recentStrength: Int
    }

    static let minimumAuthoredPages = 40
    static let minimumSpanDays = 60

    /// Reader-authored seeing: userAuthored keeps of these types with
    /// >= 4 words of userInput.
    static let seeingTypes: Set<BookPageType> =
        [.souvenir, .diary, .mood, .wonderCompass, .plainPage]

    static func receipt(days: [BookDay], now: Date = Date()) -> SeeingReceipt?
}
```

`receipt` algorithm (all with one `SentenceBuilderEngine()`):
1. Collect qualifying pages (type in `seeingTypes`, `origin == .userAuthored`
   where origin is available on the page — otherwise `!userInput.isEmpty`),
   with `userInput` of ≥ 4 words. Fewer than `minimumAuthoredPages` → nil.
2. Span between first and last qualifying page < `minimumSpanDays` days → nil.
3. Early window = first 30 days of the archive; recent window = last 30 days
   before `now`.
4. Early average `memoryStrength` and recent average. Require
   `recentAverage >= earlierAverage + 0.75` **or** the recent windows' vivid
   share (`isVivid` fraction) ≥ 2× the early share (guard early share > 0; if
   early share is 0, require recent share ≥ 0.25). Otherwise → nil.
5. `earlierQuote` = the shortest early-window sentence with
   `memoryStrength <= 1` (first sentence of the input via the existing
   `bookPreviewSentenceLimit(1)` helper); `recentQuote` = the recent-window
   sentence with the highest `memoryStrength` (must be `isVivid`). Same page
   may never supply both. If either is missing → nil.
6. Clip both quotes to 110 characters at a word boundary (copy
   `TaughtReading.clipped`).

### 3b. The Notices page — `Shared/SourceAdapters.swift`

In the Book Notices adapter, when `HowYouSee.receipt(...)` is non-nil AND the
how-you-see notice hasn't spoken in **90 days** (use the exact `spoke:` tag rest
mechanism the reflective notices already use — find `spoke:` handling in the
notices adapter and copy it with tag `spoke:how-you-see`), emit a notice
candidate that outranks the ordinary notice that day (score +8 over the
adapter's normal notice score).

Body prose (verbatim; fill `{earlierMonth}`, `{earlierQuote}`, `{recentQuote}`):

> I am careful with certainty. But this I can show you, in your own hand.
>
> In {earlierMonth} you kept: "{earlierQuote}"
>
> This week you kept: "{recentQuote}"
>
> The second one has weather in it, and weight, and something moving. The world
> did not get better written. You started reading it closer. I only keep the
> pages — the seeing is yours.

Title: `How You See`. Attach two `NoticePatternCard`s (the evidence-card type
notices already carry): card one titled `Then`, text = earlier quote +
month; card two titled `Now`, text = recent quote. Reuse the existing
`feedbackPrompt` ("Did the Book read this right?") so the reader can correct it.

### 3c. The monthly edition section — `Shared/MonthlyEdition.swift` + `InsideCoverApp/MonthlyEditionPDF.swift`

- Add `var howYouSee: HowYouSee.SeeingReceipt?` to `MonthlyEdition`; populate in
  the builder by calling `HowYouSee.receipt` over the full archive (not just the
  month) — the receipt is only included when non-nil, and only in months where
  the recent window overlaps the bound month.
- PDF: render a short section titled **"How You See"** after "What The Book
  Noticed": the two quotes as pull-quotes with the month names, and one closing
  line (verbatim): `Same reader. Closer eyes.` Match the existing section
  renderer primitives (section opener band, date chips); no new visual system.

### 3d. Tests — `Tests/InsideCoverCoreTests/HowYouSeeTests.swift`

Fixture: builder that produces N days of pages with controlled `userInput`
(plain sentences like "fine, walked" early; vivid ones like "the kettle hissed
and the cold window went soft with steam" late — verify with a quick
`analyze` call in the test that your vivid fixtures really score ≥ 3).

1. Young archive (< 40 authored pages) → nil.
2. Short span (< 60 days) → nil.
3. No improvement (vivid early AND late) → nil. **This is the anti-shame test.**
4. Real improvement → receipt with the expected two quotes; earlier ≠ recent
   page.
5. Determinism: same input, same receipt.
6. Notices rest: after emitting once, the adapter stays quiet for 90 days
   (follow the existing reflective-rest test pattern in the suite).

---

## Phase 4 — One-Way Currency (the world-sim spends noticing, never mints it)

The Fae already model this correctly: gifts are fronted, and only *sensory
field reports* pay. Bring three other loops in line. Small, surgical nerfs —
nothing here should feel like punishment, only like consumption pages going
quiet in the wallet.

### 4a. Audit: `readerBeliefReward` on consumption pages

`grep -n "readerBeliefReward" Shared/*.swift`. For every site that sets it on a
surface whose type is one of `.lore, .quip, .helpTips, .patreon, .radio,
.gossip, .illustration`: remove the metadata (the working-tree diff already did
exactly this for compass pages — same move). Add one test per removed site
asserting the surfaced page's `metadata["readerBeliefReward"]` is nil (copy the
existing compass assertions in `WorldSystemsTests`).

### 4b. The daily tide ember — `Shared/WorldSystems.swift`, `BeliefEconomyEngine`

Locate the reader's keep ember inside `runBeliefEconomyDailyTick` (the "small
ember for keeping pages" grant). Split it:

- **Full ember (current amount):** the day's kept pages include at least one
  page where `page.type.pointsOutward` (Phase 1's property) **or** a
  reader-authored page with non-empty `userInput`.
- **Reduced ember (1):** pages were kept, but all were consumption
  (generated/lore/radio/etc. with no reader input).
- No pages kept: unchanged (whatever it does today).

Record the distinction in `recentMovements` so the overnight digest stays
legible (line, verbatim): full — `Your noticing fed the Glow.`; reduced —
`The Book banked a quiet ember.`

Tests in `WorldSystemsTests`: a day of only-lore keeps yields the reduced
ember; one souvenir with input yields the full ember; a `pointsOutward` keep
with empty input (e.g. todaysSky) also yields the full ember.

### 4c. Chosen register gated on recent outward keeps — `Shared/StoryEngine.swift`

Being *picked* (Entrusting / Summons / Reader's Mark) should be downstream of
having *looked*.

1. Add to `StoryRecipeRequirement` (line ~5428): `case outwardWake`.
2. Add a helper on `StoryFormRegistry`:

```swift
/// True when the archive holds at least one outward keep (a mission,
/// sky, place, or errand page — or any compass-step tag) in the last
/// 7 days. The chosen register is earned by looking, not by waiting.
static func hasRecentOutwardKeep(days: [BookDay], now: Date) -> Bool
```

Match: page `createdAt` within 7 days AND (`type.pointsOutward` OR tags contain
a `compass-step:` prefix OR tags contain `playful-mission`).

Note: `pointsOutward` includes the plain capture doors (diary, inner weather,
fuel), so a faithful journaler passes this gate without ever running a mission.
That is intended — attention to the real day qualifies; the `.deepBond`
requirement and the day-scale cooldowns still carry the chosen register's
scarcity. This gate only fences out pure-consumption play.

3. In the eligibility filter (line ~1895–1904, beside the `.deepBond` check):

```swift
if requirements.contains(.outwardWake) && !StoryFormRegistry.hasRecentOutwardKeep(days: inputs.days, now: now) { return false }
```

(If `inputs.days` isn't already threaded into that function, follow how the
`.deepBond` check gets `inputs.narrative` — the `inputs` bundle is in scope.)

4. Append `.outwardWake` to the `requirements` arrays of exactly three bundled
   recipes: the Entrusting, the Summons, and the Reader's Mark (find by their
   recipe ids in the bundled recipe list; they are the three with day-scale
   cooldowns 240h/336h/192h).

Decoding safety: `StoryRecipeRequirement` is `String, Codable`; only bundled
recipes gain the new case, so reader-imported packs are untouched. Confirm the
pack decoder's existing invalid-recipe tolerance test still passes.

Tests: chosen-register recipe ineligible with a 7-day archive of only diary
pages; eligible once one kept page carries `compass-step:sense`; the other
(non-chosen) recipes are unaffected.

### 4d. What NOT to touch

- Keep/dismiss source warming (once/day, capped) — leave as is; it's
  preference-learning, not income.
- Entity/thread/relationship deltas on gossip/lore keeps — leave; the *world*
  may move, only wallets are gated.
- Festival/enchantment Belief bonuses — leave; the Almanac's invitations are
  outward by nature.

---

## Phase 5 — Desk Retirement (door pages rest longer)

The desk has 3 slots and ~57 adapters. Pages that merely *duplicate a door the
reader already owns* (the radio has the dial, the shop is in the Glow menu, the
inventory is a flyleaf) should visit the desk rarely instead of contending
daily.

### 5a. Slow-desk types — `Shared/SurfaceAndCurator.swift`

Find `CuratorMood.allowsTypeRefresh` (the type-refresh cooldown). Add:

```swift
/// Door-duplicating page kinds: surfaces that only re-open a door the
/// reader already owns elsewhere (the dial, the Glow menu, the flyleaf).
/// They visit the desk as occasional reminders, not daily contenders.
static let slowDeskTypes: Set<BookPageType> =
    [.radio, .inventory, .helpTips, .patreon, .quip]
```

and give those types a **72-hour** refresh cooldown where ordinary types use
the existing (shorter) one. Keep the existing "never starve the desk" fallback
untouched — if the pool would be empty, the cooldown already yields.

Explicitly NOT slowed: `.lore` (it feeds Shadow Wonder and events), `.gossip`
(world motion), `.bookShopPreview`-style sources (already weekly), anything
`pointsOutward`.

### 5b. Maturity gates — `Shared/SurfaceAndCurator.swift`, `BookMemoryGate`

Read `BookMemoryGate.locks(_:keptPageCount:)` and add, following its existing
entry pattern: `.patreon` and `.quip` locked until `keptPageCount >= 30`. (The
first month belongs to the loop and the lens, not the tip jar.)

### 5c. The house law — `PROJECT_OVERVIEW.md`

Add one line to the Design principles list (verbatim):

```
- **One in, one out:** a new page family only joins the desk rotation when an
  existing one is retired, slowed, or moved behind a door. The desk has three
  slots; the lens must never be crowded out of the daylight one.
```

### 5d. Tests

`BookCuratorTests`: a radio page shown at noon does not reappear on the desk at
+24h or +48h but can at +73h; quip absent below 30 kept pages, present above;
desk never starves (all-slow candidate pool still fills slots via the fallback).

---

## Phase 6 — The Overflow (high Belief burns, and the burn goes somewhere)

*Nothing interesting happens at full Belief.* The sink already exists:
`BeliefEconomyEngine.dailyTick` (`Shared/WorldSystems.swift` ~line 8105) settles
reader Glow above `readerSoftCeiling` (74) by −1 per night, −3 at ≥90, with the
note "Excess Glow settled back into the paper overnight." Two problems: the
burn is too gentle to force a spending decision, and the excess vanishes into
nothing — invisible, so it teaches nothing. Fix both.

### 6a. Steepen the settle — `Shared/WorldSystems.swift`, `dailyTick`

Replace the current two-tier delta (`>= 90 ? -3 : -1`) with three tiers:

```swift
let delta: Int
switch context.readerBelief {
case 90...: delta = -4
case 82...: delta = -2
default:    delta = -1   // 75...81 (the branch already requires > readerSoftCeiling)
}
```

### 6b. Route the overflow into the cast

The excess should visibly drift to whoever the reader has been paying attention
to — a loss of *choice*, not just of points, which is the honest incentive to
spend deliberately (the Glow menu, Chapter talismans, pressing Pact claims,
Book Jump stakes all already exist as spend doors; add none).

Implementation: the `tideCandidates` selection (recently-touched entities under
70, non-Nothing, sorted by belief + weight) is currently computed *below* the
reader tide/settle block. **Hoist that computation above the reader block** (it
has no dependency on `readerDelta`). Then, inside the settle branch, after
applying the reader delta:

```swift
if let catcher = tideCandidates.first {
    let caught = min(abs(delta), 2)
    entityDeltas[catcher.id, default: 0] += caught
    movements.append(movement(.entity, id: catcher.id, name: catcher.name, delta: caught, reason: .dailyTide, now: context.now, note: "\(catcher.name) caught your overflowing light."))
}
```

And change the reader-side settle note (verbatim):
`Unspent Glow overflowed — the paper cannot hold more than a life spends.`

Rules that must hold:
- The catcher comes from the existing `tideCandidates` filter, so it is always
  recently-touched, under 70, and never Routine or its kin.
- If no candidate exists, the overflow settles into the paper exactly as today
  (keep the current note for that case).
- The catcher may receive both the ordinary tide point and the overflow on the
  same night; that is fine (still capped by the <70 filter at selection time).
- `glowInvitation` (rises at reader Belief 80, warns at 90) is untouched — it
  remains the deliberate front door for spending; the overflow is what happens
  when the reader ignores it.

### 6c. Tests — extend `WorldSystemsTests` (the Belief-economy tests live there)

1. Reader at 91 with one touched entity under 70: reader −4, entity +2, and
   `recentMovements` contains both verbatim notes.
2. Reader at 84: −2, entity +2. Reader at 76: −1, entity +1.
3. Reader at 91 with no eligible entity: reader −4, no entity delta, note is
   the existing "settled back into the paper" line.
4. Reader at 60: no settle (tide branches unaffected — assert existing ember
   behavior still passes).
5. An entity tagged `nothing` is never the catcher.
6. Day-gating unchanged: a second `dailyTick` on the same day is a no-op.

---

## Suggested landing order

| # | Phase | Size | Risk |
|---|-------|------|------|
| 1 | The Three-Lane Desk (1a–1e) | L | medium — reshapes curator selection; expect curator-test fallout to update |
| 2 | Moon Slot (2a) | S | low — pure local |
| 3 | The Overflow (6a–6c) | S | low — two edits inside one function |
| 4 | One-Way Currency (4a–4d) | M | low — nerfs, well-tested seams |
| 5 | Desk Retirement (5a–5d) | S | low |
| 6 | How You See (3a–3d) | M | medium — new engine, prose surfaces |
| 7 | Anchor Doorbells (2b) | M | medium — CoreLocation glue |
| 8 | Weather Bell (2c) | M | highest — background task + async weather; land last |

Each phase must leave `swift test` green and is individually revertable.
