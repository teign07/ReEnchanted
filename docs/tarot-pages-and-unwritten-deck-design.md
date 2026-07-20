# Tarot Pages & The Unwritten Deck

**Product and art design document**
**Status:** Proposed production bible
**Last updated:** July 17, 2026
**Working product name:** Tarot Pages
**Working deck name:** **ReEnchanted Tarot: The Unwritten Deck**

---

## 1. The decision in one page

Tarot Pages is a low-frequency reflective Page that can surface naturally on the
reader's three-slot desk. It does not arrive with a card already chosen. It
arrives as a small, unopened deck and lets the reader choose:

- **One card — A Page for Now**
- **Three cards — Root / Weather / Door**

The deck itself is a complete, 78-card Rider–Waite–Smith-compatible tarot deck,
not a tarot-like oracle deck. It retains the traditional names, suits, numbering,
court ranks, and recognizable symbolic structure. Every illustration is redrawn
through ReEnchanted's visual and narrative language: graphite and ink,
transparent watercolor, antique paper, academy-file marginalia, restrained
jewel colors, the five Chapters, the Wonder Compass, and the Great Unwritten
Chapter.

The reading ritual protects the reader's own meaning-making:

1. The reader chooses one or three cards.
2. They may hold a question or leave the field blank.
3. They cut or touch the deck.
4. The app fixes the random draw locally and saves it immediately.
5. The art is revealed before any interpretation.
6. The Page asks, **“What caught your eye?”**
7. The reader can then open the traditional meaning and, optionally, Aurora
   Whispers' reading.
8. The reader's own final reflection is what becomes canonical if the Page is
   kept.

Aurora Whispers is the host, not an oracle with privileged access to truth. Her
Tidecrest fault is part of the design: she sees the most hopeful plausible
version of a card and says so openly. The cards make the present answer back;
they do not predict the future, diagnose the reader, or make decisions for them.

The production target is:

- 78 accepted card-face illustrations
- 1 orientation-neutral card back
- 1 finished Aurora Whispers portrait
- code-rendered borders, titles, numerals, suit marks, and accessibility labels

That is 80 new accepted raster assets. A realistic production budget is
approximately 200–350 generations and surgical edits, because consistency and
symbol verification—not raw generation—will be the largest part of the work.

---

## 2. Why Tarot belongs in ReEnchanted

ReEnchanted is not a generic journal, chatbot, or prediction engine. It is a
private, attentive Book that treats ordinary life as material worthy of literary
attention. Tarot fits when it is used as a structured instrument for noticing,
not as an authority.

The fit is unusually strong:

- A tarot card is already a **Page**: image, title, symbol, ambiguity, margin.
- A spread is a temporary **story structure** made from juxtaposition.
- A reading asks the reader to notice what they bring to an image.
- Keeping a reading creates a dated artifact that may mean something different
  later.
- Rider–Waite–Smith imagery is legible enough to support beginners and deep
  enough to reward return.
- ReEnchanted's Chapters give the four suits and the shadow register a coherent
  house language without replacing tarot's established system.

The feature fails if it becomes any of the following:

- an AI fortune teller;
- a daily streak machine;
- a yes/no answer button;
- a slot machine for repeatedly drawing a nicer card;
- a personality score built from card frequency;
- a library of dozens of spreads presented before the reader knows why they
  opened the Page;
- a generic fantasy deck wearing ReEnchanted colors;
- an incomplete “major arcana only” novelty shipped as a full tarot experience.

Version one has no permanent Tarot tab, deck hub, or daily-card destination. The
invitation surfaces as a Page; unfinished readings reopen from that Page, and
kept readings live in the archive. One-card and three-card readings are the
entire spread menu.

---

## 3. Product principles

### 3.1 A mirror, not a verdict

Every interpretation is framed as a possible way to read the image. Copy uses
phrases such as:

- “One way this card can read…”
- “The hopeful edge Aurora sees…”
- “The harder edge of the card…”
- “What changes if this is about attention rather than prediction?”

Avoid:

- “This will happen.”
- “The universe is telling you…”
- “Your person is definitely…”
- “Yes,” “No,” or probability claims.
- medical, legal, financial, fertility, mortality, or safety decisions made by
  a card.

### 3.2 Reader interpretation comes first

The card is visible before keywords. The first prompt is sensory and specific:

> What caught your eye first?

The app should never hurry to prove that its interpretation is clever. The
reader's noticed detail is the beginning of the reading.

### 3.3 Structured before generated

The draw, orientation, spread position, canonical meanings, and saved artifact
are typed local data. Runtime prose is an optional layer on top. An interrupted
model call can never change or lose the draw.

### 3.4 Random means random

The local model does not choose cards. The question, archive, mood, weather,
Chapter, and desired answer do not weight the deck. Once a reading starts, every
card remains available.

### 3.5 Difficult cards remain difficult

Death, the Devil, the Tower, the Three of Swords, and the Ten of Swords are not
softened into decorative self-care. Their imagery can be non-gory and humane
without removing rupture, grief, attachment, ending, or consequence.

### 3.6 The Page is a daily ritual

The project has a one-in/one-out rule and only three home slots. Tarot should be
a once-per-calendar-day reflection source after the First Door. Today's
face-down invitation receives one ordinary desk slot if ranking did not already
choose it. It can replace a generic reflection or reference candidate, but it
does not evict an earned milestone or the evening braid.

Keeping a reading closes Tarot for the rest of that local calendar day. The
next day begins cleanly even if fewer than 24 hours have passed. This makes the
ritual feel daily rather than like a timer the reader has to remember.

### 3.7 The kept reflection is canonical; the draw is not evidence

A random sequence of cards is not a discovered fact about the reader. The Book
may remember the reader's explicit question, noticed detail, and final
reflection. It must not later claim, for example, that “Swords keep following
you” as personal evidence merely because random draws produced them.

---

## 4. Current tarot product research

The recent app market clusters around four approaches:

1. **Learning systems.** Labyrinthos offers a large spread library, custom and
   freeform readings, reversals, journaling, and structured card study.
2. **Daily ritual and visual identity.** Mystic Mondays centers a daily pull,
   calendar, concise keywords, and a strong proprietary deck aesthetic.
3. **Reference and practitioner tools.** Tarot! and Tarot Journal emphasize
   traditional meanings, saved readings, user-authored meanings, and journaling.
4. **AI reader products.** Newer apps such as Aluma add combination readings,
   conversational follow-ups, widgets, and physical-deck scanning.

The useful lesson is not to combine every feature. A small 2026 CHI interview
study of AI-assisted tarot users found a recurring tension: people appreciated
help with combination meanings, but experienced readers worried that immediate
AI interpretation could displace intuition. The most relevant recommendation
for ReEnchanted is progressive assistance: let the reader interpret first, then
offer layers of help.

### What Tarot Pages should borrow

- A clear visual ritual.
- Traditional meanings for learning.
- Saved readings with the reader's own notes.
- Combination interpretation for three-card spreads.
- Reversals as an optional preference.
- A later way to log a reading made with a physical deck.

### What Tarot Pages should refuse

- Streaks, coins, scarcity timers, or “lucky” rerolls.
- Seventy spreads on the first screen.
- Unlimited clarifier cards.
- An always-open AI chat that turns a reading into dependency.
- Accuracy scoring or “prediction confirmed” prompts.
- Card-frequency personality claims.
- Push notifications that imitate urgency or supernatural summons.

---

## 5. Naming and in-world framing

### Recommended public name

**ReEnchanted Tarot: The Unwritten Deck**

This is searchable and honest about being tarot while giving the physical and
digital deck an ownable title.

### Recommended feature name

**Tarot Pages**

It describes the app surface plainly and sits naturally beside Story Pages,
Weather Pages, and the Book of You.

### In-world description

> A deck from the Academy's unnumbered cabinet. It does not tell the future.
> It makes the present hold still long enough to be read.

### Host

**Aurora Whispers**

Aurora is already canonical in `Shared/BookReferenceLibrary.json`: Tidecrest,
dreamy, adventurous, associated with tarot readings, and inclined to imagine the
best possible version of everything. That optimism is her perspective, not a
product claim.

Recommended host line:

> “I can show you the brightest honest reading I see. You still get the last
> word.”

Aurora appears in the Page chrome, transitions, guide copy, and optional
interpretation. She should not appear on the card faces. Named cast would turn
universal archetypes into lore trivia and make readers ask “what does this
character mean?” instead of meeting the card.

---

## 6. The deck system

### 6.1 Traditional structure remains intact

- **22 Major Arcana**, numbered 0–21 in Rider–Waite–Smith order.
- **56 Minor Arcana** in Wands, Cups, Swords, and Pentacles.
- Four court cards per suit: Page, Knight, Queen, King.
- Traditional card names remain unchanged.
- Traditional suit names remain unchanged.
- Strength is VIII and Justice is XI, following Rider–Waite–Smith.

The product should say **Rider–Waite–Smith (RWS)** and credit illustrator
Pamela Colman Smith prominently. “Rider–Waite” alone erases the artist whose
visual system makes this project possible.

### 6.2 ReEnchanted correspondence

The correspondences guide palette, material, marginalia, and voice. They do not
claim that the Academy Chapters are the historical origin of tarot.

| Tarot system | ReEnchanted register | Visual materials | Core motion |
|---|---|---|---|
| Wands | Emberheart | ember-red wax, gold leaf, ash-black staffs | agency, appetite, making, beginning |
| Cups | Tidecrest | sea glass, tidal blue, foam white, rain marks | feeling, relationship, presence, change |
| Swords | Riddlewind | ink-black steel, sky grey, warm brass ciphers | thought, language, decision, conflict |
| Pentacles | Mossbloom | living moss, old silver, parchment cream, pressed seals | body, work, home, resource, tending |
| Major Arcana | The Great Unwritten Chapter | all five Chapter marks, Academy thresholds, the Compass | the reader's larger passage |
| Shadow register | Duskthorn | black violet, thorn green, tarnished silver | friction, reversal, boundary, necessary darkness |

**Duskthorn is not a fifth suit.** It is the deck's cross-cutting shadow
register. It appears most strongly in reversals and traditionally difficult
cards, but it can sharpen any card whose honest meaning has been avoided.

**Riddlewind is more than Swords.** The Wind Cipher also governs the act of
reading cards together: relationship, juxtaposition, and the new meaning that
exists between images.

### 6.3 The Instrument Law and the suit of Wands

ReEnchanted canon says that magic is written, never waved. The traditional suit
must still be called **Wands** for tarot literacy and interoperability.

Art rule:

- depict Wands as sprouting staffs, walking sticks, measuring rods, branches,
  banner poles, and practical wooden implements;
- never depict a person casting a spell by waving one;
- the Magician raises an opinionated pen or quill, while the four suit emblems
  remain present on the table;
- when writing instruments appear, they behave like ReEnchanted instruments:
  chosen, particular, and a little opinionated.

### 6.4 Reversals

Ship with reversals **off by default**. Offer them in Page settings after the
reader has completed at least one reading.

A reversal is not the “bad” version of a card. The content model should store:

- `lightMeaning`: direct, available, outward, or moving;
- `shadowMeaning`: blocked, inward, excessive, avoided, or asking for repair.

If reversals are enabled, orientation is decided by the local draw and persisted.
The art does not need a second asset.

---

## 7. Reading experience

### 7.1 How the Page surfaces

The desk candidate appears unopened. It can show:

- a face-down deck;
- Aurora's wind-tugged ribbon;
- one sea-glass accent;
- the line **“The deck has left a page open.”**

No card has been drawn yet. Dismissing this invitation does not consume a draw.

Recommended curation policy:

- available only after the First Door is complete;
- one reading may be kept per local calendar day;
- today's unopened invitation receives an ordinary desk slot;
- no new invitation while an unfinished Tarot draft exists;
- suppressed while the existing distress signal is active;
- disabled through normal source preferences;
- strong base score in the reflection/reference lane;
- never displaces an earned milestone or evening braid;
- eligible for a small Belief boost only after the reader has kept a useful
  reading, just like other page families.

Suppression decides only whether the invitation appears. It must never remove
“difficult” cards from a chosen reading.

### 7.2 State machine

```text
invitation
  -> choose spread
  -> optional question
  -> cut/touch deck
  -> draw fixed and autosaved
  -> reveal
  -> reader's first look
  -> traditional meaning
  -> optional Aurora synthesis
  -> reader reflection
  -> keep or gather cards
```

Once the draw is fixed, closing and reopening returns to the same cards,
orientations, question, and stage.

### 7.3 One card: A Page for Now

Use when the reader wants a single image to sit beside the day.

Prompt:

> Hold a question, or leave the space open.

Position label:

> **For now**

Interpretation sequence:

1. Full card art.
2. “What caught your eye?”
3. Card name and 3–5 canonical keywords.
4. A short light and shadow reading.
5. Optional: “Let Aurora read beside me.”
6. “What will you keep from this?”

### 7.4 Three cards: Root / Weather / Door

This should be the only three-card spread in version one.

| Position | Reader-facing question | Interpretive boundary |
|---|---|---|
| **Root** | What is underneath this? | context, inheritance, assumption, source—not a deterministic past |
| **Weather** | What is moving through now? | present condition, tension, or atmosphere—not identity |
| **Door** | Where does agency live? | opening, choice, experiment, or next honest question—not a command |

This spread is distinctly ReEnchanted without renaming tarot cards. It also
prevents the familiar Past / Present / Future spread from implying prediction.

Three-card reveal:

- reveal one card at a time;
- allow the reader to pause between cards;
- ask for one first-look note after all three are visible;
- show individual meanings before combination synthesis;
- keep the whole spread visible while Aurora speaks about the relationships.

### 7.5 Assistance levels

The reader can stop at any level:

1. **Just the cards** — art, title, position.
2. **Open the field notes** — bundled keywords and light/shadow meanings.
3. **Aurora's reading** — local synthesis grounded in the cards, positions,
   question, and reader's optional first-look note.
4. **Another angle** — one bounded alternative reading, not an open-ended chat.

The final prompt always returns authorship:

> What feels true, useful, or worth disagreeing with?

### 7.6 Keeping, abandoning, and revisiting

- The draw is autosaved as a private draft immediately after selection.
- **Keep this Page** archives the spread and its reader-authored reflection.
- **Gather the cards** abandons the draft without pretending it never happened;
  it records only source fatigue, not an archive Page.
- There is no **Draw again** button inside a reading.
- After seven days, a kept Page may be eligible for a gentle return:

  > “Has the way you read this changed?”

Do not ask whether the cards were “accurate.” Hindsight is another reading, not
a prediction score.

---

## 8. Interpretation and voice

### 8.1 Bundled canonical content

Every card ships with original ReEnchanted-authored content:

- 3–5 keywords;
- one light meaning;
- one shadow meaning;
- two visual anchors to notice;
- two reflection prompts;
- a concise meaning for each of the three spread positions;
- accessibility description of the picture;
- content notes where appropriate.

Do not copy prose from modern commercial guidebooks. Public-domain historical
sources may inform the system, but all reader-facing language should be newly
written in ReEnchanted's voice.

### 8.2 Aurora's runtime input

Version one synthesis should receive only:

- card IDs and orientations;
- spread positions;
- the bundled canonical meaning packet;
- the reader's optional question;
- the reader's optional first-look note;
- the voice and safety contract.

It should **not** silently read the archive. A later explicit option could say
“Read beside my recent Pages,” with a visible receipt of exactly which Pages
were used. Hidden personalization would make a reflective ritual feel invasive.

### 8.3 Aurora voice contract

Aurora is:

- dreamy but concrete;
- hopeful without denying hard cards;
- Tidecrest: interested in this moment more than destiny;
- drawn to what might still become possible;
- candid that she is offering a perspective.

Aurora is not:

- omniscient;
- therapeutic or clinical;
- a generic breathy mystic;
- certain about another person's private thoughts;
- allowed to turn ambiguity into prediction;
- allowed to override the reader's own interpretation.

Suggested synthesis shape:

1. **The picture together** — one paragraph about the cards' relationship.
2. **The hopeful edge** — Aurora's characteristic reading.
3. **The thorn in it** — the honest tension, expressed without melodrama.
4. **A door you could try** — one optional, small experiment or question.
5. **The last word is yours** — return to the reader.

### 8.4 High-stakes boundary

If the question asks a card to make a medical, legal, financial, safety,
fertility, mortality, or crisis decision, Aurora should not answer the decision.
She can name the emotional question beneath it and invite an appropriate
real-world source of help.

In-world line:

> “Don't let a picture make that call for you. We can read what the choice is
> stirring, but the decision belongs with real information and real help.”

---

## 9. Visual art bible

### 9.1 The governing visual sentence

> A Pamela Colman Smith-readable tarot tableau found inside an Enchantify
> Academy field dossier: sparse graphite and ink, delicate crosshatching,
> transparent watercolor, warm worn paper, restrained jewel-color evidence,
> and a little living marginalia.

The order matters. **The card tableau is the first read. Marginalia supports it.**
Existing character and location dossiers are intentionally dense; a tarot card
must remain readable at phone-thumbnail size.

### 9.2 House-style sources already in the project

The closest existing anchors are:

- `LabyrinthTalismanTideGlass`
- `LabyrinthCharacterLydiaBoggle`
- `LabyrinthLocationStacks`
- the style and exclusions in `ILLUSTRATIONS.md`
- `BookPalette` and `PageVisualStyle` in
  `InsideCoverApp/BookSurfaceViews.swift`

Existing Labyrinth dossiers are 1122 × 1402. They are useful style references,
not the final card ratio.

### 9.3 Card-face composition

Each card has two production layers:

1. **Generated illustration plate**
   - full-bleed portrait scene;
   - no title, numeral, suit label, logo, border text, or watermark;
   - generous crop-safe area;
   - all required symbolic objects visible;
   - one clear focal hierarchy.
2. **Code-rendered card frame**
   - card number or rank;
   - traditional title;
   - suit mark;
   - fine border and Chapter accent;
   - optional Academy catalog ticks;
   - accessibility and localization support.

Even though current image generation can render text well, titles should remain
code-rendered. A programmatic frame gives all 78 cards identical typography,
correct spelling, Dynamic Type alternatives, localization, and future physical
layout control.

### 9.4 Materials and mark-making

Required:

- graphite construction lines that remain faintly visible;
- black or warm-brown ink contours;
- delicate crosshatching, not comic-book hatching;
- transparent watercolor blooms and tide marks;
- warm sepia paper;
- restrained shadow;
- small areas of jewel color;
- weathered, imperfect edges;
- symbolic marginalia tied to the card rather than random decoration.

Allowed in moderation:

- taped evidence scraps;
- compass ticks;
- academy stamps without legible generated text;
- botanical samples;
- pinholes, thread, wax, pressed leaves;
- a small Chapter or talisman echo;
- subtle ink stains and fingerprints.

Avoid:

- glossy digital fantasy concept art;
- generic fantasy pinups;
- polished anime;
- plastic skin;
- photoreal celebrity likeness;
- heavy oil paint;
- neon magical glow;
- airbrushed gradients;
- overfull scrapbook collage;
- room-first compositions;
- random celestial clutter;
- illegible AI writing;
- extra suit objects added only as decoration;
- sanitizing every difficult scene into serenity.

### 9.5 People

- Use archetypal, unnamed figures rather than established cast.
- Represent varied ages, bodies, skin tones, gender expression, mobility, and
  family structures across the deck.
- Avoid making all Queens young women or all Kings older men. Retain traditional
  rank names while treating each court as a mode of relationship to the suit.
- Keep faces expressive but not portrait-dominant.
- Hands, gaze, body direction, and interaction with objects are card meaning and
  must be specified and reviewed.

### 9.6 Symbol fidelity

The deck may transform setting and material, but it should retain the RWS
symbolic scaffold strongly enough that an experienced reader recognizes a card
before reading its title.

For every card, create a required-symbol checklist. Examples:

- Three of Swords: one heart, exactly three swords, rain.
- Seven of Cups: exactly seven vessels with distinct visions.
- Ten of Pentacles: exactly ten pentacles, generations, arch/home.
- Moon: moon, two towers, two canines, water creature, winding path.

Exact object count is a release criterion, especially for pip cards. Generated
beauty does not excuse the wrong number of cups.

### 9.7 Chapter palette is an accent, not a wash

Most cards share parchment, graphite, ink, and quiet watercolor. Suit identity
comes from a controlled 15–25% color accent:

- Wands: ember red, gold leaf, ash black.
- Cups: sea-glass green, tidal blue, foam white.
- Swords: sky grey, ink black, warm brass.
- Pentacles: moss green, parchment cream, soft silver.
- Duskthorn moments: black violet, thorn green, tarnished silver.

### 9.8 The card back

The back must be perfectly orientation-neutral so it does not reveal reversals.

Recommended design:

- a closed central Book;
- a symmetric Wonder Compass rose;
- the five talisman marks arranged as a balanced quincunx or ring;
- Wind Cipher geometry connecting them;
- sea-glass and lamp-gold highlights on ink-violet ground;
- fine parchment fibers and worn-gilt edge;
- no readable text and no obvious “top.”

Asset name: `TarotBackUnwritten`

---

## 10. Card-by-card art manifest

These are composition briefs, not final image prompts. Every final prompt also
receives the shared art bible, palette, required-symbol checklist, exclusions,
and crop instructions.

### 10.1 Major Arcana

| ID | Card | Reading core | ReEnchanted art direction and required anchors |
|---|---|---|---|
| `major-00-fool` | 0 — The Fool | beginning, trust, risk | A new reader at an Academy cliff-threshold, small white dog tugging at their hem, white rose, bright sun, tiny bundle, eyes lifted rather than watching the drop. A blank Page escapes the bundle. |
| `major-01-magician` | I — The Magician | agency, skill, manifestation | A standing writer with one hand pointing to earth and an opinionated pen raised to the sky; table holds staff, cup, sword, and pentacle; infinity sign, roses, lilies. No spellcasting wand. |
| `major-02-high-priestess` | II — The High Priestess | intuition, mystery, inward knowledge | Seated keeper between ink-black and parchment pillars, moon at feet, scroll partly hidden, veil patterned with pomegranates and palms; a closed living Book behind the veil. |
| `major-03-empress` | III — The Empress | abundance, creation, nurture | Crowned figure in a living Mossbloom garden, wheat, waterfall, heart shield with Venus mark, twelve-star crown; fabric and vines actively growing into the page margin. |
| `major-04-emperor` | IV — The Emperor | structure, boundary, stewardship | Figure on a stone throne carved with ram heads, red robe, mountains, orb and ordinary scepter; an Ember Seal presses a clean boundary into one corner. |
| `major-05-hierophant` | V — The Hierophant | tradition, teaching, chosen lineage | Academy teacher between two pillars with two learners below, crossed keys, raised teaching hand, three-tier crown translated into layered bookplates; solemn but not authoritarian. |
| `major-06-lovers` | VI — The Lovers | relationship, values, consequential choice | Two unclothed or simply draped figures standing apart in an open garden, tree and serpent behind one, flame tree behind the other, winged witness and sun above; mutual gaze and choice, not romance-only. |
| `major-07-chariot` | VII — The Chariot | direction, will, held opposites | Armored traveler in a wheeled Academy book cart beneath a star canopy, black and white sphinx-like paper beasts, city behind; no reins, movement governed by attention. |
| `major-08-strength` | VIII — Strength | courage, compassion, inner steadiness | Calm figure gently closing or opening the mouth of a lion-like ink creature, infinity sign, flowers, mountain; no domination or violence. |
| `major-09-hermit` | IX — The Hermit | solitude, search, inner lamp | Elder on a high Stacks landing holding a six-pointed lamp and staff, snow or mist below; the lamp illuminates only the next few steps. |
| `major-10-wheel` | X — Wheel of Fortune | change, cycle, turning | A great Compass-and-card-catalog wheel with RWS letter and elemental echoes, serpent descending, Anubis-like figure rising, sphinx above, four winged book witnesses in the corners. |
| `major-11-justice` | XI — Justice | truth, consequence, balance | Direct-gazing figure between pillars holding upright sword and balanced scales, red robe, square clasp, violet veil; both tools ordinary and exact. |
| `major-12-hanged-man` | XII — The Hanged Man | pause, surrender, changed perspective | Serene figure suspended by one foot from a living story-door shaped like a T, free leg bent, halo, hands behind back; voluntary stillness, no distress. |
| `major-13-death` | XIII — Death | ending, transformation, inevitability | White skeletal rider on white horse with black banner and white rose, fallen crown, figures of several ages, two towers and rising sun; autumn pages becoming spring shoots. Do not omit death. |
| `major-14-temperance` | XIV — Temperance | integration, proportion, healing | Winged figure with one foot on land and one in water, pouring luminous ink-water between two cups, path to a crown-like light, irises; fluids visibly travel against gravity. |
| `major-15-devil` | XV — The Devil | attachment, appetite, chosen bondage | Horned archetypal figure above two loosely chained people, inverted torch, dark pedestal; chains visibly removable, expressions complicated rather than terrified. Duskthorn palette, no gore. |
| `major-16-tower` | XVI — The Tower | rupture, revelation, collapse | Academy tower struck by lightning, crown blown free, two figures falling, twenty-two flame marks, storm-black sky; torn pages fly outward, but the foundation is visible. |
| `major-17-star` | XVII — The Star | hope, renewal, openness | Unclothed or simply draped figure kneeling with one foot in a pool and one on earth, pouring water onto both, one great eight-point star and seven smaller stars, bird in tree; quiet night. |
| `major-18-moon` | XVIII — The Moon | uncertainty, imagination, projection | Full moon with profile between two Academy towers, dog and wolf, crustacean rising from water, gold path into hills; Tidecrest mist, sharp shadow, no horror styling. |
| `major-19-sun` | XIX — The Sun | vitality, clarity, joy | Childlike rider on a white horse beneath a banner, four sunflowers, walled garden, large radiant sun; warm paper and unapologetic marigold. |
| `major-20-judgement` | XX — Judgement | awakening, reckoning, answering | Winged herald sounding a trumpet above figures rising from open book-shaped coffers, mountains and tidal water; the call is heard differently by every figure. |
| `major-21-world` | XXI — The World | completion, integration, living whole | Androgynous dancing figure within a living laurel wreath, two small writing instruments in hand, four winged witnesses in corners; all five Chapter colors reconciled without becoming a rainbow wash. |

### 10.2 Wands — Emberheart

Wands are sprouting staffs and useful wooden implements, never spellcasting
wands.

| ID | Card | Reading core | ReEnchanted art direction and required anchors |
|---|---|---|---|
| `wands-ace` | Ace of Wands | spark, initiative | A hand from clouded paper offers one budding staff; distant keep, river, and hills; a faint Ember Seal glow in the wood grain. |
| `wands-02` | Two of Wands | planning, possibility | Figure on a battlement holds a small world and one staff while another is fixed to the wall; sea and settlement beyond. |
| `wands-03` | Three of Wands | expansion, waiting for return | Cloaked figure with back turned watches three ships from a height; three staffs, one held; gold-red sky. |
| `wands-04` | Four of Wands | welcome, milestone, belonging | Exactly four garlanded staffs form a threshold; two celebrating figures, distant gathering and Academy walls. |
| `wands-05` | Five of Wands | friction, practice, competing aims | Five distinct young people cross exactly five staffs in energetic confusion; read as contest or rehearsal, not battle. |
| `wands-06` | Six of Wands | recognition, visible success | Rider returns through a crowd carrying a laurel-crowned staff; exactly six staffs visible; public praise with a hint of performance. |
| `wands-07` | Seven of Wands | defense, conviction | Figure on uneven high ground braces one staff against six rising below; mismatched shoes preserved as a subtle RWS echo. |
| `wands-08` | Eight of Wands | speed, message, alignment | Exactly eight staffs fly diagonally across a clear sky over river and green country; no people, strong directional motion. |
| `wands-09` | Nine of Wands | endurance, guarded readiness | Bandaged watcher holds one staff before a fence of eight; alert eyes, worn academy wall, dawn beginning. |
| `wands-10` | Ten of Wands | burden, responsibility | Figure carries exactly ten bundled staffs toward a town, view partially blocked by the load; Emberheart ambition at its limit. |
| `wands-page` | Page of Wands | curiosity, message, first fire | Young or youthful messenger studies a sprouting staff in a dry landscape; salamander pattern, feathered cap, delighted attention. |
| `wands-knight` | Knight of Wands | pursuit, heat, impulsive motion | Knight on rearing horse drives forward holding a staff; desert pyramids/hills, salamander tunic, movement barely contained. |
| `wands-queen` | Queen of Wands | warmth, confidence, self-possession | Seated sovereign with sunflower and staff, black cat at feet, lions and sunflowers on throne; direct, welcoming gaze. |
| `wands-king` | King of Wands | vision, leadership, sustained fire | Seated sovereign holds living staff, salamander and lion motifs, small salamander at feet; posture ready to rise rather than fixed. |

### 10.3 Cups — Tidecrest

Use sea-glass vessels whose water behaves with emotional specificity. Keep exact
cup counts.

| ID | Card | Reading core | ReEnchanted art direction and required anchors |
|---|---|---|---|
| `cups-ace` | Ace of Cups | feeling, openness, overflowing | Hand offers one overflowing sea-glass cup, dove lowers a wafer or white petal, five streams descend into a pool with water lilies. |
| `cups-02` | Two of Cups | mutuality, exchange | Two figures exchange exactly two cups beneath caduceus and winged lion head; equal footing and eye line. |
| `cups-03` | Three of Cups | friendship, shared joy | Three varied figures raise exactly three cups in a circle, fruit and flowers underfoot; celebration without luxury-ad gloss. |
| `cups-04` | Four of Cups | withdrawal, reevaluation | Seated figure beneath a tree faces three cups while a cloud-hand offers the fourth; refusal may be discernment, not ingratitude. |
| `cups-05` | Five of Cups | grief, attention to loss | Cloaked figure looks at three spilled cups; two remain standing behind; bridge, river, and house in distance. |
| `cups-06` | Six of Cups | memory, innocence, return | Two children or figures of different ages exchange a flower-filled cup; exactly six cups, old courtyard, gentle sentry. |
| `cups-07` | Seven of Cups | fantasy, options, projection | Silhouetted viewer faces exactly seven floating cups containing distinct visions: face, shrouded figure, snake, tower, jewels, laurel, dragon. |
| `cups-08` | Eight of Cups | leaving, chosen search | Figure walks away from exactly eight stacked cups beneath eclipsed moon, crossing tidal ground toward mountains. |
| `cups-09` | Nine of Cups | satisfaction, wish, enoughness | Content figure sits before an arcing display of exactly nine cups; abundance with a slight guardedness in the folded arms. |
| `cups-10` | Ten of Cups | shared belonging, emotional home | Two adults or elders lift their arms while children play beneath an arc of exactly ten cups; home, river, green land; family form inclusive. |
| `cups-page` | Page of Cups | imaginative message, surprise | Youthful messenger holds one cup from which a fish peers; shore, waves, sea-glass blue clothing, amused rather than shocked. |
| `cups-knight` | Knight of Cups | invitation, romance, quest of feeling | Calm knight on white horse offers one cup, river and mountains behind; measured approach, wing motifs. |
| `cups-queen` | Queen of Cups | empathy, deep receptivity | Sovereign at water's edge studies an ornate closed cup, shell and water-nymph throne carvings, feet near tide but not submerged. |
| `cups-king` | King of Cups | emotional steadiness, diplomacy | Sovereign on a stone seat amid rough water holds cup and scepter, ship and sea creature behind; calm without emotional absence. |

### 10.4 Swords — Riddlewind

Swords are symbols of thought, language, truth, and conflict. Do not glamorize
violence. Warm-brass Wind Cipher marks can appear in geometry and margins;
Duskthorn enters the hardest cards.

| ID | Card | Reading core | ReEnchanted art direction and required anchors |
|---|---|---|---|
| `swords-ace` | Ace of Swords | clarity, truth, decisive thought | Hand offers one upright sword crowned with laurel and palm, six falling marks, mountains below; blade reflects a line of ink. |
| `swords-02` | Two of Swords | stalemate, protected decision | Blindfolded seated figure crosses exactly two swords before a rocky tidal sea, crescent moon; stillness as temporary protection. |
| `swords-03` | Three of Swords | heartbreak, painful truth | One anatomical-paper heart pierced by exactly three swords beneath rain clouds; restrained red-violet wash, no gore. |
| `swords-04` | Four of Swords | rest, recovery, deliberate pause | Recumbent figure in a chapel-library, one sword carved beneath and three hanging above, stained-paper window of blessing. |
| `swords-05` | Five of Swords | hollow victory, aftermath | Foreground figure gathers three swords while two figures depart; two more swords on ground, wind-torn water behind; ambiguous triumph. |
| `swords-06` | Six of Swords | passage, carrying what happened | Boat carries cloaked adult and child across water; ferryperson poles; exactly six swords stand in boat without sinking it. |
| `swords-07` | Seven of Swords | strategy, concealment, partial truth | Figure carries five swords away from tents while two remain planted; backward glance; strategy rather than cartoon villainy. |
| `swords-08` | Eight of Swords | restriction, narrowed perception | Loosely bound blindfolded figure among exactly eight swords on wet ground, distant keep; clear open path visible to viewer. |
| `swords-09` | Nine of Swords | anxiety, nightmare, mental pain | Figure sits upright in bed, face in hands; exactly nine swords on dark wall, quilt patterned with roses and signs; no monster. |
| `swords-10` | Ten of Swords | ending, exhaustion, no further denial | Prone cloaked figure with exactly ten swords, dark sky breaking into gold dawn, still water; symbolic and non-gory. |
| `swords-page` | Page of Swords | alertness, inquiry, restless mind | Youthful figure holds raised sword in both hands on windy ground, birds and racing clouds, hair and garments pulled by crosswinds. |
| `swords-knight` | Knight of Swords | charge, conviction, haste | Armored rider drives into storm with raised sword, bent trees and torn clouds; purposeful but unable to see much beyond the charge. |
| `swords-queen` | Queen of Swords | discernment, independence, honest speech | Sovereign in profile holds upright sword and extends open hand, cloud-cleared sky, butterflies and crescent marks; sorrow has sharpened, not frozen, her. |
| `swords-king` | King of Swords | reason, authority, ethical judgment | Front-facing sovereign holds sword slightly angled, butterfly and moon motifs, wind-tossed trees; intellectual authority under scrutiny. |

### 10.5 Pentacles — Mossbloom

Pentacles may appear as pressed brass-and-silver seals with the traditional
five-pointed star. They remain recognizable coins, not generic glowing orbs.

| ID | Card | Reading core | ReEnchanted art direction and required anchors |
|---|---|---|---|
| `pentacles-ace` | Ace of Pentacles | material beginning, opportunity | Hand offers one pressed pentacle above a flowering garden path and arch, mountain beyond; moss grows at the coin's edge. |
| `pentacles-02` | Two of Pentacles | adaptation, juggling demands | Figure loops exactly two pentacles in an infinity ribbon while two ships rise and fall behind; motion playful but effort visible. |
| `pentacles-03` | Three of Pentacles | craft, collaboration, being seen | Artisan works in an Academy arch while two others consult plans; exactly three pentacles in stonework; different kinds of expertise. |
| `pentacles-04` | Four of Pentacles | holding, control, protection | Seated figure holds one pentacle to chest, one under each foot, one above crown; city behind; grip both secure and constricting. |
| `pentacles-05` | Five of Pentacles | hardship, exclusion, available shelter | Two weathered travelers pass an illuminated window containing exactly five pentacles; snow, injury or mobility aid, warmth visible but not magically solved. |
| `pentacles-06` | Six of Pentacles | giving, power, reciprocity | Standing figure holds scales and gives coins to two people; exactly six pentacles arranged above; generosity and imbalance both legible. |
| `pentacles-07` | Seven of Pentacles | patience, assessment, cultivation | Gardener leans on tool studying a vine bearing exactly seven pentacles; one at feet or harvest basket, work paused for evaluation. |
| `pentacles-08` | Eight of Pentacles | practice, apprenticeship, repetition | Craftsperson engraves a pentacle at bench; exactly eight visible in work sequence; town distant, attention on skill. |
| `pentacles-09` | Nine of Pentacles | earned independence, cultivated pleasure | Figure in lush garden with hooded falcon or bird, grapes, exactly nine pentacles, distant home; solitary abundance without loneliness claim. |
| `pentacles-10` | Ten of Pentacles | legacy, home, generations | Elder, adults, child, and dogs beneath an arch/home; exactly ten pentacles in Tree-of-Life arrangement; lineage may be chosen family. |
| `pentacles-page` | Page of Pentacles | study, practical beginning | Youthful figure lifts and studies one pentacle over a green field, furrowed earth and distant trees; complete concentration. |
| `pentacles-knight` | Knight of Pentacles | reliability, patience, steady work | Still dark horse and armored rider hold one pentacle over plowed land; no charge, weight and readiness in the posture. |
| `pentacles-queen` | Queen of Pentacles | embodied care, resourcefulness | Sovereign in a green garden cradles one pentacle, rabbit nearby, goat and fruit motifs; care grounded in material reality. |
| `pentacles-king` | King of Pentacles | stewardship, durable abundance | Sovereign on bull-and-vine throne holds pentacle and scepter, grapes, flowers, city behind; prosperity shown as tending, not conquest. |

---

## 11. Image-generation production workflow

The art is generated during production and bundled with the app. No reader's
tarot session should call a cloud image model.

OpenAI's current image workflow supports generation, editing, multiple image
references, detailed composition constraints, and flexible output sizes. The
official prompting guidance recommends explicit invariants and small,
single-change editing passes instead of repeatedly overloading or replacing a
good image. That is exactly the right workflow for a 78-card consistency
project.

### 11.1 Build the style-lock packet first

Every generation session receives labeled references:

1. **Composition reference:** a verified public-domain 1909 RWS card.
2. **House line/color reference:** `LabyrinthCharacterLydiaBoggle`.
3. **Artifact/material reference:** `LabyrinthTalismanTideGlass`.
4. **Environment reference:** `LabyrinthLocationStacks`.
5. **Golden tarot reference:** the approved prototype card closest in suit and
   lighting.

Tell the model what each reference contributes. Do not say only “combine these.”

### 11.2 Prototype six cards before the deck

Generate and approve:

1. The Fool — bright Major, full figure, many anchors.
2. The Moon — nocturnal Major, animals, landscape, uncertainty.
3. The Tower — difficult Major, motion, architecture.
4. Three of Swords — minimal iconic composition.
5. Ten of Pentacles — crowded pip card with exact count and generations.
6. Queen of Cups — court identity, water, ornate object.

These six expose the likely failure modes: excessive collage, generic fantasy,
night scenes becoming digital, object-count errors, crowded composition, face
drift, and overdecorated courts.

Do not begin the remaining 72 until these six look like one deck.

### 11.3 Prompt template

```text
TASK
Create the illustration plate for [CARD NAME], part of a complete
Rider-Waite-Smith-compatible tarot deck called ReEnchanted Tarot:
The Unwritten Deck.

REFERENCE ROLES
- Image 1 supplies the required RWS composition and symbolic scaffold.
- Image 2 supplies graphite-and-ink portrait line quality and watercolor handling.
- Image 3 supplies parchment, artifact material, and restrained jewel accents.
- Image 4 supplies Academy architecture and environmental texture.
- Image 5 is the approved deck-consistency anchor. Match its paper, line weight,
  finish, and level of detail.

CARD IDENTITY AND REQUIRED SYMBOLS
[CARD-SPECIFIC CHECKLIST, INCLUDING EXACT COUNTS]

REENCHANTED TRANSFORMATION
[SUIT/CHAPTER MATERIALS, SETTING, CHARACTER DIRECTION, MARGINALIA]

COMPOSITION
Portrait illustration plate. Preserve the recognizable RWS staging.
One clear focal hierarchy. Full bodies and hands visible where specified.
Keep critical symbols away from the crop edge. Leave quiet space at top and
bottom for the code-rendered frame.

STYLE
Sparse graphite and warm ink linework, delicate crosshatching, transparent
watercolor washes, warm sepia paper, restrained shadows, weathered evidence,
and 15–25% jewel-color accent. Handmade, literary, uncanny but humane.

INVARIANTS
- Exactly [COUNT] [SUIT OBJECTS].
- Preserve [POSE / GAZE / OBJECT RELATIONSHIP].
- No generated title, numeral, caption, border text, logo, or watermark.
- No spellcasting wands.
- No glossy digital fantasy, anime, plastic skin, neon glow, airbrush,
  photoreal celebrity, or overfull collage.
- Do not add extra symbolic objects.
```

### 11.4 Iterate surgically

If a result is strong except for one defect, edit it:

- “Change only the extra cup: remove the eighth vessel. Keep all seven original
  vessels, the figure, layout, palette, linework, paper, lighting, and crop
  unchanged.”
- “Restore the figure's original face and hand pose. Change only the sword
  angle.”
- “Reduce marginal collage by 30%. Preserve every required symbol and the
  central tableau.”

Restate preserved elements on every edit. Archive the accepted parent and all
material edits.

### 11.5 Production batches

1. Six-card prototype.
2. Card back and final frame system.
3. Remaining Major Arcana.
4. Four Aces and sixteen court cards.
5. Numbered Wands and Cups.
6. Numbered Swords and Pentacles.
7. Whole-deck color and line-weight normalization.
8. Physical-print proof pass.

Avoid generating all cards of a suit in a single giant prompt. Each accepted
card needs its own symbolic QA.

### 11.6 Output and crop strategy

- Generate a portrait master with extra composition room.
- Preserve the original accepted image at full resolution.
- Create a non-destructive final crop for the digital frame.
- If a physical deck is planned, choose the printer, trim size, corner radius,
  and bleed before final crops.
- Standard tarot proportions are narrower than many default portrait outputs;
  never assume the initial generation ratio is the print ratio.
- Upscale and sharpen only after the accepted crop and visual QA.
- Do not burn titles or borders into the generated plate.

### 11.7 Provenance record

Keep a manifest entry for every accepted card:

```json
{
  "id": "major-18-moon",
  "assetName": "TarotMajor18Moon",
  "deckVersion": "unwritten-1",
  "rwsReference": "verified-1909-source-id",
  "promptVersion": "art-v3",
  "referenceAssets": [
    "LabyrinthCharacterLydiaBoggle",
    "LabyrinthTalismanTideGlass",
    "LabyrinthLocationStacks",
    "TarotGoldenNight"
  ],
  "requiredSymbols": [
    "moon",
    "two towers",
    "dog",
    "wolf",
    "water creature",
    "winding path"
  ],
  "review": {
    "symbolCount": "approved",
    "anatomy": "approved",
    "style": "approved",
    "crop": "approved",
    "accessibility": "approved"
  }
}
```

### 11.8 Asset naming

- `TarotMajor00Fool` through `TarotMajor21World`
- `TarotWandsAce`, `TarotWands02` … `TarotWandsKing`
- `TarotCupsAce`, `TarotCups02` … `TarotCupsKing`
- `TarotSwordsAce`, `TarotSwords02` … `TarotSwordsKing`
- `TarotPentaclesAce`, `TarotPentacles02` … `TarotPentaclesKing`
- `TarotBackUnwritten`
- `LabyrinthCharacterAuroraWhispers`

---

## 12. App architecture

### 12.1 New typed surface

Add:

- `BookPageType.tarot`
- source ID `tarot-pages`
- title `Tarot Pages`
- origin `.simulated` for the local random draw
- privacy `.privateLocal`
- intent `.reflect`
- render style `.tarotReading`
- a dedicated `PageVisualStyle` drawing from Tidecrest sea glass, ink violet,
  lamp gold, and parchment

This is a real Page family and should not be smuggled through `.gamePage`,
`.illustration`, or string-only metadata.

### 12.2 Core types

Suggested shape:

```swift
struct TarotCardDefinition: Codable, Identifiable, Equatable {
    var id: String
    var arcana: TarotArcana
    var suit: TarotSuit?
    var rank: TarotRank
    var displayName: String
    var assetName: String
    var keywords: [String]
    var lightMeaning: String
    var shadowMeaning: String
    var visualAnchors: [String]
    var reflectionPrompts: [String]
    var accessibilityDescription: String
}

struct DrawnTarotCard: Codable, Identifiable, Equatable {
    var id: String
    var cardID: String
    var position: TarotSpreadPosition
    var isReversed: Bool
    var order: Int
}

struct TarotReadingArtifact: Codable, Equatable {
    var schemaVersion: Int
    var readingID: String
    var deckVersion: String
    var spread: TarotSpread
    var drawnAt: Date
    var cards: [DrawnTarotCard]
    var question: String
    var firstLook: String
    var generatedSynthesis: String
    var readerReflection: String
    var interpretationVersion: String?
}
```

Add an optional typed `tarotReadingArtifact` to `BookPage`, following the same
compatibility pattern as weekly and monthly artifacts. Older archives decode
with `nil`. Do not flatten the reading into an opaque metadata dictionary.

### 12.3 Draw engine

- Build the full 78-card array from the bundled manifest.
- Shuffle locally with an injectable random-number source.
- Draw without replacement.
- If reversals are enabled, choose orientation independently for each card.
- Persist card IDs, order, orientation, spread, deck version, and timestamp
  before beginning the reveal.
- Tests use a seeded fake RNG; production does not derive a seed from the
  question or user data.
- A tactile “cut” can rotate the already shuffled deck by a reader-chosen index.
  It must not invoke a model or weight cards.

### 12.4 Runtime interpretation

Runtime interpretation uses:

1. bundled meanings for an immediate offline reading;
2. the existing local-brain path for optional Aurora synthesis;
3. a deterministic fallback template if local generation is unavailable.

The image-generation model is a production tool only. Tarot Pages must work
fully offline after the deck ships.

### 12.5 Archive and downstream memory

When kept:

- `promptText` may store the spread title and question;
- `userInput` stores the reader's final reflection;
- `playerReply` may store Aurora's synthesis but remains marked generated;
- the typed artifact preserves the complete reading;
- tags may include `tarot`, spread ID, and card IDs for search.

Downstream systems may use:

- the reader's explicit question;
- their noticed detail;
- their final reflection;
- the fact that they kept or revisited the Page.

Downstream systems may not infer a personal pattern from:

- suit frequency;
- repeated random card IDs;
- reversal rate;
- “positive” or “negative” card counts;
- the generated synthesis alone.

### 12.6 Share and export

- A reader can export a beautiful spread image.
- The question and reflection are excluded by default.
- Adding private text requires an explicit toggle.
- Export metadata should credit the deck and Pamela Colman Smith's RWS visual
  lineage.
- Archive PDF rendering should use the same programmatic frames as the app.

---

## 13. Interaction and accessibility

### Motion

- Card backs may breathe or drift subtly before selection.
- Reveal uses a restrained turn or lift, not casino dealing.
- Haptics are light and optional.
- Reduce Motion replaces flips with a crossfade and preserves sequence.
- No flashing glows or rapid shuffling.

### VoiceOver

Recommended order:

1. spread position;
2. card name;
3. orientation;
4. visual description;
5. “Write what caught your attention” action;
6. meanings;
7. optional Aurora reading.

Every card needs two text layers:

- **visual description**, which says what is pictured without interpreting it;
- **meaning**, which remains separately expandable.

### Layout

- One card may expand nearly full width.
- Three cards may sit in a horizontal tableau on iPad.
- On iPhone, default to a vertical sequence with a persistent miniature
  three-card strip for relationship.
- Card names remain visible at high contrast outside the generated image.
- Never communicate suit, reversal, or selected state by color alone.
- Support Dynamic Type without scaling the physical card frame into
  illegibility; offer the meaning in normal responsive text below it.

### Content care

- Difficult cards can have an optional one-line content note.
- Do not replace Death with “Transformation” or the Devil with “Attachment.”
  Explain the traditional name without sensationalizing it.
- The Page can always be closed after a reveal and safely resumed.

---

## 14. Quality gates

### Deck integrity

- Exactly 78 unique card IDs.
- 22 Major Arcana.
- 14 cards in each of four suits.
- Correct RWS numbering.
- Traditional names spelled consistently.
- Every asset exists and matches its manifest ID.
- Every card has bundled meanings, prompts, visual anchors, and alt text.

### Art review

For every card:

- recognizable without title at thumbnail size;
- exact required symbol and pip counts;
- correct pose, gaze, hand/object relationship;
- plausible anatomy and no extra limbs/fingers of consequence;
- no accidental text, watermark, logo, or gibberish;
- no unintended spellcasting wand;
- no generic fantasy rendering;
- suit palette is present but controlled;
- difficult meaning not cosmetically erased;
- safe crop at digital and intended print ratios;
- consistent border-free plate treatment.

Whole-deck review:

- figures are meaningfully diverse rather than token-swapped;
- courts share status without sharing one face;
- night cards remain graphite/watercolor, not glossy digital blue;
- no six-card cluster looks like a different deck;
- Chapter symbolism supports rather than overwhelms RWS symbolism.

### Product tests

- no duplicate card in a three-card spread;
- closing after draw restores exactly the same reading;
- abandoning does not archive a Page;
- keeping archives the typed artifact;
- reversals are off by default and honor preference when enabled;
- model failure leaves bundled meanings and draw intact;
- Aurora receives only allowed fields;
- distress suppresses the invitation, not individual cards;
- source fatigue and unfinished-draft rules work;
- archive search finds spread and card names;
- random draws do not become Book Notices evidence;
- private question text is absent from default share output;
- VoiceOver reads position before meaning;
- Reduce Motion removes the flip animation.

### Voice review

- Aurora names uncertainty.
- She does not predict.
- She does not claim knowledge of absent people's thoughts.
- Her hopeful bias is visible but not saccharine.
- The thorn or tension remains present.
- The final word returns to the reader.

---

## 15. Rollout plan

### Phase 0 — Lock the bible

- Approve product name and in-world name.
- Approve Root / Weather / Door.
- Approve reversals-off default.
- Select one verified public-domain RWS reference set.
- Choose eventual physical trim size before final crops.

### Phase 1 — Six-card visual prototype

- Generate the six prototype cards.
- Create two border treatments: quiet field-guide and denser academy-file.
- Test at iPhone thumbnail, full-screen, iPad, archive, and print size.
- Generate Aurora's canonical portrait.
- Choose the golden day, night, court, and pip references.

**Exit criterion:** all six cards unmistakably belong to one deck and remain
recognizable as their RWS cards without titles.

### Phase 2 — Data and reading skeleton

- Add the typed deck manifest and validation tests.
- Add `.tarot`, source, visual style, and artifact model.
- Implement local draw, persisted draft, one-card and three-card states.
- Render with the six prototypes and development placeholders.
- Implement bundled interpretation before local-brain synthesis.

### Phase 3 — Complete art production

- Finish Majors.
- Finish Aces and courts.
- Finish numbered minors.
- Run suit-level and whole-deck QA.
- Write all alt text and meaning packets alongside art review, not afterward.

### Phase 4 — Aurora and archive

- Implement bounded Aurora synthesis.
- Implement reflection and keep flow.
- Add archive detail and search.
- Add seven-day hindsight resurfacing.
- Add privacy-safe sharing.

### Phase 5 — Physical deck readiness

- Printer proof, bleed, corner radius, color profile, and black handling.
- Box and guidebook design.
- Full colophon and Pamela Colman Smith credit.
- Optional app flow for logging draws from the physical deck.

Do not ship the Tarot Page publicly with only six illustrated cards or only the
Major Arcana. The prototype is for building and testing; the feature promise is
a real deck.

---

## 16. Decisions still needing a prototype, not a meeting

These should be answered by seeing the six cards:

1. **Final title:** recommended `ReEnchanted Tarot: The Unwritten Deck`.
2. **Border density:** recommended quiet field-guide frame; reserve dense
   dossier treatment for the Page around the card.
3. **Reversals:** recommended supported, off by default.
4. **Aurora visibility:** recommended small host portrait or ribbon in Page
   chrome, never on card faces.
5. **Academy crest:** recommended card back only, not every face.
6. **Physical size:** choose before final crop; do not let a default image-model
   ratio make this decision.

---

## 17. Rights and attribution

The original 1909 Rider–Waite–Smith images are old enough to be in the public
domain in the United States. Use a provenance-verified 1909 source, not a modern
commercial recolor, restoration, scan, border treatment, or guidebook. A later
scan may introduce separate rights or provenance questions even when the
underlying art is public domain.

Recommended colophon:

> ReEnchanted Tarot: The Unwritten Deck is an original visual and narrative
> interpretation of the Rider–Waite–Smith tarot system. With gratitude and
> prominent credit to Pamela Colman Smith, whose 1909 illustrations established
> the visual language from which this deck descends, and to A. E. Waite for the
> published system.

Before international physical distribution, review public-domain status and
trademark/product naming in each intended market.

---

## 18. Sources

### Product research

- [Labyrinthos Tarot](https://apps.apple.com/us/app/labyrinthos-tarot-reading/id1155180220)
- [Mystic Mondays](https://apps.apple.com/us/app/mystic-mondays/id1233064572)
- [Tarot!](https://apps.apple.com/us/app/tarot/id543929148)
- [Tarot Journal](https://apps.apple.com/us/app/tarot-journal/id1271120458)
- [Learn Tarot: Rider Waite Cards](https://apps.apple.com/us/app/learn-tarot-rider-waite-cards/id6452754512)
- [Aluma AI Tarot](https://apps.apple.com/us/app/ai-tarot-card-reading-aluma/id6532592297)
- [CHI 2026 paper: AI-assisted tarot and user meaning-making](https://arxiv.org/abs/2602.11367)

### Image production

- [OpenAI GPT Image generation models prompting guide](https://developers.openai.com/cookbook/examples/multimodal/image-gen-models-prompting-guide)
- [OpenAI GPT Image 2 model page](https://developers.openai.com/api/docs/models/gpt-image-2)

### Rider–Waite–Smith provenance

- [U.S. Copyright Office: What is Copyright?](https://www.copyright.gov/what-is-copyright/)
- [Wikimedia Commons: Rider–Waite tarot deck](https://commons.wikimedia.org/wiki/Category:Rider-Waite_tarot_deck)

### ReEnchanted project sources

- `PROJECT_OVERVIEW.md`
- `ILLUSTRATIONS.md`
- `Shared/PageModel.swift`
- `Shared/SourceAdapters.swift`
- `Shared/SurfaceAndCurator.swift`
- `Shared/WorldSystems.swift`
- `Shared/BookReferenceLibrary.json`
- `InsideCoverApp/BookSurfaceViews.swift`
- `InsideCoverApp/CapturePageSheet.swift`
