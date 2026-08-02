# The Thorned Bargain: catastrophe and eucatastrophe

The year-arc that gives the app teeth. One descent, one turn, once per year.
The reader is the protagonist. The stakes are their actual life. The Book is
the loyal servant who carries the letter, not the hero.

## Why this is possible without paternalism

The antagonist is already correct in canon. Duskthorn: *"It only draws blood
from a story that's already gone numb - never from a living one. No conflict,
no story. The grey wants your days smooth and quiet and forgettable. The Thorn
wants them to cost something. That's not cruelty. That's plot."*

The current implementation contradicts its own villain. `NothingTide` demotes
the Rut to "weather, not war," clamps the grey at 3, and forbids the world from
reacting to anything (`greyLevel(quietDays:)` accepts the parameter and
deliberately discards it). The one instance of the word "irreversible" in the
entire codebase is a *prompt string* telling the local brain to write turns the
app itself cannot produce.

Meanwhile the reader is already asked, at intake, to define their own numbness:

- `rut-signal` — "Which 'ugh, that's me' line hit first?" Examples in the pool:
  *whole weeks are happening but I couldn't tell you what I did* / *I keep
  opening my phone without knowing why* / *figuring out dinner feels like a
  major administrative task* / *when plans get canceled, relief arrives before
  disappointment* / *things I usually like feel weirdly flavorless.*
- `rut-depth` — 0–12. "0-3: tired but functional. 4-7: in the rut. 8-10:
  whirlpool. 11-12: deep water."
- `rut-season` — "What should we call this season?"

Every one of those example lines is an **observable behaviour in the reader's
real life.** The bite is fair because the standard is theirs, in their words,
sworn to by the antagonist. This is not the app judging the reader. It is the
app holding them to their own definition, which they signed.

## Act 0 — The Bargain (opt-in, ~week 3+)

Duskthorn approaches through Thornwave and a `.faeBargain` page. This is the
only bargain in the app whose counterparty is the antagonist, and the only one
that runs a year.

**Terms sworn by the Thorn:**
1. It acts only on signals the reader named, quoted in the reader's own words.
2. It never acts on a living story — grief, crisis, and real distress bar it
   absolutely (see Guards).
3. It never touches the reader's own writing.
4. It is strongest in the dark half of the year and weakest at Imbolc.

**Terms sworn by the reader:** they name up to three Rut signals, a depth, and
a season name. They accept that failing a challenge costs something real and
that what is lost does not come back on request.

**Paid immediately:** the Dusk Thorn itself, on loan. Conflict becomes
available — thorned truths, sharper pages, shadowed wonder answering sooner
after dark (the aftermath line at `WorldSystems.swift:4760` already exists for
exactly this).

**Refusable.** Declining is permanent and in-character: the Thorn does not ask
twice. That reader gets the app without the arc, forever. The refusal has to be
real or the acceptance means nothing.

## Act I — The Thorn Notices (grey 1–2)

The grey rises from **evidence about the reader's life, never from app usage.**
This distinction is the whole difference between a faerie tale and a streak
counter, and it is not negotiable:

| Admissible (their life) | Inadmissible (their app) |
| --- | --- |
| Location entropy collapsing — same 2–3 anchors for N days (`PlaceMemory`, `AnchorRegistry`) | Days without opening the app |
| Photographs stopping | Days without a keep |
| Calendar emptying, or every entry cancelled | Dismissal counts |
| Vocabulary narrowing across the archive (falling type-token ratio) | Session length |
| ContextWeave habit-breaks — the things they did in rain, after dark, on weekends, stopped | Notification taps |
| Inner-weather pages reporting the same flat mood | Streaks of any kind |

A signal fires only when **two or more admissible sources corroborate one of
the reader's own stated lines** for a sustained window. Then Duskthorn speaks,
and it quotes them:

> You told me I'd know when dinner became administration. Eleven days, three
> places, no photograph, and your weather page has said "fine" nine times. I
> am not guessing. You wrote the terms.

**The challenge.** Terms and a deadline. Small, real, specific, and drawn from
their own life — go somewhere not on the list of three; cook the one thing;
answer the person you have been giving one word to; be outside after dark.
Never "write a page about it." The cost is an afternoon, not a tap.

- **Paid** → the Thorn withdraws a shade, and something is earned that the
  reader could not have got any other way.
- **Unpaid** → a price, and the price is irreversible. Start small: a door
  closes. A recipe leaves the pool for the year. A shelf shuts.

## Act II — The Long Defeat (grey 3 → 5, uncapped)

Extend the grey scale to match the reader's own 0–12 report. Past 3 the losses
become structural, ordered, and **legible** — a visible Ledger of the Thorn
listing what has gone, in order, with dates. The reader must be able to watch
themselves losing.

**The talismans are taken one at a time, and each removes a real capacity:**

| Talisman | Belief | What its loss takes |
| --- | --- | --- |
| Moss Clasp (Mossbloom) | *grows a leaf whenever someone is truly listened to* | The Book stops listening. Cast bonds cannot warm; margin replies go generic. |
| Wind Cipher (Riddlewind) | *life is a story we write together* | No braids, no Connections, no ContextWeave findings. The Book cannot relate two things. |
| Tide Glass (Tidecrest) | *the moment is complete in itself* | No surprise. The desk becomes predictable — no unplanned pages, no Pocket, no rare arrivals. |
| Ember Seal (Emberheart) | *you are the author, the protagonist, and the pen* | Authorship. Story pages lose their choices; the Book writes *at* the reader. |
| Dusk Thorn (Thornwave) | *no conflict, no story* | Taken last, and this is the nadir: conflict itself. |

Alongside: the world moves on without them (`CastUndertakings` already advances
on the world clock — let undertakings *finish* unattended, let festivals be
missed, let someone else take the thing). Cast members go quiet — withdrawn,
not rested. And the Book's own voice degrades: shorter, flatter, more generic
with each talisman lost.

## Act III — The Mercy of Thorne (the nadir)

Headmistress Seraphina Thorne, unseelie, *"would keep you safe by keeping you
in the dark and call it mercy."* She has been waiting for this the whole time.

She seals the Book for the reader's protection. The app becomes precisely the
thing the reader feared it was: pleasant, smooth, generated, safe. Content with
no world behind it. The Bleed prints one dull page. The radio plays one loop.
The desk offers three inoffensive pages that could have come from anywhere.

**Duskthorn is barred too.** The reader loses even their enemy. That is the
deepest cut available and it is the true bottom: not pain, but the total
absence of friction. The punishment for going numb is that the app goes numb.

Two rules for this act:

1. **Days, not minutes.** It has to be endured.
2. **No visible path out.** Any exit puzzle turns a defeat into a mechanic. The
   reader must actually conclude it is over. Nothing they do can end Act III —
   which is the precondition for the turn being a grace rather than a reward.

## Act IV — The Turning

**The mechanism is banked mercy.** In Tolkien the turn is always causally paid
for by the protagonist's earlier small kindnesses, whose significance was
invisible at the time. Bilbo's pity for Gollum is the deposit nobody knew was a
deposit. This app is already an archive of exactly that.

Read the **entire archive** retroactively and score every kept page as
attention deposited into one of the five beliefs. No new capture surface, no
onboarding cost, and it works for a reader who has never heard of any of this:

- A page where someone was heard → **Moss Clasp**
- People threads, collaborations, letters, anything two-sided → **Wind Cipher**
- Unplanned keeps, souvenirs, pocket objects, the odd detail → **Tide Glass**
- Authored sentences, plain pages, the reader's own voice → **Ember Seal**
- Pages kept on days the reader marked heavy → **Dusk Thorn**

The reader has been paying dues to five beliefs for months without knowing it.

**At the bottom, the five Chapters audit their own ledgers and find the reader
in credit.** They break Thorne's seal. And it costs:

- The Cast who move are specifically the ones the reader was kind to, named
  with the dates.
- **At least one of them is lost permanently doing it.** They are kept as a
  plate in the Pocket and never speak again. This is the poignancy Tolkien
  insists on — Joy "poignant as grief." Without a casualty the turn is a
  pamper, and the reader will know.
- Talismans return **only where the deposits cover them.** A belief the reader
  never fed stays gone for the rest of the year.
- Duskthorn returns last, and it is the only one not paying a debt. It comes
  back because it wants the story to keep costing something: *"You went numb.
  I bled you. You're still here. That was the point."*

**The final beat.** The Book hands back the record — the deposits, with dates,
in the reader's own words. It claims no credit and issues no verdict. It was
the courier. The person who saved the reader is the reader, six months ago, on
a day they were sure was nothing.

## Act V — After

- **The scars stay.** Closed doors stay closed. The dead stay dead. Talismans
  not covered by deposits stay gone.
- **The naming unlocks.** `rut-season` reopens retroactively and the reader
  names the season *backwards*, in keeping with the existing law that seasons
  are only ever named by the reader, looking back.
- **One artifact only the descent could produce:** a bound Season Edition of
  the whole arc — the ledger, the challenges paid and failed, the deposits, the
  casualty.
- Grey resets to the reader's honestly reported depth, not to zero.
- Once per year-arc. Samhain and the dark months amplify; **Imbolc is the
  natural place for the turn** — the festival of returning light, and already
  the start of the Thorned Bargain year. Season amplifies, evidence triggers.
  Never the reverse, or the whole thing is fake.

## Guards

Four, and every one is a craft argument rather than a caution.

1. **Never the archive.** Take standing, bonds, doors, talismans, the war.
   Never the reader's own written pages. Destroying someone's journal is not
   peril, it is data loss — and it also breaks Act IV, since the deposits have
   to survive in order to pay out.
2. **Grief is not numbness.** `distressActive` bars the Thorn absolutely, and
   it bars it *in character*: "I don't draw blood from a living story." This is
   Duskthorn's own canon, not a system override. Per the shadow-shelf law,
   grief in full colour is the opposite of the Rut. An app that cannot tell
   apathy from sorrow is badly written before it is anything else.
3. **Their life, not their usage.** The admissible/inadmissible table in Act I
   is the load-bearing wall. The moment app usage raises the grey, this stops
   being a faerie tale and becomes a retention mechanic wearing one.
4. **Revocable at a price.** The reader can end the bargain. The Thorn takes
   what it is owed and the arc closes unfinished — no turn, no Season Edition.
   Free exit would mean nothing was ever at stake; punished exit would be
   coercion. Owed exit is the honest middle.

## Build order

1. **Make loss possible.** Irreversible closes (`expiresAt` meaning expired),
   the Ledger of the Thorn, and one takeable talisman with one real capacity
   attached. Nothing else matters until something can actually be lost.
2. **Uncap the grey** to the reader's 0–12 scale; delete the
   `greyLevel(quietDays:)` no-op overload and the "weather, not war" clamp.
3. **The life-signal reader** — location entropy, photo cadence, vocabulary
   breadth, calendar shape, ContextWeave habit-breaks — with the two-source
   corroboration rule and per-signal receipts.
4. **Act 0 and Act I**: the bargain page, challenges with terms and deadlines,
   small irreversible prices. Shippable alone as a season.
5. **The deposit ledger** — retroactive archive scoring into five beliefs.
   Pure, deterministic, testable against a synthetic archive.
6. **Acts II–V**: the talisman cascade, Thorne's seal, the turn, the casualty,
   the Season Edition.
