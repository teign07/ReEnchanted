# The Field Book — every edition worth more than its highest price

Written 2026-09-30, after [print-value-audit-2026-09-30.md](print-value-audit-2026-09-30.md).
bj's brief: premium paper is a start; **page count and content actually printed matter; no padding,
find the content; think outside the box: a magical field story-journal of the reader's modern
faerie-tale life.**

## Status (2026-09-30): built, and measured on a synthetic reader

Everything below the status block is the design. This block says what exists.

**Built and in the app target** (`Shared/BoundDayBook.swift`, `InsideCoverApp/FieldBookPDF.swift`,
plus hooks in `MonthlyEditionPDF.swift`):

- **The Serial, frozen at the moment of showing.** `AuthoredContentReceipt` now carries
  `printedTitle`, `printedBody`, `printedChoiceLabel`, `roomID`, `castIDs`, written by
  `SurfacePage.authoredContentReceipts` for story scenes. **Only receipts written by a build with
  this change carry text, so this must ship before readers open October.**
- **`BoundDayBook`**: per-day world side and reader side, weeks, a Labyrinth chart (story rooms +
  the Academy's timetable via `AcademyWhereabouts`), and a Ledger of Nights. Private body, fuel and
  rest Pages stay out of a printed day unless the reader opened that drawer.
- **Monthly**: Almanac (calendar of moons, nights, scenes and photographs), the Labyrinth chart and
  the reader's own ground, a Cast sketchbook (full plates), week leaves with a day-by-day digest and a
  week chart, then **The Days**: each date's world side (the scene as read, your choice, who was in
  the room, Bleed clippings, the Cast's lines, a margin note) and your side (the braid, the pressed
  photograph, specimens collected, your own words, kept drawings). Days that held only a sentence are
  gathered on "between the nights" leaves. Short sections now share a leaf.
- **Seasonal**: per chapter, the almanac, the chart (when a scene was read), week leaves and the scenes
  as read; a Cast sketchbook across the season.
- **Annual**: per chapter the almanac and a one-line story digest; a Cast sketchbook; **the Ledger of
  Nights** (every night, a line each), and the "every night" caption on trimmed braids now says it is a
  sampling.
- **Weekly**: rebuilt on day spreads (title leaf, bound story, week leaf, days, worksheet, closing).
  It stays a paid option; postage is the customer's.
- **No blank pages**: the ruled "padding" is gone. A press-minimum shortfall is filled with at most two
  Field Notes leaves (a prompt and rules), then plate leaves. The leaf before a worksheet is a plate,
  not an empty sheet. **One deliberate exception: the reverse of a worksheet leaf stays plain white**
  (marker must not ghost through); revisit if you would rather print a plate on it.
- **Caps** 128 / 176 / 256 (weekly 48) in `PrintSpec.pageCap` and the Worker's `EDITION_PAGE_CAPS`
  together; Worker tests pass (pricing, gifts, print options, memberships, previews).
- **Fitting**: a day book gives up a second photo and long specimen lists first, then thin days, then
  clippings and lines, then half the scene-less nights; the scenes go last.

**Measured** with the proof harness (`--smoke-edition-proofs`, a synthetic 229-day reader with the
real October scenes as receipts, 9 braids and 2 photographs in October, so a *light* reader):

| Edition | Before | Now |
|---|---|---|
| Monthly | 32 pp, 11 blank | 60 pp, 1 notes leaf |
| Seasonal (3 chapters) | 58 pp | 104 pp |
| Annual | 198 pp, 47% of an engaged year | 252 pp, every night named |
| Weekly (7 kept pages) | 20–24 pp, mostly one line a leaf | 12 pp, every leaf with content |

The model's ~110-page engaged month has **not** been rendered; the fixture reader is light. Run the
harness with a heavier fixture before quoting page counts.

**Not done / open:**

1. **The reader's real-world map** is drawn when the app passes a `RenderedMapPlate`; the harness
   passes none, so only the "room by room" fallback was seen.
2. **Marginalia drawings** appear as kept marks beside a day's words; the Cast's text notes appear as
   margin slips. The botanical drawings are 200-pixel files, so they are set small (about 1.4 in).
3. **Illuminated photographs** ride the same path as photographs; not seen on a page.
4. **The Cast's act lines** (`BoundDayCastLine`) are built but the fixture has none.
5. **Pricing, copy and landing** still describe the old volumes; the Bound Year margin at the new
   page counts is modelled, not measured, and shipping by weight is still unquoted.
6. Copyright pass on quote pages and tarot images, and the Witness Law on specimen titles, are
   still owed before print.

## The idea

Today's edition is an archive with a cover: kept pages, flowed one after another. The Field Book
is what a naturalist of the reader's own life would carry: dated entries with the sky, the moon and
the day's specimens beside them; a field guide to the creatures, words and doors that kept
turning up; a map; the month's serial story *as this reader read it*; pasted-in ephemera from
the Labyrinth; exercises to try; an index. Every leaf is a real thing the Book already knows.
The press minimum stops being a problem because the authored material alone fills it.

**The key observation: the monthly issue is a short novella the reader already reads for free and
we never print.** October's pack holds ~16,000 words of authored scenes plus art, a maze, a map, notes,
Bleed articles and radio patter. Today's bound month prints only its canon summary ("The Record").
Printing the scenes the reader actually read, with their choices and their own kept sentence set into
them, is about 28 pages (assumed; verify against the read path). Those pages exist for every reader,
however little they kept, so **a month that kept almost nothing still binds at about 70 pages with
no padding.**

## The worth test

An edition passes when, at its highest price (shelf + shipping + Stripe, or the member-year cost for
the Bound Year), all four hold:

1. **Landed price per page ≤ $0.55 softcover/saddle, ≤ $0.50 hardcover** for an engaged reader
   (Storyworth ≈ $0.26–0.36, Day One ≈ $0.25–0.40; we are premium colour, illustrated, with
   authored fiction, so a premium over them is fair and more than 1.6× is not).
2. **No leaf without a reason**: every leaf has a minimum of words, a plate, a map or a
   worksheet. A lint in the proof harness fails the build otherwise. A deliberate notes leaf is the
   only ruled page, at most two per book, and only where the module asks for it.
3. **At least a third of the pages exist only in this reader's copy**, and at least a third are
   authored by us. Neither half is allowed to be the whole book.
4. **One object they cannot print themselves**: the serial, a map, found-object leaves, a bound
   index. Free PDFs and DIY printing ($14–22 landed) are the real ceiling on price.

## The modules

Each has a source already in the app (E = already printed, P = exists in the app but not printed,
N = new), a yield in printed pages, and a priority for the fill ladder.

| # | Module | What it is | Source | Pages |
|---|---|---|---|---|
| 1 | **Flyleaf** | Field Book number, "if found, return to…", Reader's Mark, dedication, name the Book gave them | E/P | 2 |
| 2 | **Field Notes** | Each braid on its own leaf as a dated entry: header strip (date, **moon phase, sky, time of day**), the braid, **"Specimens collected"** in the margin (the kept pages that fed it), one spot drawing chosen by the night's motif | P: `context.moonPhase/weatherTags/dayPart`, braid source pages, marginalia cabinet. N: layout | ~1.0 per night |
| 3 | **The Serial** | The month's authored story as this reader read it: scenes from frozen receipts (`storyText`), the choice taken in the margin, the reader's own sentence set in where the story asked for it | P: `AuthoredContentReceipt.storyText`, pack scenes. N: assembly + layout | ~28 |
| 4 | **The Almanac** | Month calendar with moon, sky glyph, feast days, a dot per kept page, braid nights marked; ink clock; the month's weather in numbers | P: moon/weather tags, `FeastdayComposer`. N: layout | 4 |
| 5 | **Field Guide** | Entries for what kept returning: motifs and words as specimen cards (first sighting, dated sightings in the reader's own phrases, the Book's note), learned correspondences, creatures met | E (a list on one page) → N cards. P: motif counts, grimoire ledger, surface metadata | 3–8 |
| 6 | **Cast Sketchbook** | A plate and a dossier leaf for each Cast member who acted this month, with their marginalia | P: 22 Cast plates, `CastDossier`, `castSection` | 6 |
| 7 | **Maps** | The Labyrinth as staged this month (the living map) and the reader's own trail, coarsened at print | E: `MapPlateImageRenderer`; P: `AcademyMapView` | 3 |
| 8 | **Found Objects** | The month's props as typeset ephemera: a Bleed front page, a radio programme guide with the patter, a timetable, a library card, the relic | P: Bleed articles, radio banter, pack art. N: layout | 5 |
| 9 | **Field Exercises** | The month's spells and favors as instructions (rules played straight), the pack's maze and riddle leaves with answers, the threshold leaf, each with room to write | E: play leaves. P: spells, favors | 6 |
| 10 | **Pressed & Kept** | Photographs, souvenirs as a commonplace (several to a leaf), scrapbook and Pagewright pages | E | 2–8 |
| 11 | **The Record** | Canon, finished tales, consequences | E | 4 |
| 12 | **Index** | "Where things turn up": motifs, Cast, places, with page numbers | N (the writers already re-render to settle margins) | 2–3 |
| 13 | **Archive, set dense** | What remains, two columns at reading size rather than one item per line | E, re-set | 2–6 |
| 14 | **Closing** | The Book's letter, colophon | E | 3 |

Modules 2, 3 and the day-bound parts of 8 (Bleed and radio lines) are laid out **inside The Days**
(next section), not as separate sections.

**Fill ladder**: to reach an edition's target, add modules in the order 3, 2, 4, 6, 8, 9, 5, 7, 10,
12, 13. Never add a page that is not one of these. If a module cannot fill (no photographs, say),
it yields nothing. An edition that still cannot reach the press minimum is too thin to bind as a
softcover and is offered as a saddle-stitched booklet; nothing is padded. (No current month gets there:
the guaranteed modules 1, 3, 4, 6, 7, 8, 9, 11, 14 alone total about 60–65 pages.)

### Outside the box: cheap, true, and only a book can do them

- **Endpaper maps.** The first and last leaves carry the Labyrinth and the reader's constellation.
  They are interior pages, so they count, and they are the most photographed part of a hardcover.
- **The Ledger of Nights** (annual). Every night of the year on one line: date, title, and
  the one object the night's closing named ("what one object from tonight did"). 365 lines are
  8 pages. It replaces the false "every night" caption: best nights are full, the rest are
  in the ledger, nothing is missing.
- **Sealed wagers.** The Book's bets, sealed in one volume and resolved in the next.
  Uses the existing `BookWager` sealing, costs nothing, and gives the next book a reason to exist.
- **Month dividers that carry something**: a plate, the month's strip calendar and its headline line,
  so the twelve annual dividers stop being near-empty leaves.
- **Reader's fieldwork pairs**: the two-looks leaf (the same doorway seen twice) already exists for
  the crossings; give every month one.
- *Considered and parked*: a QR to the month's radio episode (link rot outlives a hardcover);
  loose inserts (Lulu will not insert them).

## By the day (recommended structure for the main bulk)

Yes: make **The Days** the spine, with each date laid out as a facing spread.

- **Verso, the world's day**: date numeral, moon, sky, feast day; the authored scene or branch the
  reader read that day (their choice marked); who was in the room; a Bleed line or radio line
  if one landed; a tucked marginalia drawing.
- **Recto, your day**: the braid; the photographs kept that day (pressed, with corner mounts) and the
  illuminated version where the reader made one; a "specimens collected" list of what fed the
  braid with clock times; their own kept sentence on a torn slip; a botanical or creature drawing.
- **A quiet day** gets one leaf (the world's side). Consecutive days with nothing authored and
  nothing kept fold into one "days between" leaf of almanac lines. No day is padded.
- **Weeks** open with a single leaf: the week's map thumbnail, the week's strongest night, its story
  beat. The weekly edition is exactly these gatherings.
- **Reading straight through** still works: braids run in date order, and a contents table gives
  the page for each scene, so the serial can be read in sequence.

Why better than modules-first: braids are the story of a day, the authored scenes were read on
days, and photographs belong to days. Interleaving them makes the reader's own life and the
Labyrinth's month one continuous thing, which is the point of the product. It also yields more
pages per unit of real content, because each day has two sides that are both true.
Estimate for an engaged month: about 25 spreads (50pp) plus quiet-day leaves and four week
openers (about 10pp) carry 60 of the ~110 pages.

**Maps stay their own spread.** A month map of the Labyrinth shows where each Cast member was
(the timetable's `AcademyWhereabouts`, computed per date, plus the rooms scenes were staged in) and
which rooms the story visited, with routes in scene order. Facing it, the reader's own ground: a
map snapshot of their places, always loosened to a district for print, with the Outer Stacks doors
where the two maps touch. For a season: one map per month on a spread; for a year: a trail.
Cast whereabouts before the scene-metadata change (2026-09-27) come from the timetable only, and
the page should say so.

## Will it look awesome? What I checked

I built a real-art mock (`docs/field-book-mock/`, preview name `field-book-mock`): four spreads —
a day, the two maps, a Cast plate beside Bleed clippings, and field guide + correspondences — on
the pack's real Hunt-branch text, the real Bleed articles and radio lines, the real Cast plates,
botanicals and marginalia drawings, and the real room coordinates from `AcademyGeography`.
It looks like a hand-kept book, not a report. Three limits:

1. It is HTML, not the PDF writer. The print writer omits the marginalia column at 6×9
   (63pt margin), which is why today's proofs look plain; the mock puts marginalia on
   the page as tucked taped scraps instead, so the layout needs new code, not a setting.
2. The door photograph, moon phase, specimen times and correspondence entries are hand-set or invented.
3. Two asset gaps: the marginalia drawings are 220px (fine at about an inch, soft larger) and
   illuminated photos need a sample to judge; I did not have one.

## What each edition becomes

Figures are from the model in this session's scratch (`fieldbook.py`), at 25 nights for *engaged*.
Shipping is $6.88 plus an **assumed** $0.75 per 50 pages past 112; neither is a Lulu quote.

| Edition | Now (engaged) | Field Book | Cap | Landed $/page | Contribution | Worth test |
|---|---|---|---|---|---|---|
| **Monthly** softcover | 36pp, $58.82, $1.63 | **110pp**, $61.16 | 92 → **128** | **$0.56** (light 12 nights: 88pp, $0.67) | $35 | passes at engaged; light misses by $0.12 |
| **Seasonal** softcover | 96pp, $79.40, $0.83 | **~170pp**, ~$80 | 112 → **176** | **~$0.46** | ~$43 | passes |
| **Annual** hardcover | 208pp (47% of nights), $110, $0.53 | **~246pp**, $112, every night present | 208 → **256** | **$0.46** | $51 | passes |
| **Weekly** saddle | 20pp, $29.56, $1.48 | 28–36pp (seven day spreads), $30–31 | 48 | $0.85–1.05 | $15 | waived: the reader chooses to pay the postage |
| **Bound Year** ($249 / $299.88) | ~500pp | **~780pp** | — | **$0.32 / $0.38** | see below | passes |

Notes on each:

- **Monthly.** Price stays $49.99 until the book passes 93 pages, then rises at cost + $35
  (13.9¢ a page): $52 at 110pp, $54 at 120pp. A month with no braids at all still binds at about
  72pp ($0.82 a page) because modules 3, 4, 6–9 and 11 do not depend on the reader; that
  reader is the one the worth test does not clear, and the only one for whom the price should
  not drop. Light readers pass $0.55 only by keeping more, which is the point of the product.
- **Seasonal.** It should *not* reprint three full Serials. It carries each month's story as
  a one-spread digest with the choices, plus the season's Field Notes, guide, maps and
  the Record. The full Serial lives in the monthly book.
- **Annual.** Twelve chapter dividers that carry a calendar and a line, the Ledger of Nights, the
  year's best nights in full (~100), twelve Serial digests, a year heatmap, year-level field guide,
  endpaper maps. Above 256 pages the trim order still applies, but braids stop being the first
  thing to go.
- **Weekly.** Keep it, as an option that earns. The customer pays the postage, so the $15
  contribution holds and the worth test's per-page bar does not apply. What changes is the
  content: seven day spreads (below), a week map, and a workbook leaf, 28–36 pages with no
  ornament-only endpapers. It is also the unit the monthly is built from: four weekly
  gatherings, so the two products share one layout and one test.
- **Bound Year.** Page count nearly doubles while the price holds, so margin moves:

| Member-year (engaged) | Pages | COGS | Net, annual $249 | Net, monthly $299.88 |
|---|---|---|---|---|
| Today | ~500 | $117 | $122 (49%) | $168 (56%) |
| Field Book, seasonals 176pp, annual 256pp | ~784 | ~$162 | ~$77 (31%) | ~$123 (41%) |
| Seasonals held at 128pp, annual 240pp | 624 | $138 | $102 (41%) | $148 (49%) |
| Seasonals uncapped (~256pp) | 1,043 | $202 | $37 (15%) | $83 (28%) |

  The uncapped row is why the seasonal cap matters. Doubling pages is affordable only while
  the seasonal stays a digest of its months. Shipping weight is the largest unmeasured term:
  get live Lulu quotes at 128, 176 and 256 pages before any cap changes.

## Decisions this needs from you

1. **Caps**: monthly 128, seasonal 176, annual 256. They move together in `PrintSpec.pageCap(for:)`,
   the Worker's `EDITION_PAGE_CAPS`, and gift allowances (`GIFT_PRESS_PAGE_COUNTS`).
2. **Bound Year margin**: accept ~31% net on the $249 (about 780 pages for $0.32 a page) or
   hold seasonals at 128pp for ~41%. The $249 price is your number; this plan does not change it.
3. **Weekly**: keep it as a paid option (your call, reflected here), rebuilt on day spreads.
4. **Serial in print**: every reader gets the month's story bound in. It is free on the phone
   today, so this is the main new thing paper carries. Confirm.
5. **Copyright and privacy before print**: quote pages (copyright pass owed), tarot imagery
   (the RWS files are marked temporary), and the Witness Law on people in Field Notes
   specimen lists all need a print-time filter, per the permissive-archive rule.

## Build order

**0. No padding.** Remove `blankEndpaper` and the weekly ornament endpapers; add the
no-empty-leaf lint to `EditionProofHarness`; give the annual an honest caption until the Ledger ships.
This lands alone and is small.
**1. Field Notes leaf, Almanac, the Serial.** These three carry most of the pages and the
value. The Serial depends on confirming that every scene's receipt holds frozen `storyText`.
**2. Cast Sketchbook, Maps, Found Objects, Exercises, Field Guide cards.** Mostly layout over assets
and ledgers that already exist.
**3. Index, dense archive, seasonal digest, annual Ledger and dividers.** Then the caps and Worker
lockstep, and a live Lulu quote at each new size.
**4.** Re-run the proof harness, then the audit table, and only then change landing copy and
prices; `LandingPage` and the BookShop strings currently describe the old volumes.

## What I have not verified

- That `storyText` is frozen for every October scene, or how many words a typical read path
  is (I counted ~16k words of markup-laden JSON, not reader paths).
- The per-page yields: they are modelled from the Sept 24 proofs, not from a Field Book
  render. The plan's page counts are targets to prove with the harness.
- Shipping cost by weight, and whether Lulu's softcover perfect-bind quality holds at 176+ pages.
