# The Student's Handbook & Workbook — the moonshot plan

Written 2026-10-01. bj's decisions (2026-10-01):

1. The frame is **a student's handbook and workbook**, a story field journal.
2. **The ruin loop**: readers deface the book, photograph it, and the app and the next volume answer.
3. **A la carte editions let the reader choose thickness. The subscription has a fixed page limit.**
4. **The weekly becomes a 32-page magazine.**
5. **The daily section carries everything the reader kept**: photographs, illuminated photographs,
   enchantments, Cast notes and letters, generated stories, classes and clubs.

Builds on [field-book-plan.md](field-book-plan.md) (built; status block at its head) and
[print-value-audit-2026-09-30.md](print-value-audit-2026-09-30.md). Honest state today: the Field
Book renders and tests green, but a light synthetic reader gets 60 monthly pages and a 12-page weekly,
the art is repetitive, and none of it has been on paper. This plan is how it gets from "good
foundation" to something a stranger would pay $60 for and photograph.

## Status (2026-10-01)

**Decided:** the default Proctor is **Thorne**; a **Resit creates its errand automatically**; Slim is
priced differently (cost plus about $25 instead of the $49.99 floor, so it reads as the small
entry); personal titles and renaming, the ruin loop on by default.

**Phase 1 built** (typed daily section; heavy-reader fixture):

- `BoundDay.keeps`: letters, Cast notes, enchantments, generated stories, classes, clubs, illuminated
  plates, library lines and quotations, each drawn as itself (a letter set as a letter with the writer's
  signature; a class as a timetable card with room and professor; an enchantment as a framed card with
  its plate; a story with a chapter head and drop cap; a Cast note as a taped slip in their ink).
  Small kinds on a day with no night and no photograph gather on "between the nights" leaves.
- **Typed keeps come from the whole month**, not the curator's sample: a short Cast note under the
  curator's threshold used to be set aside and never bound.
- **Authored content in the days**: a scene the reader opened prints as read; a scene only reported prints
  as "The Academy's record", third person, never as something they did; the dial prints what it played,
  frozen when it played (radio and report receipts now carry their text).
- Heavy-reader fixture: 26 nights and every kind of keep. Result: **88 pages** (cap 128), 31 days.

**What the heavy render says:** an engaged October is 88 pages, below the Standard target of 96, so the
reader's own material alone does not fill the book. That confirms the plan: phase 2 (field guide
selected by the reader's motifs, Cast dossiers, the Bleed broadsheet, the radio programme, the weekly
Issue) is needed even for engaged readers. A heavy reader's thin spots are days with one small
keep and a botanical, which the Field Guide layer should fill.

## The frame: a term at the Academy

A book is not a record of what you kept. It is **the handbook you were issued, with your term written
in it.** The Academy already exists in the app (a timetable of sessions, rooms, a Cast, clubs
referred to on the radio, a Labyrinth map), so the frame costs no invented world.

| Edition | Is | Shape |
|---|---|---|
| Weekly | A week of term | A 32-page magazine: the Issue |
| Monthly | A term's month | The handbook: orientation, the days, coursework, field guide, correspondence, ruins |
| Seasonal | A term | The handbook plus the Examination and the Report Card |
| Annual | The year | The yearbook: the term books bound, the Cast signing, the Ledger of Nights, graduation |

Every book is built from five layers. The first three exist whether or not the reader wrote a word;
that is how a light user's book is full.

| Layer | What | Source today | Same for everyone? |
|---|---|---|---|
| A. Authored, monthly | The month's story as read, the Bleed, the radio, props, maze and map | Monthly issue pack (~16k words in October) | Yes |
| B. Evergreen field guide | Creatures, lore, enchantments, recipes, club charters, class problem sets, ruin prompts | `BookReferenceLibrary.json` (48 compass, 90 lore, 83 character plates), `CreatureLore`, 14 enchantment spells, the feast calendar, the Academy timetable | Library is shared; **selection is personal** |
| C. Generated | Puzzles from the reader's own words; letters; annotations; examination | Deterministic engines first, Gemma for short prose | No |
| D. The reader's own | Braids, photographs, illuminated photographs, enchantments, classes, clubs, Cast notes, letters, generated stories | The archive | No |
| E. Ruins | What the reader did to the last volume | New (the loop below) | No |

**Selection is the trick.** A reader who kept "door" five times gets the door creature, the Vault of
Doors lore, a door enchantment and a door puzzle. One library fills many different books, and the
evergreen layer reads as personal.

## The daily section (the spine)

Today a day is a world side, a braid, one photo, specimens and a slip of words, and every other kept
page is flattened into a title in a list. That is the biggest waste. **Every kept page type gets its
own proper treatment on its day**, in date order, flowing from the same cursor. The model grows
`BoundDay.keeps: [DayKeep]`, a typed list, replacing `specimens`/`words` as the default carrier.

| Kept thing | Page type(s) | On the page |
|---|---|---|
| Photograph | pages with media | Pressed photo, corner mounts, the time, the sky. Several get a small contact strip |
| Illuminated photograph | `illuminatedPhoto` | A full or half plate with its gold frame; the caption from the reader's own words |
| Enchantment | `enchantment`, `spell` | The enchantment card: its name, what they looked at, what it said back, the plate |
| Letter | `letter` | Set as a letter: paper, hand, the writer's ink, the seal |
| Cast note / gossip / bond | `gossip`, `castBond`, `bookAside`, `bookNotices` | A taped slip signed in the speaker's own ink and glyph |
| Generated story | `narrativeOS`, `taleBound` | A story leaf with a chapter head and the day's spot art; a Tale that closed gets its Once / Then / In the end plate |
| Class | `academyClass`, `elective` | A timetable card (session, room, professor), what the reader did, and the problem set from Layer B |
| Club | `supportGuild`, club pages | The club's charter card and the minute of that day's meeting |
| Braid | `bookOfYou` | As now, with the Cast lines of that day beside it |
| Small logs | souvenirs, weather, mood, anchors | Gathered on "between the nights" leaves, as now |
| Health | `body`, `fuel`, `rest` | **Stay out** unless the reader opened that drawer for binding (already enforced) |

Rule: a day's page budget is spent in this order: the reader's own pages first, then the world side,
then Layer B items that touch that day's motifs. Nothing is added to a day to make it longer.

## Page budgets

Reader's choice on à la carte editions. The price is cost plus a $35 contribution (weekly $15), never
below the floor, so thicker books cost more and the margin holds. Landed figures use $6.88 postage plus
an assumed $0.75 per 50 pages over 112 (unquoted) and Stripe.

| Monthly softcover | Pages | Landed | $/page |
|---|---|---|---|
| **Slim** | 64 | $58.82 | $0.92 |
| **Standard** | 96 | $59.15 | $0.62 |
| **Full** | 128 | $63.97 | $0.50 |
| **Grand** | 160 | $69.04 | $0.43 |
| **Tome** | 192 | $74.11 | $0.39 |

| Weekly saddle | Pages | Landed | $/page |
|---|---|---|---|
| Brief | 24 | $30.13 | $1.26 |
| **The Issue (default)** | **32** | **$31.28** | **$0.98** |
| Long | 40 | $32.42 | $0.81 |
| Double | 48 | $33.56 | $0.70 |

Seasonal 128 / **176** / 224 / 288 ($0.62 → $0.31); annual hardcover 192 / **256** / 320 / 384
($0.58 → $0.31).

**The subscription has a fixed limit**: three 176-page seasonals and a 256-page annual. Cost about
$162, net about $77 on $249 and $123 on $24.99 a month. A member may upgrade one volume to Grand at
cost plus $35. Because the subscription can never grow, **the editor trims layers B and C first and
the reader's own pages last** whenever a month overflows its budget.

### The monthly handbook, as a budget (Standard to Full, 96–128 pages)

| Part | What | Light | Engaged |
|---|---|---|---|
| Front | Flyleaf and Reader's Mark; the Book's handbook letter; term calendar and almanac; **How to ruin this book**; endpaper maps | 10 | 10 |
| I. The Days | The typed daily section above | 20 | 50–70 |
| II. Coursework | Classes taken (card plus problem set); club pages; 8 puzzle and worksheet leaves; an Examination on the reader's own month and its marked key; a one-page Report Card from the Cast | 24 | 20 |
| III. Field Guide | Personalised creatures, lore, enchantments, recipes; Cast dossiers; the month's recurring words as specimens; correspondences | 20 | 16 |
| IV. Correspondence | Cast letters; the Bleed as a broadsheet; the radio programme; the pack's found objects | 12 | 12 |
| V. Ruins | Last volume's ruined pages as plates; two sealed pages; six pages built to be defaced | 10 | 10 |
| Back | Index; colophon; the Cast's signature page | 4 | 4 |
| | **Total** | **~100** | **~125 and over** |

Engaged readers overflow, which the editor handles. Light readers reach about 100 with no padding,
**provided layers A and B are authored deeply enough**. That authoring is the real bottleneck.

### The weekly Issue (32 pages)

Masthead and the week, bound (2) · the Bleed front page (2) · the week's days, typed (8–12) · the class
and the club of the week (2) · the puzzle spread (2) · an enchantment or recipe (2) · a Cast profile
(2) · the radio guide (1) · letters (1) · tear-out worksheets (2) · ruin pages (2) · closing and
colophon (1) · notes (up to 2, never more).

## The workbook: puzzles, classes, the Examination

Deterministic first. A puzzle built from the reader's own kept words is exact and cannot be wrong;
Gemma only dresses it.

- **Families to build**: maze (a generator exists in the Count pack tooling), word ladder, blackout
  poem cut from the reader's own braids (a play form exists), acrostic from their name and motifs,
  cryptogram in a Cast member's voice, spot-the-difference between two of their own photographs,
  "complete the sentence" from their own openings, a crossword from their month's vocabulary.
- **Classes**: each session of the Academy timetable gets a problem set (six per session, 12 sessions,
  72 sets) and the reader's attendance makes it appear.
- **The Examination** (seasonal, and a short one monthly): questions about the reader's own term, with
  a key marked by the Cast, **kindly**. The Rut is the villain; the reader is never the failing party.
- **The Report Card**: Cast comments on the reader. The Cast are fictional, so the Witness Law holds.
  Real people never speak.

## The ruin loop

The Book is a character who invites being handled. Print on demand rules out die-cuts, perforations,
inserts and special papers, so interactivity is **pens, scissors, tape, folds, tea and thumbs**, plus a
loop back into the app.

1. **Every page is addressable.** A small printed mark in the outer margin: `p.41 · 7K3-Q`, set in the
   book's own hand. Apple Vision text recognition reads it; a pick-the-page picker is the fallback.
2. **The app knows the volume.** Binding records a volume registry in the vault: edition, order,
   page map (which page is a day, a worksheet, a ruin page, a sealed page).
3. **Return the ruins.** Camera, find the mark, rectify, keep as a Page (`ruin`, tied to its volume and
   page). The Vision pipeline describes it (coloured, torn, written on, stained, taped shut), and the
   Book answers in its voice. It counts toward that night's braid ("you tore out page 41").
4. **The next volume prints the ruins** as pressed plates with the Book's remark. The books evolve.
5. **Sealed pages.** A pair marked "tape these shut; open on the 1st". The content is the Book's
   sealed wagers (the sealing machinery exists) and a note from the reader to themselves. On the date the
   app asks for the opened page back and resolves the wager.
6. **Six to ten pages a book are built to be defaced**, from a library of about 40 ruin prompts:
   scribble the grey over your worst week, tear this out and give it away, a tea ring to turn into a
   map, a rubbing, a pressed leaf, trace your hand, a letter to be taped shut.

**Guards.** No fire, no liquids that damage the binding, nothing for children. The reader's PDF is
always kept in the app, and a clean second copy is an ordinary à la carte order. Ruin photographs
are the reader's: a photograph is bound into the next volume only when they say so, and nothing
leaves the phone except the finished PDF at checkout. **The unknown that can sink this**: which pens
and markers bleed through a 60# uncoated page (the books moved off coated on 2026-10-11 so pencil and
ink take). A physical proof answers that before any ruin prompt ships.

## Gemma's job

Foreground only: iOS gives no GPU in the background and MLX aborts, so no scheduled generation.
Generate **at keep time** (as margin replies already are) and store the result with the page, so that
binding is assembly rather than a long wait.

- A margin gloss on a kept page (30 words); a "what you learned" line on a class; a specimen note.
- Cast letters (about 120 words, four a month) written at binding from the month's plan, the way the
  braid is: a skeleton of kept details, a few plain rules, then Gemma writes.
- Everything passes the existing contracts (the Book's voice spec, the character lint, the Witness Law,
  the forbidden claims) and has a deterministic fallback. **Phone latency for this volume of
  annotations is not measured.**

## What has to be written (the real cost)

| Corpus | Target |
|---|---|
| Creature and lore entries (extends `CreatureLore`, `enchantifyLore`) | ~150 |
| Enchantment cards and recipes | ~60 |
| Class problem sets | 72 |
| Club charters and meeting minutes | ~15 |
| Letter templates and Cast voices | ~60 |
| Puzzle frames (per Cast voice) | ~30 |
| Examination banks and Report Card lines | ~100 |
| Ruin and sealed-page prompts | ~60 |

Drafted by the agents through the Wire, checked by `scripts/voice-lint.mjs`, signed off by bj. One
authored corpus serves every edition for years.

## Build order, and what proves each step

| Phase | Build | Proves |
|---|---|---|
| 1 | The typed daily section (letters, classes, clubs, enchantments, generated stories, Cast notes, illuminated photographs, photographs). A **heavy-reader fixture**. A content-mix lint (no section over a share, no repeated art) | Engaged months render near 110–130 pages and look varied |
| 2 | The weekly Issue (32). The field-guide selector; Cast dossiers; the Bleed broadsheet; the radio guide | A light reader reaches ~96 with no padding |
| 3 | The puzzle engine; class problem sets; the Examination and Report Card | A book you can write in |
| 4 | The ruin loop: page marks, registry, capture, ruins plates, sealed pages | The loop closes end to end on a device |
| 5 | Gemma keep-time annotations and letters; measure latency | Cost in seconds per page |
| 6 | The thickness chooser, Worker tiers, subscription budget, pricing; **a physical proof** | The object |

A phase is done when the proof harness renders it with no sparse-page lint hits, the unit tests pass, and
(from phase 4) a physical proof copy exists. The quality bar for the whole programme:

1. A light reader's Standard monthly is at least 96 pages with no padding.
2. At least a third of any book is the reader's own, a third authored or evergreen, and a tenth
   something to do with a pen.
3. No two consecutive pages use the same art; every spread holds something the reader could not
   have predicted.
4. Landed price per page at Standard is at most $0.65, and at Grand at most $0.45.
5. A physical proof passes a reaction test with three readers who have played a month.

## Decided 2026-10-01 (second round)

- **Titles are the reader's to name.** Otherwise a book takes its title from the month's content pack,
  made personal with the reader's own role and the month's motif theme. Whatever is chosen prints
  with the reason beside it, as `SeasonTitler` already does.
- **The ruin loop is on by default.**
- **A Slim tier exists.**
- **The Examination can mark the reader down.** The Report Card grades how well the reader is turning
  their life into a modern faerie tale: aliveness and attention. *Pending bj's answer to the standing
  decision that aliveness and the Rut are internal-only; see "The Report Card" below.*
- **Authored content lives in the daily section**, not in a section of its own: everything that
  happened, day by day.

### The authored content, day by day

The world's side of a day prints, in order of preference: the scene the reader **read** (their text, their
choice); the scene's public **report** if they did not (the pack's `report` field, true only after that
live day has ended, in the third person); that day's Bleed and radio lines; the Academy's timetable and who
was where; the feast and the sky; and what the Book left on the desk. An unread scene is never
described as something the reader did.

### The Report Card: reconsidered

bj's challenge (2026-10-01): the "aliveness and the Rut are internal-only" rule is months old
(`docs/permanent-twin-plan.md`, 2026-08-03) and predates the doctrine that faerie has teeth
(2026-08-31, "the fae answer is *consequence for an ignored errand*"). Re-read on its merits:

**What the old rule protected.** (1) The aliveness pulse is reader-answered; show it as a score and
readers answer to protect the number. (2) The Rut "makes story, not shame"; a visible number is a shame
gauge. (3) Silence is never Rut evidence; absence cannot be concluded from. (4) Inferred signals may
inform curation but not score it ("do not score yourself with the signal you optimise"). (5) Grief is not
Rut; app engagement is not aliveness.

**What survives.** (1), (2) and (3) are real, but they are about **the pulse, the Rut as a number, and
absence**, not about grading what the reader does. (4) and (5) survive as design rules for the rubric.
None of them is a reason not to print marks for the practice itself, which is the consequence
mechanism the teeth doctrine asked for.

**The card:**

- **Subjects, graded on receipts, not on inference.** They are the twin plan's own aliveness evidence,
  renamed for the Academy: *Noticing* (concreteness of what was kept: a smell, a sound, a texture,
  against "nice day"), *Initiative* (pages kept unprompted), *Fieldwork* (new places, new subjects),
  *Curiosity* (questions asked), *Deeds* (lived receipts: errands done with evidence, doors opened,
  enchantments cast), and *Spreading* (wonder given away: gifts, public margins, the pages torn out
  and handed on, the people missions).
- **Marks.** Distinction / Merit / Pass / **Resit** / Incomplete. A Resit is not a failure state; it
  comes with a task, an errand for next term. Marks mean something because they can be low.
- **Marks are on what the reader turned in, never on what they did not.** Absence is *Incomplete*, with
  no penalty and no conclusion. A grief-heavy page that is specific scores high; mood is never graded.
- **Marks carry their receipts** ("Noticing: Merit. Eleven of fourteen kept details had a sense in
  them; these three did not") and can be **contested before the Headmistress**, which is the existing
  correction affordance. A wrong grade is then a claim with a falsifier, which is cheap and self-correcting.
- **The reader chooses their Proctor.** Penny (facts), Thorne (secretly Unseelie, and exacting),
  Permancer (the rules), Ambrose (the ordinary), Wicker (provocation). The default is honest; the reader
  may soften the register, which is their choice and not the house default.
- **Distress.** The existing distress gate stands down the card: "On leave. The Academy has kept your
  place." That is the one place reader protection lives, as elsewhere.
- **One-way valve.** Marks narrate; they never feed curation. The Book's efficacy keeps being measured
  by reader-answered pulses, which are never printed and never graded.
- **Not printed on gift copies.**

## Open for bj

- Report Card: the default Proctor, and whether a Resit task is automatic.
- Cover direction.
- Slim's price (the floor makes it nearly the price of Standard; see below).
