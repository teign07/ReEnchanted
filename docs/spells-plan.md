# Spells — the Book's move against the Curse (implementation plan)

Goal: give the Book a third kind of magic that changes how the reader looks at
the next ten minutes of their actual life.

An Enchantment decorates a photograph. A Compass Run sends the reader out on a
route. A **Spell** is smaller and stranger than either: an instruction, drawn
from something people really did, that makes an ordinary place briefly
unfamiliar — and a way of bringing back what happened.

This is the most on-theme feature left on any list. The Curse is "the flattening
force of forgetting, cynicism, and autopilot" (`NarrativeCore.swift:89`), and a
Spell is the Book's direct move against it: not a record of noticing, but an
instrument for it. Everything else the Book does observes the reader. This one
acts on them.

Five phases, smallest first, each landable alone:

1. **The model and the shelf of them** — a `SpellDef`, a registry, an authored
   seed. No UI; testable on a cold archive.
2. **The door** — available Spells listed in the Glow → Magic submenu, beside
   Compass Run and Enchantment.
3. **Casting** — the Page, the instruction, the reader's answer, the keep.
4. **Conditions** — a Spell exists only when the world is right for it.
5. **Manners** — rest, cooldowns, and what a cast is worth.

---

## Decision record

**A Spell is a `FeastDef` unchained from the calendar.** That shape already
carries everything this needs: a real practice named truthfully, the Book's own
account of it, a one-line instruction, and a `CelebrationMechanic` to resolve
it. Shab-e Yalda is already a Spell in all but name —

> *blurb:* "…a book of Hafez opened at random so the poem you land on can be read
> as an answer to whatever you were worrying about. A whole civilisation has been
> doing bibliomancy at the winter solstice for two thousand years."
> *invitation:* "Open any book at random tonight and read the first line your eye
> lands on. Keep it here. Don't pick a better one."
> *mechanic:* `.findOneLine`

— so the work is re-chaining it to a **condition** instead of a date, not
inventing a mechanism.

**Reuse `CelebrationMechanic`, do not invent a second resolution path.** All five
already exist and are wired: `findOneLine`, `nameSomething`, `throwTheBones`,
`pressAKeepsake`, `countersign`. Two of them leave something behind through
`resolveFestivalMechanicIfNeeded` (`ContentView.swift:16375`); the other three
complete the moment the Page is kept. Generalise that function rather than
copying it.

**Spells get their own `BookPageType`.** Not `.enchantment` (that is photo
casting, and bj deliberately kept the two apart) and not `.festival` (which would
tangle them into the feast calendar and its grief rules). The cost is real and
should be paid deliberately: roughly seven switch arms in `PageModel.swift` and
about ten more across the app, **including a `marginAsk`** — the contract that
`PageMarginAskTests.testEveryPageTypeNamesWhatToWrite` enforces, and which is
currently red because something already went in without one.

**Naming is settled.** The Glow submenu is **Magic**. It holds three distinct
kinds: Compass Run, Enchantment, and now Spell. Enchantments keep their name.

**A cast produces a kept Page.** That is what makes it real rather than a prompt:
the result enters the archive, carries a context snapshot like anything else, and
becomes evidence the grimoire can find correspondences in. Spells feed the
shelf they came from.

---

## House laws

- **The Book never claims the spell works.** It says people have done this for a
  long time, and that tonight the reader is one of them. Effect is the reader's
  to notice; the Book's job is to get them to look.
- **Attribution, shared with `docs/correspondences-plan.md`.** Real traditions
  are named truthfully. Academy inventions are permitted and are attributed to
  the Academy, so a reader can always tell invention from inheritance. Same
  field-not-typography rule: `source` is `.folk` or `.academy`.
- **The instruction must be doable in the next ten minutes, with what is to
  hand.** No shopping, no preparation, no waiting for a season. If it needs a
  season, it is a feast day and belongs in the calendar.
- **Not a wellness prompt.** No streaks, no habits, no scoring, no "take a moment
  to". A Spell is an odd thing to do, offered by something that is not a
  therapist. See [[gentle-register-is-an-injection]] in memory: play is the meal.
- **Voice: simple, direct, clear, childlike, anthropomorphic, independent** —
  and the Curse is the motive underneath, rarely the noun on the page.
  `CorrespondenceVoiceTests` already lints the shapes that go wrong (long
  sentences, semicolons, `", which …"` asides); Spells get the same lint.
- **Refusal is free and permanent.** The feast days already have this
  (`restCelebration`): a reader may rest a Spell forever, with no second ask.
- Pure logic in `Shared/`, platform glue in `InsideCoverApp/`. New `Shared/`
  files need both `Package.swift` and the pbxproj; prefer growing
  `ReferenceLibrary.swift`, which is where authored shelves already live.
- Tests: `CLANG_MODULE_CACHE_PATH=/private/tmp/insidecover-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/insidecover-spm-module-cache swift test`

---

## Phase 1 — The model and the spells themselves

`SpellDef`, `SpellPack`, `SpellRegistry`, in `ReferenceLibrary.swift` beside the
correspondence shelf whose pattern it copies.

```
id, title
practice        the real thing people did, named
source          .folk | .academy
blurb           the Book's account of it — why anyone bothered
invitation      the instruction, one or two sentences
mechanic        CelebrationMechanic
trigger         SpellTrigger?   (Phase 4; nil means always available)
weight, symbolName, accent
```

Seed with a dozen or so, **half of them modern**. An all-antiquarian shelf reads
as a museum, and the point is the reader's own life now — but modern must not
mean invented. Most of these have better provenance than the folk ones, because
somebody wrote down who started it and when.

**Old, portable, needs nothing:**

| Spell | Practice | Mechanic |
|---|---|---|
| Bibliomancy | open any book at random, take the first line | `findOneLine` |
| Apotropaic marks | find one mark somebody cut to keep something out | `pressAKeepsake` |
| First-footing, in miniature | be the first thing through a door on purpose | `countersign` |
| Saining | clear a room with breath or smoke | `nameSomething` |
| Naming a tree | it has been there longer than you | `nameSomething` |
| Counting magpies | the rhyme is a real prediction system | `throwTheBones` |

**Modern, and just as real:**

| Spell | Practice | Mechanic |
|---|---|---|
| **The Dérive** | Debord, 1956. Drift on foot and let the street choose the turns. The whole method is refusing your usual route. | `nameSomething` |
| **Shufflemancy** | Genuine modern folk divination: ask a question, hit shuffle, the first lyric answers. | `findOneLine` |
| **Blackout poetry** | Tom Phillips, *A Humument*, 1966. Take any printed page, cross out until a sentence is left standing. | `findOneLine` |
| **Camera-roll bibliomancy** | Scroll to a date you don't choose and take the first photograph you land on. Bibliomancy for a device. | `pressAKeepsake` |
| **Sonder** | Koenig, *Dictionary of Obscure Sorrows*, 2012. Pick one stranger and grant them an entire life as detailed as yours. | `findOneLine` |
| **N+7** | Oulipo, 1961. Take a sentence, replace every noun with the seventh noun after it in a dictionary. | `findOneLine` |
| **Network names** | The Academy holds that the names people give their routers are omens, being the only naming most people ever do in public. No evidence. Attributed. | `throwTheBones` |

The modern half is doing real work: the Dérive and Sonder are the two purest
statements of what this app is for, and they were written down by named people
in living memory rather than inherited from nobody in particular. Shufflemancy
and camera-roll bibliomancy also show the reader that the old moves survive into
the devices they already carry, which is a better argument for enchantment than
any amount of hawthorn.

**One caution.** A spell that says "go and find a desire path" is fine. A
*taxonomy* of things to spot would be rebuilding the hidden-magic lens, which is
a deliberately retired design with a test guarding it. Instructions, never a
checklist.

**Tests.** Every spell attributed; Academy inventions say so; every instruction
is doable indoors with nothing bought; every `mechanic` is one the resolver
handles; voice lint.

## Phase 2 — The door (DONE, 2026-09-06)

A `Spell` header and `ForEach` in the Magic submenu, sibling to the Enchantment
block at `BookStatusCards.swift:1767`. Needs a `GlowMenuAction.openSpell`, a menu
item type mirroring `GlowEnchantmentMenuItem`, an updated subtitle for
`.magic`, and a bump to the hardcoded submenu height (`case .magic: return 398`).

Watch the layout note already in that file: building a long list inside the same
transaction that grows the paper costs the spring its first frames. Cap the
listed spells at four or five — which is also the right feel. A Book that offers
forty spells is a catalogue.

## Phase 3 — Casting (DONE, 2026-09-06)

The `.spell` page type, its `marginAsk`, and the Page itself: the Book's account
of the practice, the instruction, and the affordance for the mechanic. On keep,
`resolveFestivalMechanicIfNeeded` — generalised off `.festival` — presses the
keepsake or saves the naming as it already does for feasts.

The kept Page carries its practice and source in metadata, so a spell cast near
water on a foggy evening is ordinary evidence the grimoire can build a
correspondence from later.

## Phase 4 — Conditions (DONE, 2026-09-06)

Rather than a `SpellTrigger`, `PageTrigger` gained `placeKinds` and
`PageTriggerContext` gained `placeKind` (read off the nearby Anchor's own
category). One trigger vocabulary, and pack pages can now key on place too.

Sixteen of the twenty-seven spells are conditional. A conditional spell scores
**+1400** over an unconditional one, so when it is foggy the fog spell is the one
waiting rather than a lucky draw. With no context at all only unconditional
spells are offered: showing a fog spell in bright sun is worse than showing one
spell fewer.

The Glow menu builds its context with `resolveMissingWorldEvents: false`, since
it is assembled in a view body and no spell triggers on a world event.


`SpellTrigger`, borrowing `PageTrigger`'s vocabulary (`PagePacks.swift:376`):
time bands, months, moon phases, weather tags, quiet days, absence days,
deterministic daily rarity — and, now that Phase 5 of the correspondences plan
landed, **place kind**.

This is what turns a menu into magic. A spell for fog should not exist on a clear
day. A spell for a place you keep returning to should appear when you are there.
The reader should occasionally find one waiting that they have never seen before
and may not see again.

## Phase 5 — Manners (DONE, 2026-09-06)

- **Rest** reuses the feast days' door: `festivalCanRest` metadata, the same
  plain row, no confirmation. Spells rest in their own ledger
  (`restedSpellIDs`), so the sheet routes by page type rather than guessing
  from an identifier — the feast row passes a `celebrationID`, and a spell
  passing one would have written to the wrong store.
- **Cooldown**: six days, recorded in `spellCastLog` when the Page is kept, and
  written inside `vault.mutate` alongside whatever the mechanic saves, since
  each consecutive vault write rebuilds the desk. Not an economy — it is so the
  one feature that breaks a routine does not become one. A clock that has run
  backwards is treated as a clock problem, not a reason to withhold everything.
- **Worth**: nothing to build. `beliefBonus` is written into feast metadata and
  never read by anything, so feasts do not award through it either; a cast Spell
  is a kept Page and already earns whatever a kept Page earns. Inventing a
  parallel award for spells alone would have been new machinery pretending to be
  a mirror.
- **Cast history** is `spellCastLog`, which the Book can later read to say "you
  did this one before, in the rain" rather than offering it blind. Not yet
  surfaced in prose.


- **Rest**: permanent, one tap, no second ask.
- **Cooldown**: day-scale per spell, so a spell cannot be farmed.
- **Worth**: a cast earns Belief like a feast does. Decide the number against
  `beliefBonus` on feast days rather than inventing a scale.
- **Cast history**: what the Book remembers about spells already worked, so it
  can say "you've done this one before, in the rain" rather than offering it
  blind.

---

## Deliberately not in this plan

- Renaming Enchantments or Compass Runs.
- Any claim that a spell has an effect.
- Spells that need equipment, purchases, preparation, or a season.
- A second mechanic vocabulary. If a spell cannot resolve through the five that
  exist, it is the wrong spell or the vocabulary needs one more case — and that
  case is a decision, not a convenience.
- Streaks, scores, or completion percentages of any kind.
