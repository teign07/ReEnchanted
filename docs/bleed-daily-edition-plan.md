# The Bleed: the daily edition

Plan, 16 October 2026. Builds on Codex's newsroom work (`docs/bleed-newsroom-rethink.md`,
uncommitted) and turns its editorial centre around.

## The idea

The Weekly Tale tells the Reader's week. The monthly, the seasonal Term and the
annual Yearbook tell longer stretches. **The Bleed is the smallest edition: one day,
printed twice.** The editions bind days. The Bleed is where each day first goes to
press.

What makes it magic: **an enchanted school's newspaper reports your ordinary day
as news.** You found a moth asleep in a lampshade, and the next morning that's the
front page of the Academy's paper. Penny Blackletter attests to it. Wicker writes
a letter to the editor about it. The Academy's own news runs beside it, as if
your life and theirs happen in the same town. That's the feeling we want: your
life is becoming a modern faerie tale, and the other world is paying attention.

The paper also makes a claim on you. Every morning it sends you out on an
assignment as its correspondent. Every evening it prints what you brought back.
That's the aliveness half: the paper doesn't just notice your day, it changes it.

## The daily loop

```
 MORNING EDITION            YOUR DAY              EVENING EDITION          NIGHT
 yesterday, attested   →   you go out on   →    today so far,       →   the Book of You
 the Academy overnight     the assignment       your dispatch,          braids the day
 today ahead               keep pages           the Academy today            │
 your assignment           write in the         answers, tomorrow            │
 a puzzle                  paper's margin       stop press: the braid ───────┘
        ▲                                                                    │
        └──────────── next morning's front page: yesterday, finished ────────┘
```

- **Morning closes yesterday and opens today.**
- **Evening gathers today and hands it to the braid.**
- The braid closes the day. The next morning's front page prints it as news.
- Seven mornings' front-page headlines are the Weekly Tale's chapter titles. The
  Reader sees "In which you found a moth asleep in the lampshade" first in the
  paper, then again, bound, at the end of the week. Same function, same words.

## The three questions, decided

**1. Does the morning paper deliver last night's braid?** It reports it; it doesn't
reprint it. The front page is yesterday as news:
- the chapter heading as the headline;
- Penny's short attested report;
- one of the Reader's own lines, set in their hand;
- their photo as a halftone plate;
- the braid's kept line ("The Book kept the page: …").

When the braid is still unread, the front page ends "The whole story is in the
Book of You" and opens it. The braid stays the place you read your story. The
paper becomes the place you discover your day was news.

**2. What does the printed paper look like?** A newspaper from another world,
not plain office paper and not the Field Book. Keep Codex's typesetting engine:
Core Text columns, overflow onto a second sheet, real links, Unicode. Put the
magic back on top of it:
- the existing `TheBleedBanner` masthead art;
- a light, print-safe newsprint tone with the foxing specks the editions use
  (never alpha gradients: PDF drops them);
- the Reader's photo of the day as a halftone plate;
- morning and evening each with their own ink colour and edition line.

The in-app paper (the pocket leaf) gets the same treatment first, because that's
where most people read it.

**3. Keep the "For Penny:" letters?** No magic prefix. Write in the margin of
the paper and that's your letter to the editor. The Bleed's margin ask changes
from "What caught your eye" to **Letters to the Editor**, and tomorrow's paper
prints it with Penny's reply. The trigger lives on the paper itself (the
book-object law). Consent stays exactly as strict as Codex made it: only words
written in the paper's own margin become letters. Diary pages never do.

## What each edition carries

Sections appear only when they have something real. A paper is never padded.
The front page and the Academy are always there, so there is always a paper.

### Morning edition: "The day you had, the day you'll have"

| Section | What it is | Source |
| --- | --- | --- |
| **Front page** | Yesterday, attested. Headline = the day's chapter heading. Penny's report, the Reader's line in hand, halftone plate, the braid's kept line. | `BoundDayBook.make` for yesterday; `WeeklyTaleBuilder.headings`; braid via `WeeklyTaleBuilder.split` |
| **Returning** | "I remember *gate* from Tuesday's page. Here it is again." A literal word that came back, with both dates. This replaces Codex's 60-day "Two lines, side by side". | `WeeklyTaleReading.returns` over the last 14 days |
| **Letters to the Editor** | The Reader's letter from yesterday's margin with Penny's reply. Plus one or two Cast letters reacting to the front page. | Kept `.theBleed` margin; Cast voices weighted by belief (the KeepMarginalia pool) |
| **The Academy overnight** | The monthly pulse, word for word. Scene follow-ups that actually changed. Corridor Whispers (gossip) brought back. | `SceneWorldCanon.dailyPulse`; Codex's `academyBriefs` and print records; `CastStoryGossip` |
| **Today** | The sky in a line; today at the Academy (this month's lesson in a room, any feast or moon); your appointments. | `PaperSkyOutlook`; `AcademyCurriculum`; the Almanac; calendar strip (Codex's fixed fetch) |
| **Your assignment** | The paper sends you out as its correspondent. One real dare, mission or spell, put on the desk today. | `WickerDareRegistry` and the playful missions and spells, under their existing rests |
| **The puzzle** | Made from your own words: your week's nouns, scrambled; a cloze from a line you kept. Answer tonight. | `HandbookPuzzles` (anagrams, cloze, odd-one-out) seeded from this week's `BoundDay`s; Codex's ten literary pairs as fallback |
| **Classifieds** | Academy small ads, placed by the Cast. | Monthly pack (see "Content supply") |

### Evening edition: "Late final"

| Section | What it is | Source |
| --- | --- | --- |
| **Lead** | Your dispatch when you filed one ("OUR CORRESPONDENT RETURNS: PIGEON WINS"); otherwise today so far, attested. | The assignment's lived receipt; `BoundDayBook.make` for today |
| **Today, so far** | What you kept: your lines in hand, the photo as a plate, any Cast note or letter that came. | Today's `BoundDay` |
| **The Academy today** | Only what changed since the morning paper (Codex's revision records). | `academyBriefs` with history |
| **Answers** | The morning puzzle's answer, and the classified's reply. | Paired at press time |
| **Tomorrow, posted early** | Tomorrow's sky, appointments, and Academy day. | As in the morning's "Today" |
| **Stop press** | The braid's appointment: "The Book of You goes to press tonight. So far it has caught the pigeon and the blue plank." | `BraidEmber.evening` line; the ember yields when the paper carried it |

**A day with nothing kept.** The evening lead is "OUR CORRESPONDENT HAS NOT FILED.
Penny is holding the column till the last post." That's anticipation, not
reproach, and the Academy fills the rest of the paper. The next morning, a quiet
yesterday makes a short front page, and the Academy takes the top.

**A hard day** (`DistressSignals`): no assignment, no jokes about the Reader's
lines, no Cast letters about them. The Academy, the sky and a quiet front page
that only attests. This is Codex's restraint rule, kept.

**On the weekly drop day**, the morning paper runs "THIS WEEK'S TALE IS BOUND" and
lists the week's seven headlines. On the monthly pack's recap days (10, 17, 24,
29), the Academy section is the recap.

## Specimens

Synthetic Reader ink, written to set the voice. These aren't app output.
Academy lines marked † are real shipping copy. Everything else shows the shape
and needs real authorship.

**Morning, Friday 16 October · Issue #212**

> **IN WHICH YOU FOUND A MOTH ASLEEP IN THE LAMPSHADE**
> *Attested by P. Blackletter, Department of Attestation*
>
> Yesterday evening the Reader found a moth asleep inside a lampshade and left the
> lamp off so it could finish. The moth has not given a statement. Attested.
>
> *In the Reader's hand:* Found a moth asleep inside the lampshade. Left the lamp
> off so it could finish.
>
> [halftone: the lampshade] · The whole story is in the Book of You.

> **LETTERS**
> Madam, a moth in a lampshade is a lodger. Charge it rent. *W. Eddies, the Gate*

> **THE ACADEMY OVERNIGHT**
> Every coat in the Great Hall is wet on one side only, the side that faces the
> East Stacks.†

> **YOUR ASSIGNMENT**
> The Bleed is sending you out. Lose a staring contest to a pigeon.† It's on your
> desk. The evening paper holds the column for your dispatch.

> **THE PUZZLE** · Three words from your week, scrambled: HTOM · KLNPA · TAGE.
> Answers tonight.

**Evening, same day · Late final**

> **OUR CORRESPONDENT RETURNS: PIGEON WINS**
> The Reader went out on this paper's assignment and lost a staring contest to a
> pigeon. *In the Reader's hand:* It won. It knew it won.

> **ANSWERS** · MOTH · PLANK · GATE.

> **STOP PRESS** · The Book of You goes to press tonight. So far it has caught
> the pigeon.

## Laws for the paper

These carry forward from existing doctrine. They're listed so nobody has to
rediscover them.

- **Penny attests; she doesn't interpret.** Her report retells what the Reader
  kept, in the third person and the past tense. Jokes about the world are fine
  ("The moth has not given a statement"). Claims about the Reader's feelings,
  growth or meaning are not (the no-verdicts law). Every noun in the report must
  come from the day's sources; Codex's source-support review enforces it.
- **The Reader's words are locked.** The compositor inserts them byte for byte.
  The model never touches them (Codex's rule, kept).
- **The Reader is never put inside the Academy.** The Academy reads about you.
  You don't walk its halls in the paper.
- **The Cast react to the news like readers of a paper.** They write in from
  their own corners, in their own canon voices. They never claim to have been
  there.
- **The voices.** Penny writes in her own canon voice: plain, dry newsprint.
  Anywhere the Book speaks, it's the Book's voice: simple, direct, an independent
  child. Never "X, not Y", never hinge talk, never naming the machinery.
- **Claims are welcome.** The assignment is the paper's spine, not garnish. It
  rests only under the dare and mission registries' existing rests, never under
  an extra Bleed ration.
- **There's always a paper.** It is never rationed away and never empty.

## From Codex's work

**Keep (the plumbing):**
- `BleedPrintRecord`, history and revisions: no unchanged reprints.
- `BleedIssueCurator`: selection before prose. Add a protected `.day` desk.
- Locked Reader quotes and the compositor that inserts them.
- `BleedCopyDesk`: its stock-phrase lint and source-support review.
- `SceneWorldCanon.dailyPulse`, shared with the braid.
- The calendar fixes (whole-day fetch, all-day and overnight events, DST,
  denied access).
- The Core Text PDF engine and `BleedReadingCopy` parser.
- The structured pocket reading with Dynamic Type.

**Change:**
- **The Reader desk.** Its three 60-day forms give way to the front page and
  "Returning" (today's word that came back).
- **The outside interest column.** It stays opt-in, but moves to the back page,
  evening only, at most one item. It never leads. It isn't the Reader's day.
- **The PDF look.** Newsprint, masthead, halftone (see question 2).
- **The margin ask.** It becomes Letters to the Editor; the "For Penny:" prefix
  goes.
- **Puzzles.** Generated from the Reader's own words first; Codex's ten pairs
  are the fallback.
- **The header comment.** "The week, not the daily paper, tells the reader's
  larger story" goes.

**Cut:**
- The generic small ads and very short fictions as the main pleasures.
  Classifieds come from the Cast and the monthly pack instead. Delete "a question
  with working hinges" now, wherever it ends up.
- The hardcoded trigger list for "Read it another way" (door, gate, key…).
- The dead `frontPagePacket` and `whispersPacket`, once the new front page and
  Corridor Whispers replace them.

## Architecture

No new files, so no pbxproj edits. Everything goes in `Shared/TheBleed.swift`,
plus the press run in `InsideCoverApp/ContentViewFeatures.swift` and the reading
view in `InsideCoverApp/CapturePageSheet.swift`.

**`BleedDayDesk`** turns one `BoundDay` into front-page material:
- yesterday for the morning, today so far for the evening;
- built with `BoundDayBook.make(pages:…, startDate: dayStart, endDate: dayEnd)`;
- gives the headline candidates (`WeeklyTaleBuilder.headings`), entries (locked),
  photo plates, the braid opening and kept line, scenes read, Cast lines,
  keeps, and the Reader's role when named.

**New briefs in `BleedNewsroom.candidatePool`:**
- `front-page` (desk `.day`, protected, always first);
- `returning`, `letters`, `academy-today`, `whispers`;
- `assignment` (morning) and `dispatch` (evening);
- `own-words-puzzle`, `classified`, `stop-press`.

**The order is fixed, like a real paper:** front page → letters → Academy →
today / tomorrow → assignment → puzzle and classifieds → stop press. Practical
strips stay a compact rail.

**The assignment.** At press time, the morning paper picks one dare, mission or
spell that is eligible under its existing rest. It records the choice in the
print record (`assignmentID`) and gives that page a chair on today's desk, tagged
`bleed-assignment:<slot>`. The evening paper looks for that page's lived receipt
or written return. If it's there, the dispatch prints verbatim and takes the
lead. If not, the column is held. No new return channel: the existing dare
flow is the channel.

**Letters.** The margin text on a kept morning or evening `.theBleed` page is
the Reader's letter (`userInput` already holds it). The next paper prints it
with Penny's reply. Cast letters come from the KeepMarginalia voice pool,
weighted by `effectiveCastBelief`. A reply is either an authored line or one
short model line, checked by the existing character fidelity reviewer.

**Model budget: at most three local-brain calls per paper.**
- Penny's front-page report (60–90 words), with a deterministic floor.
- Penny's reply to a letter (one or two sentences), with an authored floor.
- One Cast letter, with an authored floor.

Everything else is deterministic or authored. Calls run only in the foreground,
when the paper is opened (Gemma has no GPU off-screen). The "Setting type…" press
theatre stays.

**The floor.** Without the model, Penny's report is the chapter heading's clause
retold, plus "Attested." For example: "Yesterday the Reader found a moth asleep
inside the lampshade. Attested." The paper never waits on the model to exist.

**Ties to the editions:**
- Morning headlines equal the Weekly Tale's chapter headings for the same day:
  same function, same seed, same day.
- `BoundDay.clippings` already carries kept Bleed pages into the editions.
- A monthly leaf, **"The Month's Front Pages"**: a newspaper collage of that
  month's morning headlines.

## Content supply

Two papers a day is about 60 a month. Authored banks run dry in a week, so most
of the paper must come from the Reader's day, the Academy's systems and
generators. The authored layer comes from the monthly pack.

- **Classifieds and Cast letter lines.** Use the existing `.bleedArticle` channel
  in the monthly pack, with new kinds `classified` and `castLetter`. About 15
  classified pairs and 30 letter stems per month, in each Cast member's voice.
  November's pack is the first to carry them.
- **Puzzles.** `HandbookPuzzles` over the Reader's own week, which never runs
  out. Codex's literary pairs are only for the first days, before there's a
  week to draw on.
- **Penny's report** is the only daily prose, and it's mostly the Reader's own
  facts retold.

## Phases

**Phase 0: land Codex's plumbing safely.**
- Build, and run `BleedNewsroomTests`, `BleedReaderAndCurationTests`,
  `BleedInterestNewsTests`, `WorldStoryContinuityTests` and `TheBleedTests` for
  the first time. Fix them.
- Commit the Bleed files on their own: the working tree holds many other
  sessions' changes.
- Delete the hinges ad.

*Done when:* the build is green, those suites pass, and there's one commit.

**Phase 1: the front page.**
- `BleedDayDesk`, the `front-page` brief, Penny's report with its floor, the
  locked line, the halftone plate in the pocket view, the braid's kept line and
  the "whole story" link.

*Done when:*
- In the year-matrix fixture (`--proof-only=matrix`), every morning headline
  equals that day's Weekly Tale chapter heading.
- No Reader line repeats across a week's papers.
- The source-support check passes on 30 synthetic days.

**Phase 2: the correspondent.**
- Assignment, then dispatch; the evening lead; the held column; the hard-day
  rule.

*Done when:* a simulated day goes from morning assignment → desk page → lived
receipt → evening lead.

**Phase 3: letters.**
- The margin ask becomes Letters to the Editor; the Reader's letter and Penny's
  reply; Cast letters.

*Done when:* yesterday's margin prints the next morning, and a diary page never
does.

**Phase 4: the Academy pages.**
- Corridor Whispers back, from `CastStoryGossip`.
- Today at the Academy, the sky line, the stop press, the weekly-drop and recap
  days.

**Phase 5: puzzles and classifieds.**
- Puzzles from your own words; the classified and castLetter kinds in the pack
  schema; November content.

**Phase 6: the print object and edition ties.**
- The newsprint PDF, "The Month's Front Pages" leaf, a device proof of both
  editions, VoiceOver and large text.

Phases 1–3 are the moonshot. 4–6 make it rich.

## How we'll know it's working

- **Reading:** both editions opened on the same day, read through, and Kept.
- **Living:** assignments that come back as dispatches (the aliveness measure).
- **Writing back:** letters written in the margin (the Reader talking to the
  world).
- **Repetition:** the weekly matrix lint finds no repeated sentences across 14
  papers.
- **The real test:** bj reads a week of his own papers on his phone and wants
  the next one.

## Unknowns

- **Opening time.** Three local calls per paper is unmeasured on an
  iPhone-15-class device. If it's slow, Penny's report moves to the floor and
  only the letter reply uses the model.
- **The Cast letters' register.** One line, funny and fae, from inside their
  own world, about your ordinary day. They need authoring care, not just a
  prompt.
- **The assignment chair.** How the curator gives the assignment a guaranteed
  desk place without disturbing other pages. bj has rejected whole-desk changes,
  so it should work like the story-beat chair.
