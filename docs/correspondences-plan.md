# Correspondences and the Gazetteer (implementation plan)

Two features that turned out to be the same shape. The Book's deep systems are
built and live — the grimoire finds correspondences, anchors record places, every
kept Page remembers where it happened — and none of them have a **room**. Nothing
on the Book's surface says "grimoire". The reader cannot walk anywhere and look.

Both features are therefore a **door plus a derivation**, not new subsystems.
Worth holding as a principle for the rest of this push: before building an
engine, check whether the engine exists and is simply unreachable.

- **Part I — Correspondences.** A shelf of correspondence tables, half inherited
  from real folklore and half worked out by the Book about this reader, printed
  in one list so the two can agree, disagree, and cross each other out.
- **Part II — The Gazetteer.** The reader's own places: what they are, what
  happened there, and a map of the whole world of them.

---

## Phase 0 — The permissive archive and the filtered boundary

**Policy change, decided 2026-09-05.** `BookPageContextSnapshot` currently
declares "no coordinates, calendar titles, raw Health data, or copied chart
prose" (`PageModel.swift:2329`). That restriction is lifted. The archive may hold
whatever earns a feature — coordinates, richer health, chart prose — because it
is on-device, never synced, and belongs to the reader.

**The restriction does not disappear; it moves to the boundary.** There are paths
where data genuinely leaves the device, and "it's local and it's theirs" does not
cover them:

- **Print.** `PhysicalBookOrders.swift:146` — "The app owns PDF generation; the
  backend owns payment, Lulu credentials, **PDF hosting**, tax/shipping quotes,
  and print-job submission." A printed edition's PDF transits the backend and
  Lulu.
- **Share and export.** Souvenir cards, Pagewright PDFs, gift sheets.

So, one rule replacing the old one:

> **The archive is permissive. Boundaries filter.** Anything the reader gave the
> Book may be stored richly and forever on device. Anything crossing a boundary —
> print, share, export, backend — passes a sensitivity check that defaults strict
> and is overridable by the reader per artifact.

**Health data is the sharp case.** The app reads real HealthKit values (resting
heart rate, HRV, sleep — `Daybook.swift:446`). Apple requires explicit consent to
disclose HealthKit data to third parties and separately bars storing it in
iCloud. HRV inside a PDF that transits a server is a disclosure. The print step
therefore needs its own consent moment; the storage does not.

**Build on what exists.** `SelfFactSensitivity` and `SelfFactUsePermission`
(`ReferenceLibrary.swift:211`) are already a per-fact sensitivity and
use-permission model. Extend those to cover coordinates, health and chart prose
rather than inventing a second one.

**Tasks, and what scoping them turned up.**

*0a — the model (DONE, 2026-09-06).* Only one field was genuinely new.
`BookPageContextSnapshot` already carried `sleepHours`, `steps`,
`restingHeartRate` and `heartRateVariability`, so "no raw Health data" was
already false when we read it. Chart prose stays a *reference*
(`innerWeatherEntryID`, `fuelEntryID`) until a feature needs the prose itself.
So 0a was: add `latitude`/`longitude`/`horizontalAccuracyMeters`, and rewrite the
doc comment that stated the old law. Migration was free — the snapshot's decoder
is `decodeIfPresent` with a default on every field.

`horizontalAccuracyMeters` is not decoration, because **accuracy already varies
by path**: `WeatherLocationReader` asks for `kCLLocationAccuracyThreeKilometers`
(`AppSupport.swift:3472`), `AnchorLocationReader.requestLocation()` for a hundred
metres, and `requestAnchoringLocation()` for ten with no reuse of a cached fix.
Without a recorded accuracy those are indistinguishable once stored, and anything
meaning "here" would trust all three equally. Latitude and longitude are only ever
stored as a pair, on both the init and decode paths.

*0a-writer (DONE, 2026-09-06).* `pageContextSnapshot(at:)`
(`ContentView.swift`) now passes the coordinates through. They were already in
scope — `lastAnchorReadingLatitude`/`Longitude`, used for a place lookup and then
discarded — so nothing new is read and no GPS is woken at keep time, which the
keep path cannot afford anyway.

What was missing was a **timestamp**. Those are `@State`, so across a long-lived
session a fix is of unknowable age, and attaching a stale one would file a page
in whatever neighbourhood the Book last looked at — poisoning every
correspondence built on it. `lastAnchorReadingAt` is now stamped at all five
assignment sites, and coordinates are attached only when the reading is within
ten minutes of the keep. The automatic context refresh rests fifteen minutes
between attempts, so a tighter window keeps a stored fix inside the refresh it
belongs to.

**Four separate comments stated the old law**, three of them already false
because health metrics were being stored regardless: the snapshot's own doc
comment, `pageContextSnapshot`'s, `ContentView.swift`'s "never latitude or
longitude", and `NightlyBraidLiveContext`'s "deliberately carries no coordinates
into the page" (`AppSupport.swift` — **still unfixed**, left alone while Codex
was in that file).

*0b — the boundary filter.* **Not urgent, and smaller than it looked.** No export
composer reads page context at all: `MonthlyEditionPDF`, `MonthlyEdition`,
`WeeklyBindingPlan`, `PhysicalBookOrders` and `EditionCurator` have zero
references to `BookPageContextSnapshot`. Nothing that leaves the device touches
this data today, so coordinates in the archive cannot currently leak through any
existing path.

**Filter at composition, not at egress.** There are 25+ `ShareLink` sites in
`CapturePageSheet` and `BookSurfaceViews` alone, and a filter placed at egress
would be silently bypassed by the twenty-sixth. There are only a handful of
*composers*. Since none of them reads context yet, the filter should be
introduced as the **required accessor** the first time a composer wants context —
making the safe path the only path rather than auditing every share button.

*Revised sequencing.* The rule is **not** "fields, filter, writer". It is:

> Fields, then the writer, then the filter — but the filter lands **before the
> first composer reads page context**, and that accessor is how it reads it.

Populating coordinates is safe on its own, because nothing composes them into
anything that leaves the device.

---

## Decision record

**Correspondences gets its own section, not a new face of the Margins Atlas.**

- **There is no Atlas room to route into.** `.marginsAtlas` is only ever a Page,
  rendered by `marginsAtlasView` (`CapturePageSheet.swift:5283`). Building the
  room is required either way.
- **Different claims.** The `laws` face is titled "The Rules I Worked Out" and
  means *earned by observation, with a falsifier running*. Inherited folklore
  under that title would have the Book claiming lore as its own counting.
- **Different jobs.** `GrimoireVoice.folio` is deliberately incomplete — a Page
  that rises and boasts. A shelf the reader walks to can be complete.

The Atlas `laws` face is **unchanged** by this plan.

**Places build on `AnchorRecord`, not on `PlaceState`.** `PlaceState`
(`PlaceMemory.swift`) is the Academy's rooms. `AnchorRecord`
(`WorldSystems.swift:3894`) is already the reader's place record and is richer:
the reader's own name and words, visit count and last visit, the weather/moon/
season when it was made, accumulated belief, the fiction grown over it
(`outerStacksRoom`, `fae`, `localRule`, `miniStory`), `emotionalRegister`, and a
real privacy model in `AnchorPlaceIdentity`. Do not port `PlaceState`.

**The place history already exists.** Every Page carries `nearbyAnchorID`
(`PageModel.swift:2336`); `StacksSearch.swift:984` already reads it back. Derive
a place's history from kept Pages rather than adding a parallel incident log that
can drift.

**Public name is "Correspondences"** everywhere it is visible. Internal
identifiers may say whatever is clearest.

---

## House laws

- **Origin is a field, never a typographic convention.** An inherited row and an
  observed row must be distinguishable in the model, or the first surface to
  render them somewhere new will present folklore as the Book's own finding.
  Same law the Quotes page keeps: borrowed lanterns, always attributed.
- **Untestable lore is first-class.** `observable` is optional; nil means the row
  is furniture — readable, attributed, and **never** a claim about the reader.
- **The Book never asserts inherited lore about the reader.** It may report it,
  agree with it once it has its own days, or contradict it. It may not adopt it.
- **Never compute correspondences on a read path.** Rooms read standing rows,
  like the desk. Violating this is how the 448ms desk stall came back last time.
- **The shelf does not call `folio()`.** It shares `GrimoireVoice`'s sentence
  builders (`law`, `plainClaim`, `crossingOut`, `evidence`) and has its own page
  builder: completeness is the point here, selectivity is the point there.
- **No counts in a Contents row detail.** That line redraws on every desk render.
- **Health may be a subject, never a readout.** The Book may say what it has
  noticed across time — "you sleep better on cold nights" — because that is a
  correspondence: earned, dated, falsifiable. It may not play back a reading. No
  scores, no averages, no "resting heart rate down three". The test is whether an
  attentive friend could have noticed it without a sensor. If only an instrument
  could know it, the Book does not say it.
- **Plates, not Maps.app.** A chart is drawn once and printed. The Atlas may pan,
  but nothing in this plan opens Maps.app, offers directions, or uses Look
  Around. The reference is the endpaper map in a fantasy novel.
- **Register:** contractions by default; short concrete sentences; no ALL-CAPS
  headers; no closing aphorism; no explaining its own epistemology. Section
  headers are spoken fragments ("Sure of these:").
- New `Shared/` files must be registered in **both** `Package.swift` sources and
  the pbxproj (the grimoire's seven are at `Package.swift:84-90`).
- Tests: `CLANG_MODULE_CACHE_PATH=/private/tmp/insidecover-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/insidecover-spm-module-cache swift test`

---

# Part I — Correspondences

## Phase 1 — The inherited shelf (MODEL + SEED CORPUS DONE, 2026-09-06)

Lives in `Shared/ReferenceLibrary.swift` beside `QuotePack` and
`AffirmationPack`, whose shape it copies exactly — same pack/registry/
availability pattern, and no new file, so the pbxproj stays untouched.

Shipped: `GrimoireOrigin` (`.observed` / `.inherited`), `CorrespondenceSource`
(`.folk` / `.academy`), `InheritedCorrespondence`, `CorrespondencePack`, and
`CorrespondenceLibraryRegistry` with `all` / `testable` / `loreOnly` /
`matching(observable:)`. Twelve seed rows — ten folk, two Academy.

`observable` is the join to Phase 5: a row naming `place-kind:water` is testable
*because* place kinds now exist. Three of the twelve are keyed
(`weather:rain`, `place-kind:water`, `hour:evening`); the other nine are
furniture and stay furniture.

Tests: `InheritedCorrespondenceTests` (11). The one that earns its keep is the
**wiring lint**: it runs `WorldConditionsProjector` over a grid of contexts to
collect the feature ids anything can actually emit, then asserts every
`observable` is among them — so a row keyed to a feature nothing produces cannot
sit in "inherited, untested" forever pretending to wait for evidence. It carries
its own proof of teeth (a known-bogus id must *not* be in the producible set).

**Still to author:** the corpus is a seed, not a shelf. Twelve rows set the
voice; a correspondence table is pleasurable because it is long. Growing it is
pack authoring and needs no further engine work.

### Original notes

Model and content only. No engine change; works on a cold archive.

**Model.** An inherited correspondence carries a stable id, the pair as prose
(`subject` / `sense`), a `tradition` for attribution, the lore body, and an
optional `observable` mapping onto a grimoire feature id. Nil `observable` means
lore-only, permanently. `GrimoireOrigin` is `.observed` or `.inherited(id:)`, and
every row rendered anywhere carries one.

**Attribution law** (shared with the Spells work): real traditions are named
truthfully and never blurred into Academy invention; Academy-invented
correspondences are permitted and attributed to the Academy. The Book does not
claim any of it works.

**Corpus.** A new pack type, riding the content-pack pipeline. Breadth over
cleverness — a correspondence table is pleasurable because it is *long*.

> **Hawthorn** — *don't bring it indoors.*
> May tree, whitethorn, faerie tree. Cutting one without asking is asking for
> trouble; the blossom indoors was said to bring death with it, which botanists
> now think is because it smells faintly of decay. Both things are true at once
> and I find that very satisfying. *(British and Irish folk custom)*

> **Iron** — *a threshold, a bargain, a boundary.*
> Nails over the door, a horseshoe, a blade under the bed. The one thing
> everybody in three hundred years of collected faerie lore agrees on. *(Widely
> attested, Northern European)*

**Tests.** Every inherited row has a tradition; no row claims the reader; ids are
stable; a nil-`observable` row can never reach a claim-rendering path.

## Phase 2 — The Correspondences room

`BookObjectDivision.correspondences`; a page builder printing the corpus with
attribution; an eleventh `PagesRisingContentsEntry` in
`pagesRisingContentsEntries` (`ContentView.swift:9991`), detail in the Book's
voice, no counts.

At the end of this phase a day-one reader opens Contents → **Correspondences**
and finds a full attributed shelf. That alone is the feature working.

## Phase 3 — Interwoven

The Book's own rows join the same list:

- **Sure of these** — `.standing`, via `plainClaim` (lists want uniform framing).
- **Still betting on** — `.spoken`, falsifier printed.
- **Turning over** — `.watching`.
- **Inherited, untested** — corpus rows with an `observable` not yet gathered.
- **Crossed out** — either origin, and never the section dropped for space.

Lore-only rows sit in their own standing section outside this ladder, because
they are not claims and must never appear to be.

**Where the two argue.** When the Book's own evidence clears the bar on a pair an
inherited row also names, print it once with both hands visible — agreement
("they've said this for four hundred years; I've nine days of my own now") or
contradiction, which routes to the existing crossing-out mechanic, now firing on
*borrowed* authority. That can happen in week one instead of after months.

Dedupe on the **pair**, not the rendered sentence.

## Phase 4 — Onboarding seeds

An onboarding answer is *told*, not observed, and has nothing to falsify against.
It founds a `.watching` row printed openly as untested — "you told me you think
better near water. I've written it down. I haven't checked it yet." — promoted
only by the ordinary bars on the Book's own evidence. Eligibility gated by the
existing `SelfFact` sensitivity and permission fields. Two or three seeds is
plenty.

---

# Part II — The Gazetteer

## Phase 5 — The Book learns what *kind* of place it is (DONE, 2026-09-06)

**What was already there:** `placeKind` was *already a declared domain* on
`WorldConditionsProjector`, with exactly one thing emitting it — `waterFeature()`,
fired by `isWaterPlace()`, a substring match over the place's *name*. So the
domain had a home and no taxonomy. "Waterloo Road" was water; a beach the reader
called "the quiet end" was not. And when `locationLabel` was nil the place
feature fell back to the Anchor id, giving `place:anchor-7f3a`.

**Shipped:** `PlaceKind.key(fromCategoryRawValue:)` in `WorldSystems.swift`
turns `MKPOICategoryBeach` into the stable token `beach`. It is set only from a
real `MKPointOfInterestCategory` — never from the weekly scout's hand-written
strings, which is why it is a separate field from the display `category` — and
rides `LocalPlaceSignal.categoryKey` → `AnchorPlaceIdentity.categoryKey` →
`BookPageContextSnapshot.placeKind`, filled at keep time from the nearby Anchor.
`WorldConditionsProjector` emits `place-kind:<key>` from it.

A real category now outranks the name for the water reading. Pages kept before
the taxonomy arrived carry no kind and keep the old name reading, so nothing
retroactively loses a feature it used to have.

Tests: `PlaceKindTests` (9). `GrimoireWiringTests` still green, which matters —
it enforces that every emitted domain is declared by its projector.

**Still open from this phase:** unifying the hand-written `categoryPool`
(twenty strings, weekly quest scout) with the real taxonomy, and keying the
inherited correspondence corpus to POI categories — the bridge to Part I, where
standing near a bridge earns four hundred years of inherited opinion about
bridges.

### Original notes


`LoomProjectors.swift:341` currently feeds the grimoire `nearbyAnchorID` — an
opaque string. So the Book can form "you write differently at anchor-7f3a" but
**cannot** form "you write differently near water". The kind is already fetched:
`anchorCandidates` reads `MKPointOfInterestCategory` and then flattens it to a
display label through `readableCategory` (`AppSupport.swift:6318`).

Persist the POI category as a **real key** on `AnchorPlaceIdentity`, and project
it as a grimoire feature. Also unify it with the hand-written `categoryPool`
(`AppSupport.swift`, twenty strings used for the weekly quest scout), which is a
second, disjoint vocabulary for the same concept.

**This is also the bridge to Part I.** The POI taxonomy is unusually
folklore-loaded — bridges, crossroads, wells, water, churchyards, mills, ferries,
harbours, orchards, libraries. Keying inherited correspondence rows to POI
category makes the folklore **locally triggered** rather than merely readable:
stand near a bridge and the Book has four hundred years of inherited opinion
about bridges. Costs only authoring, because the category is already fetched.

Also persist `locality` usefully — it is already captured and unused, and "your
town" is a better organising object than a flat list.

## Phase 6 — The Gazetteer room

A division and Contents row listing anchors by the reader's own name for them.
Each entry: what it is, when it was made, the weather and moon it was made under,
how many times they have come back, and **what happened there** — derived from
kept Pages carrying that `nearbyAnchorID` (plus, after Phase 0, coordinates).

Proximity keeps doing exactly what it does today: standing within
`proximityRadiusMeters` opens the room (`SourceAdapters.swift:12072`). That is
good magic and this plan does not touch it. The shelf is for *remembering* a
place you are not standing in — which is the thing that does not exist today, and
the reason places feel unintegrated.

Veiled anchors stay veiled on the shelf.

## Phase 7 — Map plates

Nothing in the app renders a map today. A gazetteer entry carrying a small chart
of its place — desaturated into the ink palette, no pins, no labels — turns a
list of names into an atlas. `.atlas` is already a `LeafVisualDialect` with its
own grammar and layout proportion (`PagesRisingFolio.swift:3189`, `:5876`).

`MKMapSnapshotter`, once per place at anchor time, cached as an image. Static by
definition; this is the thing that survives into print.

**Plates must not be merely decorative.** A plate carries the place's marks: the
anchor itself, and where its kept Pages fall. A chart with nothing on it is
wallpaper.

**Styling is the whole risk.** A default Apple map screenshot on parchment reads
as a bug. `pointOfInterestFilter = .excludingAll`, labels stripped, under a
parchment/sepia treatment layer. Apple's tiles cannot be recoloured arbitrarily,
so a blend overlay is the realistic technique.

## Phase 8 — The Atlas

The pannable room: the reader's whole world of places spread out. Pins are the
Book's own marks — anchors, and (after Phase 0) every kept Page by coordinate.

**The Atlas is an instrument, not a pin board.** Four jobs, in order:

1. **Lenses**, drawn from the grimoire's own feature vocabulary — the same
   features correspondences are built from. Water, rain, night, season, a Cast
   member, a real person. "Show me where the rain pages are." This is what makes
   it useful rather than decorative, and it is nearly free because the vocabulary
   exists in `LoomProjectors`.
2. **A way in.** Tap a pin, get that place's kept Pages, its anchor room, its
   visits. A spatial route into the archive, which Stacks search cannot offer.
3. **It shows what the reader did not know.** Clusters, drift across years, the
   shape of a season — annotated in the Book's voice: "you have never once
   written from the east side of the river."
4. **It asks.** An unanchored cluster is the Book noticing the reader keeps
   writing from somewhere it has no name for. This is the anchor-creation ramp,
   and it is the reason the Atlas earns its place while still sparse: a thin map
   that asks good questions gets thicker.

Styling as Phase 7. The Atlas never exports at full fidelity; print inherits the
strictest veiling.

---

# What Phase 0 opens

The archive change is not one feature. Every newly persisted field is a new
*condition* the grimoire can form correspondences from, so every surface already
built on it widens at once — Notices, Book Today, Ask the Book, the braid, and
the Correspondences shelf above. New conditions now reachable: place kind,
distance from home, whether the reader was moving, sun elevation, sleep debt, HRV
band, and weather at the reader's actual coordinates rather than a regional tag.

Follow-on features, roughly by strength per unit of work. None are committed by
this plan; they are what it makes possible.

- **"A year ago you were standing here."** Coordinates plus dates gives return
  journeys — the Book noticing the reader is where something happened. Currently
  impossible, cheap once Phase 0 lands, and among the most affecting things a
  journal can do.
- **Today's Sky becomes true.** Sun and moon at the reader's actual position:
  real golden hour, real first light, real moonrise.
- **Personal seasonal signs.** The week the lilacs arrive *here*; the first
  evening the reader stayed out. Needs location, dates, and years — the one that
  keeps getting better for a decade.
- **The Weather Grimoire.** Per-place weather history instead of tags. "This
  place is always cold when you come."
- **Place-to-place relationships.** "Everything you've written about your mother
  happened within a mile of each other." The Atlas shows it; the grimoire claims
  it.
- **A year's movement as a printed endpaper.** An artifact nobody else can make
  for this reader.

## The paused-place invitation, and what it costs

"You pause here on your walks — do you want to write a sentence to capture it?"
is the strongest version of the anchor-creation ramp: the Book notices a
recurring stop and asks, rather than waiting to be told. It is an *invitation*,
never a claim, so it is safe by construction.

It is also in a different cost bracket from everything else here, and should be
chosen deliberately rather than arrived at:

- **Precision.** The place paths ask for a hundred metres
  (`AnchorLocationReader.requestLocation()`), which is a block rather than a
  bench. Anchor *creation* already reaches for ten metres with no cached reuse
  (`requestAnchoringLocation()`) — that is the tier a paused place would need,
  and it is deliberately not what the ambient path uses.
- **Continuity.** Location today is one-shot and foreground —
  `requestLocation()` on an explicit tap. Detecting a lingering stop wants
  `CLVisit` monitoring, which is the right primitive: low power, semantically
  "arrived and stayed" rather than a GPS trace, and far less invasive than
  continuous tracking.
- **Authorization.** That means **Always**, not When-In-Use, plus
  `NSLocationAlwaysAndWhenInUseUsageDescription`. The current string
  (`INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`, pbxproj:894) promises
  the opposite — "uses your location **when you ask**" — and would have to be
  rewritten honestly.

This changes the app from one that looks once when asked to one that knows where
the reader goes. The feature is worth it, but it is a different promise to the
reader and a different conversation with App Review than persisting what the
Book already sees.

## Two engineering consequences of a permissive archive

- **The sweep budget is combinatorial.** `GrimoireKeeper.sweepBudget` is 250
  pairs per tend, and the feature table has already had to be trimmed once —
  context blends at six per observation were 80% of it and were capped at three.
  Every new persisted field multiplies the pair space. Decide separately which
  fields become *projected features* and which are merely *stored*: not
  everything kept needs to be hunted through.
- **Claims land faster.** More evidence per day means `BookClaimTier` climbs
  sooner. Good, provided the falsifier discipline holds; without it the Book
  becomes a machine that asserts constantly.

## Deliberately not in this plan

- Changing the Atlas `laws` face.
- Porting `PlaceState` to reader places.
- A reader-confirmation gate on any grimoire promotion. Settled: the Book asserts
  and pays with a falsifier and a visible crossing-out.
- Adopting inherited lore as the Book's own finding, under any conditions.
- Look Around, directions, `openInMaps`, or any surface that leaves the Book.
- A parallel place-incident log.
- Anything named "ritual".
