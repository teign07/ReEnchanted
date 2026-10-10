# Academy Geography

*Draft, 2026-09-27. The first map of the Academy and the Labyrinth: which rooms
exist, where they sit, what connects to what, and how the map grows.*

Nothing in the app draws the Academy yet. Every map we have (the Atlas,
MapPlate, the Gazetteer, GazetteerGaps, ReaderAtlas) draws the reader's real
world. The Academy has **names without a floor plan**. The seven
`coreLocations` in `Shared/NarrativeCore.swift` have characters and
`PlaceMemory` gives them history, but nothing says what is next to what. This
doc sets that out once so the Book's map, a walkable-rooms page and any
future game all read the same list.

Everything marked **canon** is already written somewhere (source given).
Everything marked **proposed** is new here, and bj can change it.

> **Built 2026-09-27.** bj said "let's implement", so the proposals below
> shipped as their defaults:
> - The room graph is in `Shared/AcademyGeography.swift` (`AcademyGeography`,
>   `AcademyCartographer`), tested in `AcademyGeographyTests`.
> - The map is `InsideCoverApp/AcademyMapView.swift`, opened from the contents
>   as **A Map of the Labyrinth** (`BookRoom.labyrinthMap`, so it wears).
>
> Three changes from the draft came out of drawing it for real:
> - The Binding Hall opens off the Great Hall's south-east side.
> - The Still Room sits on the south axis, and Wing 3 is reached *through* it.
> - The tower is labelled **The Tower**.
>
> Not built yet: the `storyGated` stability (§5) and the endpaper (§7).
> §9's questions are still bj's to overrule.

---

## 1. Principles

1. **The Academy is a complete place.** Its surveyed walls are drawn before
   the first story visits them. Discoveries add remembered Pages, incidents
   and marginal notes; they never hide someone's current address. Monthly
   borrowed rooms and the Reader's Anchor chambers still extend the map.
   This replaces the original blank-room rule following bj's 2026-10-08 review.
2. **The Academy can be charted. The Labyrinth resists being charted.** The
   school has walls that stay put. The Labyrinth around it moves: the map marks
   its rooms "seen here on…", and sometimes the Book has to cross one out.
3. **The Book draws the map.** It's the Book's own map, in its hand, with
   its opinions in the margins. It's not a floor plan from somewhere else.
   *"A map is an invitation, never an answer"* (Soren Ng, lore bible §5).
4. **The two maps meet in the Outer Stacks.** The lore already says the Outer
   Stacks is where a real place becomes a room. The reader's Anchors show
   up there as doors. This is the only place the real-world Atlas and the
   Academy map touch.
5. **My Dorm is the Reader's.** It's always on the map, because it's home. But
   the map never makes up what's in it (NarrativeCore's own fault line for the Dorm).

---

## 2. How the places nest

> A school inside a labyrinth inside a book. — lore bible §4

```
THE BOOK
└── THE LABYRINTH            the living library; shelves, thresholds, rooms that move
    ├── The Outer Stacks     the outer edge; real places come in here
    ├── The Stacks           the deep archive, a ring around the school
    │   └── The East Stacks  the reach where October's castle grew
    └── THE ACADEMY          the settled middle: walls that stay put
        ├── the Heart        Great Hall, Still Room, Binding Hall, Headmistress's tower
        ├── the four Wings   one per compass point
        ├── the warm rooms   Kitchens, Book Burrow, the Dorm
        └── the Grounds      the field, the gate, the gardens
```

Every `coreLocation` currently carries `chapter: "Labyrinth"`. That is true in
the loose sense (it's all inside the Labyrinth). The map needs the finer split
above, as a `zone` field (see §6).

---

## 3. The layout: the Academy is built on the Compass

**Canon:** the five core classes already map to the Wonder Compass, and
three of their rooms are numbered Wings (lore bible §4 timetable;
`AcademyScheduleRegistry` in `Shared/WorldSystems.swift`):

| Compass | Practice | Class | Room |
|---|---|---|---|
| North | Notice | The Art of the Glint (Boggle) | **Wing 4: The Glint Hall** |
| East | Embark | Wayfinding & Kineticism (Momort) | **Wing 2: The Momentum Yard** |
| South | Sense | Synesthetic Resonance (Euphony) | **Wing 3: The Resonance Chamber** |
| West | Write | Ink-Binding (Villanelle) | **The Inkworks** |
| Center | Rest | Quiet Hours (Stonebrook) | **The Still Room** |

**Proposed:** make it literal. The Academy is a compass rose in stone:
four Wings on the four points and the Still Room at the centre. Walking the
school is walking the Compass. Momort's slightly wrong East (exits instead of
arrivals) is then a real direction you can walk, and the Open Field Gate
sits past his Yard.

**Proposed:** the Inkworks is **Wing 1**, which completes the numbering. The
numbers don't run clockwise (N=4, E=2, S=3, W=1). Keep that. The Book should
have an opinion about why, and nobody at the Academy should agree on the answer.

### Sketch

```
                          ~ ~ THE OUTER STACKS ~ ~
              (the reader's Anchors open here as doors onto real streets)

      ::::::::::::::::::::::::: THE STACKS ::::::::::::::::::::::::::::::
      :                                                                  :
      :   Bibliophonic Hall          Headmistress's tower                :
      :   (under the library             │                               :
      :    ceiling)              ┌───────┴────────┐                      :
      :        │                 │  WING 4  N     │      Spark Annex     :
      :        │                 │  Glint Hall    │           │          :
      :        │                 └───────┬────────┘           │          :
      :        │                  North Staircase             │          :
      : ┌──────┴────┐          ┌─────────┴──────────┐   ┌─────┴──────┐   :   EAST
      : │ WING 1  W │ Corridor │    GREAT HALL      │   │ WING 2  E  │ Quillquarium ── STACKS
      : │ Inkworks  │═ of ═════│  Binding Hall off  │═══│ Momentum   │   (drawbridge)   │
      : └───────────┘ Whispered│  its west end      │   │ Yard       │        Vault of Doors
      :               Secrets  │  ▼ stair down to   │   └─────┬──────┘   :
      :                        │   THE STILL ROOM   │         │          :
      :   Kitchens ── Book     └─────────┬──────────┘   Open Field Gate  :
      :   (Pantry)    Burrow             │                  (the field)  :
      :      │          │        ┌───────┴────────┐                      :
      :      └── the Dorm        │  WING 3  S     │     The Walled Garden:
      :         (your room)      │  Resonance     │       └ Secret Garden:
      :                          │  Chamber       │         of Prose     :
      :                          └────────────────┘                      :
      ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
```

This drawing is a proposal for the adjacency graph, not the art. The art is
a separate job (§7).

---

## 4. The rooms

`id` follows the existing `location-*` convention. **Source** is where the name
comes from. **At start** says whether the room is drawn on day one or waits for
the story to go there.

### The Labyrinth

| id | Room | What it is | Source | At start |
|---|---|---|---|---|
| `location-outer-stacks` | **The Outer Stacks** | The outer edge. Shelves remember footsteps. Real places come in as rooms. The reader's Anchors are doors here. | canon: coreLocations | **drawn** (the reader came in this way) |
| `location-stacks` | **The Stacks** | The archive. Catalog cards misfile things *toward* meaning. A ring around the whole school. | canon: coreLocations | drawn, edges only |
| `location-east-stacks` | **The East Stacks** | A reach of the Stacks by the Quillquarium and the Vault of Doors. October: Dracula's composite castle grew through it. The red chair still turns up after closing. | canon: Count Unbound pack | fog |
| `location-vault-of-doors` | **The Vault of Doors** | Book Jumping (Permancer) and the Book Jumpers club. Doors into other books. The Sunday Jump opened the wrong one. | canon: timetable | fog |
| `location-bibliophonic-hall` | **The Bibliophonic Hall** | Inkwright Society. Pages read aloud and burned, and the smoke soaks into the library ceiling. So it sits under the Stacks. | canon: clubs | fog |
| `location-corridor-whispered` | **The Corridor of Whispered Secrets** | Marginalia Guild. Notes left for future readers. Runs from the Inkworks to the Great Hall. | canon: clubs | fog |
| `location-shelf-misfiled-days` | **The Shelf of Misfiled Days** | Where ordinary days come back filed on the wrong shelf. A drifting room: never in the same place twice. | canon: NarrativeCore thread | fog, **drifts** |
| `location-rain-room` | **The Rain Room** | Opens only in certain weather. Proposed: it's on the map only while it's actually raining where the reader is (PaperSky already knows). | canon: NarrativeCore thread; gate proposed | **weather-gated** |

### The Heart

| id | Room | What it is | Source | At start |
|---|---|---|---|---|
| `location-great-hall` | **The Great Hall** | Where everyone gathers. Bright and full of politics. Banners change when Belief moves. The school's crossroads: every Wing connects here. | canon: coreLocations | **drawn** |
| `location-still-room` | **The Still Room** | Quiet Hours (Stonebrook). Rest/Centre, "the ground the directions emerge from." Proposed: *below* the Great Hall, so the loudest room sits on top of the quietest. The way south to Wing 3 goes through it. | canon: timetable; placement proposed | fog |
| `location-binding-hall` | **The Binding Hall** | Where a reader is bound to a Chapter. The candles go blue-white. Thorne presides. Proposed: an antechamber off the Great Hall's south-east side. | canon: SourceAdapters | **drawn** (every reader has been bound) |
| `location-north-staircase` | **The North Staircase** | Climbs from the Great Hall to Wing 4 and on to the tower. Wicker is banned from it. It stays very still. | canon: PagePacks undertaking | fog |
| `location-headmistress-tower` | **The Tower** | Thorne's office, where the inkwell is kept "for safekeeping. Officially." The Academy's one tower, the one in the Tarot art. | canon: ReferenceLibrary, Tarot XVI; combined proposed | fog, **guarded** |

### The four Wings and their annexes

| id | Room | What it is | Source | At start |
|---|---|---|---|---|
| `location-glint-hall` | **Wing 4: The Glint Hall** (N) | The Art of the Glint (Boggle). Notice. | canon | fog |
| `location-momentum-yard` | **Wing 2: The Momentum Yard** (E) | Wayfinding & Kineticism (Momort). Embark, slightly wrong. | canon | fog |
| `location-resonance-chamber` | **Wing 3: The Resonance Chamber** (S) | Synesthetic Resonance (Euphony). Sense. | canon | fog |
| `location-inkworks` | **Wing 1: The Inkworks** (W) | Ink-Binding (Villanelle). Write. | canon room; wing number proposed | fog |
| `location-spark-annex` | **The Spark Annex** | Basic Enchantments (Wispwood). Everything speaks. Proposed: off the northeast, between Glint and Momentum. | canon room; placement proposed | fog |
| `location-quillquarium` | **The Quillquarium** | Living pens that school like fish. Where the reader's Quill chose them. It borders the East Stacks, because October's drawbridge hung over it. | canon: coreLocations + Count Unbound | drawn at the Chosen Quill ceremony |

### The warm rooms

| id | Room | What it is | Source | At start |
|---|---|---|---|---|
| `location-kitchens` | **The Kitchens** | Ambrose's ground. Pantry labels rewrite themselves toward care. Serenity woke here after the East Stacks. | canon: coreLocations | **drawn** |
| `location-pantry` | **The Pantry** | Off the Kitchens. The Pantry Keeps Receipts. | canon: NarrativeCore thread | fog |
| `location-book-burrow` | **The Book Burrow** | The common room. Armchairs move toward whoever needs quiet company. | canon: coreLocations | **drawn** |
| `location-dorm` | **The Dorm** | The reader's room. The desk rearranges around the last Page kept. | canon: coreLocations | **always drawn** |

### The Grounds

| id | Room | What it is | Source | At start |
|---|---|---|---|---|
| `location-open-field-gate` | **The Open Field Gate** | Compass Running on Saturdays (Stonebrook). The field past the east side, the one way out of the walls. | canon room; placement proposed | fog |
| `location-walled-garden` | **The Walled Garden** | The storyline "Mend the Walled Garden." A garden that needs looking after. | canon: StoryEngine | fog |
| `location-secret-garden-prose` | **The Secret Garden of Prose** | Compass Society (Zara). No one mocks a sentence here. Proposed: a door *inside* the Walled Garden, so you find it only after the mending. | canon room; nesting proposed | **hidden** |

### Named but not placed yet

These exist in the canon but don't need a room yet. The map can pick them up
when a pack needs them:

- **The Bleed's office**: Penny's newsroom (Department of Attestation).
- **Wicker's sealed room**: his undertaking is to get into it "without
  technically entering it." A room whose door is on the map but can't be
  opened is a good map joke.
- **The library ceiling**: where the Inkwright smoke goes. Maybe it's the
  Stacks' upper storey.
- **The five Chapter common rooms**: nothing in the canon yet. Duskthorn
  having no room at all (the Chapter "does not appear in the sorting ledger")
  is worth keeping: a blank on the map exactly where a sixth door should be.

That's **27 rooms** ready for the map: 7 core, about 11 from the timetable, and 9
from the story and packs. That's enough to start without inventing more.

---

## 5. How the map grows

A room goes from fog to drawn when **any** of these happens:

1. **The story sets a scene there.** A kept Story Page, a braid night or a
   pack scene set in the room. (To verify: do Story Pages carry a
   location id or tag we can read at keep? The `coreLocations` carry tags
   like `great-hall` and `story-setting`, but the link from Page to room
   still needs checking in the code.)
2. **PlaceMemory records an incident there.** `PlaceState.incidents` is
   already keyed by location id.
3. **A pack's manifest reveals it.** For example, October's pack reveals the
   East Stacks and the Vault of Doors as the Sunday Jump happens.
4. **The reader's own Anchor wakes.** Each Anchor adds a door in the
   Outer Stacks (the Atlas `places` layer is the data source).

Once a room is drawn, it keeps its **margin notes**. PlaceState already has
most of them:

- `condition`: written beside the room ("the chair is facing the right way now").
- `refusal`: the thing the room has started refusing, in the Book's hand.
- `slowChange`: the one detail that changes by season.
- `favoredOccupantIDs`: small initials of whoever keeps turning up there.

**How stable each room is** (a proposed field; the Academy is all `fixed`):

| Stability | Meaning | Examples |
|---|---|---|
| `fixed` | Walls. Always in the same place. | Every Academy room |
| `drifting` | On the map with a "seen here on…" date. Can move between visits. | Shelf of Misfiled Days, parts of the Stacks |
| `weatherGated` | On the map only while the real sky allows it. | The Rain Room |
| `storyGated` | Drawn, but the door stays shut until a thread opens it. | Headmistress's tower, Wicker's sealed room, Secret Garden |

---

## 6. Data shape (built as `AcademyRoom` / `AcademyPassage`)

Keep the characters where they are (`NarrativeWorldEntity` in
`coreLocations`). Put the geography in its own table so the two can't get in
each other's way:

```swift
struct AcademyRoom {
    var id: String              // matches a location entity id
    var name: String
    var zone: Zone              // .labyrinth / .heart / .wing / .warm / .grounds
    var compass: Compass?       // .north / .east / .south / .west / .center
    var stability: Stability    // .fixed / .drifting / .weatherGated / .storyGated
    var passages: [Passage]     // (to: roomID, kind: .door / .stair / .corridor / .drawbridge / .hidden)
    var startsDrawn: Bool
}
```

Two clean-ups this would force, both good:

- `AcademySession.room` in `AcademyScheduleRegistry` is a free string
  (`"Wing 4: The Glint Hall"`). It should become a room id, so the timetable
  can say **who is in which room right now**. The walkable-rooms idea (§8)
  depends on that.
- A wiring lint (same pattern as `WiringLintTests`): every room id is a
  location entity, every passage points both ways, every timetable room exists
  on the map, and every room can be reached from the Dorm. **Built:**
  `AcademyGeographyTests` covers all of these except the first, which runs the
  other way round (every authored location is a room). The timetable keeps its
  free strings; `AcademyGeography.room(forTimetableName:)` resolves them, and a
  test fails if one doesn't resolve.

---

## 7. Where the map lives

- **Contents:** a new entry, separate from "The Atlas" (real places) and "The
  Gazetteer" (your places, leaf by leaf). Candidate names: *The Academy*,
  *A Map of the Labyrinth*, *The Grounds*. It needs its own `BookRoom` case so
  opening it by hand leaves Wear.
- **Print:** front endpaper = the Academy, back endpaper = your places
  (`MapPlate.endpaperSpec` already draws the back). That's the classic
  fantasy-book pairing, and it shows both halves of the Book's world.
- **Art:** built from pieces rather than one finished painting, so it can grow. A
  parchment base, one small illustration per room placed at a fixed position,
  and hand-drawn paths along the passages. Fog is plain blank paper. Adding a
  room = one illustration + one position + passages, like the Cast plate recipe.

---

## 8. What reads this map later

Listed so the map is built with them in mind. None of them is a commitment.

- **Walkable rooms** (bj, 2026-09-27): a MUD-style page where the reader goes
  from room to room, looks around and talks to whoever is there. It needs this
  room graph, the timetable as room ids, and PlaceMemory. It could grow by
  one pack a month.
- **The videogame** (see memory: videogame direction): "one dense handmade
  Academy/Labyrinth, no countryside." This room graph is that game's list of
  levels. A text version of the Academy that people actually walk would be the
  cheapest possible test of which rooms they love.

---

## 9. Open questions for bj

1. **The compass layout.** Wings on the compass points, Still Room at the
   centre. Keep it?
2. **Wing 1 = the Inkworks**, with the odd numbering kept as a mystery?
3. **Still Room under the Great Hall** (loud room on top of the quiet one), or
   a room of its own in the middle?
4. **Headmistress's tower**: one tower, combining her office and the Tarot
   tower?
5. **Secret Garden inside the Walled Garden**, found after the mending?
6. **The contents name**: *The Academy*, *A Map of the Labyrinth*, or
   something the Book would call it?
7. **Chapter common rooms**: add five (with a blank where Duskthorn's would
   be), or keep the Chapters roomless?

---

## 10. Staging a month (built 2026-09-28)

The map is live. Who's where comes from these sources, strongest first:

1. **The month's staging** for the current stretch: a live phase, or the
   foreshadow or residue week.
2. **Pages**: anything on the desk right now, and anything kept in the last
   three hours, read from the Page's metadata (kept Pages keep it).
3. **The timetable.**
4. **Everyone's own day**: meals at 7, 12 and 18 in the Great Hall; haunts
   re-picked every two hours; Chapter common rooms from 19 to 22; dormitories
   from 22 to 7. Authored night wanderers retain their night haunts. This
   residential fallback replaces the earlier disappearance at bedtime.

When someone's room changes, they walk the route there through the passages,
for 45 seconds to four minutes, depending on the route, the reason for moving,
and that person's pace. Opening the map during a journey reconstructs the
original departure and shows its current progress. Teachers mid-class,
people in a scene, and the restless
characters (`AcademyMotion.restless`) pace; everyone else stands still. Shut
rooms are walked around.

### What a pack can say

On a `WorldEventPhase`, or on the event as `foreshadowAcademy` /
`residueAcademy` for the weeks either side:

| Field | What it does |
|---|---|
| `staging` | `{castID, roomID, note, name?, fromDay?, throughDay?, fromHour?, untilHour?}`: puts somebody in a room. `name` makes them a visitor out of another book: drawn in rust ink, with no page to open. Hours may wrap past midnight (`20` until `6`). Days count from the start of that stretch. |
| `closedRoomIDs` | Shuts rooms: drawn crossed through, nobody drifts in, and a class held there moves to the Great Hall. |
| `roomNotes` | `{roomID, note, fromDay?, throughDay?}`: a line beside a room. |
| `borrowedRooms` | `{id, name, note, x, y, width, height, form, joins: [{roomID, kind}], fromDay?, throughDay?}`: a room out of another book, drawn in rust ink while its window's open. |

On a **story scene** or a **beat**: `roomID` and `castIDs`. These are written
into the Page's metadata as `academyRoomID` / `academyCastIDs`, so the Page
moves people while it's on the desk and for three hours after it's kept. A
beat's window runs for days, so it never pins anyone by itself.

Any room the month stages, shuts or writes about is drawn on the map for as
long as it does. Nobody is ever staged into the Dorm.

### The Count Unbound, as staged

| When | On the map |
|---|---|
| 24–30 Sept | Permancer checks bookmarks in the Vault every evening; the East Stacks turn their own pages after dark. |
| 1–7 Oct | Serenity and Wicker over her map at Kitchens lunch; Sunday 4th, 9–12, the Jump fills the Vault. |
| 8–21 Oct | East Stacks shut. Serenity awake in the Kitchens (visits through Ambrose); Permancer in the Vault; Penny in the Stacks; from the 15th, the Count reads in the Old Reading Room at night. |
| 22–28 Oct | The Wrong Castle grows between the East Stacks and the Quillquarium; the Borrowed Ballroom joins the Great Hall from the 25th; the Count sups in the Great Hall on the 28th. |
| 29–31 Oct | Borrowed rooms gone, East Stacks open; Serenity's moon cards in the Kitchens; Permancer fitting safeguards. |
| 1–7 Nov | The red chair; the Vault's amended notice; Serenity at breakfast, still listening. |

`complete_small_media.py` carries the beat rooms (`BEAT_ROOMS`), so re-running
it keeps them.

## 11. The Reader's doors (source implementation, 2026-10-08)

The Academy map now receives the same Anchor ledger as the Atlas and Gazetteer.
`AcademyAnchorRoom.project` draws every named Anchor as a chamber beyond the
Outer Stacks, using its existing room description, keeper, rule and kept Pages.
Pages are linked by their recorded `nearbyAnchorID`, not by words matching a
place name. These chambers stay outside the Cast's room graph: drawing a door
does not stage a character there or record a real-world visit.

The parchment extends north in staggered pairs around a crooked aisle.
Ledger order keeps old doors still as new Anchors are appended, including
Anchors made on the same day. Names retain their drawing size; the leaf shows
the nearest doors, while the opened map pans through the whole growing sheet.
“Your places” finds any door. Opening one shows the Reader's words separately
from the fictional room, links its newest kept Pages, and reuses the Gazetteer's
Apple map plate and existing name-veiling rules. Returning adds books to the
chamber's shelves. New walls ink in when motion is enabled.

Each chamber has a drawn imprint: water and a paper boat, garden beds, a kettle,
a crooked library, a bridge, a lantern, or a door and key. Whole words in the
Reader's original Anchor words/name choose the motif first, then the confirmed
place category, then the existing fictional room. Private Maps names and
localities are not mined for imagery. These are fictional chambers, not real
building plans. Names sit below the drawings. Only the selected chamber's
water, steam or lantern moves; Reduce Motion and leaf previews keep it still.
The long passage is painted in strips with backing heights of at most 512
drawing points rather than one unbounded Canvas.

Hold a chamber or touch its folded note to unfold a sentence. The note uses the
newest actual Reader sentence atom from a Page recorded at this Anchor, with a
link to that exact Page, even when it falls beyond the five recent Page links.
Book-only prose and fictional choices are never quoted as Reader sentences.
When no such sentence exists, the original anchoring words can be folded
instead; without either, there is no fabricated note. Unfolding lasts for the
opened map and does not create a new persisted store or discovery counter.

At the Gazetteer's existing quiet threshold, a little dust appears. The note
names days since the last **recorded** check-in, not the Reader's absence from
the real place. A recorded return clears it; the door is never locked.

Swift syntax and source-layout checks were performed, including room spacing,
stable door positions and selection framing through 201 doors and five viewport
sizes. A separate vector drawing study was inspected for the seven motifs and
long names. Regression tests were added for ledger order, Page identity, full
Anchor coverage, veiled plates, atomic sentence provenance, imprint sources and
recorded check-in timing. At that source pass, no app build, test-suite run,
install or on-device visual proof was performed.

Rabbit follow-up for the Anchor iteration, 2026-10-08: all 74 `AcademyGeographyTests` passed. The complete
current workspace built successfully with the Debug `InsideCoverApp` scheme;
the signed app bundle and its Share/Widget extensions were checked, and no
workspace files changed during the build. Installation and launch on Rabbit
both succeeded. On-device map appearance and interaction still need visual
review; compilation, tests and launch do not establish that proof.


## 12. A complete inhabited Academy (source iteration, 2026-10-08)

After Rabbit review, bj asked for a real magical map and every Cast member on
it. The campus now has 39 permanent rooms connected by 42 passages. A single
survey arranges the compass teaching wings around the Great Hall, with outer
masonry, corner turrets, paved courts, window slits, table and workshop plans,
and the enclosing Stacks. The enlarged 920 by 1500 drawing keeps room lettering
and names readable when opened and zoomed. These are native vector drawings.

All five existing Chapters have distinct common rooms and attached dormitory
stairs: Emberheart's hearth, Mossbloom's growing beds, Tidecrest's round room,
Riddlewind's shared table, and Duskthorn's thorn study. Faculty and staff quarters and
guest rooms give the rest of the roster an address. The Book Burrow remains
shared. The map says **My Dorm**, preserves its existing `location-dorm` ID,
and draws nothing about its private interior. After Binding, its door joins
the dormitories of the Chapter resolved through the existing talisman registry.
Before Binding, it stays off the Book Burrow. Cast never enter it.

The roster comes from enabled narrative packs plus the Reader's custom Cast,
rather than just the original 23 authored haunts. An unfamiliar character gets
a Chapter-based routine; an unknown Chapter gets the guest rooms at night.
Scenes use this same roster, including kept Page metadata and borrowed rooms.
Monthly staging still outranks recent scenes, which outrank the timetable and
ordinary routines. Sleeping people keep their name and still feet on the map;
Penny, Wicker, Damien and Thorne retain their explicit night whereabouts. Invalid
or closed story addresses fall back to the person's day rather than dropping
them into an unseen room. The Rain Room's walls remain visible; the actual sky
opens or shuts its door.

Every name has its own footprint pair and ribbon. The three-person drawing cap
and its `+N` marker are gone. Crowded rooms put names beside the feet in closer
rows. **Find a name** lists full names and current addresses, marks walkers as
on the way to their destination, centres their current footsteps (including
other floors), and highlights the selected ribbon. Floor counts include
people passing through. The viewer observes room changes between minute ticks
as well as reconstructing recent timetable, routine, and story departures. A
view-local cache reuses the passage survey while the Reader pans or zooms. Reduce
Motion keeps the feet still and the name-finding camera jump immediate.

Borrowed rooms keep their authored position when it fits. When the surveyed
campus now occupies that paper, the chart finds clear paper nearest its joining rooms,
preserving room IDs and passages. The Ballroom grows off the Great Hall; the
Wrong Castle can lean between the East Stacks and the Quillquarium. The survey reserves all three moving-shelf
positions and resolves borrowed rooms before the drawing and footprints use
coordinates. The Reader's existing Anchor extension remains separate from this
Cast graph and continues to unfold north.

Validation for this source iteration: Swift syntax parsing and `git diff
--check` passed. A separate source geometry check exercised 36 combinations of
unbound/all five bound Chapters, three shelf positions, and October's borrowed
rooms: no room intersections, route fallbacks, or routes through unrelated
room walls. A standalone drawing study was inspected; it is not a native app
screenshot. The rescaled Anchor extension was also checked through 201 doors
and five viewport sizes, retaining bounded 512-point drawing strips. Regression coverage was updated and expanded for complete hourly
roster coverage across a week, residential connections, private home Binding,
custom characters and Page metadata, bedtime, closures, and borrowed-room
placement. These updated tests have not run. No app build or Rabbit install was
performed for this iteration; Rabbit still has the preceding Anchor build.


Rabbit deployment attempt for the inhabited campus, 2026-10-08: all 84 updated
`AcademyGeographyTests` passed. The complete current workspace built with the
Debug `InsideCoverApp` scheme for `generic/platform=iOS`; its signed app bundle,
Share extension and Widget extension were checked. The workspace snapshot
reported no files changed during the build. Both CoreDevice and Xcode's device
inventory reported Rabbit unavailable. The installation attempt failed with
CoreDevice error 1011 because it could not locate Rabbit. The completed bundle
is ready at `/private/tmp/ReEnchanted-Rabbit-Campus-20261008/Build/Products/Debug-iphoneos/InsideCoverApp.app`.
Rabbit reconnected on the subsequent retry at 21:11 UTC. The completed signed
bundle installed successfully and launched successfully through CoreDevice,
without rebuilding. Installation and launch are confirmed; on-device visual
review of the map remains pending.

Illustrated atlas iteration, 2026-10-09: bj asked for image-generated parchment
and multiple levels. Four original plates now underlie live room labels,
Cast ribbons, footprints, closures and navigation: the Undercroft, School &
Gardens, Upper Rooms, and Tower & Stacks. `AcademyIllustratedAtlas` surveys
39 permanent floors onto those plates while preserving room IDs and the
existing story/timetable/scene graph. Level tabs show counts; finding a Cast
member changes leaves, and room/stair links cross between them. The private
My Dorm follows the Reader's bound Chapter. Reader Anchor doors remain on
the growing Stacks extension; borrowed rooms unfold onto paper below their
entrance leaf. Daily shelf drift and timed cross-level footsteps remain live.
The artwork, full prompts, paths and verification limits are recorded in
`docs/academy-atlas-art.md`. Source parsing, asset references, whitespace and
18 home/shelf geometry variants passed; browser registration review is a
drawing study. Nine added regression tests have not run. This iteration has
not been built or installed on Rabbit.
