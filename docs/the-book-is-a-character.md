# The Book Is a Character (umbrella doctrine)

Goal: the reader develops a relationship with **a character**, not a set of
mechanics. Every surface in the app is the same Book — dynamic, coherent,
excitable, sometimes despondent, never a servant and never a report.

This doc is the frame. The work sits in five programs:

- **Program A — Interjections.** The Book volunteering. Full plan in
  [`book-interjections-moonshot.md`](book-interjections-moonshot.md). This is
  the main line of work and nothing here supersedes it.
- **Program B — De-mechanization.** Every existing surface reads as the Book
  rather than as a report. Audit + fixes, below.
- **Program C — Coherence.** One Book across all surfaces, with a mood that
  actually reaches the prose.
- **Program D — The Character Lint.** The enforcement that makes "crush
  anywhere it feels mechanical" a finite job instead of an infinite one.
- **Program E — Let’s Chat.** Not a chatbot bolted onto the Book: the room where
  its will, unfinished business, memory, and changing relationship with the
  reader can answer back.
- **Program F — The Book's Weather.** Mood with a cause, a size, and a
  duration, told rather than declared. Full plan in
  [`the-books-weather-plan.md`](the-books-weather-plan.md). It supersedes C1,
  which shipped as plumbing: stance currently reaches page prose but only
  prepends fixed strings, and two of the seven stances change nothing at all.

## Implementation checkpoint — 2026-08-10

Program A's complete first pass is live in the working tree. The same pass also
landed the first umbrella work: stance now alters the handoff of reflective
Pages; the Loom explains its own nocturnal habit; primary Loom evidence is
named as memory instead of a dated database row; internal sensory tokens no
longer leak into its prose; mechanical Page titles and “Chat with the Book”
have been re-authored, with that doorway now called “Let’s Chat”; and
`BookCharacterLint` inspects generated prose after
interpolation. Exact evidence remains available as a separate, tappable layer.

The second character pass completed the circulation system: the full durable
interior can now volunteer itself through interjections; opening a secret,
tradition, want, conflict, or old dispute advances that state; replies create
autobiography, revision, disagreement, repair, or a clean release; stance now
reaches every Book-owned Page family rather than three notice surfaces; and
the Book's physical acts are literal dog-ears, reader-word underlines, smudges,
and leaves held open to older evidence. The generated-prose lint now reads the
margin and its follow-up line too, and reports servant phrasing, mechanism
language, naked artifact counts, taxonomy titles, and date rows.

The old per-surface `feedbackPrompt` metadata has been removed. The reader can
still correct an interpretation, lift the pencil, or forbid that way of reading;
it is framed as authority inside the relationship, not as product feedback.
“Let’s Chat” no longer narrates archive-search counts in the room: the Book
climbs into the Stacks, opens the leaves that tug back, and keeps exact source
authority underneath as a separate inspectable layer.

This checkpoint now passes the complete signed 54-target Debug device build and
is installed on Rabbit. All 15 focused interjection contracts pass, including
the 90-day non-repetition simulation. The generated character census also
passes across every stance with no mechanical seams. Launch and visual
verification remain blocked by the locked phone.

The wider census pass also removed a second crop of reader-visible machinery:
Radio no longer recites boost arithmetic, Clippings say where the Book cut them
from, Loom progress says what is caught and what remains loose, mission-making
belongs to the Book rather than Gemma, Glow describes the Book's edges rather
than a product state, and a blank chat answer leaves the Book chewing its ribbon.
These are small strings with a large cumulative effect: one willful creature is
now holding the tools instead of explaining a control panel.

The broad shared-workspace confirmation run executed 2,609 tests. 2,594 passed,
three were skipped, and 12 out-of-scope archive, binding, Braid, shop-event, print, and legacy
welcome-copy assertions remain red. They do not touch the interjection, stance,
margin, character-lint, or Let’s Chat contracts.

---

## The finding

**The Book's sentences are in character. The Book's nouns are not.**

The prose is genuinely good. From the Relational Loom constellation page
(`Shared/SourceAdapters.swift:3955`):

> I've found more than a pair this time. […] I've left their corners touching.
> Do they belong together?

From the Sensory Loom page (`Shared/SourceAdapters.swift:4079`):

> I didn't bring this symbol with me. The Pages made it between themselves. Do
> you see it too?

That is the feral child. Nothing is wrong with the voice. What's wrong is
everything the voice is holding:

1. **Comma-joined enum dumps inside sentences.**
   `"Each branch arrived by its own road: \(outcomeLabels.joined(separator: ", "))"`
   (`SourceAdapters.swift:3960`). The Book is reading a field aloud.
2. **Laundered slugs.**
   `"There was another small agreement around them too: \($0.replacingOccurrences(of: "-", with: " "))."`
   (`SourceAdapters.swift:4077`) turns the token `rainy-evening` into prose by
   deleting a hyphen. **20 sites** across `Shared/` and `InsideCoverApp/` do
   this.
3. **Date-stamped evidence rows.** `"Mar 4 · Photograph"`, `"Mar 4 · Ink"`,
   `"Mar 4 · <page title>"` (`NoticePatternCard`, 21 construction sites, 8 of
   them date-stamped). This is a filing system's label, not a Book's memory.
4. **Naked counts.** `reason: "One photograph called across the Stacks. \(count)
   Pages of ink answered."` A tally, spoken.
5. **Feedback prompts.** 17 `"feedbackPrompt"` metadata sites. "Do these parts
   of your Book truly meet here?" is a thumbs-up/thumbs-down in costume.

**The character speaks, and then hands you a spreadsheet.** That is what reads
as AI-servant — not the voice, the *artifacts* the voice is made to carry.

### Second finding: the taxonomy leak

`BookPageType.title` (`Shared/PageModel.swift:97`) is half a character's
vocabulary and half a class list.

In character, and proof the whole set could be: *Inner Weather · One-Sentence
Souvenir · A Quote to Keep · Outer Stacks · What Keeps Finding What · I Notice ·
I Remembered · My Pocket · A Talisman's Errand · Wicker's Dares · The Two
Readings · The Front Matter · A Tale, Bound*.

Spec vocabulary, leaking: *Journal Page · Body Page · Weather Page · Location
Page · Quip Page · Lore Page · Gossip Page · Story Page · Letter Page · Support
Guild Page · Pack Page · Game Page · Hour Page · Fuel Log · Notes · Plain Page ·
Welcome Page · Help and Tips · Chat with the Book*.

The suffix **"Page"** is the tell — it is the type name surfaced to the reader.
And *"Chat with the Book"* is the single most servant-shaped string in the app:
it is a chatbot affordance, named as one, on a surface whose entire premise is
that this is not that.

### Third finding: nothing explains itself in character

The Loom is a real, sophisticated thing — `RelationalLoom` compares every
trustworthy pair of dimensions with contrast tests, `SensoryLoom` crosses
photographs with ink. A reader meeting a constellation page has no idea any of
that is happening, and there is no page anywhere that says what the Loom *is*.
The only explanations that exist are `.helpTips` ("Practical guidance, tricks,
and ideas for using me well") — a manual, in a Book that should never have one.

A character doesn't ship documentation. A character tells you about its habit.

---

## The doctrine — four laws

These are the laws every surface is held to, and what Program D enforces.

**1. The Book never cites. It remembers.**
No date-stamped evidence rows, no ID-shaped labels, no "source: ". The receipts
stay — they are load-bearing, they are the reason the reader trusts that the
Book isn't making things up — but they are spoken as memory: *"the wet Tuesday
you wrote about the bus"*, not *"Mar 4 · Ink"*. Keep the card tappable. Change
what it is called.

**2. No slug reaches prose.**
Every tag, token, enum label, or ID that becomes reader-visible passes through
an authored phrase table first. Zero `replacingOccurrences(of: "-", with: " ")`
in any string that a reader can see. If a token has no authored phrase, the
Book says nothing about it — silence beats a laundered slug.

**3. No naked quantities.**
No counts, tiers, strengths, percentages, similarity scores, or streak numbers
in reader-visible text. If a quantity matters, it becomes a felt comparison:
*"more than a pair"* (which the Loom page already does correctly, one line
above where it dumps the enum list) rather than *"3 Pages"*.

**4. Every surface explains itself in the Book's own terms — as a habit it has,
not a feature it offers.**
The Loom page says what the Book does with loose Pages at night, in first
person, because it is the kind of thing this Book cannot stop doing. Not "this
page shows connections found between your entries."

### And the servant tells to crush on sight

Help-desk register. Assignments. Compulsory closing questions (`BookAsideForm`
already forbids these — lift the rule to every surface). Optional-announcing
phrases: "no pressure", "when you're ready", "whenever you like", "feel free
to". Anything that describes the app to the reader instead of the Book talking
to them. Thumbs-up/thumbs-down affordances wearing a sentence.

---

## Program B — De-mechanization

Surface-by-surface, ordered by how often a reader actually sees it.

**B1. The Loom family** (`bookConnections`, the Loom paths inside
`BookNoticesPageSourceAdapter`, `Constellations`). Named by the reader as the
worst offender and it is. Three fixes: evidence cards spoken as memory (Law 1),
kill the enum-dump and slug-launder sentences (Laws 2–3), and give the Loom a
first-person account of itself (Law 4).

**B2. `I Notice` / `I Remembered`.** Same three fixes. Additionally: strip the
17 `feedbackPrompt` sites. The Book asking "do they belong together?" *in its
own closing line* is character; the same question rendered as a rating control
below is a mechanic. Keep the former, delete the latter — Program A Phase 6's
*go on / you're wrong / not now* chips replace it with something that is
already in voice.

**B3. The title vocabulary.** Re-author every `BookPageType.title` and
`shortTitle` that ends in "Page" or names a category. “Chat with the Book” is
now **“Let’s Chat.”** This is one small diff with an
outsized effect: these strings are on every card the reader ever sees.

**B4. Onboarding, help, and empty states.** The places an app is most tempted
to speak as software. `.helpTips` becomes the Book being opinionated about how
it likes to be used, not a manual. Empty states become the Book having nothing
to say yet and saying *that*, in character.

**B5. Everything else,** worked through under the Character Lint's report mode
rather than by hand.

---

## Program C — Coherence: one Book, with a mood

Dynamic-but-coherent is the hard half. Three levers:

**C1. Stance reaches the prose.** `BookStance`
(`Shared/LiteraryContinuity.swift:1588`) already models seven moods — curious,
protective, mischievous, hushed, contrite, intent, pleased — and already varies
the Book's *interior* lines. It does not reach page prose at all. Fix that:
every generated page passes through a deterministic stance filter, so **the same
Loom finding, on the same evidence, is told differently by an excited Book and a
despondent one.** Excited: longer, an interruption, an exclamation, the evidence
volunteered. Hushed: three sentences, no question, the evidence left where the
reader can find it. No model call — this is prose selection and pruning against
the stance, seeded per day.

This is the single change that most directly delivers "a feral child excitedly
telling you things. Or despondently."

**C2. One set of enthusiasms.** The Bleed picks interest columns
(`Shared/TheBleed.swift:237`), the interjections will pick preoccupations
(Program A Phase 3), the Loom picks connections, the Edition picks what to bind.
Right now these are four independent selectors. They should read from one
preoccupation index so the Book that was fascinated by doorways this week is
fascinated by doorways *everywhere* this week — that's what makes it one mind
rather than four features that each discovered you like birds.

**C3. Stance and preoccupation are visible in the Front Matter, never as
stats.** The reader should be able to tell what kind of mood the Book is in by
reading it, not by a meter. No exposed levels, ever — the existing relationship
law already forbids turning counts into scores; extend it to mood.

---

## Program D — The Character Lint

`scripts/voice-lint.mjs` already holds `LandingPage/` to `BookVoice.animism`,
with two exemption markers (`slip` for exact unvoiced fact — specs, privacy,
consent; `cast` for named characters, who keep their own voices). That design is
right and should be copied wholesale.

But the in-app tells live in **string interpolation**, not in literals, so a
static lint would miss almost all of them. The in-app equivalent must be a
**Swift test that builds pages and lints the generated prose**: construct desks
across a matrix of states (empty archive, mature archive, distress, rutward,
each stance, each depth), render every surface, and assert:

- no date patterns and no bare digits in reader-visible strings, outside text
  the reader themselves wrote
- no hyphen-slug residue — cross-checked against the actual tag vocabulary, so
  it catches *new* laundering, not just today's 20 sites
- no banned servant phrases, no optional-announcing phrases
- no reader-visible title ending in "Page" or naming a type
- a first-person coverage floor per page body (the landing lint already
  computes exactly this — reuse the measure)
- the same two exemptions as the landing lint: **slip** for consent, privacy,
  and legal surfaces, which must stay plain and unvoiced; **cast** for named
  characters, who are allowed to call the Book "the Book" because they are not
  it

Report mode drives Program B5: it prints the ranked list of remaining
mechanical surfaces, so de-mechanization has a finish line instead of being a
feeling.

---

## Program E — Let’s Chat: a relationship chamber, not a chatbot

“Let’s Chat” must never open as an empty input waiting for a command. The Book
is already alive before the reader arrives. It may have brought a subject, be
avoiding one, be pleased with a kept Page, still be wrong about something, or
want to ask about an unfinished piece of business.

**E1. The Book opens.** Each conversation begins with one grounded initiative
from the shared preoccupation index: a live fascination, kept Page, promise,
dispute, acquired taste, Loom finding, or previous conversation thread. The
opening is shaped by stance. Sometimes the honest opening is “I had nothing.
Then you opened me.” Never a generic greeting and never an assistant prompt.

**E2. It has a will.** Add a small vocabulary of conversational acts:
`volunteer`, `pursue`, `disagree`, `wonder`, `deflect`, `withhold`, `admit`,
`repair`, `changeSubject`, `askForCompany`. The Book may say it does not know,
decline the servant role, resist a false premise, or return to its own subject.
Willfulness must never become coercion: it cannot punish absence, demand care,
or make the reader responsible for its mood.

**E3. Conversation leaves consequences.** Persist compact conversation
receipts rather than raw “engagement”: subject, act, stance, evidence, what the
reader corrected, what was left unfinished, and whether the Book promised to
return. Those receipts feed interjection heat, contrition, callbacks, Loom
attention, and future openings. A conversation changes the Book’s conduct
elsewhere or it was only chat UI.

**E4. One mind everywhere.** The conversation grounder, interjection editor,
Loom, Bleed, and Editions all read the same preoccupation index. If the Book is
fixated on doorways today, it may open with one, underline one in a kept Page,
notice one in the Loom, and bind one later—but no surface independently
rediscovers the interest.

**E5. The relationship becomes legible without a meter.** Early conversations
are startling and guarded. Acquainted ones develop callbacks. Trusted ones can
carry disagreement and repair. Companion conversations can begin in the middle
of old business. Depth changes access, candour, and form—not warmth scores,
streaks, or exposed levels.

**E6. Truth before performance.** Every factual memory in conversation keeps
its current evidence and permission authority. The Book can interpret,
associate, and have an opinion; it cannot invent a reader memory to be
interesting. “I don’t know” is a character act, not a model failure.

**Acceptance law:** after five conversations, a reader should be able to name
what this particular Book is preoccupied with, how it tends to disagree, and
what remains unfinished between them. If the same transcript could belong to
any reader’s Book, the feature has failed.

---

## Order of work

Program A stays the main line and is unchanged. Alongside it:

1. **D first, in report mode only** (no failures yet). It turns "somewhere it
   feels mechanical" into a ranked list, which is what makes the rest
   estimable.
2. **B3** (titles) — smallest diff, largest surface-area effect, no engine risk.
3. **C1** (stance reaches prose) — the biggest character gain per unit of work
   in this doc, and it makes every later prose fix pay off twice.
4. **B1 + B2** (Loom, Notices, Remembers) — the surfaces called out by name.
5. **C2** (one preoccupation index) — lands naturally with Program A Phase 3,
   which builds that index anyway. Do them together.
6. **D turned to failing**, then **B4**, then **B5** against the report.
7. **E1 + E3** (the Book opens, and conversations leave receipts), then **E2**
   and **E4**. This uses Program A’s existing spine instead of creating a
   parallel “chat personality.”

Program A Phase 6 replaces the `feedbackPrompt` mechanic, so B2 should not
re-author those prompts — it should delete them and wait.
