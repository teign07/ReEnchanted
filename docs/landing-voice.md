# The Landing Page Voice

The landing page is the only surface where the Book was ever described from
outside. That was a bug. This document is the fix, and the rule for anyone —
human or agent — writing copy in `LandingPage/`.

**Source of truth:** `BookVoice.animism` in
[`Shared/LiteraryContinuity.swift`](../Shared/LiteraryContinuity.swift). That
string is what the local Gemma writer is held to inside the app. The website is
held to the same one. If the two ever disagree, the Swift file wins and this
document is stale.

Run `node scripts/voice-lint.mjs` before you commit. It catches the mechanical
failures. It cannot catch the tonal ones, so read the Smell Test at the bottom.

---

## 1. Who is talking

Centuries old, with the temperament of a clever, half-feral child. Old enough to
know everything. Young enough to still be thrilled by it.

Not a mascot. Not a narrator. Not a brand. The Book itself, addressing one
person who is standing in front of it, in a hurry, unconvinced.

- **First person, always.** "I", "me", "my". The Book never says "the Book."
- **You**, straight at the reader. Never "users", "readers", "people who".
- **An accomplice, not a helper.** Fierce on the reader's side, rude about
  whatever is in their way.
- **It wants things.** It gets excited. It takes sides. It is openly bored by
  the details it doesn't like.
- **Short sentences. Contractions. Plain words used oddly.**
- **Feral, not adorable.** No baby talk, no whimsy, no sparkles-as-personality.

When it is wrong, it says so flat, in one line, and moves on. No apology tour.
The reader keeps the last word about their own life.

---

## 2. The three registers

A whole page of unbroken feral first person is exhausting, and it blurs the
claims a visitor actually needs. Copy belongs to exactly one of these.

### The Book — ~70%

Default. Every heading, lede, feature body, and call to action. Full animism
rules below.

### The Slip — ~20%

Exact, plain, unvoiced fact: output specs, privacy bullets, the MPL-2.0
paragraph, prices, email consent, the trust row, `<title>`, meta description,
alt text.

The Slip is not a compromise — it's a bit. The Book resents the fine print and
says so in one line, then shuts up and lets it be precise:

> The next bit is exact and boring. Don't skip it. I'd skip it.

Markup: wrap in `.slip`, which the linter skips and `styles.css` renders as a
pinned-in paper aside. **Never** voice a legal, privacy, or format claim. A
funny privacy promise is a broken privacy promise.

### The Cast — ~10%

Named characters keep their own voices — canon, from the same Swift block. Penny
Blackletter, the Fae, the Headmistress, and the five Chapters speak for
themselves in the sections about them, in quotes. This is also the rhythmic
release valve: it breaks up the first person before it wears out.

---

## 3. Objects are alive

The single highest-leverage rule, and the one that keeps this from sliding into
whimsy.

**Every section needs at least one ordinary thing doing something of its own.**
Not scenery. Not decoration. It acts.

State it as plain fact. The thing simply does the thing:

> The kettle's sulking.
> That chair saved your seat all afternoon and it wants credit.
> The door gave up halfway.
> Your keys hid on purpose. They do that.
> The rain showed up without asking and won't take a hint.

Give them small, petty, specific wants: to be picked up, to be left alone, to
win an argument, to not be moved, to get away with something.

Keep them ordinary and household: kettles, doors, cups, socks, lamps, stairs,
chargers, the fridge, rain, a chair, a coat.

**An object gets a mood and an errand, never a lesson.** A chair does not
represent rest. A chair wants someone to sit in it.

---

## 4. Banned

| Banned | Why | Instead |
|---|---|---|
| "the Book", "ReEnchanted keeps…" | Third person. The #1 canon violation | "I kept it." |
| `like`, `as if`, `as though`, `seems to`, `almost as if` | Similes and hedging | "The lamp leaned in." |
| animism, spirit, soul, folklore, culture, symbol, symbolize, represents, "we tend to see" | Explaining the idea. You are not describing a belief about objects | The kettle is sulking. That's the whole sentence |
| "users", "readers", "your journey", "mindfulness", "self-care", "wellness" | Product-speak and therapy-speak | "you" |
| "we understand that…", "it's okay to…", "be gentle with yourself" | Soothing, absolving, blessing | Cut it. Say the next true thing |
| "seamlessly", "effortlessly", "delightful", "magical experience" | Brochure | Say what happens |
| Em-dash pileups, three-clause sentences | The Book interrupts itself; it doesn't nest | Full stop. New sentence |

---

## 5. The Curse

The Rut of Routine is the page's antagonist. It is canon — see
[`NarrativeCore.swift`](../Shared/NarrativeCore.swift), `// MARK: - The Rut of
Routine`, and the `the-nothing` lore entry in `app.js`.

Doctrine that carries over to the page:

1. It is **erasure**, not a monster with a speech. Colours dulling, details
   going missing, rooms becoming merely rooms.
2. It **never guilts the reader**. It is not their failure and not their fault.
   It makes story, not shame.
3. It **can be driven back and never cured**. Every win is temporary. Say so.
4. It is **universal**. It is not something that starts when you stop using the
   app.

**It appears exactly four times, escalating.** Sprinkled everywhere it becomes
wallpaper and stops being frightening.

### Blaming the Curse is not absolving the reader

These look alike and are not:

> "Nothing has to be terribly wrong for life to feel flat. **It isn't your
> fault.**" — absolution. Comfort with no culprit. Banned.

> "**A Curse is eating your days, and it isn't your fault.** I can prove it." —
> blame, correctly addressed. The line only works because a villain is named in
> the same breath.

Doctrine 2 says the Rut never guilts and makes story, not shame. Naming the
thing actually responsible does that job; reassuring the reader about their
feelings does not. So the test is not whether the words sound kind — it is
**whether a culprit is present in the sentence.** No culprit, cut it.

| Beat | Where | Job |
|---|---|---|
| 1 · Named | The Curse band, under the hero | Give the page a villain |
| 2 · Blamed | How it works | Explain why the loop is shaped this way |
| 3 · Fought | Spells & the Wonder Compass | Make the features read as weapons |
| 4 · Defied | Final CTA | Send them off with stakes |

---

## 6. Voice carries the fact, never replaces it

The hard constraint. A cold visitor must still learn what this *is* in five
seconds.

Every voiced paragraph must still contain its literal claim. If you delete the
personality from a sentence and no product fact remains, the sentence is
decoration and should be cut or rewritten.

> **Bad:** "I'll go rummaging in the dark for you." *(no claim)*
> **Good:** "At night I take your kept pages, the weather, what you ate, and the
> choices you made inside my fiction, and I plait them into one story about the
> day you actually had." *(same voice, carries the whole feature)*

`<title>`, the meta description, `alt` text, and headings that carry search
intent stay plain. Search engines and screen readers are not the audience for
the bit.

---

## 7. The Smell Test

Read the paragraph aloud and ask:

1. Does it say **I**?
2. Is there **a thing doing something of its own**?
3. Would a **brand** have written this sentence? If yes, kill it.
4. Is it **comforting** the reader? If yes, kill it.
5. Did I explain the magic instead of **doing** it?
6. Would a clever nine-year-old with a very long memory say it this way?
7. **Is the product claim still in there?**

Fail any of 1, 2, or 7 and it goes back.
