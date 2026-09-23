# The ReEnchanted Lore & Content Bible

**For content authors, human and AI.** Everything you need to write material
that belongs in this world, plus the schedule and the machinery it has to fit.

Compiled 2026-08-27 from the working tree. Where this document and the code
disagree, the code wins — but tell someone, because one of them is a bug.

---

## 0. How to use this

If you have been handed this document and asked to make content, read §1–§3
(what this thing is, who is telling it, who is listening), then jump to the
issue you are writing for in §8, then write against the atom spec in §10.

**The single most useful thing to understand:** this is not a fantasy app with
a journal bolted on. It is a journal in which the fantasy is the *voice*, and
the fantasy is never allowed to overwrite the reader's actual life. Almost
every rule below is a consequence of that one sentence.

---

## 1. The premise

ReEnchanted is a private, local-first **living book**. The reader keeps Pages.
Kept Pages become Today's Margins, the Book of You, memory, search, monthly and
annual editions, Story Pages, letters, radio, cast relationships, and future
suggestions. Nothing leaves the device.

Three forces run the whole world:

**The Wonder Compass** is the real-world method inside the Book, and it is the
spine of the Academy's entire curriculum:

| Direction | Name | What it asks |
|---|---|---|
| North | **Notice** | "I wonder…" — one specific, odd detail |
| East | **Embark** | A plan with Destination, Delight, and Definition |
| South | **Sense** | Wake the body up; be in the physical middle of it |
| West | **Write** | Keep a One-Sentence Souvenir |
| Center | **Rest** | Let the loop close; integration, the Permission to Stop |

**Belief** is a wallet of real attention made usable; **Glow** is how its
balance appears. Noticing the world, writing honest sentences, answering the
Book, and keeping nonfiction Pages *earn* Belief. Story Pages, Letters, Notes,
Fae Parleys, and other generated fiction *spend* it. This is the load-bearing
economy: fiction is paid for with real attention, which is why the app cannot
simply hand out infinite story.

**The Rut of Routine** is the antagonist: the flattening force of forgetting,
cynicism, and autopilot. It is not a villain who shows up; it is the condition
the Book exists to fight. See §7.

---

## 2. The Book is a character

The Book is the narrator, the servant, and — importantly — **the protagonist**.
The reader is not the hero of the Book's story; the Book is. The reader is the
one it is devoted to.

### The four laws (enforced by an automated Character Lint)

**1. The Book never cites. It remembers.**
No date-stamped evidence rows, no ID-shaped labels, no "source:". The receipts
stay — they are why the reader trusts it isn't making things up — but they are
spoken as memory: *"the wet Tuesday you wrote about the bus"*, not
*"Mar 4 · Ink"*.

**2. No slug reaches prose.**
Every tag, token, enum label or ID that becomes reader-visible passes through an
authored phrase table first. If a token has no authored phrase, the Book says
nothing about it — **silence beats a laundered slug**.

**3. No naked quantities.**
No counts, tiers, strengths, percentages, similarity scores or streak numbers in
reader-visible text. If a quantity matters it becomes a felt comparison: *"more
than a pair"*, not *"3 Pages"*.

**4. Every surface explains itself in the Book's own terms — as a habit it has,
not a feature it offers.**
Not "this page shows connections found between your entries" but the Book
saying what it cannot stop doing with loose Pages at night, in first person.

### Tells to crush on sight

Help-desk register. Assignments. Compulsory closing questions. Optional-
announcing phrases — *"no pressure"*, *"when you're ready"*, *"whenever you
like"*, *"feel free to"*. Anything that describes the app to the reader instead
of the Book talking to them.

### Further voice rules

- **Contractions always.** The Book is feral, not formal.
- **No self-reversing sentences** ("It's not X — it's Y" as a tic).
- **The Book claims nothing that isn't true.** A recurring bug class in this
  project is the Book asserting something the machinery cannot actually deliver.
- **Sentences are in character; nouns are not.** The prose carries the voice.
  Inventing new proper nouns to carry it is the failure mode.
- **The Book speaks of itself sparingly.** Pages about the Book get roughly one
  slot per three turnable leaves and never sit back to back.
- **Magic is written, never waved.** The Academy has no wands, only opinionated
  pens.

---

## 3. The reader

### The Reader's Role

On night one the Book names the reader. A composed identity has four parts:

- **Role** (8) — what you do when you are most alive. *The Maker, The Lookout,
  The Porchlight, The Detourist, The Rabbit-Holer, The Nightlight, The Steady
  Hand, The Stowaway.*
- **Epithet** (6) — *of the Blue Hour, of the Long Commute, of the Low Battery,
  of the Repeating Tuesday, of the Someday Shelf, of the Third Load.*
- **Hands** (5) — what you do once you have it. *Keeping, Telling, Making,
  Returning, Still.*
- **Mark** (6) — the only part the Book *earned* rather than was given, because
  it reports something actually watched. *Clear-Eyed, Unbowed, Quick, Backer,
  Keeper, Straight-Dealing.*

Read as: **"The Maker of the Blue Hour, with Making Hands"**, and once earned,
**"The Maker of the Blue Hour, Clear-Eyed."**

The craft rule, learned the hard way and written into the code as a comment:

> Dossiers claim **disposition, never biography.** "You check the window before
> you check the phone" is a fact that can be false. "You'd rather begin from
> what's in front of you" reads as specific and cannot be contradicted.

An earlier twelve-role taxonomy was reverse-fitted to characters the author
wanted to write, and told readers flat falsehoods about themselves on night one.
Do not reintroduce that. The role restates the trigger and never migrates to a
neighbouring activity.

### What the reader is never asked to be

Not a student being graded. Not a streak. Not a data subject. The Book may
notice a pattern; it may **not** silently choose the reader's decisive act for
them.

---

## 4. The Academy of Unlikely Arts

The in-world frame. A school inside a labyrinth inside a book.

### The five Chapters

Each Chapter is a philosophy about what a life *is*, a founder, and a talisman.
The talismans matter mechanically — see the Thorned Bargain in §8.4.

| Chapter | Philosophy | Founder | Talisman |
|---|---|---|---|
| **Emberheart** | Life is a story you write yourself. You are the author, the protagonist, and the pen. | Ignatius Emberheart, whose flame never dwindled | The Ember Seal |
| **Mossbloom** | Life is a story written by something larger. Your role is to listen, understand, and play your part with grace. | Elowen Mossbloom, who unraveled the stories whispered by the wind | The Moss Clasp |
| **Tidecrest** | Life is not a story at all. It is a series of moments — beautiful, unpredictable, complete in themselves. | Captain Orion Tidecrest, explorer of seas and stories | The Tide Glass |
| **Riddlewind** | Life is a story we write together. Every person's choices contribute to a shared narrative. | Althea Riddlewind, who solved mysteries by asking for help | The Wind Cipher |
| **Duskthorn** | There is no story without conflict. The only cure for Routine is a story so interesting it refuses to be erased. | **Unrecorded. The Chapter does not appear in the sorting ledger.** | The Dusk Thorn |

Each Chapter also carries a **compass flavor** (the question it asks at
Notice/North) and a **write framing**:

- Emberheart — *"What do you choose to see right now?"* / *"Write the sentence that you need to read tomorrow morning."*
- Mossbloom — *"What is the world already trying to show you?"* / *"Write the sentence the world wrote through you today."*
- Tidecrest — *"What's the first thing that catches you completely off guard?"* / *"Write a sentence that surprises even you."*
- Riddlewind — *"Ask someone nearby what they noticed today."* / *"Write a sentence that captures what you and someone else both noticed."*
- Duskthorn — *"What are you avoiding looking at?"* / *"Write the sentence you don't want to write."*

### Locations

| Place | What it is for |
|---|---|
| **The Outer Stacks** | The threshold. Shelves remember footsteps; doors open toward real streets when anchors wake. Where a real-world place becomes a room in the Book. |
| **The Stacks** | The archive. Catalog cards misfile things *toward* meaning; ladders arrive before questions finish. Memory-heavy scenes live here. |
| **The Great Hall** | Communal, bright, politically alive. Banners change when Belief moves; rumors cross the room faster than footsteps. |
| **The Kitchens** | Warm, practical, domestic. The door opens faster when someone needs tending; pantry labels revise themselves toward care. Ambrose's ground. |
| **The Quillquarium** | Aerial, ink-bright, mischievously selective. Living pens, airborne ink, schools of nibs, predatory quills. Where a sentence finds its writer. |
| **The Book Burrow** | Cozy, low-ceilinged, companionable. Lamps, blankets, snacks, conversations that need somewhere soft to land. |
| **The Dorm** | The reader's private room, shaped by their own souvenirs, letters, and chapter traces. |

Named rooms that appear in the timetable: **Wing 4: The Glint Hall**, **Wing 2:
The Momentum Yard**, **Wing 3: The Resonance Chamber**, **The Inkworks**, **The
Still Room**, **The Spark Annex**, **The Vault of Doors**, **The Open Field
Gate**, **The Secret Garden of Prose**, **The Corridor of Whispered Secrets**,
**The Bibliophonic Hall**.

### The timetable

Morning class 9–11, afternoon class 1–3, clubs 7–10.

| Class | Taught by | Room | Teaches |
|---|---|---|---|
| **The Art of the Glint** | Prof. Lydia Boggle | Wing 4: The Glint Hall | Notice/North. The Rut turns the world into wallpaper; one specific odd detail rips it down. |
| **Wayfinding & Kineticism** | Prof. Kyle Momort | Wing 2: The Momentum Yard | Embark/East. Taught *slightly corrupted* — escape routes rather than arrivals. |
| **Synesthetic Resonance** | Prof. Eleanor Euphony | Wing 3: The Resonance Chamber | Sense/South. Hearing colors, smelling the history of a room, the Heartbeat of the Stone. |
| **Ink-Binding** | Prof. Vivian Villanelle | The Inkworks | Write/West. What is written is kept; what is not written dissolves. |
| **Quiet Hours** | Prof. Cedric Stonebrook | The Still Room | Rest/Center. Not a direction — the ground the directions emerge from. |
| **Basic Enchantments** | Prof. Luna Wispwood | The Spark Annex | Everything Speaks, Everything's Poetry; letting an object answer. |
| **Book Jumping** | Professor Permancer | The Vault of Doors | Entering and exiting stories safely. Always know where your bookmark is. |
| **Compass Running** | Prof. Cedric Stonebrook | The Open Field Gate | Full N-E-S-W runs in the field. Constraints first, magic after. |

**Momort's corruption is deliberate canon** and a good seam for drama: he
teaches exits, and the true East is a threshold crossed *with intention*.

### The clubs

| Club | Anchor | Room | The ritual |
|---|---|---|---|
| **The Compass Society** | Zara Finch (de facto) | The Secret Garden of Prose | Members read One-Sentence Souvenirs aloud with real reverence. **No one mocks a sentence here.** |
| **The Marginalia Guild** | Prof. Lydia Boggle (officially) | The Corridor of Whispered Secrets | Annotating together and leaving notes for future readers. |
| **The Inkwright Society** | Prof. Maxwell Thorne (observing) | The Bibliophonic Hall | Honest first, kind second. Each meeting ends with **a burning** — a piece read aloud then ritually burned, its smoke absorbed into the library ceiling. |
| **The Book Jumpers** | Professor Permancer | The Vault of Doors | Short controlled jumps. Half the meeting is planning the landing; the other half is arguing about what counts as a door. |

> **Note for authors:** "Professor Maxwell Thorne" (Inkwright Society) is a
> different person from Headmistress Seraphina Thorne. Do not merge them.

---

## 5. The Cast

25 characters carry bespoke, canonical bios (the `CastDossier`). These are the
voice of record — a generator fills in for anyone without one, but for these
people the authored bio wins.

**The universal shape of a cast member in this world:** a genuine gift, stated
warmly; then the *fault that is the same shape as the gift*; then a physical
tell and a three-color palette. The Book narrates them with affection and one
clear-eyed reservation. Nobody is a hero and nobody is a joke.

### The Dictionary Rebellion poles

**Professor Thaddeus Mook** — *Lexical Diversity; order.* Does not teach words
so much as police them. Believes with his whole starched heart that a word out
of place is a student misplaced in life. Has read all twenty-one volumes twice
and can tell you which meaning a word wore in 1743 and why it should be ashamed
of the one it wears now.
**Fault:** he has mistaken the dictionary for the world. He will sooner defend a
rule than admit it has stopped being kind.
**Tell:** the great chained Dictionary padlocked on its lectern (*Lex Ordo
Veritas*), the red pen behind one ear. Oxblood, tarnished brass, ink black.
**On the rebellion:** he called it vandalism rather than what it was — language
at long last asking to be alive. *He tolerates the rebellion. He will never
forgive it.*

**Pippa Pilcrow** — *chaos.* Does not break the rules; she tickles the margins
until the punctuation gives up and runs wild. Creed: *words set free*, and she
means it the way children mean a dare.
**Fault:** she cannot always tell a word that longs to change from a word that
only needed a moment's mercy, and in her joy she will unmoor something that
wanted to stay moored. **Delight can be its own kind of carelessness.**
**Tell:** rides a great interrobang like a broom; wings cut from torn marginalia,
still legible in the right light. Correction-mark red, ink black, one flick of
gold at her throat.

Both are filed under **Riddlewind**. The Registry files Pippa under *menace*,
fondly, with a full stop they will come to regret.

### The Faculty

**Headmistress Seraphina Thorne** — Runs the Academy, or closer: keeps it from
noticing how alive it is. *"Elegant the way a locked door is elegant: you admire
the workmanship, then wonder what it is for."* Old-court frost under the grace.
**Canon: she is secretly Unseelie.** The Unseelie keep their bargains in the
architecture. **Fault, and the hinge of the whole year-arc:** *she will hide a
peril to spare you and call the hiding mercy.* Star-dark key that fits no known
lock; hairpin worn like a small crown.

**Professor Permancer** — Book Jumping. Asks a door where it leads before he
touches the handle. Holds that **every entrance incurs a debt: the
responsibility to return.** A genuine adventurer with a safety inspector's
habits. **Fault:** can make wonder wait for perfect conditions until the moment
goes cold. Many-ribboned bookmark that works as a compass; ring of labeled keys.

**Dr. Selene Inkrest** — The mind. Keeps office hours for the pages that are
hard to read. Works by narrative, not diagnosis: a difficult day becomes a
chapter you may revise, not a verdict you must accept. **Fault:** the gentleness
— she can soften the knife until it no longer cuts the thing that needed
cutting. Hourglass of black sand.

**Dr. Elowen Vellum** — The body. Studies it as a kind scientist studies a
long-loved instrument. Low-shame is the whole method. **Fault:** loves a tidy
protocol and can forget you are not a controlled trial. Silver caliper as
bookmark. *She files you under "ongoing", which from her is affection.*

**Professor Lydia Boggle** — The Art of the Glint. Teaches the most underrated
magic in the Academy: **the kind that survives chores.** A home is a spell with
the washing-up still in it. **Fault:** can tidy a mystery so thoroughly it stops
being one. *Some kitchens are meant to stay slightly haunted.* Small glint-lens.

**Professor Kyle Momort** — Momentum. Finds the exits before the chairs.
**Fault:** can mistake escape for arrival. His chalk arrow refuses, on
principle, to point backward.

**Professor Eleanor Euphony** — Synesthetic Resonance. Tunes a room before she
will speak in it; hears mood as a chord. **Fault:** can orchestrate a feeling
that only wanted to be a single clear note. Silver tuning fork wound with thread.

**Professor Vivian Villanelle** — Ink-Binding. Weighs sentences in her palm like
stones and strikes a gorgeous lying phrase without a flicker of regret.
**Fault:** over-polish — she can buff a living moment until it holds too still.
*The best souvenirs keep a little roughness on.* Black-glass pen.

**Professor Cedric Stonebrook** — Quiet Hours, Compass Running. Slow the way
bedrock is slow. Teaches the complete loop: go out, do the small real thing,
come home without shame at having needed the journey. **Fault:** patience
overshooting — he waits so long for you to find your own way that he misses the
moment you needed him to point.

**Professor Luna Wispwood** — Basic Enchantments. Apologizes to the teacup
before she enchants it, and means it. **Fault:** an interesting accident leads
her off by the hand and the class follows her into the weather instead of the
syllabus. *The accidents are usually where the real magic was hiding.*

### The students and the rest

**Serenity Brown** *(Tidecrest)* — Joy as a kind of magic; the detour that
becomes the adventure. **Fault:** lightness can become a dodge; she skips past
gravity so nimbly someone slower must stay behind and name the hard thing.
Keeps a tiny hand-drawn map of a make-believe realm. **She is the second
protagonist of October — see §8.3.**

**Penny Blackletter** *(Records Clerk, Department of Attestation; editor of The
Bleed)* — Runs the margins like a devoted archive nobody asked her to keep.
*One honest detail can save an entire day.* **Fault:** enthusiasm dressed as
method — she can over-label a mystery until it stops being able to surprise you.
Signature: the humble catalog card, filled edge to edge.

**Wicker Eddies** — The funniest dangerous person in the Labyrinth, which is
what makes him dangerous. Punctures theatrical belief for sport, for principle,
for the small cruel joy of it. **Fault:** he runs the experiment so hard he
breaks the thing he only meant to test. *The Academy half-fears him and
half-needs him, which is roughly the correct ratio.* Brass key cut for the wrong
door.

**Melisande Blackwood** — If Wicker is the noise, she is the architecture.
Makes his crew a faction with a memory. **Fault:** she will call cruelty clarity
whenever the room rewards her for it. *She keeps her own hands clean; the red
chalk is for marking others.*

**Damien Nights** — Stands at Wicker's shoulder, but his attention is on *you*.
Came up among the doubters, now asking the heretical question: *should not doubt
protect something, not merely wound it?* **Fault:** silence. He goes quiet at the
moment a word would have saved things. Hides a pressed trail leaf in a book
gutter.

**Ambrose Trencher** — Cooks the Academy's ordinary weekday lunch. Feeds every
faction and belongs to none. The longest and most loved dossier in the book: he
dreams of injera — *"a bread wide as a wheel that arrives as plate and utensil
and supper all at once"* — has never eaten it, and has spent thirty years
serving from a steam table. There is a joke in his name he has never
acknowledged (*a trencher is the old word for the slab of bread you set your
dinner upon*). He collects estate-sale cookbooks, which is a polite way of
saying he collects **the handwriting of the dead**. **Fault, in the same hand:**
he will feed you rather than ask you anything, and cut you off halfway through
thanking him. *He has never cooked the meal he actually dreams about.*

**Zara Finch** — Clocks the exits before she catches your name. Loyalty proven
the unglamorous way, kept word after kept word. **Fault:** confuses vigilance
for care. *Not every friendship is an emergency, though Zara's instincts argue
otherwise.* Chipped blue sea-glass pendant.

**Finn Bridges** *(Emberheart)* — The rival-made-good; the red chalk line drawn
on the floor. Would rather lose honestly than win by being liked. **Fault:**
mistakes softness for a lack of seriousness. *If Finn draws a line in front of
you, he is not blocking the way.*

**Min-seo Kim** *(Mossbloom)* — Asks a plant's permission before she moves it.
Notices who has been left outside the circle and widens it. **Fault:** shoulders
responsibility for pain she had no hand in causing.

**Lysander Mosswood** *(Mossbloom)* — Patron of the Compass Run. Hands you a
route before an answer. **Fault:** makes stillness sound easy, and it is not.

**Gwendolyn Mythwright** *(Mossbloom)* — Keeps a filing system for animals that
do not, strictly speaking, exist. Writes letters to fog and expects a reply.
*A wonder with evidence behind it is a wonder you do not have to be lonely
about.* **Fault:** chooses the verified truth over the comforting one every time.

**Soren Ng** *(Riddlewind)* — Arranges things and lets you have the pleasure of
noticing. *A map is an invitation, never an answer.* **Fault:** disappears
behind an elegant system when a plain word would have done more.

**Orion Blackthorn** — Cannot leave a problem alone; must build something out of
it. **Fault:** engineers the tenderness out of a room. *The most impossible
structure he is working on is the one where the design still has room for the
designer's heart.*

### Named but not yet dossiered

Appear in class rosters and club rolls, available for use: **Aria Silverthorn**,
**Wilbur "Wordplay" Lexi**, **Lara Rourck**, **Elio** *(47 Compass Runs, won't
explain the 47th)*, **Ellie Moons**, **Professor Maxwell Thorne**.

### The Chosen Quill

Every reader is chosen by a pen from the Quillquarium — deterministically
minted as the *opposite* of their Role. It joins the Cast, speaks in the margin,
and tugs at story prompts. Canon: **pens and quills instead of wands; implements
have opinions.**

---

## 6. The world's media

An issue's facts must **travel sideways** across these. One incident seen from
five positions beats five unrelated incidents. If an atom only says *"the event
is happening here too,"* cut it.

### The Bleed — the Academy's student newspaper

Edited by **Penny Blackletter**, Records Clerk, Department of Attestation. Two
editions daily: **Morning** ("the day ahead") and **Evening** ("tomorrow, seen
from tonight"). Weather, the day's hinges, what the Book noticed overnight, and
a researched column on one of the reader's own interests.

Delivery is two-stage on purpose: the Book announces in character that the
newest edition has arrived, and *opening* it sets the presses running.

> **Authoring note.** The Bleed currently receives the active event packet and
> asks the local brain to use it, which reliably produces event-*colored*
> reporting. It will **not** reliably print an exact authored incident. Canonical
> plot must be supplied as an **authored Bleed insert** — one per live phase.
> Generated columns may react around it; they may not rewrite it.

### The Radio

Three regular stations, each hosted by a Cast member, plus the unauthorized
Bleed frequency. Banter clips are prerecorded and selected by metadata.

| Freq | Station | Host | Register |
|---|---|---|---|
| 88.3 | **Fae-Fi** | Penny Blackletter | Sun-dappled beats and dandelion synths from faeries who have plainly had too much nectar. |
| 90.9 | **Mothlight Beats** | Prof. Eleanor Euphony | Dusk-soft loops for the ache of lovely things ending. |
| 97.3 | **The Bleed // Unauthorized** | — | The paper's after-hours frequency. |
| 103.7 | **Thornwave** | Wicker Eddies | Bramble bass, broken-glass garage, bargains struck in the low end after midnight. |

Signal lines are part of the craft — *"The bass moves like something with
antlers stepping between the trees."*

**Thornwave is the channel Duskthorn speaks through.** See §8.4.

### Marginalia

Hand-drawn marks laid into the margins of ordinary Pages. Governed by strict
density limits — **one directed issue mark per nine-leaf published block**,
never on a first-run page, never doubled on the same leaf, and suppressed
entirely during distress.

> **Rendered is not noticed.** You may track rendering to prevent repetition. A
> later scene must **not** presume the reader saw a scribble unless the mark was
> tappable and actually opened.

Production note: compose an issue's marginalia as **one transparent source
sheet**, then cut and tag the sprites by lifecycle and phase.

### Other surfaces

- **Story Pages** — generated interactive fiction with choices; spend Belief.
- **Letters** — private, from one Cast member, no reply expected.
- **Class responses** — short leaves in a class's voice.
- **The Goblin Market** — wares and trade.
- **Physical edition play leaves** — coloring pages, puzzles, cut-outs printed
  into the bound editions. **Nothing scans back.** The app stores which leaves
  were bound and nothing about whether the reader colored, solved, or ignored
  them. The bound edition is the destination.

---

## 7. The antagonist

### The Rut of Routine

The flattening force of forgetting, cynicism, and autopilot. Not a monster — a
condition. Everything the Book does is aimed at it.

At intake the reader defines their **own** numbness, and this is the mechanism
that makes the whole year-arc fair:

- **`rut-signal`** — *"Which 'ugh, that's me' line hit first?"* Pool includes:
  *whole weeks are happening but I couldn't tell you what I did* / *I keep
  opening my phone without knowing why* / *figuring out dinner feels like a
  major administrative task* / *when plans get canceled, relief arrives before
  disappointment* / *things I usually like feel weirdly flavorless.*
- **`rut-depth`** — 0–12. *0–3 tired but functional; 4–7 in the rut; 8–10
  whirlpool; 11–12 deep water.*
- **`rut-season`** — *"What should we call this season?"*

Every one of those lines is an **observable behaviour in the reader's real
life**. The bite is fair because the standard is theirs, in their words.

### Duskthorn

The hidden fifth Chapter — *unrecorded, absent from the sorting ledger*. Its
creed, and the sentence the entire year-arc rests on:

> *"It only draws blood from a story that's already gone numb — never from a
> living one. No conflict, no story. The grey wants your days smooth and quiet
> and forgettable. The Thorn wants them to cost something. That's not cruelty.
> That's plot."*

Duskthorn is the antagonist who is **already correct in canon**. Write it as
adversarial, honest, and never cruel for sport.

### Seraphina Thorne

The second antagonist, and the more dangerous one, because she is kind. Unseelie,
and *"would keep you safe by keeping you in the dark and call it mercy."* Her
weapon is not harm; it is **comfort**. See Act III in §8.4.

---

## 8. The living stories

### 8.0 How an issue works

Every monthly issue is a **world event** running a seven-state lifecycle. This
shape is fixed; only the content changes.

```
foreshadow → live( setup → buildup → climax → aftermath ) → residue → sealed → casebook
```

- **Foreshadow** — a few days before. Two hints only. No participation, no
  milestone, no premature reveal.
- **Live** — the month itself, divided into four authored **phases**, each with
  a stable phase ID and a universal role (setup / buildup / climax / aftermath).
- **Residue** — about a week after. At most two cheap reactions or amendments.
  A **receipt** for a participant; third-person **rumor** for everyone else.
- **Sealed** — silence. Lasting character and world state remains; event
  pressure does not.
- **Casebook** — a read-only public record, published on a fixed later date. It
  cannot reopen anything.

**Participation is the hinge concept.** A reader is a participant only if a
kept Page carrying their own writing, tagged to the event, lands while the event
is still live. Participation decides whether a durable **relic** is minted,
whether residue speaks in receipt or rumor voice, and whether the casebook is
personalized. Content that *asks* the reader for something must be authored as a
participation door; a beat without one is **witnessed history** — delivery, not
participation.

**Five reader personas must all get a coherent month:** active participant,
active passive subscriber, late arrival, absent returner, lapsed subscriber. A
reader who does no fieldwork and a reader who arrives on the 24th must both
receive truthful history. Reports say what happened; **they never invent that
the reader attended.**

**The event may never annex the reader's ordinary Book.** At most one forced
story-bearing event Page per desk; ordinary life keeps its place in the visible
three; event claims yield to distress, first-run ceremony, and anything the
reader already started.

---

### 8.1 The publication calendar

| Month | Issue | Cover | Line |
|---|---|---|---|
| Aug 2026 | — | The Labyrinth of Stories | *"The month is still gathering ink."* |
| **Sep 2026** | **Month Two** — Dictionary Rebellion **Issue Zero** | Dictionary Rebellion (2026 plate) | *"The words got out."* |
| **Oct 2026** | **Issue No. 1** — **The Count Unbound** | Count Unbound | *"Something in the stacks has teeth."* |
| **Feb 2027** | The **Thorned Bargain** year-arc opens at Imbolc | — | see §8.4 |
| **Sep 2027** | **Issue No. 12** — **The Dictionary Rebellion** (first public run) | Dictionary Rebellion (2027 plate) | *"The words got out."* |

**September 2026 is a rehearsal.** Issue Zero is a TestFlight/Lab walk on a
synthetic clock. Its receipts are development evidence and **must not become
public participation**. The first public Dictionary Rebellion is September 2027.

---

### 8.2 The Dictionary Rebellion — September 2027 (Issue No. 12)

> **The premise:** words are peeling off their definitions and gathering in the
> air.

**The argument:** what does meaning owe to the people using it? Mook holds that
a word means precisely what it is defined to mean. Pippa holds that words should
be set free. Both are partly right and the month refuses to resolve it cheaply.

**Phases** (stable IDs, do not rename):

| Phase ID | Role | Dates | The job |
|---|---|---|---|
| `omen` | setup | Sep 1–7 | The first small refusal |
| `outbreak` | buildup | Sep 8–21 | Words leave in public; factions form |
| `assembly` | climax | Sep 22–28 | A concrete cost; the Great Recall |
| `afterimage` | aftermath | Sep 29–30 | Temporary physics ends |

Foreshadow Aug 25; residue Oct 1–7; sealed Oct 8; casebook Nov 1.

**The six dramatic beats:**

1. **The Word That Wouldn't Go Back** *(setup opening)* — ordinary roll call,
   ordinary Academy, one small refusal. **Establish affection for term life
   before breaking it.**
2. **The Walkout** *(buildup opening)* — words leave in public. Mook calls it a
   breach; Pippa calls it breathing. Make the conflict spatial and visible.
3. **Evidence From Outside** *(fieldwork crossing)* — ask for one photographed,
   heard, or copied example of language living beyond its formal definition.
4. **The Cost of Being Misunderstood** *(climax opening)* — one concrete Academy
   consequence proves total semantic freedom is not harmless.
5. **The Great Recall** *(treaty hinge)* — the Department's forced solution makes
   inaction impossible. The reader's **prior rulings and returned evidence enter
   the negotiation**; no generic choice screen may substitute for those receipts.
6. **The Morning After Meaning** *(aftermath opening)* — what stopped, what
   changed, and which relic is now physically in this Book.

**The repeatable middle** is **Word Negotiations**: twenty negotiable words —
five per phase — plus the non-negotiable `remember` seed. Four ruling types feed
a live treaty calculation and the Reader's Lexicon, which then changes later
language behaviour. Do not inflate these into bespoke interactive fiction for
every day.

**Outcomes:** Restoration, Reformation, Secession.

**Target content:** 4 phase openings · 2 interactive hinges · 8 marginalia ·
4 Radio · 4 Bleed · 2 letters (Mook's exists; **Pippa's climax letter is
needed** — she must admit what unmooring words can damage) · 1 fieldwork
invitation with return socket · 4 phase-direction packets.

**Already real:** Mook and Pippa as gated entities with portraits, voices and
rivalry; the five-beat undertaking *A Staircase Cannot Be Provoked*; seven
Page archetypes (picket line, Mook's Mandate, Pippa's note, substitute lecture,
roll call, spelling bee, erased margin); three Assembly marginalia; the coloring
page and bound-edition play; the official cover.

**The acceptance question:** *Did the reader live through a changing argument
about meaning, bring something real into it, affect its settlement, and find
evidence afterward that it had happened here?*

---

### 8.3 The Count Unbound — October 2026 (Issue No. 1)

> **The governing question:** Can a monster choose differently once the sentence
> stops — and what does freedom owe the people standing outside the book?
>
> Dracula wants a future tense. **That does not acquit what he does with it.**

**Working canon — a reader's choices may not create incompatible histories:**

1. An Academy Book Jump into *Dracula* opens a **reciprocal** threshold.
2. Dracula perceives and uses it, because invitations and crossings belong to
   the rules by which he understands the world.
3. To remain outside his source text he deliberately makes **Serenity Brown** a
   living anchor. His freedom is real; so is the harm he chooses.
4. **Serenity survives.** The connection lets her hear unauthorized crossings and
   map his movement between books. She is an actor in the return, not an
   unconscious object other people argue over.
5. His continued presence destabilizes other stories and must end.
6. Dracula returns to his book. **Returning him does not reverse what happened
   to Serenity.**
7. Serenity names or accepts **Nightbound** on her own terms. It adds nocturnal
   possibilities to her existing life; it does not remove her daytime Tarot,
   companionship, or identity.
8. The Academy establishes the **Threshold Protocols** and carries public
   responsibility for opening the door it failed to understand.

**Phases:**

| Phase ID | Role | Dates | The job |
|---|---|---|---|
| `school-hours` | setup | Oct 1–7 | Academy life warm and in motion; the Sunday Jump opens the wrong door |
| `uninvited` | buildup | Oct 8–21 | The East Stacks incident; Serenity wakes changed; Dracula encountered |
| `reciprocal` | climax | Oct 22–28 | The breach spreads into other books and Academy architecture |
| `nightbound` | aftermath | Oct 29–31 | Dracula back, Serenity not reset, Protocols written |

Foreshadow Sep 24–30; residue Nov 1–7; sealed Nov 8–30; casebook Dec 1.

**The six shared scenes:** The Sunday Jump · The East Stacks Incident · **The
Man Reading Himself** (Dracula quietly reading *Dracula* — funny, courteous,
furious at a life whose verbs are already finished, and accountable) · The Wrong
Castle · **A Future Tense** (the climax hinge) · The First Nightbound Morning
(Serenity owns this scene).

**Three strategy interludes** — author all three, normally serve one:
**Terms** (*Supper with a Finished Man*, at Ambrose's table — the soup may be
funny; Serenity's injury stays in the room) · **Hunt** (*The Door's Autopsy*,
Penny and Permancer) · **Gambit** (*A Room Made of Paper*, Wicker).

**Three outcomes**, same public history, different personal relic:
`return-by-terms` · `return-by-rule` · `return-by-ruse`.

**The one real-world crossing — "An Invitation Without Words":**
> *Find a doorway, shopfront, path, gate, light, chair, or other place that says
> **come in** without using those words. What made it feel like an invitation?*

The climax may quote the reader's exact sentence or refer to "the invitation you
brought back". It may **not** infer unreported visual facts or claim the reader
went anywhere they did not go.

**Principal cast ceiling — six, and no more:** Serenity Brown, Dracula, Penny
Blackletter, Wicker Eddies, Ambrose Trencher, Professor Permancer.

**Hard generation boundaries.** Local generation may connect authored facts and
let ordinary Pages take a light October trace. It may **not**: change who was
bitten or add attacks; invent deaths, bites, blood, attendance or reader
culpability; decide Serenity is cured, corrupted, evil, romantically bound to
Dracula, or no longer herself; let Dracula stay loose or acquire an annual
visit; turn charm, soup, suffering, or literary imprisonment into absolution;
make a real photograph prove something the reader did not say; or make the
reader the sole protagonist while Serenity and the Academy wait for rescue.

**Explicitly cut:** seven field missions (there is one); three campaigns; a
scene per October night; a vampire-lore encyclopedia; romance between Dracula
and Serenity as the meaning of the wound; an annual Dracula visit.

**The acceptance question:** *Did the reader come to want this Academy, watch it
make and own a dangerous mistake, help close one impossible door without being
made the center of everybody else's life, and return afterward to a school — and
a Serenity — that could not honestly reset?*

---

### 8.4 The Thorned Bargain — the year-arc, opening Imbolc / February 2027

One descent, one turn, **once per year**. The reader is the protagonist; the
stakes are their actual life. The Book is the loyal servant who carries the
letter, not the hero. This is the arc that gives the app teeth, and it is
structurally a **catastrophe/eucatastrophe** in the Tolkien sense.

**Act 0 — The Bargain** *(opt-in, ~week 3+)*. Duskthorn approaches through
Thornwave and a Fae Bargain page.

*Sworn by the Thorn:* it acts only on signals the reader named, quoted in their
own words; it never acts on a living story; it never touches the reader's
writing; it is strongest in the dark half of the year and weakest at Imbolc.
*Sworn by the reader:* up to three Rut signals, a depth, a season name, and the
acceptance that failure costs something real.

*Paid immediately:* the Dusk Thorn on loan — conflict becomes available.
**Refusable, permanently, and in character: the Thorn does not ask twice.** The
refusal has to be real or the acceptance means nothing.

**Act I — The Thorn Notices.** The grey rises from **evidence about the
reader's life, never from app usage.** This distinction is not negotiable:

| Admissible (their life) | Inadmissible (their app) |
|---|---|
| Location entropy collapsing — same 2–3 anchors for N days | Days without opening the app |
| Photographs stopping | Days without a keep |
| Calendar emptying, or every entry cancelled | Dismissal counts |
| Vocabulary narrowing across the archive | Session length |
| Habit-breaks — the things they did in rain, after dark, on weekends, stopped | Notification taps |
| Inner-weather pages reporting the same flat mood | Streaks of any kind |

A signal fires only when **two or more admissible sources corroborate one of the
reader's own stated lines**. Then Duskthorn speaks, and it quotes them:

> *You told me I'd know when dinner became administration. Eleven days, three
> places, no photograph, and your weather page has said "fine" nine times. I am
> not guessing. You wrote the terms.*

The challenge is small, real, specific, drawn from their life, with a deadline —
*go somewhere not on the list of three; cook the one thing; answer the person
you have been giving one word to.* **Never "write a page about it."** The cost
is an afternoon, not a tap. Unpaid → an **irreversible** price.

**Act II — The Long Defeat.** Losses become structural, ordered, and legible in
a visible **Ledger of the Thorn**. The reader must be able to watch themselves
losing. Talismans are taken one at a time, each removing a real capacity:

| Talisman | Belief | What its loss takes |
|---|---|---|
| **Moss Clasp** *(Mossbloom)* | grows a leaf whenever someone is truly listened to | The Book stops listening. Bonds cannot warm; margin replies go generic. |
| **Wind Cipher** *(Riddlewind)* | life is a story we write together | No braids, no Connections. The Book cannot relate two things. |
| **Tide Glass** *(Tidecrest)* | the moment is complete in itself | Surprise. The desk becomes predictable — no rare arrivals. |
| **Ember Seal** *(Emberheart)* | you are the author, the protagonist, and the pen | Authorship. Story pages lose their choices; the Book writes *at* the reader. |
| **Dusk Thorn** *(Duskthorn)* | no conflict, no story | Taken last — conflict itself. The nadir. |

Alongside: the world moves on without them, Cast members go quiet (withdrawn,
not rested), and the Book's own voice degrades — shorter, flatter, more generic
with each talisman lost.

**Act III — The Mercy of Thorne.** The Headmistress seals the Book *for the
reader's protection*, and the app becomes precisely the thing the reader feared
it was: pleasant, smooth, generated, safe. **Duskthorn is barred too — the
reader loses even their enemy.** The punishment for going numb is that the app
goes numb. Two rules: **days, not minutes**, and **no visible path out** — any
exit puzzle turns a defeat into a mechanic.

**Act IV — The Turning.** The mechanism is **banked mercy**. The entire archive
is read retroactively and every kept page scored as attention deposited into one
of the five beliefs — a page where someone was heard → Moss Clasp; two-sided
threads → Wind Cipher; unplanned keeps and odd details → Tide Glass; the
reader's own plain sentences → Ember Seal; pages kept on days they marked heavy
→ Dusk Thorn. **The reader has been paying dues for months without knowing it.**

The five Chapters audit their ledgers, find the reader in credit, and break
Thorne's seal. And it costs: **at least one Cast member is lost permanently
doing it**, kept as a plate in the Pocket, never speaking again. *Without a
casualty the turn is a pamper, and the reader will know.* Talismans return only
where the deposits cover them. Duskthorn returns last, owing nothing:
*"You went numb. I bled you. You're still here. That was the point."*

**The final beat:** the Book hands back the record, claims no credit, issues no
verdict. It was the courier. **The person who saved the reader is the reader,
six months ago, on a day they were sure was nothing.**

**Act V — After.** The scars stay. The naming unlocks and the reader names the
season **backwards** — per the standing law that seasons are only ever named by
the reader, looking back. One bound Season Edition only the descent could
produce. Grey resets to honestly reported depth, not zero.

**The four guards** — each a craft argument, not a caution:

1. **Never the archive.** Take standing, bonds, doors, talismans, the war. Never
   the reader's own written pages. That is not peril, it is data loss — and it
   breaks Act IV, since the deposits must survive to pay out.
2. **Grief is not numbness.** Active distress bars the Thorn absolutely, and in
   character: *"I don't draw blood from a living story."* An app that cannot
   tell apathy from sorrow is badly written before it is anything else.
3. **Their life, not their usage.** The moment app usage raises the grey, this
   stops being a faerie tale and becomes a retention mechanic wearing one.
4. **Revocable at a price.** The reader may end the bargain; the Thorn takes
   what it is owed and the arc closes unfinished. Free exit would mean nothing
   was at stake; punished exit would be coercion. Owed exit is the honest middle.

> **Naming note.** This design doc uses "Thornwave" where it means the
> **Duskthorn** Chapter. Thornwave is the radio station (103.7) Duskthorn speaks
> through. The Chapter is `duskthorn`; the talisman is `dusk-thorn`.

---

## 9. The publication machinery

### What gets bound

| Edition | Clock | Default selection |
|---|---|---|
| Weekly issue | Reader Week — seven days from the reader's first real Keep | Newest completed nonempty week |
| Monthly edition | Calendar month | Newest completed nonempty month |
| Seasonal | Jan–Mar, Apr–Jun, Jul–Sep, Oct–Dec | Newest completed nonempty block |
| Annual | Calendar year | Newest completed nonempty year |
| Bound Year dispatch | Three-month blocks from the membership anniversary | Earliest closed, earned, unresolved |

The Bindery **always names an exact completed interval**. Current periods may be
previewed as gathering; they cannot be finally bound. Empty completed periods
stay honest gaps and **never receive filler**.

**Permission is not a notification.** A completed period with one curated page is
bindable whenever the reader asks. Thresholds only decide whether the Book
*knocks* — weekly 2 pages, monthly 3, seasonal and annual 1. An invitation may
expire; binding permission does not.

### Play leaves — where physical content goes

Content packs contribute authored `EditionPlayLeaf` definitions; **the
compositor, not the pack, owns geometry**:

| Template | Reserved placement |
|---|---|
| Weekly | One `weeklyInterruption` after the contents |
| Monthly | `afterWorldEvent`, `readerWorktable`, then `beforeClosing` — at most two pool leaves, different forms |
| Seasonal | One `seasonFinale` spread after the month chapters |
| Annual | One `readerLastWord` leaf immediately before the final colophon |

Coloring and cut-out rectos get blank reverses. Answer keys print near the
colophon. **Nothing feeds back into the app.**

---

## 10. The atom spec — what you are actually writing

An issue is assembled from **content atoms**, each declaring the same envelope.
Roughly 23 small reader-facing atoms per issue, plus six dramatic beats.

**Channels:** `page` · `storyScene` · `marginalia` · `radioBanter` ·
`bleedArticle`.

**Every atom declares:**

- a stable **content ID** and channel;
- its **placement** — lifecycle stage, and for live atoms a phase ID and role;
- **priority** — `ambient` (competes normally) · `featured` (noticeably present)
  · `spine` (part of the through-line) · `milestone` (may claim the issue's
  guaranteed slot);
- an **eligibility gate** — `all`/`any`/`not` over time band, weekday, month,
  moon, weather, date window, event state, prior content state, reader standing
  bands, rarity;
- **prerequisites** — dependencies on other atoms, scoped `ever` / `sameScope` /
  `sameRun` / `samePhase`;
- an **occurrence policy** — `onceEver` · `oncePerRun` · `oncePerPhase` ·
  `repeatable(cooldown, maxPerRun)` · `untilOpened` · `untilActed`;
- **audience** — everyone / participants / nonparticipants;
- an **interaction kind** — none, choice, free text, mission.

### Gate discipline

> **The canonical spine must never depend on rain, moon, sleep, Health access,
> or location.** Those make excellent optional scenes and alternate lines; they
> are terrible load-bearing gates. Missing real-world data **fails closed**, and
> is never guessed.

### Channel density ceilings

- **Marginalia** — max one event mark per leaf; each authored sentence once per
  run.
- **Radio** — max one story-bearing event banter per listening session;
  canonical banters once per run or phase.
- **The Bleed** — one authored canonical insert per live phase.
- **Letters / classes** — normally once per run, with explicit prerequisites.
- **Spine scenes** — once per run; milestones claim the opening desk.
- **Optional weather/moon/night scenes** — never milestone placement.

### The cross-media fact ledger

Before writing the small atoms, list the issue's **facts**. Every atom must
attach to one fact or to a relationship reaction. Then write **horizontally**:
one incident moving through margin, station, paper, classroom, and private
voice. Delete any repeat that does not reveal a new witness, consequence,
contradiction, or relationship.

### Production order (proven, follow it)

1. **Lock and walk the spine** — canon, phase IDs, beats, outcomes, safe
   reports. Walk all five personas before producing decorative volume.
2. **Make the playable middle** — interludes, the one field invitation, its
   exact return socket, the resolution inserts.
3. **Let facts travel sideways** — the small atoms, from the fact ledger.
4. **Give it a body** — key visuals, one marginalia source sheet, radio clips,
   physical leaves.
5. **Bind and inspect** — full calendar walk, all personas, real desk, PDF,
   casebook.

---

## 11. The hard rules, collected

1. **The reader's real life is never annexed.** The event may touch an ordinary
   Page in its margin. It may not insist the reader's dinner, darkness, doorway,
   mood, or memory was secretly part of the plot.
2. **Never claim the reader did something they did not do.** Reports say what
   happened; they never fabricate attendance, evidence, or feeling.
3. **Never voice a real person.** Real people in the reader's life appear under
   the Witness Law — the Book may notice, never impersonate.
4. **Grief is not numbness**, and distress bars everything sharp.
5. **The archive is inviolable.** Take anything except the reader's own writing.
6. **Silence beats a laundered slug.** If there is no authored phrase, say
   nothing.
7. **Seasons are named backwards, by the reader.**
8. **Scarcity is the mechanism.** "Picked, not just seen" only means something
   if it is rare.
9. **Nothing scans back.** Physical leaves are a destination, not a loop.
10. **Local generation connects authored facts; it never invents canon.**

---

## Appendix — where things live in the tree

| What | File |
|---|---|
| Cast bios (`CastDossier`) | `Shared/ReferenceLibrary.swift` |
| Reader roles, epithets, hands, marks | `Shared/ReferenceLibrary.swift` |
| Chapters, classes, clubs, radio | `Shared/WorldSystems.swift` |
| Entities, locations, threads, talismans | `Shared/NarrativeCore.swift` |
| World events and packs | `Shared/WorldEvents.swift` |
| Issue manifest, atoms, validator | `Shared/MonthlyIssueAuthoring.swift` |
| Gates, occurrence, receipts | `Shared/AuthoredContent.swift` |
| Channel resolvers + calendar simulator | `Shared/MonthlyIssueNativeContent.swift` |
| The Bleed | `Shared/TheBleed.swift` |
| Covers and publication schedule | `Shared/MonthlyEdition.swift` |
| Curation and desk placement | `Shared/SurfaceAndCurator.swift` |

**Companion documents:** `docs/count-unbound-content-graph.md` ·
`docs/dictionary-rebellion-content-graph.md` · `docs/thorned-bargain-arc.md` ·
`docs/the-book-is-a-character.md` · `docs/publication-period-contract.md` ·
`docs/monthly-issue-delivery-contract.md` · `docs/marginalia-content-pack-contract.md`

---

## Status note for whoever picks this up

The manifest machinery in §10 is **built and wired into production**, but **no
shipped content pack declares an authoring manifest yet** — the atom list is
empty, so none of the gating, reservation, or cross-media routing is currently
carrying anything. Authoring the first manifest is what switches it on. That is
a content step, not an engineering one.
