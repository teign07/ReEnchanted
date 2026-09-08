# The Stillroom — kitchen receipts, and what the Book does with them

A stillroom was the room in a house where somebody made the preserves, the
cordials, the remedies and the rubs. The book they kept there — the *stillroom
book* — is the closest real thing to what this app is pretending to be:
handwritten, added to by everybody who owned it, and completely unbothered
about the line between a recipe, a remedy and a charm. Elizabeth Freke's runs
to two volumes and has gingerbread on one page and a cure for the bite of a mad
dog on the next.

That is the object. This plan builds it.

## The name

Public-facing, the things in it are **Kitchen Receipts**. "Receipt" is the real
word — it was what English called a recipe until the twentieth century, and a
stillroom book says receipt on every page — but on its own nobody knows what it
means, and the codebase already has `RelationshipPageReceipt`,
`LivedQuestReceipt` and "First Reading receipts" meaning something else
entirely. "Kitchen" does the disambiguating, keeps the old word, and points at
kitchen witchery, which is where half the corpus comes from.

The room is **The Stillroom**. Room names in this Book are allowed to be
strange — the Gazetteer, the Outer Stacks, Pages Rising — and the Book glosses
this one itself, once, in its own voice.

The type is `KitchenReceipt`. **`Recipe` is unavailable**: 193 uses across
`StoryRecipe`, `PublicationEditionRecipe`, `LeafDecorationRecipe` and
`BookWorkings.Recipe`.

## Decision record

- **Kitchen Receipts, not Recipes.** Naming collision plus a reader who has no
  idea what a bare "receipt" is.
- **The tally is archive-derived.** No new ledger. A receipt is made because a
  kept Page says so. This is the fourth system in a row built this way and it
  has not drifted once.
- **The Book verifies by looking, and never adjudicates.** Vision can see
  `bread`, `cake`, `pie`, `pastry`, `soup`, `casserole`, `dumpling`, `scone`,
  `pudding`, `oven`, `kitchen`, `candle`, `fire` and a long fruit and vegetable
  list — 73 relevant labels. It confirms *a cake happened*, not *that is the
  simnel cake*. So recognition is a flourish on top of the reader's own mark,
  never a gate. A book that calls you a liar because your kitchen light is bad
  is a bad book.
- **Failure is a page, not an absence.** "It didn't work" is a keepable
  outcome with its own prose. Most cooking in most kitchens goes slightly
  wrong and a book that only records triumphs is a book you stop writing in.
- **Wicker Dares are not invented here.** They already exist — 47 of them, with
  `challenge`, `proofPrompt`, `pressureCost`, an outward/inward split and a
  consent law. This adds a kitchen lane to a working system.
- **Fiction and reality are both in, and the Book says which.** Same law as the
  Correspondences shelf.

## House laws

**1. Safety is a corpus constraint, not a disclaimer.**
No home canning or preserving instructions — botulism is fatal and the guidance
is genuinely dangerous to get subtly wrong. No foraging identification. No
medicinal, therapeutic or health claims. No casual instructions involving raw
egg, undercooked meat or hot sugar work. Allergens named in the ingredient
line, every time. **Anything that could hurt somebody is left out rather than
caveated.** A magic book that gives you botulism is a bad magic book.

**2. Could this be a page in a book somebody's grandmother kept?**
Five ingredients or so, mostly things already in the house, no macros, no
forty-minute prep, no shopping trip. If it needs a special tin it is the wrong
receipt. Same bar the spells corpus runs under: relatable, surprising, easy to
do.

**3. The Book cooks in its own voice.**
Simple, direct, clear, childlike, anthropomorphic, independent, obsessed with
breaking the Reader out of the Curse. Contractions. The pot is a character. A
starter is hungry, not "requires feeding". Bread genuinely is alive and the
Book does not have to pretend that is a metaphor.

**4. Nothing in the lore becomes a claim about the reader.**
Ingredient correspondences are inherited furniture with `observable: nil`, the
same law `CreatureLore` runs under. The *tally* is evidence. The folklore is
not.

---

# Phase 0 — Festival pages do not reach the desk

**This blocks everything after it and it is a live bug in shipped code.**

Verified 2026-09-08 by probing the curator directly on seven major feast days —
Samhain, Yule, Christmas, Imbolc, Beltane, Lammas, the September equinox:

- `FestivalPageSourceAdapter` produces a good candidate on every one of them,
  scoring 83–85, correctly tagged, with its mechanic and grief valve attached.
- The candidate reaches `candidatePool` — 63 candidates, festival present at
  score 85, `deskJob: .play`.
- **It is seated on zero of the seven.** Not at `limit: 3`, and not at
  `limit: 12`, where `todaysSky` (score 70) and `affirmations` (58) hold `.play`
  slots and the festival still does not appear.

So it is neither a supply problem nor a ranking problem: an admission rule in
`canAdd` is refusing it. The exact rule is not yet isolated — the first task is
to instrument `canAdd` and name it, rather than guess. The strong suspicion is a
composition cap that cannot distinguish a page that is available every single
day from one that is available once a year.

**What this costs today.** The world feast calendar is one of the richest things
in this app — every tradition through ICU calendars rather than a table, ranked,
with grief valves, one-tap permanent rest, and five celebration mechanics — and
it has been reaching nobody.

**The fix, in order:**

1. Instrument and name the rule. Add the probe as a permanent test.
2. **A festival floor.** A feast day is the one page whose entire value is that
   it is *today*. It cannot be deferred, it cannot be caught up with, and its
   candidate window is a single day per year. That is exactly the argument
   `CuratorMirrorFloor` and the loop floors already make, and it is stronger
   here than for either of them. The floor runs after composition, like the
   others, and stands down on a sheltering or distressed day — the composer
   already removes grieving feasts on a hard day and that stays.
3. The floor promotes, it does not conjure: only a candidate the adapters
   already produced, exactly like `placeLoopFloor`.
4. A test per major feast that the page is seated.

**A general lesson worth writing down.** Caps that ration by frequency-of-family
punish rarity. Anything whose candidate window is one day a year needs a floor,
not a score. Check the same question of the annual and seasonal editions.

---

# Part I — The receipts themselves

## Phase 1 — The model and the corpus

```swift
struct KitchenReceipt: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    /// One line, the Book's own. Never a subtitle.
    var blurb: String
    /// Five-ish. Plain names, allergens explicit.
    var ingredients: [String]
    /// Numbered, short, in the Book's voice.
    var steps: [String]
    /// Where it comes from, and whether it is real.
    var provenance: ReceiptProvenance
    /// What it says it is for. Folklore, not nutrition.
    var sense: String
    var minutes: Int
    var season: [Int]?          // month numbers, nil = any
    var feastIDs: [String]      // ties into WorldFeastAlmanac ids
    /// What Vision could plausibly see when it is done.
    var looksLike: [String]
    var tags: [String]
    var packID: String
}

enum ReceiptProvenance: String, Codable {
    case folk       // a real custom, with a tradition line
    case story      // out of a book, and the Book says which book
    case academy    // the Academy made it up and must admit so
    case reader     // the reader wrote it in, or got it from a person
}
```

Corpus target: **40 for the first pack**, split roughly folk / story / academy.

**Folk, real, seasonal.** Soul cakes for All Souls. Colcannon at Samhain with
the coins in it. Lammas bannock. Simnel for Mothering Sunday. Hot cross buns.
Barmbrack. Seed cake. Stone-ground oatcakes. Elderflower cordial in June.
Bonfire toffee. A king cake with the bean.

**Barmbrack is the exemplar of the whole plan.** A real Irish Samhain loaf with
charms baked in — ring for a marriage, coin for money, rag for poverty, thimble
for spinsterhood. It is a genuine folk custom that is *already a divination
mechanic*, and `CelebrationMechanic.throwTheBones` is sitting right there
waiting for it.

**Story.** Turkish delight. Cram and seed cake from Tolkien. Stone soup — which
is a receipt whose method is a con and whose result is real. The madeleine, on
the grounds that fiction made a real biscuit famous. Gingerbread, with the
Book's opinion about the house.

**Academy.** Inventions that admit they are inventions, under the standing
attribution law. A "receipt" for something that cannot be cooked at all is
allowed here and is probably the funniest page in the pack.

## Phase 2 — The Stillroom, and the tally

The room is the fourth of its shape after Correspondences, the Gazetteer and
the Bestiary: a `BookObjectDivision`, a shelf view, a row.

**Three states, all archive-derived, no ledger:**

| State | Evidence |
|---|---|
| **Made** | a kept Page tagged `stillroom-made:<id>` |
| **Went wrong** | a kept Page tagged `stillroom-wrong:<id>` |
| **Still owed** | offered, never kept |

The reader marks it with countersign chips, which the capture sheet already
renders: **Made it · Made it badly · Not yet.** Their sentence goes in
`userInput` and becomes the marginalia — printed back at them above the steps
the next time the receipt surfaces, which is exactly what a stillroom book
looks like after two generations.

**A made receipt keeps its date, weather and place**, because
`BookPageContextSnapshot` now carries all three. "The first time you made this
it was snowing" is free.

## Phase 3 — The receipt that ages

The single best idea in this plan.

An offered-and-never-made receipt is a standing offer, and the Book keeps it
open. *"I gave you this at Imbolc. It's August."* Same shape as the place that
has gone quiet and the creature that stopped turning up, and it works for the
same reason: a thing you meant to do and didn't is the Curse's exact signature,
and the Book is not going to pretend it forgot.

Rest and phrasing follow `Gazetteer.quietLeaf`: ranked by how quickly the
reason spoils, and the seasonal ones spoil hardest. A receipt for elderflower
cordial is worth raising in June and worthless in November, and the Book should
say so — *"this one's only good for about three more weeks."*

---

# Part II — The calendar

## Phase 4 — Feast and season keying

Depends on Phase 0. Once festival pages actually surface:

- A receipt with a matching `feastIDs` entry rides the feast day, offered
  alongside the celebration rather than competing with it.
- Seasonal receipts key on `season` months and on the Book's own seasons — Mud,
  Gold, Stick, Deep Winter — which is the vocabulary Anchors are already
  stamped with.
- **The eve matters more than the day.** Most of these want making the night
  before. A receipt keyed to Samhain surfaces on the 30th, not the 31st, and
  says why.

## Phase 5 — The second day

Some things are better tomorrow. A made soup earns a quiet follow-up beat the
next evening: *"It'll be better tonight. It's been thinking."* Cheap, uses the
existing rest machinery, and it is the kind of small correct observation that
makes an object feel like it knows what it is talking about.

---

# Part III — The proof

## Phase 6 — The Book sees what you made

The machinery shipped with the Bestiary commission. `Bestiary.sightings(in:)`
files creatures out of a `VisualFactPacket`; a `Pantry` files food out of the
same packet, with the same laws: whole-label matching, a `.likely` filing floor,
group-label suppression, and a validator that refuses anything not in the
vocabulary.

A photograph on a receipt page that comes back `pastry` or `bread` or `soup`
lets the Book say the thing almost nothing else in the app can say: **"I can see
it. You actually did it."**

**The law from the decision record holds absolutely.** The reader's own mark is
the record. Recognition is a flourish. Nothing is ever refused, downgraded or
questioned because Vision failed to see it — the failure mode of getting this
backwards is a book that argues with somebody holding a cake.

## Phase 7 — What it smelled like

The one ask a book can make that no camera can answer. *"What did the kitchen
smell like?"* — as a margin ask on made receipts, and later as a grimoire
feature. Smell is the sense with the shortest path to memory and the longest
odds of being written down anywhere else. This is the app's whole argument in
one question.

---

# Part IV — The ingredients

## Phase 8 — Ingredient lore, unlocked by use

Straight reuse of the `CreatureLore` pattern shipped 2026-09-07: rows in the
`InheritedCorrespondence` shape, `observable: nil` on every one, held back until
the reader has actually used the ingredient, surfaced in their own section of
the Correspondences shelf.

Kitchen witchery is *already* a correspondence table and has been for four
hundred years. Rosemary for remembrance — and it is in Ophelia, and it is on the
Australian dawn service, and Greek students wore it in their hair for exams.
Salt for a boundary. Honey for sweetening a person toward you. Bay burned for a
wish. Cinnamon for speed. Bread and salt for a threshold. Apples cut across the
core for the star inside, which is the only piece of folk divination that is
simply true and checkable in eight seconds.

Where the folklore is testable against something real, the Book says which —
same tension that made the crow row the best thing on the Bestiary shelf.

## Phase 9 — The starter is a character

If the reader keeps a sourdough starter, it is not an ingredient. It is a
**Cast member**: it has a name the reader gives it, it gets hungry on a clock,
it can be neglected, and it can die. `CustomCastMember` already exists,
anthropomorphism is canon, and the hunger clock is the most honest recurring
obligation this app could possibly offer, because it is *real*.

The Book being genuinely worried about it is not a mechanic. It is the correct
response to the situation.

---

# Part V — Missions and dares

## Phase 10 — Kitchen missions

A kitchen thing that isn't cooking. These fit the existing playful-mission
shape.

Sharpen every knife in the house. Use the good plates on a Tuesday. Eat one
meal with no screen and no book. Cook the thing your family always got slightly
wrong, and get it wrong the same way on purpose. Throw out the spice you have
had since a previous address. Eat something you have decided you don't like.
Make tea for somebody without being asked.

## Phase 11 — Kitchen wicker dares

**Added to the existing `WickerDareRegistry`**, not a new system. The model
already carries everything needed — `challenge`, `proofPrompt`, `pressureCost`,
`goesOutward`, and a standing law that it never pushes past consent, legality,
property rules, or the reader's ability to say no without penalty. One of the 47
is already "Bow to the kitchen."

The gradient across all three tiers is **effort → attention → nerve**.

Give the entire batch away and keep none of it. Cook with no receipt and no
plan and no lookup. Eat outside in weather that is wrong for eating outside.
Make the thing you have been scared to make. Serve somebody a dish and tell them
nothing about it. Fire-festival dares — Beltane, Lammas, Samhain — gate on the
feast day and on Belief.

## Phase 12 — Ask someone for the receipt

**The best mission in the plan and possibly in the app.**

A stillroom book is full of other people's handwriting. This mission ends with a
real conversation with a real person, and a page in the Book with their name on
it, and a thing that person makes now living in the reader's own book.

It lands squarely in the People of the Book register and inherits its law
whole — the Witness Law, confirm-on-suggest, the grief valve. The Book never
voices the person; it holds what the reader wrote down.

A receipt with `provenance: .reader` and a named source is the one row on the
shelf the Book will be most careful with.

---

# Part VI — What the tally becomes

## Phase 13 — Cooking as evidence

The tally is a stream of dated, weathered, placed events, which is precisely
what `GrimoireLedger` eats.

*You bake when it rains. You have never once made anything that takes more than
an hour. The only thing you have made twice is the soup. You cook for other
people in October and for yourself in February.*

These are the Book's own findings, subject to every existing law: said in
advance what would falsify them, crossed out in public when wrong, never adopted
from the inherited folklore.

## Phase 14 — The printed stillroom

A year of made receipts, with the reader's own marginalia, set as a signature in
the annual edition. Their handwriting, their failures, the date it snowed.

This is the strongest physical-object argument the app has. Nobody else can
print this book, and it is the one artifact here that a person would plausibly
hand to somebody else.

---

# Deliberately not in this plan

- **Nutrition, macros, dietary tracking, calories.** Not what this is, and the
  register is actively hostile to it.
- **Substitutions engine, scaling, shopping lists, pantry inventory.** That is a
  recipe app. This is a stillroom book.
- **Any preserving, canning, fermenting-for-safety or foraging content.** See
  house law 1. This is a permanent exclusion, not a phase-later.
- **Rating receipts.** The tally is *made / went wrong / not yet*. Five stars
  would turn the reader's own kitchen into a review site.
- **Timers, step-by-step hands-free mode, voice guidance.** A receipt is a page
  to read, not an appliance.
- **Generated receipts.** Every one is authored. A language model inventing
  cooking instructions is the single clearest way this feature hurts somebody.
