# The Kitchen — November 2026 content pack

**Themes: kitchens, cooking, dining, Trencher.**

November is a feeding month. The pack gives the Book a Kitchen, fills it with
recipes that arrive on the right days, and hands the month to the one Cast
member who already owns it.

## The name

- The room is **the Kitchen**.
- The things in it are **recipes**. Not receipts. The historical word is lovely
  and unreadable, and a reader looking for what to cook should find the word
  they were looking for.
- **The Pantry** is the shelf inside the Kitchen where ingredient lore lives,
  and the type name for the food vocabulary Vision files against.
- The type is `KitchenRecipe`. Bare `Recipe` is unavailable — 193 uses across
  `StoryRecipe`, `PublicationEditionRecipe`, `LeafDecorationRecipe` and
  `BookWorkings.Recipe`.

## Ambrose Trencher, who was built for this

Trencher is already in the Cast and already carries the whole month. Nothing
below invents him. From `NarrativeCore.swift`:

> The cafeteria cook, and deliberately neither faculty nor student. Trencher
> works the serving line, feeds every faction without joining one, and owns the
> single domain every reader already practices daily. **His engine is the gap
> between the food he serves and the food he dreams about, which is the reader's
> own unlived life, handed back as an appetite rather than a reproach.**

His `unwrittenInterest` is a table of contents for this pack: *flavours he has
only ever read about, recipes in a dead relative's handwriting, what people cook
only for themselves, feeding someone as a way of saying the unsayable, and the
smell of a house on the one day a year it smells like that.*

His goals are the pack's three phases: **put one honest meal into the reader's
actual week; teach the reader to cook one thing well enough to give away; cook,
before the end, the dish he has been reading about for thirty years.**

His faults are its drama: *has never once cooked the meal he actually dreams
about, and calls that being realistic. Feeds people instead of talking to them.
Will not let anyone finish thanking him.*

He has edges already: **Vellum** reads a meal as fuel and a humane experiment
while he reads the same plate as love and the thing someone could not say —
"neither is wrong, which is what makes it a real argument." **Boggle** keeps the
rooms while he keeps the table, the Academy's two practitioners of unglamorous
magic. And **`trencher-feeds-wicker`** already exists, which is the door between
this pack and the 47 Wicker Dares.

He carries an estate-sale copy of *The Middlemost Cookery* everywhere and will
not say what he keeps looking for in it. His tags include `harvest` and
`gratitude`.

## The arc, and why it is the right one

The Book's standing job is breaking the Reader out of the Curse. Trencher has
read about one dish for thirty years and never cooked it, **and calls that being
realistic** — which is the Curse, stated by someone who does not know he is
describing it.

So November inverts the loop. The reader's own cooking is what gets Trencher to
the stove. Three acts, tracked against the reader's real tally:

1. **He feeds you.** Recipes arrive. The Kitchen fills.
2. **He asks you to feed someone else.** The give-away dare, the asked-for
   recipe, the meal made for one other person.
3. **He cooks the dish.** Gated on the reader's own tally, at the end of the
   month, once. The one time the Book is saved by the Reader.

## On gratitude, which was also November's

[[gratitude-journaling-pack]] targeted a November 2026 pack whose defining hook
is that an entry **names a recipient**. That is not a competing pack, it is this
one's emotional register: *feeding someone as a way of saying the unsayable* and
*will not let anyone finish thanking him* are the same idea from both ends.
Recommend merging rather than sequencing — a gratitude entry naming a person the
reader cooked for is stronger than either feature alone, and the Duskthorn
etiquette ("never say a flat thank you, say I'm grateful") gives Trencher's
refusal a reason in the world.

**Flagging rather than assuming.** If gratitude should stay its own pack, say so
and this drops it cleanly — nothing below depends on it.

## Decision record

- **Recipes, room = Kitchen, lore shelf = Pantry.**
- **The tally is archive-derived.** No new ledger; a recipe is made because a
  kept Page says so. Fifth system built this way and none has drifted.
- **Vision corroborates, never adjudicates.** 73 food labels are reachable —
  `bread`, `cake`, `pie`, `pastry`, `soup`, `casserole`, `dumpling`, `scone`,
  `pudding`, `oven`, `kitchen`, `candle`, `fire`, and a long fruit and vegetable
  list. It can confirm *a cake happened*, never *that is the simnel cake*. The
  reader's own mark is always the record.
- **Failure is a page.** "It didn't work" is a keepable outcome with its own
  prose. Trencher would rather hear that than nothing.
- **Wicker Dares are extended, not invented.** 47 exist, with `challenge`,
  `proofPrompt`, `pressureCost` and a consent law. One is already "Bow to the
  kitchen."
- **Fiction and reality both, and the Book says which** — same law as the
  Correspondences shelf.

## House laws

**1. Safety is a corpus constraint, not a disclaimer.**
No home canning or preserving instructions — botulism is fatal and the guidance
is dangerous to get subtly wrong. No foraging identification. No medicinal or
health claims. No casual raw-egg or undercooked-meat steps. Allergens named in
the ingredient line, every time. **Anything that could hurt somebody is left out
rather than caveated.**

**2. No generated recipes, ever.** Every one authored. A language model
inventing cooking instructions is the single clearest way this pack hurts
someone. Gemma may write *about* a recipe; it never writes one.

**3. Could this be a page in a book somebody's grandmother kept?**
Five ingredients or so, mostly things already in the house. No macros, no
shopping trip, no special tin. Same bar as the spells corpus.

**4. Trencher's voice is his own, not the Book's.**
Warm, blunt, unhurried, quietly ravenous. He puts food down in front of people
instead of asking what is wrong. He chalks the day's menu as one sentence about
the weather. He will not let anyone finish thanking him.

---

# Phase 0 — Festival pages reach the desk (DONE, 2026-09-08)

Shipped as `3b08fea`. Feast pages were surfacing on **zero** of seven major
feasts; three separate mechanisms were each eating them. The whole calendar
layer this pack schedules against now works, and a year-sweep test holds it.

The rule that came out of it applies directly here: **a Page whose candidate
window is a single day cannot be rationed by anything designed to ration a
recurring family.** Any November beat pinned to a date needs a floor, not a
score.

---

# Part I — The Kitchen

## Phase 1 — `KitchenRecipe`, and the corpus

```swift
struct KitchenRecipe: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var blurb: String              // one line, Trencher's or the Book's
    var ingredients: [String]      // five-ish, allergens explicit
    var steps: [String]            // short, numbered, in voice
    var provenance: RecipeProvenance
    var sense: String              // what it is said to be for. Folklore, not nutrition.
    var minutes: Int
    var season: [Int]?             // month numbers; nil = any
    var feastIDs: [String]         // ties to WorldFeastAlmanac
    var looksLike: [String]        // what Vision could plausibly see
    var tags: [String]
    var packID: String
}

enum RecipeProvenance: String, Codable {
    case folk       // a real custom, with a tradition line
    case story      // out of a book, and the Book says which
    case academy    // the Academy invented it and must admit so
    case reader     // written in, or asked for from a real person
}
```

**40 for the pack**, weighted to November: harvest, dark evenings, feeding
people, the last of the garden.

**Folk.** Soul cakes for All Souls (Nov 1–2, and the souling rhyme is a real
door-to-door custom). Colcannon. Barmbrack. Bonfire toffee and parkin for
Bonfire Night. Stir-up Sunday, the last Sunday before Advent, where everyone in
the house takes a turn at the pudding and wishes. Lammas bannock, simnel and hot
cross buns for the seasons this pack does not cover but the Kitchen keeps.

**Barmbrack is the exemplar.** A real Samhain loaf with charms baked in — ring
for a marriage, coin for money, rag for poverty. A genuine folk custom that is
*already a divination mechanic*, and `CelebrationMechanic.throwTheBones` is
sitting there waiting for it.

**Story.** Turkish delight. Cram and seed cake. Stone soup — a recipe whose
method is a con and whose result is real, which is the most Trencher thing in
the corpus. The madeleine.

**Academy.** Inventions that admit they are inventions, under the standing
attribution law. *The Middlemost Cookery* is the in-world source, and what
Trencher keeps looking for in it is a thread the pack can pull all month.

## Phase 2 — The room, and the tally

The Kitchen is the fifth room of its shape after Correspondences, the Gazetteer,
the Atlas and the Bestiary: a `BookObjectDivision`, a shelf, a row.

| State | Evidence |
|---|---|
| **Made** | a kept Page tagged `kitchen-made:<id>` |
| **Went wrong** | a kept Page tagged `kitchen-wrong:<id>` |
| **Still owed** | offered, never kept |

Countersign chips, which the capture sheet already renders: **Made it · Made it
badly · Not yet.** The reader's sentence lands in `userInput` and becomes
marginalia, printed back above the steps next time — which is what a family
cookbook looks like after two generations.

A made recipe keeps its date, weather and place, because
`BookPageContextSnapshot` carries all three now. *"The first time you made this
it was snowing"* is free.

## Phase 3 — The recipe that ages *(named for the pack)*

An offered-and-never-made recipe is a standing offer the Book keeps open.
*"I gave you this at Imbolc. It's August."*

Same shape as the place that has gone quiet and the creature that stopped
turning up, and it works for the same reason: **a thing you meant to do and
didn't is the Curse's exact signature**, and the Book is not going to pretend it
forgot.

Ranked by how fast the reason spoils, like `Gazetteer.quietLeaf`. Seasonal ones
spoil hardest — elderflower cordial is worth raising in June and worthless in
November, and the Book should say so: *"this one's only good for about three
more weeks."*

Trencher's version is worse and better: he does not nag, he **re-offers**. He
puts it down in front of you again. That is his fault as a mechanic — *feeds
people instead of talking to them* — and it is much kinder than a reminder.

---

# Part II — The month

## Phase 4 — The November world event

A `WorldEventPack` with `calendar: WorldEventCalendar(startMonth: 11, startDay:
1, durationDays: 30)`, carrying `authoringManifests` from the start — per
[[issue-manifest-wired-no-content]], a pack without them installs as zero atoms
and its beats compete unprotected.

Beats pinned to real days: **All Souls** (Nov 1–2, soul cakes), **Bonfire
Night** (Nov 5, parkin and toffee), **Stir-up Sunday** (last before Advent, the
wish), **Thanksgiving** where the reader keeps it, and **the last day**, which
is Trencher's.

Each pinned beat gets a floor, not a score. See Phase 0.

## Phase 5 — Feast and season keying

Recipes with a matching `feastIDs` ride the feast day alongside the celebration
rather than competing with it. Seasonal ones key on `season` months and on the
Book's own seasons — Mud, Gold, Stick, Deep Winter — the vocabulary Anchors are
already stamped with.

**The eve matters more than the day.** Most of these want making the night
before. A recipe for Samhain surfaces on the 30th and says why.

## Phase 6 — The second day

Some things are better tomorrow. A made soup earns a quiet follow-up the next
evening: *"It'll be better tonight. It's been thinking."* Cheap, uses existing
rest machinery, and it is the kind of small correct observation that makes an
object feel like it knows what it is talking about.

---

# Part III — The proof

## Phase 7 — The Book sees what you made

The machinery shipped with the Bestiary commission. `Bestiary.sightings(in:)`
files creatures out of a `VisualFactPacket`; **`Pantry`** files food out of the
same packet under the same laws — whole-label matching, a `.likely` floor,
group-label suppression, and a validator that refuses anything outside the
vocabulary.

A photograph that comes back `pastry` or `bread` or `soup` lets the Book say the
thing almost nothing else in the app can say: **"I can see it. You actually did
it."**

House law holds absolutely: recognition is a flourish on the reader's own mark.
Nothing is ever refused or questioned because Vision failed to see it. The
failure mode of getting this backwards is a book arguing with somebody holding a
cake.

## Phase 8 — What it smelled like

Trencher's own interest: *the smell of a house on the one day a year it smells
like that.* The one ask a book can make that no camera can answer, and the sense
with the shortest path to memory and the longest odds of being written down
anywhere else. A margin ask on made recipes, and later a grimoire feature.

---

# Part IV — The Pantry

## Phase 9 — Ingredient lore, unlocked by use

Straight reuse of the `CreatureLore` pattern shipped 2026-09-07: rows in the
`InheritedCorrespondence` shape, `observable: nil` on every one, held back until
the reader has actually used the ingredient, in their own section of the
Correspondences shelf.

Kitchen witchery is already a correspondence table and has been for four hundred
years. Rosemary for remembrance — in Ophelia, on the Australian dawn service, in
the hair of Greek students sitting exams. Salt for a boundary. Honey for
sweetening a person toward you. Bay burned for a wish. Bread and salt for a
threshold. Apples cut across the core for the star inside, which is the one
piece of folk divination that is simply true and checkable in eight seconds.

Where the folklore is testable against something real, the Book says which —
the tension that made the crow row the best thing on the Bestiary shelf.

Trencher's line on all of it is already written: *a potato is owed the same
attention as saffron.*

## Phase 10 — The starter is a character *(named for the pack)*

If the reader keeps a sourdough starter it is not an ingredient, it is a **Cast
member**: a name the reader gives it, a hunger clock, and the ability to be
neglected and to die. `CustomCastMember` already exists, anthropomorphism is
canon, and the hunger clock is the most honest recurring obligation this app can
offer, **because it is real**. Nothing else in the Book gets hungry whether or
not you open it.

The Book being genuinely worried about it is not a mechanic; it is the correct
response.

Trencher gives the starter away in the first place — that is how it enters the
Cast — and a starter is the one gift that obliges you to keep something alive.

---

# Part V — Missions and dares

## Phase 11 — Kitchen missions

A kitchen thing that isn't cooking, in the existing playful-mission shape.
Sharpen every knife. Use the good plates on a Tuesday. Eat one meal with no
screen and no book. Cook the thing your family always got slightly wrong, and
get it wrong the same way on purpose. Throw out the spice you have had since a
previous address. Eat something you have decided you don't like.

## Phase 12 — Kitchen wicker dares

**Added to `WickerDareRegistry`**, not a new system, and `trencher-feeds-wicker`
is the canonical door. The gradient across all three tiers is **effort →
attention → nerve**.

Give the entire batch away and keep none of it. Cook with no recipe and no plan
and no lookup. Eat outside in weather that is wrong for eating outside. Make the
thing you have been scared to make. Serve somebody a dish and tell them nothing
about it.

## Phase 13 — Ask someone for the recipe *(named for the pack)*

**The best mission in the pack, and it is Trencher's own interest verbatim:
recipes in a dead relative's handwriting.**

A family cookbook is full of other people's handwriting. This mission ends with
a real conversation with a real person, a page in the Book with their name on
it, and a thing that person makes now living in the reader's own Kitchen.

It sits in the People of the Book register and inherits its law whole — the
Witness Law, confirm-on-suggest, the grief valve. The Book never voices the
person; it holds what the reader wrote down. A recipe with `provenance: .reader`
and a named source is the row the Book is most careful with in the whole app.

The grief valve is not optional here. "Ask someone for the recipe" lands
differently when the person you would have asked is dead, and Trencher —
who collects exactly those recipes — is the right one to know it.

---

# Part VI — What the tally becomes

## Phase 14 — Cooking as evidence

The tally is a stream of dated, weathered, placed events, which is what
`GrimoireLedger` eats. *You bake when it rains. You have never once made
anything that takes more than an hour. The only thing you have made twice is the
soup. You cook for other people in October and for yourself in February.*

The Book's own findings, under every existing law: said in advance what would
falsify them, crossed out in public when wrong, never adopted from inherited
folklore.

## Phase 15 — Trencher cooks the dish

The end of the month, once, gated on the reader's own tally.

He has read about it for thirty years and called not cooking it being realistic.
The reader's November is the evidence that undoes that, and the Book hands it to
him. **The one time in the app the Reader breaks somebody else out of the
Curse.**

He will not let them finish being thanked for it.

## Phase 16 — The printed Kitchen

A year of made recipes, with the reader's own marginalia, set as a signature in
the annual edition. Their handwriting, their failures, the date it snowed.

The strongest physical-object argument the app has: nobody else can print this
book, and it is the one artifact here a person would plausibly hand to somebody
else.

---

# Deliberately not in this plan

- **Nutrition, macros, calories, dietary tracking.** Not what this is, and
  Vellum's reading of a meal as fuel is a *character position the pack argues
  with*, not a feature.
- **Substitutions, scaling, shopping lists, pantry inventory.** That is a recipe
  app. This is a kitchen in a magic book.
- **Any preserving, canning, fermenting-for-safety or foraging content.**
  Permanent exclusion. See house law 1.
- **Star ratings.** The tally is made / went wrong / not yet. Five stars turns
  the reader's own kitchen into a review site.
- **Timers, hands-free mode, voice guidance.** A recipe is a page to read, not
  an appliance.
- **Generated recipes.** See house law 2.
