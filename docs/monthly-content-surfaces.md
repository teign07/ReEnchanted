# Everything a monthly update can change

6 October 2026. This is the single inventory of everything a monthly content
update can add or change in a Reader's Book without an App Store release. It
covers the story, Gemma's prompts, the Academy map, the radio, the margins, the
sentence helper and the printed editions, along with the dials on each one. At
the end is what each part needs from bj.

A month doesn't need all of it. October (`ContentPacks/count-unbound`) is the
worked example, so each row says whether October used it.

**Status key**

| Mark | Meaning |
|---|---|
| **Oct** | Shipped in the published October issue. Proven end to end. |
| **Ready** | The app reads it from a delivered pack, but no published issue has used it yet. Rehearse it before you rely on it. |
| **Inert** | The field parses, but nothing in the app acts on it yet. |
| **Gap** | Close, but it needs an app change before a month can ship it. |

How it gets there, schema contracts and the publish steps are covered elsewhere:
[monthly-issue-playbook.md](monthly-issue-playbook.md),
[monthly-content-runtime.md](monthly-content-runtime.md) and
[monthly-issue-delivery-contract.md](monthly-issue-delivery-contract.md).

---

## 0. The files a month can ship

A month is one folder with an `issue.json`. That file lists the files below.
Each one is a signed asset, and the app installs them all or none: one file
that fails to decode keeps the whole month off the phone.

| Asset kind | File suffix | Carries | Oct |
|---|---|---|---|
| `worldEventPack` | `.reenchantedevents.json` | The month itself: calendar, phases, pulses, map staging, beats, The Record, catch-up, Gemma packet, authoring manifest, story scenes, Bleed articles, radio breaks, directed marks, wonder lines, note prompts | **Oct** |
| `pageArchetypePack` | `.reenchantedpack.json` | Marginalia cabinet (art), marginalia snippets, new Page archetypes, word negotiations, Cast undertakings | **Oct** (cabinet only) |
| `editionPlayPack` | `.editionplay.json` | Paper activity leaves for the weekly/monthly/seasonal/annual editions | **Oct** |
| `sentenceBuilderPack` | `.sentencepack.json` | Sentence-helper chips: word pools, context themes, starter templates | Ready |
| `radioStationPack` | `.reenchantedradio.json` | Songs added to or taken off existing stations, or whole new stations with their own songs and DJ breaks | Ready |
| `storyFormPack` | `.storyforms.json` | Story forms, genres and recipes Gemma writes scenes from | Ready |
| `storyConsequencePack` | `.storyconsequences.json` | What a story choice changes afterwards (relationships, rituals, memories) | Ready |
| `media` | any (`.png`, `.mp3`, …) | Images and audio referenced from the packs as `{{asset-path:ID}}` | **Oct** |

Each asset is either **`runtime`**, which leaves the phone when residue ends, or
**`publication`**, which stays (2 MiB cap) so later editions can still bind it.
Hard limits are 180 MiB per asset and 350 MiB for the whole shelf.

---

## 1. The month's calendar and shape

*In the event pack, `events[0]`.*

| Field | What it changes | Oct |
|---|---|---|
| `calendar.startMonth/startDay/startYear/durationDays` | The live window. The shelf's foreshadow/live/residue dates are derived from it, so the app and the server can't disagree. | **Oct** (Oct 1–31) |
| `calendar.foreshadowDays` / `residueDays` | The quiet week before and the after-week. | **Oct** (7 / 7) |
| `title`, `subtitle` | The issue's name everywhere: Book Today, the Record, the edition, Gemma's context. | **Oct** |
| `phases[]` (`id`, `title`, `role`, `startsAtProgress`) | Four acts: setup → buildup → climax → aftermath. Phase IDs are permanent save identities. | **Oct** |
| `phases[].intensity` | How hard the event pushes its Pages up the desk ranking (adds up to +12). | **Oct** |
| `phases[].scene` | Reader-facing narration of what's happening this phase, in the Book's voice. Shown on Book Today and in the widget, and given to the braid. | **Oct** |
| `phases[].packetLine` | A backstage instruction to Gemma for this phase. Never shown to the reader. | **Oct** |
| `phases[].lexicalRules` | Words to push or ban per phase. | **Inert**: nothing reads it |
| `triggers`, `outcomes` (`minimumTouchCount`, `packetLine`, `monthlyEditionLine`, `effects`) | Branching ends picked by how often the reader touched the event. The outcome's line goes into Gemma's prompt and the edition. | Ready (October has none) |
| `effects[]` (target + `boost`) | Pushes page types, Cast members (`entity`) or story threads up the rankings while the event runs. | Ready. Only the `pageType`, `entity` and `storyThread` targets have readers. `relationship`, `classSession`, `letterTone`, `monthlyEdition`, `visualTreatment` and `vocabulary` parse, but nothing reads them (**Inert**). |

## 2. The story the reader takes part in

*Story scenes are the `storyScenes[]` objects in the event pack. Each one needs
an atom in `authoringManifests[0].content` (§8).*

| Field | What it changes | Oct |
|---|---|---|
| `storyScenes[]`: `title`, `opening`, `prompt`, `detail`, `choices` | A fully written Story Page. Gemma never extends it. | **Oct** (22 scenes) |
| `nodes[]` (`body`, `prompt`, `choices`, `nextNodeID`) | Multi-leaf scenes with branching routes. Node and choice IDs are permanent save identities. | **Oct** |
| `choices[].result`, `effectLine`, `consequenceTags`, `symbolName` | What a choice says and does once it's kept. | **Oct** |
| `choices[].requiresFindingContentID` | A choice that appears only while the reader's kept finding still exists. | **Oct** (Gambit) |
| `responsePlaceholder` | Ghost text in the reply box. | **Oct** |
| `missionInvitation`, `missionReturnPrompt`, `missionKeptResponse` | Field missions ("crossings"). The Book invites the reader into the real world, they come back with a sentence, and the Book answers it. | **Oct** (4 crossings) |
| `allowsFindingUse` (runtime 4) | The reader's return sentence can be used by later scenes. | **Oct** |
| `revisitsObservation` (runtime 6) | "Go back once": the reader picks an earlier sentence of theirs and looks again. | **Oct** |
| `nodes[].carryForward` (runtime 5) | An earlier choice changes a later scene's text. | **Oct** |
| `nodes[].findingInsertion` (runtime 5) | Quotes the reader's actual finding inside the fiction, with an authored fallback when there isn't one. | **Oct** |
| `nodes[].observationPairInsertion` | Quotes both of the reader's "two looks" sentences. | **Oct** |
| `jump` + `jumpAction` (runtime 3) | A supervised Book Jump into another book, with a fictional or reader-chosen anchor and a last live day. | **Oct** (Sunday Jump Club) |
| `braidText` (scene, node or choice) | The exact passage that enters that night's braid and the printed books. It's frozen once committed. | **Oct** |
| `report`, `reportAfterLiveDay` | Third-person "what happened" for readers who missed it. | **Oct** |
| `roomID`, `castIDs` | Where the scene happens and who's in it. It puts them on the map, and the kept Page remembers it. | **Oct** |
| `entities`, `tags` | Cast and tags the Curator and memory systems read. | **Oct** |
| Atom `concludesRun` / `survivesConclusion` | An ending that closes the month's live offers early. | **Oct** |
| Atom `storyContinuation` (runtime 7) | An opened, unfinished story can still be finished after its offer window closes. | **Oct** (Future Tense) |
| Relics | Method-specific keepsakes given only to readers who lived the route. These are atoms gated on receipts. | **Oct** |
| The next month's carry | A residue scene that picks up an October choice in November. | **Oct** (An evening in November) |

## 3. The Tale's daily life (no choice needed)

| Field | What it changes | Oct |
|---|---|---|
| `phases[].pulses[]` (`text`, `tender`) | One small thing the world does each day. It's offered to every night's braid, so the story is there even when the reader kept no scene. `tender` is the quiet version for a hard night. With no `tender`, the pulse is skipped on such nights. | **Oct** (34 pulses) |
| `beats[]` | Dated Pages the world hands out: classes (`pageType: academyClass`), letters (`letter`), notices (`bookNotices`), or any other `BookPageType`. Fields: `opensOnDay`, `expiresAfterDay`, `title`, `body`, `report`, `reportsWhenMissed`, `isMilestone`, `lifecycleStage`, `roomID`, `castIDs`. | **Oct** (4 classes, 2 letters, 2 residue notices) |
| `beats[].participationPrompt` / `participationPlaceholder` | Turns a beat into a door the reader answers. Only an answer during the live window counts as taking part. | Ready |
| Weekly recaps | Bleed articles tagged `weekly-recap`. On a recap day, older unfinished story beats stop resurfacing because the recap has told them. | **Oct** (live days 10/17/24/29) |
| Beat resurfacing | Story beats come back on a 6-hour slot, give way when the next beat opens, and stop after a recap. This comes from the manifest automatically, not a separate field. | **Oct** |

## 4. Catching up new and returning readers ("The Story So Far")

*`events[0].catchUp[]`, which is checked against `record.entries`.*

| Field | What it changes | Oct |
|---|---|---|
| `catchUp[]` (`id`, `fromDay`, `title`, `body`, `openQuestion`) | The authored "story so far" ladder. The Book tells the highest rung up to today. In residue the last rung tells the finished story. | **Oct** (9 rungs) |
| `catchUp[].tells` | Which Record entries a rung draws on. `WorldEventCatchUpAudit` fails any rung that tells something that isn't public yet. | **Oct** |
| Where it shows | (1) **Arriving**: a first-run Page after First Mission, for a reader with nothing from this run yet. (2) **Returning**: after 4 days away (rests 7 days, never on a hard day). (3) **Asked**: the "Catch Me Up" row in the Glow Pages menu, which exists only while a run has a ladder. | **Oct** |

Each rung should stand alone, and the ladder must never name the triangle.
November's rung 0 has to retell October in a paragraph.

## 5. The Academy map ("A Map of the Labyrinth")

*Per phase (`phases[]`) plus `foreshadowAcademy` / `residueAcademy` for the
weeks either side.*

| Field | What it changes | Oct |
|---|---|---|
| `staging[]` (`castID`, `roomID`, `note`, `fromDay`, `throughDay`, `fromHour`, `untilHour`) | Who's where and when, down to the hour (it can wrap midnight). It outranks timetables and habits. `note` is the Book's line on why they're there. | **Oct** (20 placements) |
| `staging[].name` | A visitor who isn't in the Cast, drawn by name with nothing to open. | Ready |
| `closedRoomIDs` | Rooms drawn as shut that nobody drifts into. | **Oct** |
| `roomNotes[]` (`roomID`, `note`, day window) | Lines the Book writes beside rooms. | **Oct** |
| `borrowedRooms[]` (`id`, `name`, `note`, `x`, `y`, `width`, `height`, `form`, `joins`, day window) | Rooms out of other books that push into the Academy, drawn in a different ink and gone when the window ends. | **Oct** (The Wrong Castle) |
| Beat/scene `roomID` + `castIDs` | While a beat is open, or once its Page is kept, the map shows it happened there. | **Oct** |

New **permanent** rooms need an app update (§9).

## 6. Every other channel

### The Bleed (the Academy paper)

| Field | What it changes | Oct |
|---|---|---|
| `bleedArticles[]` (`title`, `byline`, `body`, `editionKinds`, `tags`) | Verbatim articles placed into scheduled Bleed editions. | **Oct** (8, including 4 recaps) |
| `packet.bleedInstruction` | Steers Gemma's generated Bleed copy while the event runs. | Ready |

### Radio

| Field | What it changes | Oct |
|---|---|---|
| `radioBanters[]` (`stationID`, `banter`: `category`, `assetName` audio, `caption`, `weight`, `conditions`) | DJ breaks on existing stations, recorded audio with a caption fallback. `conditions` can gate by time of day, grey, weekday, month, dates, weather, recent page types, event and phase. | **Oct** (5 clips) |
| `packet.radioInstruction` | Tints the "what's playing" line Gemma sees. | Ready |
| `radioStationPack` → `stationEdits[]` (`stationID`, `addTracks`, `removeTrackIDs`) | Adds songs to or takes songs off any station, bundled or delivered. An added song with an existing ID replaces it, so a month can also re-weight or re-gate a song. Songs can be gated to the month with their own `conditions` (`months`, `startsAt`/`endsAt`, `activeWorldEventIDs`…). A removal that would leave a station silent is ignored. Audio ships as `media` (`.mp3`/`.m4a`) through a `media` rule in `issue.json`. The pack **must include `"stations": []`**: older builds require that key, and the release tool refuses a pack without it. | Ready |
| `radioStationPack` → new `stations[]` (frequency, host, songs with `meaning` traces, interstitial bed, page-type boosts, banters) | A whole new station for the month. A new station whose ID matches an existing one is ignored (the bundled one wins); use `stationEdits` instead. | Ready |

### Marginalia and art

| Field | What it changes | Oct |
|---|---|---|
| `marginaliaPack` assets with `directedOnly: true` + `marginalia[]` marks | Handwritten notes placed at specific story beats, at most one per nine-leaf block. A kept Page keeps its art for good. | **Oct** (8 Count notes) |
| `marginaliaPack` seasonal drawings with `placementTrigger` (`months`, `issueYear`, `activeWorldEventIDs`, `worldEventPhases`, `semanticTagsAny`) | The month's drawing set. They decorate that month's leaves and printed margins and show on Pagewright's **This Month** shelf. | **Oct** (20 drawings) |
| Asset `leafTraits`, `defaultOpacity`, `canTint`, `supportedTemplates` | How and where a mark can sit on a leaf. | **Oct** |
| `marginaliaSnippets[]` (`text`, `title`, `tags`, `weight`, `placementTrigger`) | Short Book pencilings picked by motif. | Ready |
| `{{asset-path:ID}}` media | Any image or audio. Changed bytes need a **new asset ID**. | **Oct** |

### The sentence helper (Capture's chips)

*A `sentenceBuilderPack`. Every field is optional, and what a pack ships is
merged onto the core set.*

| Field | What it changes | Oct |
|---|---|---|
| `concreteWords`, `sensoryWords`, `animateVerbs`, `crossingWords` | The word pools the replacement chips draw from. | Ready |
| `vagueWords`, `avoidWords` | Words the helper flags as vague, and words it steers away from. | Ready |
| `themes[]` (`id`, `name`, `anchors`, `senses`, `verbs`, `crossings`) | Context lexicons. When the reader's sentence names an anchor ("kettle", "pumpkin"), the chips come from that theme first. | Ready |
| `starterTemplates[]` (`title`, `pattern`, `slots[]` with `kind`/`title`/`options`) | Fill-in-the-blank starter sentences. | Ready |
| `ritualTitle`, `replayPrompt`, `replayHelper`, `displayName` | The helper's heading and the "close your eyes" prompt. Empty means the core text stays. | Ready |
| `availability` | Must **not** be `"locked"`, or nobody sees the pack. | n/a |

### Wonder lines and Gemma steering

| Field | What it changes | Oct |
|---|---|---|
| `wonderLines[]` (`id`, `nouns`, `needs`, `line`) | New lines for the nightly braid about what an ordinary thing wanted or did, keyed to the month's nouns. A line reusing a bundled ID replaces it. Lines must end in `.` or `!`, run 32 words or fewer, contain no "I", and use no banned words. | Ready |
| `retiredWonderLineIDs` | Takes bundled lines out of the library. | Ready |
| `packet.logline`, `atmosphere` | The event summary in every generated Page's prompt. | **Oct** |
| `packet.storyInstruction` | Steers generated story scenes. | **Oct** |
| `packet.classInstruction` | Steers generated classes. | **Oct** |
| `packet.letterInstruction` | Steers generated letters. | **Oct** |
| `packet.bookOfYouInstruction` | Steers the Book of You. It falls back to `storyInstruction`. | Ready |
| `packet.widgetWhisperLine` | The home-screen widget's line. It falls back to the phase `scene`. | Ready |
| `packet.visualTreatment` | An art-direction note. | **Inert** as far as I can find |
| `packet.fieldworkPrompt` / `Placeholder` / `RewardLine` | The month's fieldwork Page. | **Oct** |
| `packet.monthlyEditionLine` | The line the month leaves in its edition. | **Oct** |
| `storyFormPack`: `forms` (beats, director note), `genres` (lens, exemplar passage, palette), `recipes` (premise, turns, decisions, tone/choice directives, required Cast and roles, cooldowns; `world-led` tag) | New kinds of generated story scenes for the month. | Ready |
| `storyConsequencePack`: `bundles` (`when` conditions → `atoms` such as relationship warmth/tension, ritual counts, memories) | What generated story choices change in the world. | Ready |

### Ordinary Pages and the Cast's own business

*In a `pageArchetypePack`.*

| Field | What it changes | Oct |
|---|---|---|
| `archetypes[]` (`headline`, `detail`, `bodyTemplate`, `score`, `cadenceHours`, `activeHours`, `trigger`, `generation` spec, `leafVisualDialect`, `leafRegionPattern`) | New repeatable Page kinds. The trigger can key on weather, moon, place kind, grey, absence days, anniversaries, festivals, the event's phase and more. | Ready |
| `wordNegotiations[]` | Words that rebel and ask the reader for a ruling (the Dictionary Rebellion mechanic). | Ready (bundled in September, not delivered) |
| `undertakings[]` (ladders of `stages`: `line`, `trace`, `scene`, `deniability`, `door`, `surface`, `phaseID`, `castIDs`) | Business the Cast are already in the middle of. It runs whether or not the reader opens the app, and can be bound to the month's event or phase. | Ready |

## 7. Paper: the printed editions

| Field | What it changes | Oct |
|---|---|---|
| `record` (`outcomeTitle`, `historySentence`, `entries[]` with `onDay` and `knownFromDay`) | **The Record**: the Academy's own account of the month, bound into that month's edition. Participants get their receipt beside it. A release refuses an event without one. | **Oct** (15 entries) |
| `braidText` receipts | Story passages the reader actually lived, frozen into the weekly, monthly, seasonal and annual books. | **Oct** |
| `editionPlayPack` leaves (`form`: coloring, blackout, wordLadder, scrapbook, cutOut, journal, map; `cadence`; `templateSlot`; `footprint`; `prompts`; `options`; `answerKey`; `assetName`; `eventPhaseIDs` / `eventOutcomeIDs`) | Paper activities bound into the editions: mazes, maps, journaling leaves, coloring plates. Every leaf needs `eventOutcomeIDs`, even if it's an empty list. | **Oct** (map/maze ×2, threshold journal) |
| `notePrompts[]` (`id`, `kind`: day/puzzle/margin/any, `text`) | The lined-space invitations in the printed books ("What did the dark come early for tonight?"). The pack's own are dealt before the bundled ones. | **Oct** (15) |
| `retiredNotePromptIDs` | Retires bundled prompts. | Ready |
| Ruin prompts (`.ruinpack.json`: tear-out, stain, rubbing, fold… with a `months` gate) | The month's "handle this book" pages. | **Gap**: the loader and guards exist, but there's no delivery kind, so a signed issue can't carry one. |
| Field Book coursework, dossiers, bestiary, spells, keepsakes | Built from the reader's own archive and the bundled library, not from the pack. | n/a, not monthly |

## 8. Knobs on every atom (the authoring manifest)

*`authoringManifests[0]` in the event pack. Every scene, beat, article, radio
break and mark is an **atom** with these dials.*

| Dial | Values |
|---|---|
| `channel` / `reference.kind` | page · storyScene · marginalia · radioBanter · bleedArticle |
| `placement` | foreshadow / live (with phase ID and role) / residue |
| `priority` | ambient · featured · spine · milestone. A milestone claims the issue's reserved desk chair. |
| `audience` | everyone · participants · nonparticipants |
| `voice` | immediate · publicReport · participantReceipt · nonparticipantRumor |
| `interaction` | none · choice · readerResponse · readerEvidence · fieldMission |
| `occurrence` | onceEver · oncePerRun · oncePerPhase · repeatable (cooldown, max) · untilOpened · untilActed · untilResolved |
| `gate` (allOf / anyOf / noneOf) | time band, month, weekday, week of year, exact date window, moon phase, weather, world event (phase, role, stage, min/max live day, touches), prior receipts, Standing band, rarity, any Page trigger (place kind, grey, absence, anniversaries, festivals…), any radio condition |
| `dependencies` | needs another atom delivered/opened/kept/completed/accepted…, scoped ever/run/phase, with wait / reportThenContinue / expire |
| `missionReturn`, `storyContinuation` | A second window after acceptance or opening |
| `tags` | Subdivide the page channel (letter, class, weekly-recap, residue…) |
| `productionStatus` | planned · draft · ready · reuse · cut. Release refuses anything not ready. |
| Manifest `phasePlans`, `coverageRequirements` | The month's production budget, e.g. "at least 2 ready Bleed articles in buildup". The release tool enforces it. |
| `minimumRuntimeVersion` | The app is at **runtime 10**. A pack that needs more is shown as "needs a newer Book" instead of installing half. |

## 9. What a month can't change (an app release is needed)

- New **Page types**, new atom **channels**, new edition-play **forms** or
  **template slots**, and new gate predicate kinds.
- New **permanent Academy rooms** or passages (borrowed rooms are the monthly
  substitute).
- New **Cast members**. A month can stage, voice and quote existing ones, and
  can name a visitor on the map, but a dossier, plate and entity are app
  content.
- **Permanent** song changes. A station edit lasts while its pack is on the shelf, and the songs come back after residue. To keep a song off the air, each month's pack repeats the removal.
- The bundled **lore library**, **bestiary**, **spells**, feasts, Wonder Compass,
  and the Book's core voice and prose.
- **Ruin pages** (needs a delivery kind, see §7).
- `lexicalRules`, `visualTreatment` and the six unread effect targets do nothing
  until code reads them.
- Any field added to an existing type. Older apps silently ignore it, so a new
  behaviour needs a runtime bump and an app release first.
- The publishing public key (rotating it needs an app release).

---

## 10. What we need from bj

### Decisions only bj can make

| For | Needed |
|---|---|
| The month's story | The premise and arc, who's in it, and the canon calls (what's true, what's never said; e.g. "never name the triangle"). Claude, Codex and Silvie can draft everything from a brief, but bj approves canon. |
| Scope | Which rows of this document the month uses. A **lean month** is the event pack (phases, pulses, staging, catch-up, Record) plus 4–8 scenes, 2–4 Bleed articles and the marginalia cabinet. A **full month** is October's scale. |
| Real-world asks | Any field mission the reader is sent out on, signed off for safety and tone. |
| Print | Whether the month gets paper leaves (maze, map, journal), and approval of their art. |
| Free or paid | Monthly content is currently free to all (the shelf is open). Changing that is a product decision. |

### Things bj makes or approves

| For | Needed | How |
|---|---|---|
| Radio | DJ clips (October had 5, 20–40 s each). Scripts are written first in `RADIO-RECORDING.md`. | Recorded in ElevenLabs in bj's signed-in browser pane. Claude can drive it but needs bj's account session. The caption must match the take. |
| Art | The seasonal drawing set (October had 20), directed notes, and print plates. | Generated from `seasonal-art-prompts.json`, using the pixie/goblin marginalia as style references. bj reviews the contact sheet. |
| Prose review | A read of the scenes, the catch-up ladder and the Record in the Book's voice. | Drafted by agents; `StorySoFarTests` and the catch-up audit lint them mechanically. |
| Listening | A human listen to the clips on a device. | Still open for October. |

### Steps only bj can run

Claude Code's auto mode blocks these:

1. **`npx wrangler deploy`** whenever `docs/physical-book-backend/monthly-issues.mjs`
   changed since the last deploy. Do this **before** publishing, or the whole
   shelf returns 503. (`npx wrangler deployments list` shows the last deploy.)
2. **`scripts/publish_monthly_release.sh <candidate> --publish`** after Claude
   has run `rehearse`, `release`, the dry run, and
   `swift test --filter MonthlyIssueInstallability`.
3. The publisher private key stays at
   `~/.reenchanted-publishing/monthly-issue-private.key` on this Mac. If it's
   lost, the key has to be rotated through an app release.
4. Device QA on Rabbit (bj's phone): install, the first scene appearing, a map
   check, and a radio clip playing. If the month needs a newer runtime, the
   matching app build must reach TestFlight/App Store before the issue goes live.

### Monthly lead times (suggested)

| When | What |
|---|---|
| ~6 weeks out | bj's brief and canon calls; scope chosen from this list |
| ~4 weeks out | Scenes, pulses, staging, ladder and Record drafted; art prompts written |
| ~3 weeks out | bj's review; art generated; radio scripts locked |
| ~2 weeks out | Clips recorded; packs `ready`; rehearse + native tests; any app build that needs a runtime bump submitted |
| Before foreshadow (7 days before live) | Worker deploy if needed → publish → device check |

The issue must be on the shelf before its **foreshadow** week starts, not its
live day. The shelf manifest always lists **every issue still on the shelf**,
so publishing November must also carry October through its residue.
