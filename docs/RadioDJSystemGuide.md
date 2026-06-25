# ReEnchanted Radio DJ System Guide

This guide is for adding lots of prerecorded DJ banter that reacts to the app's state. The DJ system does not do live speech generation. Every spoken line is a prerecorded asset, and the app chooses the right clip at runtime from typed metadata.

The main code lives in:

- `Shared/WorldSystems.swift`: station registry, tracks, DJ banter definitions, trigger conditions, selector.
- `InsideCoverApp/AppSupport.swift`: playback loop, audio file lookup, lock-screen now playing.
- `InsideCoverApp/ContentView.swift`: builds page/weather context for reactive banter.
- `Tests/InsideCoverCoreTests/RadioBanterTests.swift`: focused tests for selection and bundled audio.
- `InsideCoverApp/RadioAudio/`: bundled songs and DJ audio.

## Station Sound And Personality

Use this section as the creative north star when adding songs, DJ scripts, transitions, sponsors, or reactive clips. The three main stations are related: all live in the same enchanted, ear-candy, fae-electronic world, but each tilts the palette differently.

| Station | Core Sound | Emotional Color | DJ/Banter Feel |
|---|---|---|---|
| Fae-Fi | Ear-candy glitchy folktronica with medieval instruments, dandelion synths, plucked strings, little bells, recorder/pipe colors, bright chopped textures, mossy percussion. | Sun-dappled, playful, caffeinated, wonder-forward, mischievous but safe. | Penny Blackletter treats all the brightness like evidence. Dry, precise, amused, secretly warm. Banter can notice souvenirs, Wonder Compass pages, bright weather, festivals, and tiny true details. |
| Mothlight Beats | Bittersweet sibling of Fae-Fi: the same fae-folktronica/glitch/medieval-instrument DNA, but duskier, slower, softer-edged, more memory-soaked. | Wistful, tender, lamp-lit, aching in a beautiful way, emotionally resonant without becoming gloomy. | Professor Eleanor Euphony hears feelings as harmony. Banter should be lush, sensory, gentle, musical, and tuned to mood pages, diary pages, remembered pages, rain, dusk, and pages kept today. |
| Thornwave | Darker cousin of the same enchanted electronic style: trip-hop, sultry low end, future-garage shadows, smooth jazzy chords, smoky lounge textures, sharp bramble percussion, night-fae bass. | Dark, sleek, seductive, dangerous, funny, after-midnight, bargain-with-teeth energy. | Wicker Eddies is smooth, amused, and dangerous, but not fake-edgy. Banter can react to story pages, Fae bargains, gossip, grey pressure, storms, and anything with doors, names, pacts, or consequences. |

Practical rule: if a new track could almost belong on another core station, change the lighting. Fae-Fi is bright morning sugar and medieval sparkle. Mothlight is the same magic after sunset, heard through memory. Thornwave is that magic in a velvet basement with a bassline and a contract.

### Station DJs

**Fae-Fi: Penny Blackletter**  
Penny is a dry, observant record-keeper from The Bleed who has somehow ended up hosting the sunniest frequency on the band. She is precise, skeptical of anything too polished, and quietly delighted by honest little details. Her comedy comes from treating faerie brightness, pixie chaos, and ear-candy beats like items that need to be filed correctly. Write her as warm underneath the deadpan: she notices the one true particular and wants the listener to keep it.

**Mothlight Beats: Professor Eleanor Euphony**  
Euphony is a sound-and-synesthesia professor who hears emotion as harmony. She speaks like she is tuning the room before the next sentence: warm, slow, lush, attentive, a little overdescriptive in a beautiful way. Her clips should make feelings feel allowed rather than solved. She is strongest when reacting to memory, mood, diary pages, rain, dusk, and the ache of lovely things ending without making the station bleak.

**Thornwave: Wicker Eddies**  
Wicker is sharp, smooth, funny, and dangerous. He punctures false magic for sport, tests belief by pressing on it, and can make doubt feel like dark companionship. He should sound amused rather than shouty, seductive rather than cartoon-villainous, and occasionally let real care show through the teeth. His clips fit story pressure, bargains, gossip, storms, grey, doors, names, pacts, and consequences.

## What The DJ Can Read

The selector receives a `RadioWorldContext`. A clip can react to any of these fields:

| Field | Condition key | Meaning |
|---|---|---|
| Time of day | `timeOfDay` | `"dawn"`, `"day"`, `"dusk"`, `"night"` derived from local clock. |
| Nothing pressure | `minGrey`, `maxGrey` | Grey pressure on a 0-100 scale. |
| Festival state | `festivalOnly` | True when the almanac has an active festival window. |
| Listening streak | `minListeningDays` | Distinct days the active station has been heard. |
| Weekday | `weekdays` | Calendar weekday numbers: `1 = Sunday`, `7 = Saturday`. |
| Recent page types | `pageTypes`, `minRecentPagesOfType` | Kept pages from the last 7 days, counted by `BookPageType`. |
| Recent source IDs | `sourceIDs` | Raw `page.sourceID` values from recent kept pages, normalized lowercase. |
| Recent source tags | `sourceTags` | Tags on recent kept pages, normalized lowercase. |
| Pages kept today | `minKeptToday` | Count of pages kept since local midnight. |
| Current weather | `weatherTags` | Tags inferred from weather/enchanted weather text. |
| Last kept page type | `lastKeptPageTypes` | The most recent kept page's `BookPageType`. |

All condition fields are additive. If you set three fields, all three must match. If a field is `nil`, the selector does not care about it.

## Time And Weather Tags

Time bands come from the current hour:

- `dawn`: 5:00-7:59
- `day`: 8:00-16:59
- `dusk`: 17:00-20:59
- `night`: 21:00-4:59

Weather tags are inferred from weather text and symbols:

- `storm`: storm, thunder, bolt
- `rain`: rain, drizzle, shower
- `snow`: snow, sleet, ice, freezing
- `fog`: fog, mist, haze
- `wind`: wind, gust, breeze
- `cloud`: cloud, overcast
- `bright`: clear, sun, bright
- `hot`: hot, heat, warm, 8, 9
- `cold`: cold, chill, freeze, snow, ice, 3, 2, 1

The numeric checks are intentionally broad because temperature text may be stringified. If a clip needs more precise weather later, add a new explicit tag in `RadioPageContext.weatherTags(...)`.

## Valid Page Types

Use these Swift enum cases in `pageTypes` or `lastKeptPageTypes`:

`mood`, `diary`, `souvenir`, `rest`, `body`, `fuel`, `weather`, `location`, `quip`, `aboutYou`, `wonderCompass`, `lore`, `patreon`, `illustration`, `illuminatedPhoto`, `narrativeOS`, `gossip`, `facultyResearch`, `letter`, `supportGuild`, `bookOfYou`, `askTheBook`, `inkrestOfficeHours`, `faeBargain`, `bookFae`, `pactDispatch`, `festival`, `twoReadings`, `castBond`, `todaysSky`, `radio`, `bookJump`, `enchantment`, `anchor`, `academyClass`, `elective`, `packPage`, `gamePage`, `calendar`, `helpTips`, `welcome`, `marginsAtlas`, `bookConnections`, `bookRemembered`, `bookNotices`, `glowInvitation`, `theBleed`, `inventory`.

In Swift, write them with dots: `.souvenir`, `.bookRemembered`, `.theBleed`.

## How Clips Are Chosen

The app plays songs and slips DJ clips between them.

1. A real audio track finishes.
2. The playout loop decides whether to insert banter. After two quiet songs, it forces an eligible break. After one song, it usually inserts a break, especially if a song-bound intro/outro is available.
3. `RadioStationRegistry.nextBanter(...)` filters clips by conditions and song placement.
4. It avoids recently heard clip IDs.
5. It avoids categories heard in the last two breaks when possible.
6. It uses stable weighted selection, so higher `weight` clips are more likely but not guaranteed.
7. The chosen clip plays if an audio asset exists. Otherwise, its `caption` appears briefly and music resumes.

Important: sequencing depends on real track files. If a station falls back to the procedural synth bed, there is no track-finished callback to create between-song banter.

## Clip Categories

Each `RadioBanter` has a category:

- `stationID`: callsign, welcome, "you are listening to..."
- `transition`: song-to-song handoff, including intro/outro lines.
- `sponsor`: in-world ad reads.
- `gossip`: rumors, cast chatter, The Bleed style lines.
- `news`: world/current-state reports.
- `network`: cross-station or hidden-band interruptions.

Categories affect repetition. For example, the selector tries not to play two recent sponsor-style clips together if another eligible category exists.

## Naming Rules

There are two names for every clip:

- `id`: stable code identity. Lowercase, kebab-case, station-prefixed.
- `assetName`: audio filename without extension. Pascal-ish `DJ_...` style.

Recommended `id` format:

```text
<station-id>-<trigger-or-category>-<short-meaning>
```

Examples:

```text
faefi-pages-souvenir-cluster
mothlight-weather-rain
thornwave-pages-fae-bargain
bleed-time-after-midnight
```

Recommended `assetName` format:

```text
DJ_<station_slug>_<category_or_trigger>_<short_meaning>_<NN>
```

Examples:

```text
DJ_faefi_pages_souvenir_01
DJ_mothlight_weather_rain_01
DJ_thornwave_pages_bargain_01
DJ_bleed_time_after_midnight_01
```

Use these station slugs for current stations:

- Fae-Fi: `faefi`
- Mothlight Beats: `mothlight`
- Thornwave: `thornwave`
- The Bleed: `bleed`
- Midnight Bindery: `midnight_bindery`
- Goblin Market Jazz: `goblin_market`

Audio file extensions supported by the loader: `.m4a`, `.mp3`, `.wav`, `.aac`, `.caf`, `.aiff`.

Bundled files should go in `InsideCoverApp/RadioAudio/` and be named exactly:

```text
<assetName>.m4a
```

Runtime/user files may also be resolved from the app Documents folder, `Documents/Radio`, or `Documents/RadioPacks`.

## Adding A Basic Clip

Add a `RadioBanter(...)` to the station's `banters:` array in `Shared/WorldSystems.swift`.

```swift
RadioBanter(
    id: "faefi-gossip-window",
    category: .gossip,
    assetName: "DJ_faefi_gossip_02",
    caption: "From my desk at The Bleed...",
    conditions: nil,
    weight: nil
)
```

This clip can play whenever Fae-Fi is active. If the audio file is missing, the caption still appears, so you can wire and test before recording.

## Adding A Reactive Page Clip

Use `pageTypes` and `minRecentPagesOfType`.

```swift
RadioBanter(
    id: "mothlight-pages-memory-cluster",
    category: .gossip,
    assetName: "DJ_mothlight_pages_memory_01",
    caption: "I'm hearing several old pages close together...",
    conditions: RadioBanter.Conditions(
        pageTypes: [.bookRemembered, .diary, .mood],
        minRecentPagesOfType: 3
    ),
    weight: 5
)
```

This fires when at least 3 recent kept pages, across the last 7 days, are any of `.bookRemembered`, `.diary`, or `.mood`.

If you set `minRecentPagesOfType` without `pageTypes`, it counts all recent kept pages.

## Adding A Last-Page Clip

Use `lastKeptPageTypes` when the most recent kept page matters more than the whole week.

```swift
RadioBanter(
    id: "mothlight-pages-last-mood-night",
    category: .gossip,
    assetName: "DJ_mothlight_pages_mood_night_01",
    caption: "The last page you kept had weather inside it...",
    conditions: RadioBanter.Conditions(
        timeOfDay: ["dusk", "night"],
        lastKeptPageTypes: [.mood, .diary]
    ),
    weight: 4
)
```

## Adding A Weather Clip

Use `weatherTags`.

```swift
RadioBanter(
    id: "thornwave-weather-storm-grey",
    category: .news,
    assetName: "DJ_thornwave_weather_storm_grey_01",
    caption: "Storm pressure on the band and grey at the edges...",
    conditions: RadioBanter.Conditions(
        timeOfDay: ["dusk", "night"],
        minGrey: 35,
        weatherTags: ["rain", "storm", "wind"]
    ),
    weight: 5
)
```

This requires night/dusk, grey pressure at least 35, and at least one matching weather tag.

## Adding A Source Or Tag Clip

Use `sourceIDs` when you care where a page came from, and `sourceTags` when you care what it carried.

```swift
RadioBanter(
    id: "faefi-source-wonder-compass",
    category: .news,
    assetName: "DJ_faefi_source_wonder_compass_01",
    caption: "Wonder Compass traffic is bright this morning...",
    conditions: RadioBanter.Conditions(
        sourceIDs: ["wonder-compass"],
        timeOfDay: ["dawn", "day"]
    ),
    weight: 3
)
```

Source IDs and tags are normalized lowercase and trimmed before comparison.

## Adding A Kept-Today Clip

Use `minKeptToday`.

```swift
RadioBanter(
    id: "mothlight-pages-kept-today",
    category: .news,
    assetName: "DJ_mothlight_pages_kept_today_01",
    caption: "You've kept enough pages today for the Book to start humming...",
    conditions: RadioBanter.Conditions(minKeptToday: 4),
    weight: 3
)
```

This is good for daily activity acknowledgement.

## Adding A Listening-Streak Clip

Use `minListeningDays`.

```swift
RadioBanter(
    id: "thornwave-listening-four-days",
    category: .stationID,
    assetName: "DJ_thornwave_listening_four_days_01",
    caption: "Fourth day on Thornwave. That stops being an accident.",
    conditions: RadioBanter.Conditions(minListeningDays: 4),
    weight: 4
)
```

Listening days are distinct local days where the station was actually tuned.

## Adding Song-Bound Transitions

Use `trackID` and `placement`.

```swift
RadioBanter(
    id: "thornwave-intro-bramble-bass",
    category: .transition,
    assetName: "DJ_thornwave_transition_bramble_bass_intro",
    caption: "The drop sounds like a door you were warned about, opening...",
    conditions: nil,
    weight: nil,
    trackID: "thornwave-bramble-bass",
    placement: .intro
)
```

Placement rules:

- `.intro`: plays immediately before the matching track.
- `.outro`: plays immediately after the matching track.
- `nil` with a `trackID`: either side is allowed.

When an intro is selected, the app pins the upcoming track so the spoken promise is kept.

## Adding A New Track

Tracks use the same asset resolver as DJ clips.

```swift
RadioTrack(
    id: "thornwave-whispering-shadows",
    title: "Whispering Shadows",
    artist: "Thornwave",
    assetName: "RadioThornwaveWhisperingShadows",
    durationSeconds: 129,
    moodTags: ["dark", "night", "shadow"]
)
```

Use:

- `id`: lowercase kebab-case, station-prefixed.
- `title`: display name.
- `artist`: usually station name.
- `assetName`: song filename without extension.
- `durationSeconds`: set if known; not required for playback but useful for metadata.
- `moodTags`: future curation hooks and documentation.

Song assets should go in `InsideCoverApp/RadioAudio/` as `<assetName>.m4a`.

## Adding A Hidden Pirate Clip

The hidden station is `the-bleed` at `97.3`. It is excluded from visible preset lists but tunable by exact dial step.

```swift
RadioBanter(
    id: "bleed-pages-gossip-cluster",
    category: .network,
    assetName: "DJ_bleed_pages_gossip_01",
    caption: "Unauthorized pattern detected...",
    conditions: RadioBanter.Conditions(
        pageTypes: [.gossip, .theBleed],
        minRecentPagesOfType: 2
    ),
    weight: 6
)
```

Use `category: .network` for pirate interruptions, intercepts, and cross-band anomalies.

## Weight Guidelines

`weight` is relative inside the eligible pool.

- Leave `nil` for normal rotation.
- Use `3-4` for reactive clips you want the user to notice.
- Use `5-6` for rare, highly contextual clips such as The Bleed or perfect page/weather matches.
- Avoid very high weights unless the condition is narrow. High-weight broad clips can crowd out station texture.

The selector already boosts some categories:

- First station ID in a session gets favored.
- Bound transitions get favored when they fit the current song seam.
- Gossip gets favored at dusk/night or when grey is at least 35.
- News gets favored near the start of the hour and during festivals.
- Conditions based on pages/weather/time get a contextual boost.

## Current Reactive Clip Inventory

Fae-Fi:

- `faefi-pages-souvenir-cluster` → `DJ_faefi_pages_souvenir_01`
- `faefi-pages-wonder-morning` → `DJ_faefi_pages_wonder_morning_01`
- `faefi-weather-bright` → `DJ_faefi_weather_bright_01`

Mothlight Beats:

- `mothlight-pages-memory-cluster` → `DJ_mothlight_pages_memory_01`
- `mothlight-pages-last-mood-night` → `DJ_mothlight_pages_mood_night_01`
- `mothlight-weather-rain` → `DJ_mothlight_weather_rain_01`
- `mothlight-pages-kept-today` → `DJ_mothlight_pages_kept_today_01`

Thornwave:

- `thornwave-pages-story-night` → `DJ_thornwave_pages_story_night_01`
- `thornwave-pages-fae-bargain` → `DJ_thornwave_pages_bargain_01`
- `thornwave-weather-storm-grey` → `DJ_thornwave_weather_storm_grey_01`
- `thornwave-pages-gossip` → `DJ_thornwave_pages_gossip_01`

The Bleed:

- `bleed-pages-gossip-cluster` → `DJ_bleed_pages_gossip_01`
- `bleed-pages-story-grey` → `DJ_bleed_pages_story_grey_01`
- `bleed-time-after-midnight` → `DJ_bleed_time_after_midnight_01`

## Low-Effort Workflow For Adding More Banter

1. Decide the station and trigger.
2. Add a `RadioBanter` entry in that station's `banters:` array.
3. Give it a stable `id` and `assetName`.
4. Write the `caption`. This is both UI copy and audio fallback.
5. Add conditions only for what the line literally reacts to.
6. Run focused tests:

```sh
swift test --filter RadioBanterTests
```

7. Export the script for ElevenLabs. Use the `assetName` as the clip heading.
8. Save/convert audio as `InsideCoverApp/RadioAudio/<assetName>.m4a`.
9. Add the clip to `testNewReactiveDJAssetsAreBundled` if it is a new bundled audio asset.
10. Build/install and tune the station.

## Recommended Test Pattern

When adding reactive clips, add both a reachability test and a bundle test.

Reachability test idea:

```swift
let context = RadioWorldContext(
    timeOfDay: "night",
    grey: 40,
    festivalActive: false,
    listeningDays: 1,
    weekday: 3,
    pageContext: RadioPageContext(
        keptToday: 2,
        recentPageTypeCounts: [.gossip: 2],
        weatherTags: ["rain"]
    )
)
```

Then call `RadioStationRegistry.nextBanter(...)` repeatedly with a matching active station and assert the desired ID appears.

Bundle test idea:

```swift
XCTAssertEqual(clips["thornwave-pages-gossip"], "DJ_thornwave_pages_gossip_01")
XCTAssertTrue(FileManager.default.fileExists(
    atPath: radioAudio.appendingPathComponent("DJ_thornwave_pages_gossip_01.m4a").path
))
```

## Common Gotchas

- The `assetName` should not include `.m4a` in Swift.
- The file on disk must include the extension.
- `id` and `assetName` are different on purpose. Do not reuse one as the other unless it already follows both conventions.
- `pageTypes` only looks back 7 days.
- `minRecentPagesOfType` with `pageTypes` counts only those types.
- `minRecentPagesOfType` without `pageTypes` counts all recent kept pages.
- `sourceIDs`, `sourceTags`, and `weatherTags` are string matches after lowercase normalization.
- Hidden station `the-bleed` must be tuned at 97.3 exactly enough to lock.
- If a clip never plays, check conditions first, recent cooldown second, missing station audio third.
- If audio is missing, the caption still plays; that is useful for testing.
- If the station has only procedural fallback audio, banter will not interleave between songs.

## Good Trigger Recipes

Recent story pressure:

```swift
conditions: RadioBanter.Conditions(
    pageTypes: [.narrativeOS, .gamePage, .bookJump],
    minRecentPagesOfType: 2
)
```

Rainy night mood:

```swift
conditions: RadioBanter.Conditions(
    timeOfDay: ["dusk", "night"],
    lastKeptPageTypes: [.mood, .diary],
    weatherTags: ["rain", "storm"]
)
```

Bright Fae-Fi morning:

```swift
conditions: RadioBanter.Conditions(
    timeOfDay: ["dawn", "day"],
    weatherTags: ["bright"]
)
```

The Bleed notices gossip:

```swift
conditions: RadioBanter.Conditions(
    pageTypes: [.gossip, .theBleed],
    minRecentPagesOfType: 2
)
```

High-activity day:

```swift
conditions: RadioBanter.Conditions(minKeptToday: 4)
```

Station loyalty:

```swift
conditions: RadioBanter.Conditions(minListeningDays: 4)
```

Grey pressure plus story pages:

```swift
conditions: RadioBanter.Conditions(
    minGrey: 35,
    pageTypes: [.narrativeOS, .bookJump, .gamePage],
    minRecentPagesOfType: 2
)
```
