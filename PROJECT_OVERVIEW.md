# InsideCover / ReEnchanted - Project Overview

InsideCover is the iOS/iPadOS app for **ReEnchanted**, the living-book surface
inside the broader Enchantify project. The app turns ordinary daily material -
kept notes, moods, weather, body/fuel logs, photos, locations, choices,
character letters, and generated story fragments - into a private illustrated
book that remembers and returns.

The product thesis is simple:

> Do not keep adding isolated page types. Make the Book a better reader.

The app is not a generic journal, chatbot, habit tracker, or game UI. It is a
storybook interface for attention. The reader keeps pages that matter; those
kept pages become durable memory; the Book later notices patterns, absences,
durations, relationships, recurring Beliefs, and seasonal shape.

## Project Facts

- Bundle ID: `com.openclaw.enchantify.insidecover`
- Xcode project: `EnchantifyInsideCover.xcodeproj`
- App target: `InsideCoverApp`
- Shared SwiftPM package: `InsideCoverCore`
- Supported runtime target: iOS 17+
- Shared-core test target: `Tests/InsideCoverCoreTests`
- Current verified shared suite: 415 tests, 1 skipped
- Device builds: build/install to a physical device (the local brain only runs on
  device; the iOS Simulator compiles but exercises only the fake fallbacks).
- Widget status: removed from this project. The old widget source has been
  moved out to `../DetachedInsideCoverWidget/` and is intentionally not part of
  the app target.

## Repository Layout

```text
InsideCover/
├── EnchantifyInsideCover.xcodeproj     Xcode project for the iOS app
├── Package.swift                       SwiftPM wrapper for shared core tests
├── PROJECT_OVERVIEW.md                 This architecture and product guide
├── README.md                           Setup-focused readme
├── SETUP.txt                           Local setup notes
├── InsideCoverApp/                     SwiftUI app, sheets, services, PDF export
├── Shared/                             Codable models, curation, story systems
├── Tests/InsideCoverCoreTests/         Unit tests for shared policy and systems
├── Sample/                             Sample payloads
├── scripts/                            Local validation/generation helpers
├── LandingPage/                        Static marketing site (index.html, app.js,
│                                       styles.css, screenshots, radio audio previews)
├── RemotionPromo/                      Separate promo-video project, not app core
└── DetachedInsideCoverWidget/          Loose widget source, intentionally out of target
```

## Philosophy

ReEnchanted treats ordinary life as material worthy of literary attention. Its
job is not to diagnose, optimize, or score the reader. It observes like a
careful book:

- "This person appears when safety is described."
- "Harbors, rain, fog, and shorelines are gathering."
- "This Belief has been in the margins for months."
- "A person, place, or motif used to appear often and has gone quiet."

The important distinction is that these are literary observations, not clinical
claims. The Book speaks in character, but the machinery underneath stays local,
structured, and explicit.

Design principles:

- **Memory over novelty:** new systems should deepen existing memory before
  adding more disconnected page types.
- **Kept pages are canonical:** dismissed pages can influence fatigue, but kept
  pages are what the Book treats as real archive material.
- **The Book is a reader:** it should surface patterns, durations, absences,
  returns, relationships, and Belief life cycles.
- **Local first:** private material stays on device unless a specific external
  lookup is knowingly used.
- **Structured before generated:** the app stores typed events, ledgers,
  memories, page metadata, and source IDs so generated prose has rails.
- **In-world, not dashboard:** data appears as pages, letters, margins, and
  editions rather than charts for their own sake.
- **Gentle agency:** the reader keeps, dismisses, gives Belief, asks, answers,
  casts, binds, searches, and exports. The Book suggests; it does not pretend
  the reader completed real-world actions.

## The Core Loop

1. The reader opens the app and the Book refreshes a small set of candidate
   surfaces.
2. Source adapters inspect today, archive history, local signals, preferences,
   Belief ledgers, nearby places, calendar pressure, and prepared generated
   pages.
3. The curator ranks candidates by score, source weight, fatigue, time affinity,
   distress/gentleness, type diversity, source settings, and page Belief.
4. The reader opens, keeps, dismisses, answers, or continues a page. Keeping a
   home-surface page retires and replaces only that page, so the rest of the
   current shelf stays stable.
5. Kept pages are persisted into the archive and can mint narrative events,
   entity memories, faculty entries, resurfacing records, talisman deltas, and
   search index material.
6. Generated systems use the archive and story field to write braids, letters,
   story pages, gossip, research, enchantments, and Ask the Book replies.
7. The Book later returns old pages, notices patterns, and can bind a monthly
   edition as a PDF.

The daily loop is therefore not "generate a page and forget it." It is:

```text
surface -> keep/dismiss -> archive -> event/memory -> curation -> return
```

## First Run And Onboarding

> **This system is complete and shipped. Do not propose building a new
> onboarding flow, tutorial, or welcome wizard — one already exists, is
> load-bearing, and is wired into first-run gating, Self Facts, Belief, the
> custom cast, and the Glow-pill reveal.** Changes here should refine the
> existing **Flyleaf Ritual**, not replace it.

### Where it lives and how it is gated

The onboarding flow is **`OnboardingFlowView`** in
`InsideCoverApp/BookSurfaceViews.swift` (around line 3361), branded in-world as
**The Flyleaf Ritual**. It is a full-screen story sequence — parchment reading
card with a stage pill, animated header, step dots, shimmer/page-tilt, and a
sparkle aura — not a settings wizard.

`ContentView` presents it as an overlay only when
`!didCompleteStoryOnboarding && !isOpeningMovieVisible` (i.e. after the opening
movie, on a fresh install). The gate is **`@AppStorage("didCompleteStoryOnboarding")`**
(`ContentView.swift:199`); `completeOnboarding` flips it to `true`, so the ritual
runs exactly once per install and never again until that flag is cleared. While
it is up, the Glow menu is suppressed.

`OnboardingFlowView` is initialized with two callbacks:

- `onGlowUnlocked` → `ContentView.revealGlowPillIfNeeded` — fired **mid-flow**
  (`notifyGlowUnlockedIfNeeded`: once `step >= 4` and the belief field is
  non-empty) so the Glow pill animates into the chrome the moment the reader
  names a first belief, before the ritual even ends.
- `onFinished` → `completeOnboarding(result)`.

### The nine beats

`stepCount = 9` (steps 0–8). Each carries a stage name, header line, SF Symbol,
and in-world prose. Steps that collect input gate their continue button until the
field is filled.

| # | Stage | Title | What happens / collects |
|---|-------|-------|--------------------------|
| 0 | Arrival | **The Cover Opens** | The reader falls through the app's own screen into Enchantify Academy (long cinematic prose; "they came through the Unwritten"). |
| 1 | The Unwritten | **The Chapter Without an Ending** | Zara Finch frames the reader's ordinary life as the Great Unwritten Chapter — the one book no one in the Academy can jump into. |
| 2 | Guide | **The Guide** | Zara introduces herself (portrait) and asks the reader's **favorite reading snack** → `snack`. |
| 3 | Name | **The Name the Book Knows** | Collects the **preferred reader name** → `name` (used in letters, Welcome, generated text). |
| 4 | Belief | **Belief and the Grey** | The Nothing, Belief, and Glow are explained via a **core-belief** prompt → `belief`. Once non-empty, an inline panel offers **Plant 3 Belief** vs **Keep it for now** → `investedBelief`. (This is where the Glow pill reveals.) |
| 5 | Chapters | **The School's Argument** | The five Academy Chapters are introduced (rendered from `AcademyChapterRegistry.publicChapters`). Chapter **Binding is explicitly deferred** — it later recognizes where Belief has lived, based on kept pages. |
| 6 | First Page | **The First Page Rises** | A **practice page**: the reader chooses **Keep** or **Let it wait** (`rehearsalChoice`); choosing Keep reveals a one-sentence field → `firstSouvenir`. Teaches the core keep/dismiss loop in a no-stakes sandbox. |
| 7 | Cast | **The Cast Notices** | Letters, memory, disagreement, and the weight of real-world action are explained. Shows a tappable cast glimpse (Zara, Finn, Penny, Orion) that opens portraits via QuickLook. |
| 8 | Threshold | **The Academy Opens** | Closing prose + a "your first loop" preview card, then hands the reader to the home shelf. |

### What completion does

`completeOnboarding(_ result:)` (`ContentViewFeatures.swift:166`) consumes an
`OnboardingFlowView.Result { snack, name, belief, investedBelief, firstSouvenir }`:

- Persists **Self Facts** for snack, name, belief, and (if written) the first
  souvenir via `saveOnboardingFact` — each a `SelfFact` with id
  `onboarding:<questionID>`, `sensitivity: .delight`, and
  `usePermission: .privateContext`, tagged `onboarding` plus topic tags.
- If `investedBelief` is true: subtracts **3** from `beliefScore` and mints a
  **custom cast member** (`saveCustomCastMember`) of kind `.motif` from the
  stated belief — `startingGlow: 34`, tags `["core-belief","onboarding",
  "belief-invested","glow-bright"]` — so the reader's first belief enters the
  world model as a real, Glowing entity that can recur and pull story toward
  itself.
- Sets `didCompleteStoryOnboarding = true` and a name-aware status message
  ("The Academy doors are open, <name>.").

The ritual teaches the actual loop (offer → keep/wait → archive → the Book
remembers) and the core vocabulary (the Nothing, Belief, Glow, Chapters), and it
explains the app as a living book of kept pages — never as a productivity app.

Relevant files:

- `InsideCoverApp/BookSurfaceViews.swift` (`OnboardingFlowView`, the nine beats)
- `InsideCoverApp/ContentView.swift` (presentation, `didCompleteStoryOnboarding`
  gate, `revealGlowPillIfNeeded`)
- `InsideCoverApp/ContentViewFeatures.swift` (`completeOnboarding`,
  `saveOnboardingFact`)
- `Shared/SourceAdapters.swift`
- `Shared/PageModel.swift`

## Page Model

`BookPageType` is a closed enum in `Shared/PageModel.swift`. Each page type has
title, short title, SF Symbol, source metadata, visual handling, default intent,
default Belief, and narrative weight.

Current page types:

```text
mood, diary, souvenir, rest, body, fuel, weather, location, quip,
aboutYou, wonderCompass, lore, patreon, illustration, illuminatedPhoto,
narrativeOS, gossip, facultyResearch, letter, supportGuild, castMember,
bookOfYou, askTheBook, inkrestOfficeHours, faeBargain, bookFae,
pactDispatch, festival, twoReadings, castBond, todaysSky, radio,
bookJump, enchantment, anchor, academyClass, elective, packPage,
calendar, helpTips, welcome, marginsAtlas, bookConnections, bookRemembered,
bookNotices, theBleed, inventory
```

Important model types:

- `BookPage` - durable kept page.
- `BookDay` - archive day containing kept pages.
- `SurfacePage` - candidate/live page in the feed or sheet.
- `BookPagePayload` - headline, body, and metadata.
- `BookPageMediaAsset` - bundled image, rendered image file, or photo-library
  reference.
- `BookPageSource` - source identity, privacy, cadence, symbol, and note.
- `BookPageSourceRegistry` - source catalog for page types.

## Source Adapters

The feed is produced by `BookPageSourceAdapters.active` in
`Shared/SourceAdapters.swift`. Each adapter receives:

- current `BookDay`,
- `CuratorContext`,
- `BookSourceInputs`,
- current time.

It returns zero or more `SurfacePage` candidates. The active adapter order is:

```text
Inventory, BookShop Preview, World Event, Rest, Mood, Diary, Souvenir,
Book of You, Book Remembered, Book Connections, Book Notices, The Bleed,
Ask the Book, Body, Fuel, Faculty Research, Character Letter, Support Guild,
Dr. Inkrest's Office Hours, Fae Bargain, Book Fae, Pact Dispatch, Festival,
Today's Sky, Radio, Book Jump, Two Readings, Cast Bond, Weather, Enchantment,
Welcome, Local Brain Awake, Academy Class, Elective, Pack Page, Calendar, Quip,
About You, Wonder Compass, Lore, Help Tips, Patreon, Illustration,
Illuminated Photo, Story Page, Margins Atlas, Gossip, Cast Member,
Outer Stacks Anchor, Location
```

`BookSourceInputs` is the central context bundle. It carries body/weather
signals, enchanted weather, anchors, nearby places, self facts, faculty entries,
custom cast members, electives, entity/page Belief offsets, surface history,
calendar events, resurfacing candidates, quiet days, current arc, recent
narrative events, the current literary-continuity digest, the reader's Fae
standing (`faeState`), the Pact War control state (`pactWar`), world-event
influence, Book Jump state, radio playback, owned packs, and live
relationship-field inputs.

## Curation

`Shared/SurfaceAndCurator.swift` owns curation policy.

Key pieces:

- `BookCurator` - gathers candidates and chooses the visible set.
- `CuratorContext` - hour, weekday, distress/gentleness state, source settings.
- `CuratorVarietyGovernor` - source fatigue, disabled sources, low-Belief
  surprise boosts, and source preference effects.
- `CuratorTimeAffinity` - time-of-day fit.
- `SurfaceDismissalLedger` - rest windows after dismissal.
- `SurfaceHistoryRecord` - what was shown recently.
- `SurfaceReadinessState` - whether a page can open immediately or needs local
  brain work first.
- `SurfaceActionRouter` - turns readiness and work state into open/block/start
  decisions.
- `WorkBlockingState` - central policy for concurrent local-brain work.
- `PreparedPageRecoveryState` and `BraidRecoveryState` - recovery after
  generation failures or interrupted work.

Curation is intentionally not pure randomness. It blends authorial source
scores with reader preference, memory, fatigue, time, and current context.

**Performance note.** The literary-continuity digest and motif clusters are
expensive over a large archive. They are computed once per data change and cached
(`ContentView.refreshContinuityCache`, signature-gated; `cachedContinuityDigest`/
`cachedMotifClusters`), and `sourceInputs` reads the cache. Never read
`sourceInputs` from a rendered SwiftUI view — that reintroduced a main-thread
freeze before the cache existed. Read dedicated `@State` (e.g. `weatherPageSignal`)
in views instead.

## Major Page Families

### Daily Capture Pages

Core capture pages include Inner Weather, Diary, One-Sentence Souvenir, Center
Page, Body Page, Fuel Log, Weather Page, Location Page, About You, and Calendar.

These are the low-friction material that later becomes the Book's archive.
Faculty-flavored capture windows, such as Dr. Inkrest for inner weather and Dr.
Vellum for fuel/body notes, use structured `FacultyEntry` records so the app
can tell whether a window has already been logged.

### Sentence Builder

`Shared/SentenceBuilder.swift` is the craft helper behind the Book's "make one
true sentence" habit. It is local, deterministic, and deliberately concrete: it
nudges the reader toward an anchor, a sensory detail, a living verb, and one
small crossed-sense image rather than vague magical phrasing.

Core pieces:

- `SentenceBuilderPack` - a configurable ritual pack (`core.faerie-real`) with
  an overlay for Souvenir sentences.
- `SentenceBuilderEngine` - returns the next nudge, analyzes the text, scores
  memory strength, emits craft marks, diagnostics, chips, and alchemy levels.
- `SentenceBuilderStepKind` - anchor, sense, motion, crossing, cutMist, and
  groundGlow.

- `SentenceScaffold` / `ScaffoldToken` - a tokenized view of the reader's own
  sentence, with grammar-safe per-word **transmutations** so tapping a word can
  swap it for a more living alternative in place.

This system supports the product thesis directly: the Book helps the reader
write a better kept page before any model has to embellish it.

The craft helper is surfaced in-app through **`LivingTextEditor`**
(`InsideCoverApp/LivingTextInput.swift`), the writing field used on capture
pages (`CapturePageSheet`). It wraps the plain editor with the live nudge, a
collapsible builder, tappable scaffold tokens, the transmutation chips, and a
shimmer/alchemy treatment as the sentence strengthens — all driven by
`SentenceBuilderEngine`, no model call.

### Book Of You

The Book of You is the nightly braid. It gathers kept pages from the day and
asks the local brain to compose them into a coherent personal page.

Related pieces:

- `BookOfYouPageSourceAdapter`
- `Braider`, `AppBraider`, `MLXBookBraider`, `FakeBraider`, `ResilientBraider`
- `BraidTextPolisher`
- `BraidRecoveryState`

The polisher removes repeated sentences, repeated ideas, motif echoes, and
overlong output. The braid only becomes canonical after it is successfully kept
and captured in the archive.

**Braid prompt context (continuity, not material).** `BraidPromptBuilder.context`
(in `Shared/LiteraryContinuity.swift`) now hands the braider a structured
`Context`: the two most recent earlier braids (continuity rule — at most one
returning image, never repeated sentences), the **month's theme** (used like a
faint watermark), the **ascendant Chapter** (from `TalismanAscendancy`), the
station currently playing (`nowPlaying`, from the living radio), and a
reader-taught `BraidLearningGuidance`.

**The braid quality/learning loop.** `BraidTastingRoom` scores a braid across six
deterministic dimensions — title, story shape, prior-braid echo, theme/Chapter
fit, keeper sentence, and concrete magic — minus penalties, and can `taste` and
rank candidates. `BraidLearningLoop` turns weak dimensions and reader feedback
into prompt guidance:

- The reader can mark a kept braid **"This is a true page"** (`braid-loved-it`) so
  the loop stops tugging the next braid away from what worked, or **"This missed
  me"** (`braid-missed-me`), which both records the lesson and offers a rewrite.
- "Read it another way" runs a **refereed rewrite**: the local brain rewrites the
  page from the weak-dimension notes, and the result is kept **only if it tastes
  better** than the original (`ContentViewFeatures`); otherwise the Book keeps the
  original and says so.
- Reader-taught notes persist in `vault.data.learnedBraidNotes` and sort ahead of
  the deterministic heuristics when building the next prompt.

Covered by `BraidPromptContextTests`.

### The Book Remembered

The Book Remembered resurfaces older kept pages when today rhymes with them.
It uses resurfacing candidates, page text, tags, and now literary-continuity
signals to explain why something returned.

This is one of the app's central "memory acting on memory" features. A returned
page is not just a search result; it is the Book saying, "This matters again."

### The Book Notices

The Book Notices is the dedicated page where the Book surfaces its own literary
observations. It is powered by `LiteraryContinuityProjector`.

It looks for:

- repeated patterns across kept pages,
- absences after previously repeated motifs,
- durations, such as how long a page or Belief has lived in the margins,
- Belief life cycles, including current glow, page count, event count, and
  related character count.

The page deliberately uses careful language:

```text
I am not certain yet. Books should be careful with certainty.
I have noticed...
```

It should feel like a living book forming opinions about the reader's story,
not like analytics.

The same page type also carries the rarer continuity moments: constellation
namings, sealed wagers, and opened seals (see Constellations And Sealed
Margins below).

### Constellations And Sealed Margins

`Shared/Constellations.swift` makes noticing consequential over time.

**Constellations.** A continuity signal that keeps surviving gets promoted into
a durable `Constellation` with a lifecycle:

```text
noticed -> watched -> named -> woven -> faded (and back, on return)
```

`ConstellationKeeper.advanced(...)` runs the promotions deterministically:
strength >= 58 creates `noticed`; three sighting days make it `watched`; five
sightings plus fourteen days of age earn it a Book-given name (`named`); nine
sightings make it `woven`; twenty-eight quiet days fade it. A faded
constellation that returns keeps its name and increments `returnCount`.

Names are deterministic per constellation and template-built by signal kind:
"The Harbor Thread", "What Shoreline Left Quiet", "The Long Archive",
"The Living Lamp". When a constellation crosses into `named`, the Book
surfaces a naming page ("The Book Names: ...").

**Sealed margins.** `SealedMarginEngine` lets the Book risk being wrong. A
strong pattern or absence signal can mint a dated, sealed `BookWager`
(maximum two sealed at once, with a 45-day per-subject cooldown). When the
open date arrives, the wager is judged against the pages actually kept since
sealing, and the Book surfaces an "opened seal" page owning the result either
way - being graciously wrong is part of the design.

Both ledgers persist in `PlayerVaultData` and are advanced by
`ContentView.tendConstellations()`, which runs alongside `tendArc()` at launch
and after narrative events. They flow into letters, gossip, monthly edition
forewords, and the save file/archive exports.

### Themes

`BookThemeEngine` (in `Shared/LiteraryContinuity.swift`) finds the month's
weather system: two or three motifs that kept gathering across kept pages,
continuity signals, and living constellations, joined into a deterministic
name like "Secrets and Harbors" or "Of Rain and Lamps". Each `BookTheme`
carries its motifs, a one-line description, evidence page IDs, and short
excerpt quotes pulled from the reader's own pages.

Themes are remembered per month in `PlayerVaultData.themes` (tended by
`tendConstellations()`); old months keep their themes forever. The live theme
flows into the Book Notices body ("The month itself is gathering into a
theme..."), character letter packets, and the monthly edition - where it
becomes the chapter subtitle and its own Themes page.

### Monthly Editions

Monthly editions are the first step toward annual bound volumes.

Each edition is a numbered chapter of a continuing book:
`chapterHeading` reads "The Book of You - bj - Chapter 3 - June 2026", where
the chapter number is the month's position among all months with kept pages,
and the subtitle is the month's theme name.

`Shared/MonthlyEdition.swift` builds a `MonthlyEdition` for the previous
calendar month. It curates:

- "What The Book Noticed"
- "Daily Braids"
- "One-Sentence Souvenirs"
- "Letters And Voices"
- "Images And Illuminations"
- "Other Kept Pages"

Every edition opens with a **foreword written by the Book**
(`BookForewordWriter`): what the month left in its keeping, what it noticed,
which constellations it named, and how its wagers went. The foreword is
deterministic - the same month always gets the same foreword.

### Volume I — The Annual

`MonthlyEditionBuilder.annual(year:...)` binds a whole year as a real **book of
chapters**, not one oversized month. It builds a fully-formed `MonthlyEdition`
for every month that kept pages (each keeping its own theme, foreword, star
chart, and binding style), and wraps them in an `AnnualEdition` carrying a
year-level foreword, the year's constellations and wager record, and a closing —
all deterministic and pure-local. Empty months are skipped; chapter numbers are
the months' positions among months with pages. Totals sum the chapters. Covered
by `AnnualEditionTests`.

`MonthlyEditionPDFWriter.writeAnnual(...)` renders it as a grand volume: a
constellation-cover title page; the Book's *Foreword to the Year* (with drop
cap); a *The Year in N Chapters* table listing each month and its theme; then,
per chapter, a **chapter-divider page** (month, theme, line) followed by that
chapter's own foreword, star chart, and curated sections (drawn in the chapter's
own palette/ornament, with per-chapter running heads and marginalia); and finally
back matter — *The Year's Constellations* star chart and a closing colophon. It
reuses the monthly renderer's primitives so the annual and the monthlies share a
visual language. The lab/export area exposes **Bind the annual** (→ `ShareLink`),
which binds the most recent year that kept pages.

`InsideCoverApp/MonthlyEditionPDF.swift` writes the edition to a PDF using
`UIGraphicsPDFRenderer`, and every month binds differently on purpose.
`EditionStyle.style(for:)` deterministically picks, from the month key and
theme:

- one of six palettes (Harbor, Lamplight, Violet Dusk, Forest Margin,
  Rose Vellum, Slate Nocturne),
- a procedural cover motif (constellation chart, moon-and-waves, lamp,
  sprig, key-and-door) - theme motifs can pull the choice (water words get
  waves, light words get the lamp),
- an ornament style (diamonds, stars, waves, leaves) used on rules
  throughout.

The bound volume contains, in order: a full-bleed illustrated cover with the
chapter heading and theme subtitle; the Book's foreword with a drop cap;
a Themes page (theme name, line, excerpt quotes, motif chips); "The Reader's
Sky" - a dark star-chart page drawing the living constellations with labels
and a legend; a contents page; the curated sections with running heads,
section opener bands, date chips, and the Book's own marginalia in the left
margin (drawn from continuity signals, named constellations, and theme
motifs); framed image plates (including Photos-library assets resolved at
binding time when access is already granted); and a colophon.

The lab/export area in `ContentView` exposes `Bind monthly edition`; once
generated, the control becomes a `ShareLink`.

This system is intentionally archive-driven. It does not generate a whole book
from scratch. It binds accumulated artifacts into a coherent monthly volume.

### Ask The Book

Ask the Book is a conversational surface. It can answer from local context,
archive material, and enchantment follow-up state. The prompt contract keeps
answers in the Book's voice but bans pretending the reader completed real-world
actions.

Related pieces:

- `AskTheBookPageSourceAdapter`
- `AskTheBookTurn`
- `AskTheBookAnswering`
- `MLXAskTheBookAnswerer`
- `FakeAskTheBookAnswerer`

### Story Pages

Story Pages are generated narrative scenes built from the story field. They can
include selected entities, threads, relationships, memories, recent real-world
signals, and a three-choice grammar.

Related pieces:

- `StoryScenePacketBuilder`
- `StoryPagePromptBuilder`
- `StoryPageResultPromptBuilder`
- `StoryPageSceneDraft`
- `MLXStoryPageWriter`
- `MLXStoryPageResultWriter`
- `NarrativeEventResolver`

Keeping or continuing story pages can record choice events and move the
narrative field.

### Gossip Pages

Gossip Pages simulate offscreen world motion. They show what characters,
threads, and entities are doing when the reader is not directly interacting.

Gossip is deliberately juicy and specific, not generic margin-muck. Each turn
carries:

- a quoted overheard line attributed to a named witness from the cast,
- a concrete detail drawn from the actor's quirks, faults, beliefs, or
  unwritten interest,
- stakes ("If it works... If it curdles, that fault becomes the story
  everyone tells at breakfast"),
- a callback to one of the reader's own kept pages from that day,
- a whisper about any named constellation the Book keeps, when one touches
  the actors or thread involved.

Gossip can create narrative events, occasionally Chapter Talisman Belief moves,
and **character-to-character Belief moves** (`GossipRelationshipMove`): an actor
invests in or attacks another character, chosen by reading the relationship field
and applied on keep (see "The Living Relationship Field"). It is a way for the
world to keep living — and the cast's web to keep shifting — between direct scenes.

### The Bleed (Pocket Edition)

`Shared/TheBleed.swift` brings the Academy's student newspaper to the phone
as a distilled twice-daily edition in Penny Blackletter's voice (Records
Clerk, Department of Attestation - dry, precise, suspicious of the word
"resolution"). The full broadsheet still lives on the Mac.

Two editions a day, by the clock: the **Morning Edition** (4:00-12:59)
focuses on the day ahead; the **Evening Edition** (from 16:00) on tomorrow.
Each carries:

- **Casement Weather** - deterministic clerk-voice weather column.
- **Today at the Academy / Tomorrow, Posted Early** - the reader's real
  calendar events, posted as the corridor noticeboard.
- **The Morning/Evening Ledger** - Penny's lead column, written by the local
  brain from a packet of continuity signals, named constellations, sealed
  wagers, the month's theme, the current arc, and today's kept pages.
- **Corridor Whispers** - the gossip simulation turns rewritten as signed
  whispers, mechanics preserved.
- **The Reader's Shelf** - a researched column on one of the reader's About
  You interests. The default path uses open-web clippings through DuckDuckGo
  fallbacks. Reddit is optional: if an approved installed-app client ID is
  configured in Colophon or bundled app configuration, the app can use
  app-only OAuth search against Reddit without asking readers to sign in to
  Reddit. If Reddit is not configured or fails, the Shelf stays live on the
  open-web path. Morning and evening pick *different* interests on the same
  day.

Delivery is two-stage and in character: the curator surfaces an announcement
("The newest edition of The Bleed is here - Open it"); opening it runs the
presses (`prepareBleedEditionIfPossible`): interest research, one local-brain
call per written column, then deterministic compositing into a single page
with masthead and colophon ("Set in type by P. Blackletter, who attests every
word and regrets several"). Issue numbers count kept editions forever.
Keeping an edition feeds Belief to `penny-blackletter`. A lab control binds
the latest edition as a broadsheet-style PDF (`BleedPDFWriter`).

### Character Letters

Letter Pages are character-authored correspondence. Sender selection considers
Belief, narrative weight, memories, recent story field presence, custom cast,
and stable jitter.

Letters can include:

- preferred reader name,
- sender voice profile,
- memories and recent events,
- unwritten interest,
- home/context material,
- continuity packet from the Book's observations,
- occasional Chapter Talisman deltas.

Related pieces:

- `CharacterLetterPageSourceAdapter`
- `CharacterLetterPromptBuilder`
- `MLXCharacterLetterWriter`
- `FakeCharacterLetterWriter`
- `CharacterLetterWriter`

### Dr. Inkrest's Office Hours

A short, distilled narrative-therapy sitting with Dr. Selene Inkrest that opens
in an evening window (8:00-10:00 pm) when the reader has kept at least one page
that day, or when a hard signal asks for gentle company.

The flow is a button-gated conversation, not an automatic one:

1. An intake form offers a rotating narrative-therapy question (externalizing,
   unique outcome, preferred story, values, re-authoring, and so on - chosen
   deterministically per day), plus "inner weather" and a free note.
2. "Knock on the door" sends the intake to the local brain, which answers in
   Inkrest's voice, grounded in her `SupportFacultyChart` (allowed/forbidden
   uses, invitations, the safety line) and the day's kept pages.
3. The sitting runs ~4-5 exchanges as one living page; Inkrest then closes with
   a re-authoring sentence and one small experiment.

Related pieces:

- `InkrestOfficeHoursPageSourceAdapter`, `InkrestOfficeHours` (window + rotating
  prompts, in `Shared/SourceAdapters.swift`)
- `InkrestIntake`, `InkrestOfficeHoursCounseling`
- `MLXInkrestOfficeHoursCounselor`, `FakeInkrestOfficeHoursCounselor`
- `LocalModelManager.inkrestOfficeHoursPrompt(...)`

The whole sitting keeps as one page; it feeds Inkrest's narrative threads.

### Margins Atlas

The Margins Atlas is the relationship/constellation surface. It has two
variants:

- **The Loom** - threads, warmth, tension, and relationship crossings. The Loom
  renders the **living relationship field** (see "The Living Relationship Field"),
  so it evolves with play rather than showing a fixed diagram.
- **The Constellation** - Belief stars and attention lines.

It is the app's knowledge graph disguised as magic.

### Wonder Compass And Playful Missions

Wonder Compass pages draw from reference snippets and mission registries. They
can offer Playful Missions, including South = Sense style sensory errands, and
can ask the local brain to generate a fresh custom mission.

Related pieces:

- `WonderCompassPageSourceAdapter`
- `PlayfulMissionRegistry`
- `PlayfulMissionWriter`
- `MLXWonderCompassChooser`
- `WonderCompassFallbackChooser`

### Enchantments And Illuminated Photos

Enchantments are camera/photo spells. A photo or object becomes material for a
spell such as poetic translation, connection, haiku, roasting, mirror, and
other modes defined by `StoryEnchantmentCatalog`.

The photo stack includes:

- Photos and Vision integration for candidate discovery/captioning,
- `PhotoLibraryService`,
- `PhotoCandidateScorer`,
- `VisionPhotoCaptioner`,
- `GemmaPhotoIlluminationAnalyzer`,
- `VLMPhotoIlluminationAnalyzer`,
- `IlluminatedPageComposer`,
- `MLXEnchantmentWriter`.

Illuminated Photos render manuscript-style image pages using bundled marginalia,
scraps, stamps, texture overlays, and layout templates.

### Weather, Body, Fuel, And Local Signals

The app can translate real signals into book pages:

- HealthKit/body data through `HealthKitBodyReader`.
- Weather through `WeatherLocationReader` and `WeatherSourceSignal`.
- Fuel logs through `VellumNutritionist` and USDA lookup when a key is present.
- Moon phase through local astronomy in `MoonPhaseCalendar`.
- Calendar pressure through `CalendarEventSignal`.
- Nearby places through `LocalPlacesScout`.

The design rule is that signals become atmosphere and pages, not exposed raw
telemetry dashboards.

### Anchors And Outer Stacks

Anchors turn real places into story rooms. Default anchors ship empty; anchors
belong to the reader's save.

Key pieces:

- `AnchorRecord`, `AnchorKind`, `AnchorRegistry`, `AnchorMath`
- `AnchorLocationReader`
- `AnchorOfferFormView`
- `OuterStacksAnchorPageSourceAdapter`
- `OuterStacksRoomEngine`
- `OuterStacksRoomSpec`

Known anchors can light within roughly 200 meters. Unanchored real places can
be offered as future anchors. Check-ins update the anchor ledger and can reward
Belief.

### Classes, Clubs, And Electives

Academy classes and clubs come from schedule registries and surface at relevant
times. Unwritten Electives let characters ask for small real-world favors tied
to their interests and, when available, nearby real places.

Related pieces:

- `AcademyScheduleRegistry`
- `AcademyClassPageSourceAdapter`
- `ElectivePageSourceAdapter`
- `UnwrittenElective`
- `ElectiveOfferWriter`
- `ElectiveFlyleafListView`

### Help, Tips, Lore, Quips, Patreon, And Packs

Reference-style content is sourced from registries and packs:

- `HelpTipsCatalog`
- `BookReferenceCatalog`
- `BookReferenceLibrary.json`
- `QuipPackRegistry`
- `PageArchetypePackRegistry`
- `BookShopCatalog`
- `PackEntitlements`

Help and Tips is practical user guidance in the Book's UI. Lore and quips are
public-reference material. Pack pages are a bridge toward more data-driven
content.

## Belief

Belief is a 0-100 attention and world-energy value used at multiple levels:

- reader/book Belief,
- entity Belief,
- page-source Belief,
- Chapter Talisman Belief,
- custom cast starting Belief.

Belief does not just change copy. It influences curation, story-field weights,
Glow menus, entity prominence, Chapter ascendance, and event effects.

Important types:

- `PageBeliefProfile`
- `GlowCommandMenu`
- `GlowEntityMenuItem`
- `GlowPageMenuItem`
- `NarrativeEventEffect`
- `ChapterTalismanMove`
- `PlayerVaultData.entityBelief`
- `PlayerVaultData.pageBelief`

The Glow menu lets the reader give or take Belief from page sources and world
entities. Those changes become ledgers and narrative events, not invisible
settings. The Glow menu is also the entry point to the BookShop, **The Margin**
(Fae standing), and **The Pact Map** (the Talisman territory war).

### The Belief Economy Engine

`BeliefEconomyEngine` (`Shared/WorldSystems.swift`) keeps Belief from inflating to
"topped-up Glow everywhere," with a persisted `BeliefEconomyState` on the vault:

- **Daily tide (targeted income).** A once-a-day tick (`runBeliefEconomyDailyTick`,
  day-gated) gives the reader a small ember for keeping pages and feeds only the
  **top-2 recently-touched** entities under 70 — never the whole cast.
- **Settling (the sink).** Reader Glow above a soft ceiling cools overnight;
  untouched high-Glow entities (>70) and page sources (>60) cool toward floors.
  The Nothing and its kin are excluded from both the tide and the cooling —
  antagonist Glow only moves through real events.
- **A closed cast economy.** Gossip invest/attack makes the *actor spend* Belief
  (`castSpendDelta`, never below a floor), and **invest is conservative** — a
  depleted actor can't mint Belief for a target; the target gains exactly what the
  actor paid.
- **Keep/dismiss pressure.** Keeping a source warms it (once/day, capped);
  repeated dismissals cool it.
- **Legibility.** Each tick records `recentMovements`; the app surfaces a one-line
  **overnight digest** ("Overnight: your Glow settled by 3, Zara Finch cooled 2.").

## The Inventory

The `inventory` page type gathers the reader's working magical objects in one
place. It is not a generic settings screen; it is a clasped flyleaf showing what
the Book can actually use.

It currently surfaces:

- warm, cold, spent, and repairable Fae gifts,
- installed BookShop folios / owned content packs,
- story objects and custom cast artifacts with their current Glow,
- gift actions such as Quieting, Reshelving, Long Memory, Calling Card, and Loose
  Page turns.

Related pieces:

- `InventoryPageSourceAdapter`
- `CapturePageSheet.inventoryPageView`
- `FaeGiftEffects`, `LoosePageReader`, `PackEntitlements`
- vault fields for Fae state, owned packs, custom cast, and object Belief

The Inventory is where Fae economy, content packs, and durable story objects
become visible as usable tools.

## ReEnchanted Radio

The `radio` page type is an Academy radio dial that can tint the feed while a
station is tuned. Stations carry frequency, host, signal line, interludes, track
metadata, mood tags, and explicit page-type boosts.

Core stations ship in `RadioStationRegistry`:

- Fae-Fi (88.3) - bright/playful faerie lo-fi; leans toward Wonder Compass,
  souvenirs, and festivals. Bundled tracks: **Mossy Footsteps**, **Folktronica**,
  and **Mossy Groove**.
- Mothlight Beats (90.9) - bittersweet wistful fae-fi; leans toward remembered
  pages, inner weather, and diary. Bundled tracks: **The Page Came Through**,
  **Fae Dust**, and **Porchlight Fading**.
- Thornwave (103.7) - dark faerie lo-fi / trip-hop / future garage; leans toward
  Book Fae, story, and gossip. Bundled tracks: **Bramble Bass** and
  **Nocturnal Faerie Lounge**.

Two further stations ship behind pack entitlements: **The Midnight Bindery** and
**Goblin Market Jazz** (with their own bundled tracks).

Radio can also load user or pack stations from `.reenchantedradio.json` files.
`RadioPlaybackState` persists the active station and tuning state in the vault,
`BookRadioManager` handles local playback/Haptics in the app, and
`RadioPageSourceAdapter` turns the dial into a keepable surface. Curation reads
`RadioStationRegistry.surfaceBoosts(...)` so the active station has mechanical
weight rather than being only ambience.

Bundled audio lives under `InsideCoverApp/RadioAudio/` and is included as a
folder reference in the app target. `BookRadioManager` checks that bundle
folder first, then the bundle root, then reader-writable Documents radio
folders (`Documents`, `Documents/Radio`, and `Documents/RadioPacks`). It accepts
common local formats (`m4a`, `mp3`, `wav`, `aac`, `caf`, `aiff`) and falls back
to procedural synth playback if no asset resolves. Track choice rotates by a
stable station hash and half-hour window, so a station can feel alive without
requiring network audio.

### The Living Radio (the station leaves marks)

Beyond curation, the tuned station reaches into the rest of the Book — like Book
Jump, it leaves marks. All pure-local; no extra model calls.

- **Atmosphere in the prose.** `RadioStationRegistry.atmosphereLine(...)` feeds a
  soft `RadioAtmosphere.promptSection(...)` ("WHAT'S PLAYING — let it color tone,
  never name it") into the braid (via `BraidPromptBuilder.Context.nowPlaying`),
  Story Pages, Book Fae encounters, gossip, and character letters. Thornwave
  darkens a fae parley; Mothlight makes a letter wistful.
- **Listening constellations.** Each real tune records into
  `RadioPlaybackState.listening` (distinct days + sessions). After three days,
  `RadioStationRegistry.listeningSignals(...)` emits a `.listening` continuity
  signal that flows through `ConstellationKeeper` exactly like other signals:
  noticed → watched → named ("You and Thornwave", "The Midnight Frequency") →
  woven. It then appears in The Book Notices and the monthly edition for free.
- **Held-station effects (real stakes).** A station kept tuned for
  `heldEffectDays` distinct days grants a signature reward: Thornwave lets the
  Nothing's grey lean one shade nearer (`greyShift`, distress-safe), Fae-Fi's
  brightness pushes it back, and Mothlight Beats deepens remembering
  (`heldSurfaceBoosts` → Book Remembered). Wired into the same `NothingTide`
  greyShift sum and `CuratorMood` boost merge the Almanac and Book Jump use.

## Book Jumping (stepping into public-domain books)

`BookJumpEngine` (`Shared/StoryEngine.swift`) lets the reader step through the
Spine into a real public-domain book — a controlled, page-at-a-time ritual that
**leaves marks on the book they live in**.

- **The shelf.** Fourteen hand-authored public-domain works (Alice, Oz, Austen,
  Frankenstein, Dracula, *A Christmas Carol*, Holmes, *The Secret Garden*,
  Treasure Island, Moby-Dick, Don Quixote, the Odyssey…), each with its own world,
  arrival, Nothing, rules, and resonances, plus a Gutenberg link. Selection is
  resonance-matched to the reader's recent pages, themes, and clusters.
- **The loop.** Open the Spine (spends Belief) → go deeper (escalating cost; the
  Nothing's pressure climbs with depth) → stabilize (name a real detail to lower
  pressure) → Find the Spine and return with a one-sentence souvenir
  (depth-scaled reward). One beat per kept page; the live brain writes each beat,
  anchored to a true detail from the reader's day and a chosen guide.
- **The fork (reader agency).** An open jump replaces the generic Keep button with
  explicit in-page controls — **Go one page deeper**, **Steady the page** (once the
  Nothing is loud), and **Find the Spine and return** (from depth 2 on, its label
  showing whether a souvenir is in hand). Each rewrites the beat's action + tag so
  Belief cost/reward, the borrowed-rule grant, and souvenir resurfacing stay
  correct (`keepBookJump(as:)` in `CapturePageSheet`). Depth and Nothing meters
  make the stakes visible.
- **Borrowed Rules.** Returning *with a souvenir* carries one of the book's rules
  home as a time-boxed `BorrowedRule` with a real, cross-system effect
  (`BorrowedRuleEffect`) — Holmes sharpens Book Notices, Dracula warms records,
  *A Christmas Carol*/Secret Garden push the Nothing's grey back, Oz warms the
  cast. Effects feed the same curator seams as the Almanac (`surfaceBoosts`,
  `greyShift`).
- **Real stakes.** Leave a jump unstabilized and the daily tick lets the Nothing
  gain a margin; if it overruns, the jump **collapses** — you lose the staked
  Belief and that book goes **cold** for a few days (skipped by selection until it
  warms back), mirroring the Fae-lapse pattern.
- **Living-world marks.** The guide who traveled with you deepens (Belief +
  relationship warmth on a companionship rule); the brought-back souvenir
  resurfaces through The Book Remembered, attributed to its source book; repeated
  visits to a book — or a repeating resonance family across books — form a named
  **companion constellation** ("You and Oz keep meeting…").
- **The open shelf.** The lab area lets the reader name *any* book; the Book
  improvises a door (`improvisedWork` + `startCustom`) and enters it live.

Covered by Book Jump and Belief-economy tests in `WorldSystemsTests`.

## Chapters And Talismans

Chapters are represented as talisman entities in the narrative pack. Talisman
Belief can move when story pages, gossip, or letters carry talisman deltas.

Behavior:

- Entities can give Belief to their own Chapter's talisman.
- Entities can attempt to take Belief from a rival talisman.
- Generated pages carry structured move metadata.
- Keeping the page applies the resulting ledger deltas in `ContentView`.

This makes world politics and attention mechanically persistent without turning
the app into a combat system.

## The Book Fae And Bargains

The Book Fae are creatures born from the ink who have read every description of
the world but never touched it - so the reader is their field agent in the world
of matter. The system models six species (`FaeKind`: Book Sprite, Sentence
Salamander, Punctuation Pixie, Literary Elf, Deep Lore Dwarf, Marginalia
Goblin), each hungry for a different kind of noticing and with its own voice.

A **Fae Bargain** is not a quest: the fae gives first, unprompted, then the
reader owes a sensory field report. Fae never trade in Belief - the stakes are a
parallel economy:

- **Warmth** - per-species reputation, earned by genuine deliveries, cooled by
  lapses.
- **Attention** - the goblins' currency, earned by paying bargains, spent at the
  Goblin Market.
- **Gifts** (`FaeGift`) - functional talismans the fae *fronts on credit*, each
  with a real effect (`FaeGiftEffect`): Reshelving (lifts a rested page kind back
  to the front), Quieting (holds the Nothing's grey back a shade), Long Memory
  (pins a kept page to resurface), Calling Card (opens the Goblin Market), and
  Loose Page (a static, regenerating collectible).

**The stake:** if a bargain is not paid by its deadline it lapses - the fronted
gift goes *cold* (stops working) and that species' market closes until the debt
is repaired. No Belief loss, never under distress, always repairable - but a real
loss of working tools and access.

Lifecycle (the page): the fae fronts a bargain (`tendFae()`, local, no model
call); the `FaeBargainPageSourceAdapter` surfaces the open debt (or a lapsed one
to repair); the reader pays with a field report; the local brain answers in the
fae's voice with a true lore fragment (the only model call, button-triggered);
keeping the page records the delivery (warmth + attention).

The separate `bookFae` page type is an interactive old-law encounter with the
Fae themselves. It follows the strongest active omen when one exists, presents
structured choices, and can create or alter omens and Fae economy state without
pretending a real-world field report happened. It uses local-brain prose when
available, with a static fallback, and is covered by `FaeBargainTests` and
`SurfaceReadinessStateTests`.

Supporting surfaces:

- **The Margin** (Glow menu) - the hub: Attention wallet, per-species Warmth,
  every gift (warm/cold/spent), and open/lapsed bargains.
- **The Goblin Market** - spend Attention for gifts, mood-priced, gated by the
  new-moon window or a Calling Card.
- **Goblin Marginalia** - occasional static goblin annotations on kept pages.
- **Seasonal goblin moods** - season maps to a `GoblinMood` that shifts market
  prices and tone.

Related pieces (all in `Shared/WorldSystems.swift` unless noted):

- `FaeKind`, `FaeGift`, `FaeGiftEffect`, `FaeBargain`, `FaeBargainStatus`,
  `FaePlayerState`
- `FaeEconomy` (offer / lapse-sweep / deliver / repair / purchase), `GoblinMood`
- `FaeBargainTemplate`, `FaeMarketCatalog`, `FaeGiftEffects`, `LoosePageReader`,
  `GoblinMarginalia`
- `FaeBargainPageSourceAdapter` (`Shared/SourceAdapters.swift`)
- `FaeBargainResponding`, `MLXFaeBargainResponder`, `FakeFaeBargainResponder`,
  `LocalModelManager.faeBargainResponsePrompt(...)`
- `TheMarginSheet`, `GoblinMarketSheet`, `FaeGiftCard`
  (`InsideCoverApp/BookStatusCards.swift`)
- vault: `PlayerVaultData.fae`; orchestration: `ContentView.tendFae()`,
  `payFaeBargain(...)`, `buyFaeGift(...)`

## The Pact War

Each Talisman has a philosophy it wants to spread, and the war is them contesting
**territory** across two fronts:

- **Shelves** - the Book's own page-kind domains (Reflection, Care, Story,
  Connection, Field).
- **Real-world doors** - the integrations the app touches (the Calendar Door,
  the Whisper Channel/notifications, the Body Margin, the Illuminated Plate, the
  Window Sky).

Control is **Control Belief, per talisman, per territory** (separate from overall
Belief), climbing the lore tiers: Contesting -> Influenced -> Controlled ->
Dominated -> Sovereign. A territory has a controller only on a clear lead.

The war is a pure local simulation - never a model call, silent under distress:

- `PactWarEngine.tick(...)` runs once a day (`ContentView.tendPact()`, alongside
  `tendArc`/`tendFae`). Each Talisman takes one pact action (Push / Challenge /
  Raid / Consolidate), gated by its overall Belief exactly like the doctrine
  (<30 push only, 30+ challenge, 50+ raid). Natural alignment makes aligned
  pushes stronger.
- The Chapter the reader is Bound to gives its Talisman a home-field bonus.
- The reader is a combatant: investing Belief presses a Talisman's claim
  (`pressPactClaim(...)`).

**Real effects (the stakes are felt, not cosmetic):**

- A shelf held at Controlled+ gives its page kinds a curator surfacing lift
  (`PactWarEffects.shelfBoost`, wired into `CuratorMood`).
- The controlling Chapter's `writeFraming` rewrites the writing prompt on that
  shelf's capture pages (`PactWarEffects.framed`, shown on the capture sheet).
- The real-world doors get voices: the Whisper Channel's controller recolors the
  Book's actual notifications, the Calendar Door's controller recolors Hour Page
  questions, and the Body Margin / Window Sky / Illuminated Plate controllers
  speak an epigraph over Body / Weather / Photo pages (`PactVoices`,
  `PactWarEffects.doorEpigraph`, applied in `BookWhispers`, the calendar adapter,
  and `framed`).

**Pact Dispatches.** When a tick seizes a territory or a Talisman crosses into
Sovereign, the engine queues a `PactDispatch` (detected against a value-type
snapshot in `tick`). `PactDispatchPageSourceAdapter` surfaces it as a keepable
`pactDispatch` lore page (static prose, no model call); it stops surfacing once
kept (tracked by a `pact-dispatch:<id>` tag) and the queue self-prunes after a
few days. A Sovereign crossing also fronts a rare Marginalia Clan (goblin) Fae
Bargain - the two systems feed each other (`ContentView.tendPact`).

**Sovereign automation.** A Talisman that reigns Sovereign acts unprompted,
within the user-initiated-model rule (scheduling/surfacing only, never silent
generation): Sovereign over the Whisper Channel schedules an extra morning
whisper in its voice (`PactVoices.sovereignWhisper`); Sovereign over a shelf is
guaranteed a slot in the surfaced feed (`PactWarEffects.sovereignShelfPageTypes`,
applied in `BookCurator.surfacedPages`).

Surface: **The Pact Map** (Glow menu) shows every territory with its controller,
tier, per-Talisman control bars, recent moves, and a "Press your claim" button.

Related pieces (in `Shared/WorldSystems.swift`):

- `PactFront`, `PactTerritory`, `PactTerritoryRegistry`, `PactTier`,
  `PactActionRecord`, `PactDispatch`, `PactWarState`
- `PactWarEngine` (alignment, overall-belief/home-field, tick, crossing
  detection), `PactWarEffects`, `PactVoices`
- `PactDispatchPageSourceAdapter` (`Shared/SourceAdapters.swift`)
- vault: `PlayerVaultData.pactWar`; UI: `PactMapSheet`
  (`InsideCoverApp/BookStatusCards.swift`)

## Notifications And Real-World Writing

Beyond reading the reader's world (calendar, Health, weather, location), the Book
reaches *outward* through the system - the literal "bleed-out".

**Whispers (`BookWhispers`, `AppSupport.swift`).** Scheduled local notifications:
the evening braid whisper (daily, 20:45), class/club bells (next three days), and
favor reminders for aging electives. The braid whisper's voice is recolored by
whoever holds the Pact War's Whisper Channel, and a Sovereign holder adds an
extra morning whisper. `BookWhisperPresenter` is installed at launch as the
notification-center delegate so whispers also appear while the app is in the
foreground. A "Send a test whisper" control fires one ~10 seconds out to verify
the pipeline.

**Real-world writing (`EventKitWriter`, `AppSupport.swift`).** Always
user-initiated buttons, never automatic:

- A Fae Bargain can set a real **Reminder** before its fronted gift goes cold.
- The Goblin Market can write the next new-moon window to the **Calendar**
  (`MoonPhaseCalendar.nextNewMoon`).

Calendar/Reminders writes need `NSCalendarsFullAccessUsageDescription` and
`NSRemindersFullAccessUsageDescription` (both in `Info.plist`).

## World Event Packs

`Shared/WorldEvents.swift` defines temporary world physics supplied by bundled
or imported event packs. Unlike ordinary content packs, a world event can
influence nearly every surface: curation, story packets, class flavor, letters,
notifications, visual treatment, and monthly binding.

The model is structured:

- `WorldEventPack` contains enabled events from bundled packs or user-imported
  `.reenchantedevents.json` files.
- `WorldEvent` defines title, calendar window, phases, triggers, outcomes,
  effects, and an `EventInfluencePacket`.
- `WorldEventResolver` resolves the active phase, player touch count, outcome,
  and effect list for the current date.
- `WorldEventPageSourceAdapter` surfaces active fieldwork prompts as keepable
  pages.

The bundled pack is **The Living Almanac**, currently including two events:
**The Dictionary Rebellion**, a September event where words peel away from their
definitions; and **The Starlit Paper Trial**, an archived midnight hearing where
receipts, lists, and loose notes are called to testify to the day's overlooked
kindnesses. Each runs through authored phases (summons → hearing → verdict, etc.).
Touches from related kept pages, class answers, letters, Compass Runs,
Enchantments, and other triggers can move the event toward an outcome. Monthly
editions bind world-event traces from kept tags, so temporary physics become
part of the archive rather than disappearing after the event window.

**Reader-facing narration vs. generation material.** Each `WorldEventPhase` now
carries an optional `scene` — in-character prose in the Book's voice describing
what is happening this phase — distinct from `packetLine` (a generation
instruction). The adapter's `narrativeBody` composes the player-facing page from
the logline, the lived scene, the packet atmosphere, a derived **standing line**
(how far the reader has stepped in, from outcome + `playerTouchCount`), and the
fieldwork invitation — deliberately keeping lexical rules and generation
instructions out of view. User-imported packs without `scene` fall back to the
logline.

**The Living Almanac door (Glow menu).** A `GlowMenuAction.openAlmanac` entry
opens the world-event door directly (`ContentView.almanacSurface`): the active or
archived event, or the quiet card. In DEBUG, when nothing is in season,
`WorldEventResolver.previewEvents` / `WorldEventPageSourceAdapter.previewSurface`
resolve an event against a synthetic window so the full machinery (phases,
outcomes, packets) is always reachable for development.

## The Almanac (Wheel of the Year + lunar esbats)

`Almanac` (in `Shared/WorldSystems.swift`) makes the app breathe with the real
sky and the pagan year. For any date and hemisphere it knows the active
celebrations:

- The eight **Sabbats** of the Wheel (Samhain, Yule, Imbolc, Ostara, Beltane,
  Litha, Lughnasadh, Mabon), hemisphere-aware (southern readers get the opposite
  point on the same date).
- The lunar **esbats** — every **Full Moon** (*The Luminous Gathering*) and
  **New Moon** (*The Quiet Hours*), read from `MoonPhaseCalendar`.
- Meteor showers (Perseids, Geminids).

Each `Celebration` carries an Academy name, prose, an **invitation** (a thing to
notice/do), a Belief bonus, a Nothing effect, and a palette accent. The
`festival` page type surfaces the day's headline celebration with its invitation
(`FestivalPageSourceAdapter`); keeping it pays the bonus, and the **full moon
doubles** Belief for festivals and Enchantments.

The Wheel bends every system, all pure-local and distress-aware:

- **The Nothing** — `Almanac.greyShift` feeds `NothingTide.greyLevel`: light
  feasts (full moon, Litha) push the grey back; thinning-veil nights (Samhain,
  new moon) let it nearer.
- **Curation atmosphere** — `Almanac.surfaceBoosts` leans the feed toward
  fitting page kinds (Samhain → Book Remembered; full moon → Souvenirs; Beltane
  → Letters/Cast; etc.), wired into `CuratorMood`.
- **The Fae** — `ContentView.tendAlmanac` opens a Marginalia-Clan bargain on
  Samhain and a free Fae window on the full moon.
- **Bleed-out** — a festival whisper at 6pm (`BookWhispers`) and an "add the
  feast to my Calendar" button (`EventKitWriter`).

Hemisphere comes from the reader's last known latitude (`Hemisphere.from`).

### Today's Sky

`SkyAlmanac` (also in `Shared/WorldSystems.swift`) reads the night overhead for a
date and hemisphere — the everyday companion to the Almanac's special feasts. It
is pure local astronomy: `SkyEphemeris` computes low-precision ecliptic
longitudes for the Sun and Moon (good to a degree or two — "close enough for a
storybook"), `Zodiac` names the tropical sign each one stands in, and
`SkyAlmanac.lightTrend` reports whether the light is lengthening, drawing in, or
near balance (hemisphere-aware, from the Sun's longitude relative to the equinox
and solstice points). `SkyAlmanac.nextEvent` picks the soonest reason to look up
— the next Full Moon, New Moon, or meteor-shower peak (seven showers, from the
Quadrantids to the Geminids) — with a "tonight / tomorrow night / in N nights"
phrase.

`SkyAlmanac.reading` bundles all of it into a `SkyReading` (moon phase + sign,
sun sign, light trend, next event, any shower peaking now, a rotating opener, and
a set of prose notes). The `todaysSky` page type surfaces it in the evening
(after 5pm, once a day) via `TodaysSkyPageSourceAdapter` — a gentle page,
welcome even on a hard day. The page shows three callouts (the Moon and its sign,
the Sun and the turning of the light, the next event) plus an "add a sky-watch to
my Calendar" button (`EventKitWriter`) seeded with the next event's date. Keeping
it deepens the reader's tie to *ordinary-magic* and the Book. The Almanac leans
the feed toward Today's Sky on esbat and shower nights via `surfaceBoosts`. No
model call — the reading is entirely computed. Covered by `TodaysSkyTests`.

## The Returning Greeting

When a returning reader opens the app (after the opening movie, never the first
run, once per launch), `presentReturningGreetingIfNeeded` shows an animated
overlay (`BookGreetingOverlay`) that greets them by name and adds one dynamic
line about what's alive right now. `BookGreetingComposer` (pure, tested) rotates
the opener and picks the line by priority: a festival, then an open Fae bargain,
then a fresh Pact dispatch, then yesterday's kept-page count, then a grey
stretch, else a call to make magic. It bleeds in from the top and slips away on
its own (or on tap).

## The Two Readings (character disagreement)

A page where two cast members read the reader's recent pages and reach
**different conclusions**, and the reader decides. The pair is chosen
**dynamically** by `DisagreementEngine.select` (`Shared/NarrativeCore.swift`) —
scoring every character pair by relationship tension, Chapter contrast, how well
each fits the current evidence, Belief weight, and rotation; never a hardcoded
table. The disagreement itself emerges from each character's real beliefs,
faults, and voice in the generated prose (`TwoReadingsPageSourceAdapter`,
`LocalModelManager.twoReadingsPrompt`, written through `LocalBrainProse`).

The reader **sides** with one (two buttons). On keep (`applyTwoReadingsSiding`):
the chosen character gains Belief and the reader spends one to give it; the other
cools; and the **relationship field** tenses the thread between the two arguers.
The kept page records the prose, who was sided with, and `entity:`/`sided:` tags,
so the choice echoes into cross-letter memory and gossip.

## Cross-Letter Memory

`CharacterLetterPageGenerator.crossLetterMemory` adds a "since your last letter"
packet to each letter draft (which the letter prompt embeds): the sender's own
previous letter and an excerpt, whether the reader recently sided **with** or
**against** them in a Two Readings, and how their Belief standing has moved. So a
letter remembers itself and reacts to the reader's choices, instead of starting
cold. Soft ("acknowledge if present"), pure-local, no extra model call.

## The Living Relationship Field

The Loom (the cast-relationship graph) is no longer a static authored diagram —
it is a **simulation**. A persistent `relationshipField` (`vault.data` →
`BookSourceInputs.relationshipField`, keyed by entity pair) holds accumulating
`RelationshipTie` values (warmth / tension / familiarity) that grow from what
actually happens, layered over the authored base edges by `NarrativeGraphData.loom`:

- Shared story scenes and gossip **warm and familiarize** the characters in them.
- A story scene escalates the **dominant** tone of each pair — characters already
  in conflict grow *more* tense, not warmer (`weaveRelationshipField`).
- Siding in The Two Readings **tenses** the judged pair.
- **Gossip Belief moves** (below) warm or tense the pairs they touch.

The Loom **renders the field**: authored threads shift, and entirely new
"woven"/"disputed" threads emerge between characters the authored graph never
connected. `RelationshipFieldEngine` is the pure engine (`weave`, `entityIDs`);
the app feeds it on every keep and siding.

**Gossip Belief moves.** Gossip turns now carry a `GossipRelationshipMove`: an
actor **invests** in or **attacks** another character, chosen by *reading the
field* (tense pairs get attacked, warm/familiar pairs get invested in). It is a
structured token (not parsed from prose) that, on keep
(`applyGossipRelationshipMoves`), moves the target's Belief and the pair's tie —
and it is fed into the gossip prompt so the rumor dramatizes it. Story generation
also reads the field, surfacing live ties as scene pressures ("they have grown
tense lately — let that friction show").

This closes the loop: play → events reshape the field → the field feeds gossip,
story, and the Loom → which shape the next events.

### Emergent Cast Bonds

The field doesn't just record — it acts. When a pair's tension or warmth crosses a
milestone, `CastBondEngine` surfaces a `castBond` page on its own: **a rivalry
erupts or an alliance forms**. `CastBondPageSourceAdapter` is stateless and
dedupes via a `cast-bond:<firedKey>` kept-tag; tapping it generates a
Gemma-narrated scene between the two (`castBondPrompt`, distress-gated, with a
static fallback). Keeping deepens both characters and mints memories, so the bond
echoes into letters and gossip without re-looping the field.

## Character Portraits And Illustrations

Every official cast member and Talisman can show real dossier art, and no one is
ever faceless.

- **`CharacterIllustrationProfile`** (in `BookReferenceLibrary.json`, ~60
  profiles) carries each subject's `core`, `signature`, `palette`, `prompt`, and
  `intendedAssetName`. The shipped app only renders art for subjects that are
  *actual cast entities* (World Register) or the five Talismans; the broader
  Enchantify roster waits for content packs.
- **`CharacterPortrait`** (resolver) maps a display name → profile → asset.
- **`CharacterPortraitView`** renders, in order: a custom cast member's own
  attached photo → the official bundled art (auto-detected via `UIImage(named:)`
  on the profile's `intendedAssetName`) → a medallion of initials over a gradient
  built from the character's official `palette` → a name-hued fallback.
- **Frictionless pipeline:** dropping a PNG into `Assets.xcassets` named exactly
  the `intendedAssetName` lights the portrait up everywhere — no code change.
  `ILLUSTRATIONS.md` is the generation manifest (subject → asset name → prompt).

Portraits appear on Cast pages, Letters, Two Readings, Cast Bond, gossip, and the
Pact Map (controlling Talisman). All ten official cast and all five Talismans
have bundled art.

## Per-Sabbat Palettes And Full-Screen Images

- **Per-sabbat festival palettes:** `PageVisualStyle.festivalStyle(accent:)`
  recolors the Festival card by the celebration's accent (Samhain amber, Beltane
  green, Yule candlelit, full moon violet, new moon slate, Litha gold).
- **Tap-to-fullscreen:** the official **Quick Look** viewer
  (`.quickLookPreview`) via the reusable `ImagePreview` helper + `imagePreviewOnTap`
  modifier — tap any real image (portraits, illustration/illuminated pages, cast
  photos, archive and Book-of-You thumbnails) to open it full-screen with system
  pinch-zoom, swipe-to-dismiss, Done, and Share. Medallions/gradients are
  correctly non-previewable.

## Characters And World Entities

Characters are not just names in prompts. The app treats them as structured
world entities with enough internal shape to stay consistent across letters,
gossip, story scenes, illustrations, search, memory, Belief, and page curation.

The central type is `NarrativeWorldEntity`. It represents characters, objects,
locations, threads, classrooms, talismans, real-world anchors, and motifs.
Every entity can carry:

- stable `id`, `packID`, display `name`, and `kind`,
- Belief and narrative weight,
- optional Chapter affiliation,
- optional `unwrittenInterest`,
- traits,
- quirks,
- faults,
- beliefs,
- goals,
- tags,
- optional `WritingVoiceProfile`.

That makes the cast deliberately well-rounded. A character is not only "warm"
or "mysterious"; they can have a worldview, a want, a blind spot, a habit, a
topic they care about, a Chapter alignment, and a mechanical weight in the
story field.

Examples from the bundled core cast:

- **The Book** is an attentive object/entity that believes attention is a kind
  of care and wants to turn real days into pages worth keeping.
- **Penny Blackletter** is dry, warm, and observant; she cares about marginalia,
  photos, indie publishing, and honest details.
- **Dr. Selene Inkrest** is gentle, precise, therapeutic, and
  narrative-minded; she tends difficult pages without rushing them.
- **Dr. Elowen Vellum** is warmly clinical and experiment-minded; she translates
  fuel, body, recovery, and health signals into low-shame field notes.
- **Headmistress Seraphina Thorne** carries authority, thresholds, secrecy, and
  institutional coherence.
- **Orion Blackthorn** pulls toward architecture, innovation, ambition, and the
  cost of making impossible structures work.
- **Zara Finch** is loyal, quick, practical, and vigilant about trust and safe
  paths.
- **Wicker Eddies** tests weak premises, doubt, and false magic.
- **Gwendolyn Mythwright** holds archives, impossible zoology, maritime
  mysteries, and evidence that makes wonder less lonely.

### What Entities Know

Entities know their own structured identity:

- what kind of being or thing they are,
- what Chapter or story pressure they lean toward,
- what they believe,
- what they want,
- what they are good at noticing,
- what they tend to get wrong,
- what topics naturally draw them into letters or electives,
- what tags connect them to pages, memories, places, motifs, and threads.

They also know world context through the packets passed into generation:

- recent kept pages,
- current day signals,
- weather/body/fuel/location context when available,
- story-field weights,
- entity memories,
- relationship edges,
- literary-continuity signals,
- current arc/thread context,
- recent narrative events,
- custom cast entities added by the reader.

Generated prose should not ask a character to "just improvise." The app hands
the character a structured packet of what they are, what has happened, what the
Book has noticed, and what the current surface needs.

### What Entities Remember

Entity memory is handled through `NarrativeEntityMemory`. These are durable,
entity-specific recollections created from narrative events. A memory records:

- the entity it belongs to,
- source event ID,
- optional source page ID,
- summary,
- tags,
- narrative weight,
- creation date.

`NarrativeEntityMemoryResolver` mints memories from events. For example, a kept
page, letter, story choice, gossip turn, or Belief action can become something a
character or entity later remembers. `NarrativeEntityMemoryConsolidator` merges
near-duplicates and caps runaway weight so memories remain useful instead of
becoming noise.

Characters can then use memory in several places:

- Letters include an entity memory packet for the sender.
- Story packets select relevant entity memories for scene context.
- Gossip can draw actors from story/memory pressure.
- Search can find entity memories directly.
- Book Notices and literary-continuity signals can be offered back into letters.

This means a character can develop a relationship to the reader over time
without that relationship living only in generated prose.

### Voice, Appearance, And Continuity

Characters have multiple identity layers:

- `WritingVoiceProfile` defines register, rhythm, diction, habits, and things
  to avoid. Letters and generated prose use this to keep character voice stable.
- `CharacterIllustrationProfile` defines palette, silhouette, signature object,
  continuity notes, prompt, negative prompt, marginalia tags, and asset
  references.
- `NarrativeRelationshipEdge` defines how entities relate: warmth, tension,
  trust, kind, note, tags, and narrative weight.
- `NarrativeWorldEntity` defines the mechanical/story identity.

These records let the same character behave consistently as:

- a letter writer,
- a story-scene participant,
- a gossip actor,
- a search result,
- a Belief target,
- an illustration subject,
- a memory owner,
- a source of electives,
- a Chapter-aligned participant.

### What Characters Can Do

Characters and world entities can act through several systems:

- **Appear in Story Pages:** `StoryScenePacketBuilder` selects entities based on
  tags, story-field weights, memories, custom cast, and current context.
- **Send Letters:** `CharacterLetterPageGenerator` chooses senders by Belief,
  narrative weight, memory hits, story-field presence, recent senders, and
  stable jitter.
- **Generate correspondence in voice:** letter prompts include sender identity,
  preferred reader name, unwritten interest, home context, research query, voice
  profile, memory packet, continuity packet, and talisman moves.
- **Participate in Gossip:** `GossipSimulationBuilder` selects actors and
  threads, creates offscreen turns, visible traces, overheard lines,
  consequences, hidden effects, Belief combat summaries, and optional talisman
  moves.
- **Ask for Unwritten Electives:** character interests can become small
  real-world favors, with nearby places used when available.
- **Move Chapter Talismans:** story pages, gossip, and letters can carry
  structured `ChapterTalismanBeliefMove` metadata. Keeping those pages applies
  ledger deltas.
- **Receive or lose Belief:** the Glow menu can adjust entity Belief. Those
  changes persist and affect future selection.
- **Become searchable:** entities, custom cast members, memories, tags, and
  Glow tiers can surface in Search the Stacks.
- **Anchor page meaning:** entity tags and memories help old pages return, help
  the Book notice patterns, and help the Margins Atlas draw relationship shape.

### Relationships And Disagreement

Relationships are typed, weighted edges rather than loose prose. A
`NarrativeRelationshipEdge` can carry warmth, tension, trust, kind, note, tags,
and narrative weight. These edges feed story packets and the Margins Atlas.

The current architecture is ready for deeper character disagreement because
characters already have different:

- beliefs,
- goals,
- faults,
- interests,
- Chapter alignments,
- relationship weights,
- memories,
- writing voices,
- tags.

For example, Dr. Vellum and Dr. Inkrest can plausibly interpret the same month
differently because one is biased toward body/fuel/recovery and the other
toward narrative repair and emotional weather. Penny can notice evidence and
publication/marginalia shape that neither doctor would foreground. Wicker can
test whether a pattern is real or theatrical. The Book can hold the whole set
as careful literary observation.

### Custom Cast Members

Custom Cast Members are first-class world entities. The reader can create one
in `CustomCastMemberSheet` with:

- name,
- kind,
- meaning,
- description,
- traits,
- beliefs,
- goals,
- tags,
- base Belief,
- narrative weight,
- optional image asset.

The saved member is converted into a `NarrativeWorldEntity` with pack ID
`user-cast`. From there it can participate in story selection, letters, memory,
Belief, search, curation, cast pages, and visual surfaces alongside bundled
characters.

This matters philosophically: the cast is not closed. People, places, objects,
and motifs that matter to the reader can enter the Book's world model and
become part of its future attention.

### Current Limits

The character system is strong structurally, but there are still useful places
to deepen it:

- Characters do not yet run a full multi-party debate engine.
- Relationship changes are present but could become more visible in letters and
  Margins Atlas pages.
- Long-term seasonal character arcs are not yet fully bound into monthly or
  annual editions.
- The Book Notices layer can offer continuity to characters, but characters do
  not yet consistently argue with those observations.

The important foundation is already there: characters know who they are, what
they care about, what they remember, how they sound, where they fit in the
world, what they can affect, and how the reader's kept pages can change their
future behavior.

## Narrative Story Field

The story field is the app's structured continuity layer.

Core types:

- `NarrativeEvent`
- `NarrativeEventKind`
- `NarrativeEventEffect`
- `NarrativeStoryFieldProjection`
- `NarrativeStoryFieldProjector`
- `NarrativeEventResolver`
- `NarrativeEntityMemoryResolver`
- `NarrativeEntityMemoryConsolidator`

Events come from kept pages, answers, selected choices, Belief actions,
letters, gossip, simulation turns, enchantments, compass runs, and talisman
moves. The projector folds events into weights for entities, threads,
relationships, and overall Belief.

Generated pages read that projection so the world reflects what the reader has
actually kept and done.

## Literary Continuity

`Shared/LiteraryContinuity.swift` is the newest deepening layer. It is separate
from ordinary memory:

- Memory remembers facts and events.
- Continuity notices patterns, absences, durations, and life cycles.

`LiteraryContinuityProjector.digest(...)` reads archive days, narrative events,
entity memories, entity Belief, and page Belief. It emits a
`LiteraryContinuityDigest` containing:

- `LiteraryContinuitySignal` records,
- `BeliefLifecycleProfile` records.

Signals feed:

- The Book Notices page.
- Book Remembered scoring/reasons.
- Character Letter memory packets - and a strong absence signal becomes the
  letter's *occasion*: the sender writes because something went quiet, asking
  after it warmly without alarm.
- Monthly edition opening sections and the Book's foreword.
- Constellation promotion and sealed-margin wagers
  (`Shared/Constellations.swift`).
- The portable save file and archive export carry the digest, constellations,
  and wagers (`ReEnchantedSaveFile.continuity`, `BookArchiveExport` schema 2),
  so the wider Labyrinth - scene engine, NPC dialogue - can reference the same
  threads by name.

This is the foundation for the Book forming careful opinions about the reader's
story.

## Memory Model

The app has several kinds of memory, each with a different job:

- `SelfFact` - reader-provided identity, preferences, home/place context, and
  About You answers, with sensitivity and use-permission.
- `BookPage` - durable kept artifact.
- `NarrativeEvent` - mechanical consequence.
- `NarrativeEntityMemory` - entity-specific recollection.
- `FacultyEntry` - structured body/fuel/mood support logs.
- `SurfaceHistoryRecord` - what surfaced recently.
- `BookArchiveResurfacing` records - return history.
- `PlayerVaultData` - anchors, electives, Belief ledgers, tutor progress, owned
  packs, surface history, current arc, constellations, wagers, themes, Fae
  standing (`fae`), Pact War control (`pactWar`), Book Jump state (`bookJump`),
  radio playback (`radio`), the living relationship field (`relationshipField`),
  and reader-taught braid notes (`learnedBraidNotes`).
- `ReEnchantedSaveFile` - complete portable export/import container.

Memory is intentionally typed. Generated prose should be an expression of these
records, not the only place continuity exists.

## Persistence, Export, And Import

`Shared/BookArchiveDatabase.swift` is the SwiftData-backed persistence layer.
`InsideCoverApp/BookDatabase.swift` is the app-facing wrapper.

Persisted data includes:

- archive days and kept pages,
- resurfacing records,
- self facts,
- narrative events,
- entity memories,
- faculty entries,
- custom cast members.

`BookStore` and `PlayerVaultData` handle the companion save/vault material.

Export/import:

- `ReEnchantedSaveFile` exports the reader's save as
  `.reenchanted-save.json`.
- Import merge-upserts material and does not delete local data.
- `BookArchiveExport` normalizes archive days for backup/export.
- `MonthlyEditionPDFWriter` creates shareable monthly PDF editions.

## Search The Stacks

Search is local and structured first.

Key pieces:

- `StacksSearchDataset`
- `StacksQuery`
- `StacksSearchEngine`
- `SearchTheStacksSheet`
- optional local-brain interpretation for unusual queries

Search can find:

- kept pages,
- prompts and user text,
- tags and page types,
- self facts where appropriate,
- entity memories,
- custom cast members,
- page family/type words,
- Glow tier language,
- co-kept correlations such as tiredness.

Kept pages reopen through the same surface sheet used by live pages, so archive
items are not inert rows.

## Local Brain

The local brain is the on-device generation layer, mostly implemented through
Gemma/MLX when `NATIVE_LOCAL_BRAIN` is available. Access is serialized by
`LocalBrainInferenceGate`.

Core files:

- `InsideCoverApp/LocalBrainServices.swift`
- `Shared/InsideCoverStore.swift`
- `InsideCoverApp/ContentView.swift`

Generation services include:

- Book of You braiding,
- Ask the Book,
- Dr. Inkrest's Office Hours counseling,
- Fae Bargain responses (in each fae's voice),
- Book Fae interactive scenes,
- Book Jump prose,
- Wonder Compass choice and mission generation,
- Weather enchantment,
- Story Page prose and result prose,
- Gossip,
- Faculty Research,
- Character Letters,
- Enchantments,
- Photo illumination analysis,
- Playful Mission generation,
- Elective offers,
- Outer Stacks room writing.

Most generated features have fake or resilient fallbacks. The app should stay
usable when the model is missing, busy, unavailable, or returns malformed JSON.
`JSONSalvage` exists to recover small-model JSON output without exposing raw
braces to the reader.

**Model calls are always user-initiated.** Every inference runs from an explicit
button press (Keep, Ask, Knock on the door, Pay the bargain, Continue the scene,
Open the edition, etc.) and off the main actor, so the loading animation never
stutters. Ambient/automatic systems - the curator, `tendArc`/`tendFae`/
`tendPact`/`tendConstellations`, surfacing, Fae offers, marginalia, loose pages,
and Pact voices - are pure local logic and never call the model. (The lone
background exception is `OvernightScribe`, which can pre-write a Story Page draft
while charging.)

## Media And Visual Design

The visual system aims to make every screen feel like a usable book, not a
generic card feed.

Key pieces:

- `BookPalette`
- `BookBackground`
- `PageVisualStyle`
- `SurfaceCard`
- `PageSourceCard`
- `BookOfYouCard`
- `ArchiveCard`
- `OpeningMovieView`
- `FairyScribe`
- `WrittenGoldText`
- `ParchmentSurface`
- `IlluminatedPageRenderer`

Illustration and illumination are data-driven:

- `IlluminationTemplate`
- `IlluminationAssetPack`
- `IlluminationTemplateLibrary`
- `IlluminationPackRegistry`
- `IlluminationMarginaliaLibrary`
- `IlluminatedPageComposer`

Assets include parchment textures, marginalia marks, illumination scraps,
sample photos, app icons, character portraits, and sound effects.

## Sound, Haptics, And Small Interactions

`InsideCoverApp/BookSounds/` contains short interface sounds for page opening,
keep/dismiss, source refresh, braiding, selection, knock, errors, and undo.

`BookFeedback` and the support code in `AppSupport.swift` coordinate haptics and
sounds. The banner knock interaction can return state-aware notes through
`BannerKnockNotes`.

### Text Selection And Copy/Paste

The reading surfaces use the standard iOS edit menu — no custom affordances. Page
prose is long-press selectable/copyable via `.textSelection(.enabled)` on the open
page (`CapturePageSheet`, covering live pages and kept-page readback), the feed
cards (`SurfaceCard`), and Search the Stacks results. Capture inputs are ordinary
SwiftUI `TextEditor`/`TextField`, so Select / Copy / Paste (and ⌘V) work natively;
the `dictationInput` mic button is a small corner overlay that does not block the
text gesture.

## BookShop And Packs

The pack system is partly data-driven and partly enum-backed.

Current pack/listing concepts:

- page packs,
- story forms,
- spark packs,
- lore packs,
- marginalia packs,
- sound packs.

`BookShopCatalog` lists available or coming-soon packs. `PackEntitlements`
tracks owned pack IDs in save data. `PageArchetypePackRegistry` and related
registries expose content once unlocked.

Useful rule:

- New content inside an existing family can often be a registry or pack change.
- A truly new page family still needs a `BookPageType`, source registry entry,
  adapter, visual style, default intent, route handling, persistence handling as
  needed, and tests.

## Privacy And Data Boundaries

The app distinguishes privacy at the page-source level:

- `privateLocal`
- `localSensitive`
- `publicReference`

Self facts also carry sensitivity and use-permission. Generated prompts should
use the smallest relevant context packet, not dump the entire archive.

Network-facing or external data paths are specific:

- optional USDA FoodData lookup for fuel estimates,
- optional web/API research paths in faculty/research helpers,
- optional Reddit app-only OAuth search for Reader's Shelf only when an
  approved installed-app client ID is configured; readers do not sign in to
  Reddit, and the default Shelf path remains DuckDuckGo/open-web fallback,
- system EventKit writes (Reminders/Calendar) only on explicit user action,
- local notification scheduling via UserNotifications,
- package resolution/build tooling during development,
- StoreKit or dev unlock paths for packs when implemented.

The product posture is local-first. The archive, memories, Belief ledgers, and
custom cast are the reader's save.

## App Target Files

Important app files:

- `InsideCoverApp/InsideCoverApp.swift` - `@main` entry point.
- `InsideCoverApp/ContentView.swift` - main orchestrator: feed, sheets,
  hydration, curation refresh, local-brain tasks, Glow actions, persistence,
  prepared pages, monthly edition share state, and generated talisman deltas.
- `InsideCoverApp/ContentViewFeatures.swift` - extracted feature helpers,
  export/import, monthly edition binding, page actions, and support operations.
- `InsideCoverApp/BookSurfaceViews.swift` - surface cards, page rendering,
  visual style, backgrounds, onboarding, archive cards, animation.
- `InsideCoverApp/CapturePageSheet.swift` - page opening/capture/generation UI
  for capture, story, gossip, Ask, Compass, mission, enchantment, photo,
  Dr. Inkrest's Office Hours, Fae Bargain, Book Fae, Radio, Inventory, Today's
  Sky, and Book Jump flows (and the Pact War framing card / goblin marginalia
  shown on pages).
- `InsideCoverApp/CapturePageSections.swift` - extracted sheet sections such as
  Chapter Binding, Anchor offers, electives, and support guild.
- `InsideCoverApp/BookStatusCards.swift` - status cards, Glow menu, Belief UI,
  lab/status displays, and the Fae/Pact hub sheets (`TheMarginSheet`,
  `GoblinMarketSheet`, `PactMapSheet`).
- `InsideCoverApp/LocalBrainServices.swift` - MLX/Gemma services, prompt
  builders, photo/Vision helpers, web/research helpers, optional Reddit OAuth
  search, and fallbacks.
- `InsideCoverApp/LivingTextInput.swift` - `LivingTextEditor`, the
  Sentence-Builder-integrated writing field (nudges, scaffold tokens,
  transmutation chips, alchemy shimmer) used on capture pages.
- `InsideCoverApp/RadioAudio/` - bundled local radio assets across all three
  core stations (Fae-Fi, Mothlight Beats, Thornwave) plus pack stations.
- `InsideCoverApp/BookDatabase.swift` - app wrapper over the shared archive.
- `InsideCoverApp/SearchTheStacksSheet.swift` - local archive search UI.
- `InsideCoverApp/CustomCastMemberSheet.swift` - custom cast creation UI.
- `InsideCoverApp/BookShopSheet.swift` - pack/shop UI.
- `InsideCoverApp/AppSupport.swift` - haptics, quips, radio playback,
  location/weather/body readers, nutrition support, the `GenerationCoordinator`
  and `PlayerVault`,
  scheduled notifications (`BookWhispers`, recolored by the Pact War's Whisper
  Channel controller; `BookWhisperPresenter` for foreground display), real-world
  writing (`EventKitWriter` for Reminders/Calendar), the `OvernightScribe`, and
  cross-cutting helpers.
- `InsideCoverApp/MonthlyEditionPDF.swift` - PDF rendering for monthly editions.

## Shared Core Files

Important shared files:

- `Shared/PageModel.swift` - page types, page/source metadata, media assets,
  durable page/day models, page Belief.
- `Shared/SourceAdapters.swift` - page source adapters and source input bundle.
- `Shared/SurfaceAndCurator.swift` - curation, readiness, action routing,
  work-blocking, surface history, and recovery state.
- `Shared/NarrativeCore.swift` - entities, threads, relationships, story field,
  events, memories, talismans, arcs, story packets, letters, gossip, the living
  relationship field (`RelationshipTie`, `RelationshipFieldEngine`, the dynamic
  Loom), and the dynamic disagreement engine (`DisagreementEngine`).
- `Shared/StoryEngine.swift` - story-generation contracts, scene/result
  packets, mission logic, writer protocols, Book Jump engine/state, gossip
  simulation (incl. Belief combat and `GossipRelationshipMove`), the letter
  generator and cross-letter memory.
- `Shared/WorldSystems.swift` - body/weather signals, moon phase, anchors,
  location math, scheduling/world helpers, radio stations/playback, the Academy
  Chapters and Chapter Binding oracle, the Book Fae economy (bargains, gifts,
  market, marginalia), the Pact War (territories, engine, effects, voices), the
  Almanac (Wheel of the Year + esbats), Today's Sky, and the returning-greeting
  composer.
- `Shared/WorldEvents.swift` - event packs, active event resolution, phases,
  triggers, outcomes, influence packets, and event effects.
- `Shared/InsideCoverState.swift` - remaining app state models and archive
  export structures.
- `Shared/InsideCoverStore.swift` - store/load, local model management,
  resilient/fake generation seams, archive store helpers.
- `Shared/BookArchiveDatabase.swift` - SwiftData archive and persistence.
- `Shared/ReferenceLibrary.swift` - reference snippets, quip packs,
  self-knowledge packs, illustration profiles.
- `Shared/PagePacks.swift` - page archetypes, save file, vault data, BookShop,
  margin tutor, JSON salvage.
- `Shared/SentenceBuilder.swift` - concrete sentence-craft nudges, diagnostics,
  chips, and alchemy levels.
- `Shared/Illumination.swift` - photo illumination templates, packs, composer,
  queue/source adapter.
- `Shared/StacksSearch.swift` - local search engine.
- `Shared/LiteraryContinuity.swift` - patterns, absences, durations, Belief life
  cycles.
- `Shared/MonthlyEdition.swift` - monthly edition curation model.

## Tests

The shared test suite is in `Tests/InsideCoverCoreTests`.

Coverage areas include:

- archive database persistence and migration,
- archive export and monthly-edition curation,
- archive indexing and search,
- curator behavior and source metadata,
- surface readiness and action routing,
- local-brain telemetry state,
- work-blocking policy,
- prepared-page and braid recovery,
- Book of You polish, braid prompt context (theme/Chapter/earlier-braid/
  now-playing carry) and the braid tasting/learning loop,
- story field, entities, relationships, Chapter Talismans,
- letters, gossip, story choices, class schedules,
- margins atlas layout,
- literary continuity and Book Notices,
- packs, entitlements, welcome/help behavior,
- Inventory, BookShop listings, owned packs, radio stations, and manual radio
  surfaces,
- weather, moon, body/fuel helpers, anchors, playful missions,
- world event packs, active event influence, Dictionary Rebellion and Starlit
  Paper Trial outcomes, out-of-season preview resolution, and monthly-event traces,
- the Goblin Market (calling-card access, mood pricing, new-moon window),
- Sentence Builder nudges, diagnostics, chips, and alchemy levels,
- Dr. Inkrest's Office Hours (window, rotating prompts, adapter),
- the Fae economy (bargains, gifts, lapse/repair, market, marginalia),
- the Pact War (tiers, controller, tick, alignment, shelf/door voice effects,
  dispatches, Sovereign automation, next-new-moon),
- the Almanac (sabbats, esbats, hemisphere flip, grey shift, surface boosts,
  festival adapter),
- Today's Sky (zodiac/ephemeris, light trend, next event, reading, evening adapter),
- the returning greeting composer,
- The Two Readings (dynamic disagreement engine, adapter, siding effects),
- cross-letter memory,
- the living relationship field (weave, emergent/cooled Loom threads) and gossip
  Belief moves,
- the Belief economy engine (daily tide, high/neglected-Glow settling, kept/dismissed
  source warmth, cast-spend floor),
- Book Jumping (public-domain shelf, progression/stabilize/return, Borrowed Rules,
  collapse + cold books, daily decay, escalating cost, open-shelf, companion
  constellations),
- the annual edition (per-month chaptering, ordering, totals, deterministic
  foreword).

Common test command:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/insidecover-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/insidecover-spm-module-cache \
swift test
```

Common simulator build command from this directory:

```sh
xcodebuild \
  -project EnchantifyInsideCover.xcodeproj \
  -scheme InsideCoverApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/InsideCoverDerivedData \
  build
```

## Development Guidance

When adding a new feature, start by deciding what kind of thing it is:

- **New content inside an existing page family:** prefer a registry, catalog,
  pack, or source-adapter change.
- **New generated prose for an existing page:** add a narrow writer protocol or
  prompt builder, a fake/fallback implementation, and recovery behavior.
- **New memory consequence:** add a typed event, effect, or memory resolver path
  before relying on generated prose.
- **New page family:** add the enum case, source metadata, adapter, visual
  style/default intent, capture/open behavior, persistence effects, and tests.
- **New export/binding format:** build from archive structures rather than
  scraping UI.

Practical rules:

- Keep generated systems structured at the boundaries.
- Use metadata keys deliberately; they become routing, search, and future
  continuity.
- Test curation and policy in shared core, not only in SwiftUI.
- Do not make real-world task completion happen in prose. The reader must
  actually keep, answer, cast, visit, or bind.
- Prefer making existing memory systems talk to each other over adding another
  isolated surface.

## Current Direction

Recently shipped (and now load-bearing): the **Book Fae** and their bargains,
the **Inventory**, **ReEnchanted Radio**, **World Event Packs**, **Book Jumping**,
the **Pact War** (both fronts, dispatches, Sovereign automation, door voices),
the **Almanac** (Wheel of the Year + esbats, with Belief/Nothing/curation/Fae and
real-world bleed effects), **Today's Sky**, the **returning greeting**, the
continuity **cache** (freeze fix), **The Two Readings** with reader-sided
consequences, **cross-letter memory**, **Sentence Builder**, and the **living
relationship field** (gossip Belief moves + an evolving Loom). Notifications are
visible, and the world can write Reminders and Calendar events on request.

The system spine is now a real **narrative simulation**: play creates events,
events reshape Belief, the relationship field, the Pact War, and the Fae economy;
those feed back into what surfaces and how the cast speaks; and the Almanac turns
the whole thing with the real sky and seasons.

Open directions worth pursuing next:

- **Two invariants to protect** in all new work: every local-model call stays
  user-initiated, and nothing heavy runs on a rendered view (read cached state).
- richer Book Remembered returns and Belief life-cycle pages,
- per-sabbat festival palettes and bundled-character portraits on Cast pages,
- the Wheel woven into monthly/annual editions as a recurring structure,
- character portraits and relationship shifts surfaced inside letters,
- an annual **Volume I** bound from accumulated monthly/archive artifacts,
- eclipses and rarer astronomical events in the Almanac.

The destination is a reader-held volume - a year of ordinary life bound into a
fairy story accumulated page by page - and a living world whose Fae, Talismans,
and turning Wheel reach gently off the screen into the reader's real days.
