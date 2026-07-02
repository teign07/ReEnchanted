# Content Pack Catalog

Last updated: 2026-06-27

This is the working map of every system in the app that can be **extended by a
content pack** — bundled, sold through the BookShop, or dropped into Documents as
a user JSON file. Use it when planning a themed pack (e.g. the "Back to School"
pack for September) to see what levers exist and what each one can carry.

## How packs work, in general

Almost every content system follows the same pattern:

- A `*Pack` struct (the unit of content) and a `*Registry` enum that loads it.
- `bundledPacks` shipped inside the app.
- A `userPackFileSuffix` so a pack can arrive as a JSON file in the app's
  Documents folder (e.g. `*.sentencepack.json`).
- `ContentPackAvailability` (`free` / `locked`) — locked packs are gated behind
  `PackEntitlements.ownedPackIDs`, written only after a verified purchase (or the
  dev counter in internal builds). See [InsideCoverState.swift](Shared/InsideCoverState.swift)
  and [PagePacks.swift](Shared/PagePacks.swift).

Because they all share this shape, a single themed pack can bundle content for
**any mix** of the systems below and sell it as one BookShop listing.

## The BookShop shelves

The Goblin Market merchandises packs under seven families. See
`BookShopListing.Family` and `BookShopCatalog` in
[PagePacks.swift](Shared/PagePacks.swift:488).

| Shelf label | Family id | Carries |
|---|---|---|
| Page Folios | `pagePack` | New page archetypes |
| Story Looms | `storyForms` | Story forms, genres, recipes |
| Wonder Tinder | `sparkPack` | Story sparks / prompts |
| Lore Crates | `lorePack` | Lore, characters, locations |
| Marginalia Sets | `marginaliaPack` | Illumination / photo decoration sets |
| Sound Bindings | `soundPack` | Radio stations, songs, DJ banter |
| World Events | `eventPack` | Time-boxed world events |

Each listing carries a `goblinPitch` (in-world sales line), an honest `contents`
description, an App Store `productID`, and a `saleState`
(`standard` / `liveEvent` / `archivedEvent` / `comingSoon`).

---

## The upgradeable systems

### 1. Sound / Radio
**`RadioStationRegistry` · `.reenchantedradio.json` ·
[WorldSystems.swift](Shared/WorldSystems.swift:509)**

The richest pack surface. A sound pack can add:

- **Radio stations** — new frequencies the reader can tune (`RadioStation`).
- **Songs / tracks** — `RadioTrack` slots per station, backed by bundled audio.
- **DJ banter** — `RadioBanter`: prerecorded spoken breaks chosen by metadata.
  Each banter has a `Category` (news, etc.), an all-optional `Conditions` gate
  (only plays when world state matches), a `Placement`, and an `assetName` that
  resolves to an audio clip. Banter can reference talismans, weather, and other
  live world state.
- **Station effects** — `RadioStationEffect` curation boosts that bias what the
  homescreen curator surfaces ("the music becomes weather in the stacks").

*Pack ideas:* a campus study-hall station with seasonal songs; a first-day DJ
who reads "orientation notices"; banter that fires only in September.

### 2. Sentence Builder / Polisher
**`SentenceBuilderPackRegistry` · `.sentencepack.json` ·
[SentenceBuilder.swift](Shared/SentenceBuilder.swift:492)**

- **Word chips** — supplied through `LexicalTheme`s feeding the step slots
  (`anchor`, `sense`, `motion`, `crossing`, `cutMist`, `groundGlow`).
- **Starter templates** — `SentenceStarterTemplate`, grammar-safe scaffolds so
  new vocabulary still composes into valid sentences.
- Packs `merge` over the core, so a theme pack only adds what's new. Bundled
  examples: `core`, `souvenir`, `nightAndGarden`.

*Pack ideas:* a classroom / autumn theme — chalk, satchels, leaf-fall, first
bells — plus starters that read like diary openings on a school morning.

### 3. Story Forms / Scenes
**`StoryFormRegistry` · `.storyforms.json` ·
[StoryEngine.swift](Shared/StoryEngine.swift:4613)**

- **Story forms** — `StoryForm`, the shapes a scene can take.
- **Genres** — `StoryGenre`. Beyond `lens` and `moodTags`, a genre should ship
  an `exemplar` (a ~40–60 word model passage in the genre's register, from no
  particular story — the local brain imitates a sample far better than it
  follows rules) and a `palette` (concrete nouns in the genre's key, used to
  seed scenes on days with no real signal). Both are optional for older packs.
- **Recipes** — `StoryRecipe`, ways forms and genres combine.
- **Clash genres** — a genre with `"clash"` in `moodTags` is recipe-gated: it
  only surfaces when the selected recipe lists it in `preferredGenreIDs`.
  Bundled example: The Unquiet Folio (Trickster's Duel, Grey Static,
  Threshold Gothic) — the drama line where something precious is being made
  generic and the reader spends Belief to keep it strange.

*Pack ideas:* "The Exam," "The Field Trip," "Detention," "The New Kid."

### 4. Wonder Sparks
**`WonderSparkRegistry` · [StoryEngine.swift](Shared/StoryEngine.swift:4991)**

Story prompts / sparks — the "Wonder Tinder" shelf. Short generative seeds that
feed the compass and scene engine.

*Pack ideas:* back-to-school what-ifs and small first-week dares.

### 5. Page Archetypes
**`PageArchetypePackRegistry` · `.reenchantedpack.json` ·
[PagePacks.swift](Shared/PagePacks.swift:86)**

- **Page types** — `PageArchetype` with a `GenerationSpec` and a template
  renderer. These are whole new kinds of page the curator can surface.
  (The bundled Nocturne Folio adds "The Insomniac's Inventory," "The Dream
  Ledger," and "Last Light.")

*Pack ideas:* "The Syllabus," "Locker Inventory," "First-Day Ledger,"
"Lunchroom Cartography."

### 6. Narrative World (Characters / Locations / Objects)
**`NarrativePackRegistry` · [NarrativeCore.swift](Shared/NarrativeCore.swift:575)**

A `NarrativePack` can introduce any `NarrativeEntityKind`:

- **Characters**, **Locations**, **Objects**, **Threads**, **Classrooms**,
  **Talismans**, **Real-world anchors**, **Motifs**.
- Plus **relationship edges** between entities and seeded **entity memories**.

The cast remembers what the reader does for weeks, so new characters become
durable. Existing bundled cast (Headmistress Seraphina Thorne, Professor Luna
Wispwood, etc.) sets the tone to match.

*Pack ideas:* new faculty, a homeroom, campus locations (the quad, the old
library wing), a class-mascot object.

### 7. World Events
**`WorldEventRegistry` · `.reenchantedevents.json` ·
[WorldEvents.swift](Shared/WorldEvents.swift:189)**

The marquee surface for a *seasonal* pack. A `WorldEventPack` carries
`WorldEvent`s, each with:

- **Phases** (`WorldEventPhase`) with in-character scene narration.
- **Recurrence** — `oneShot` or **`annual`** (fires every September).
- **Lexical rules** (`WorldEventLexicalRule`) — apply vocabulary pressure to the
  whole book while the event runs.
- **Triggers** — `calendar`, `keptRelatedPage`, `classAnswered`, `letterKept`,
  `compassRunCompleted`, `enchantmentCompleted`.
- **Effects** targeting page types, threads, entities, relationships, class
  sessions, letter tone, the monthly edition, visual treatment, or vocabulary.
- **Outcomes** and **monthly-edition traces**, so a finished event leaves a mark
  in the bound book.

Past events can be re-sold boxed as an `archivedEvent` listing so the night can
unfold again.

*Pack ideas:* "Orientation Week" — an annual multi-phase event with first-day
lexical pressure, classroom triggers, and a keepsake trace in September's
edition.

### 8. Marginalia / Illumination
**`IlluminationPackRegistry` · [Illumination.swift](Shared/Illumination.swift:502)**

`IlluminationAssetPack` — alternate decoration sets for Illuminated Photos: gilt
frames, wax seals, pressed flowers, scraps, tape, stamps.

*Pack ideas:* a stationery set — ruled-paper scraps, hall-pass stamps, gold
stars, pressed autumn leaves.

### 9. Lore
**`LorePackRegistry` · [InsideCoverState.swift](Shared/InsideCoverState.swift:411)**

`LorePack` — background lore entries that deepen the world.

*Pack ideas:* the Academy's founding, house histories, the rules of the term.

### 10. Quips & Self-Knowledge
**`QuipPackRegistry`, `SelfKnowledgePackRegistry` ·
[ReferenceLibrary.swift](Shared/ReferenceLibrary.swift:300)**

`QuipPack` and `SelfKnowledgePack` — reference-library flavor text and
self-reflection content.

*Pack ideas:* first-day-jitters quips, study-break reflections.

### 11. Support Faculty (Office Hours / Ask the Book)
**`SupportFacultyPackRegistry` · [InsideCoverState.swift](Shared/InsideCoverState.swift:155)**

`SupportFacultyPack` — the tutor "charts" behind office hours and the
Ask-the-Book prompts. See `InkrestOfficeHoursPromptBuilder` in
[NarrativeCore.swift](Shared/NarrativeCore.swift:65).

*Pack ideas:* a back-to-school study coach with its own difficult-page chart.

### 12. Academy Structure
**`AcademyScheduleRegistry`, `AcademyChapterRegistry`, `AnchorRegistry` ·
[WorldSystems.swift](Shared/WorldSystems.swift)**

Class schedules, chapters, and anchors — the scaffolding of the school year.

*Pack ideas:* a fresh term timetable, a new opening chapter for September.

### 13. Pact / Errands / Fae Bargains
**`PactTerritoryRegistry`, `PlayfulMissionRegistry` ·
[StoryEngine.swift](Shared/StoryEngine.swift:4040),
[PageModel.swift](Shared/PageModel.swift)**

- **Fae bargains** (`.faeBargain` page type) — real-day deals with the fae.
- **Pact errands** (`.pactErrand` page type) — talisman errands run on real days.
- **Pact territories** — `PactTerritoryRegistry`.

*Pack ideas:* a "first-week pact" errand chain; a fae bargain about not being
late.

---

## Putting together "Back to School" (September)

A strong cross-shelf bundle. Recommended pieces, highest payoff first:

1. **World Event** (`annual`) — "Orientation Week," the marquee, seasonal anchor.
2. **Sound pack** — a campus station with new songs + first-day DJ banter.
3. **Page Folio** — school archetypes (Syllabus, Locker Inventory, First-Day
   Ledger).
4. **Sentence pack** — a classroom/autumn lexical theme + starters.
5. **Narrative pack** — new faculty + campus locations.
6. **Story forms** — academic forms (The Exam, The Field Trip, Detention).
7. **Optional garnish** — marginalia stationery set, first-day quips, a
   first-week pact errand.

All of it can ship as one locked BookShop listing (or a small bundle of
listings) gated by `PackEntitlements`.
