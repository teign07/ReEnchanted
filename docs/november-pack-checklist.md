# November 2026 pack: everything to make

The Guest Who Came on All Souls · the Kitchen. Story: [november-the-guest.md](november-the-guest.md).
Scenes: [november-the-guest-scenes.md](november-the-guest-scenes.md). Recipes and house laws:
[kitchen-november-pack.md](kitchen-november-pack.md). Field reference for every row:
[monthly-content-surfaces.md](monthly-content-surfaces.md). October (`ContentPacks/count-unbound`) is
the worked example; its counts are given for scale.

Written 2026-10-19. Status updated the same day: the pack builds from `ContentPacks/the-guest/`
(`python3 ContentPacks/the-guest/build_pack.py`). Earlier validation passed the shelf rehearsal
and `TheGuestPackTests`. The Guest Cast addition now requires runtime 12; offline preflight and
Swift syntax checks pass, but native tests, a new app build and Rabbit QA remain pending.
See [guest-cast-implementation.md](guest-cast-implementation.md).

**Key:** ✅ done · ✏️ drafted · ⬜ to make · 🔧 needs an app change (runtime bump + install) ·
👤 the project owner makes, approves or runs it

---

## 0. The calendar problem first

- **The pack has to be on the shelf before its foreshadow week.** ✅ Chosen: a 4-day foreshadow
  (`foreshadowDays: 4`), so the foreshadow starts Oct 28 and the pack must be **published by
  Oct 27**. The rehearsal of October + November passes with those dates.
- **Options:**
  1. **Short foreshadow** (`foreshadowDays: 3`): publish by Oct 29.
  2. **Ship in two drops.** Drop 1 (by Oct 25–29): the event core, the full Record and catch-up,
     scenes 1–4, pulses, staging, the first Bleed articles, the art that exists. Drop 2 (about Nov
     10): scenes 5–8, the remaining Bleed and radio. Changed files get new asset IDs, the way
     October's runtime v5–v8 were reissued.
- **The shelf carries October through its residue** (Nov 1–7, including "An evening in November").
  The November publish has to list both issues.
- **App changes** need a runtime bump, and the app on Rabbit has to match before the pack that
  needs it goes live. Until TestFlight, Rabbit is the only reader.

---

## 1. The event (`events[0]` in `november.reenchantedevents.json`)

- ✅ **Calendar:** Nov 1, 30 days; foreshadow and residue days (see §0).
- ✅ **Title and subtitle:** "The Guest Who Came on All Souls", plus a subtitle.
- ✅ **Four phases.** The IDs are permanent save identities:
  - setup: *All Souls* (Nov 1–7);
  - buildup: *Guest-right* (Nov 8–15);
  - climax: *The Offer* (Nov 16–25);
  - aftermath: *The Bowl* (Nov 26–30).

  Each phase needs:
  - ✅ `scene`: what's happening, in the Book's voice. It shows on Book Today and in the widget.
  - ✅ `packetLine`: backstage steering for the model.
  - ✅ `intensity`.
- ✅ **Pulses**, 32 (October had 34): one small thing the world does each day, each with a
  `tender` version for hard nights. For example: the pots scrubbed again; a letter gone from
  "cinnamon"; Ambrose chalking the menu; the Guest at the edge of the bonfire light.
- ✅ **Staging** (October had 20 placements): who's where, by phase and hour.
  - The Guest is now a **story-gated Cast member**, keeping the original `visitor-the-guest` ID.
    Runtime 12 adds the dossier, illustration, voice, relationships and memories. Earlier apps
    cannot install this revised pack. He is named Aiken Drum only on the Stay route.
  - The west door is a room note; the Kitchens at 3 a.m. is a placement.
- ✅ **Room notes** and `closedRoomIDs`.
- ✅ **A borrowed room:** *the Cold Kitchen*, a room from the Court that pushes in at
  night during the climax, drawn in different ink. October had the Wrong Castle.
- ✅ **foreshadowAcademy** (the week before): Ambrose testing soul cakes; the onion sack at the
  west door.
- ✅ **residueAcademy** (Dec 1–7): who's where after each ending.
- ✅ **Effects:** boost `entity: ambrose-trencher` and the Kitchen page types while the event runs.
- ✅ **Packet:** `logline`, `atmosphere`, `storyInstruction`, `classInstruction`,
  `letterInstruction`, `bookOfYouInstruction`, `widgetWhisperLine`, `bleedInstruction`,
  `radioInstruction`, `fieldworkPrompt`/`Placeholder`/`RewardLine`, `monthlyEditionLine`.
- ✅ **The Record**, 15 entries (October had 15; a release refuses an event without it):
  - `outcomeTitle` and `historySentence`;
  - dated public entries, each with Cast memories and gossip lines.
- ✅ **Catch-up ladder**, 8 rungs (October had 9):
  - rung 0 retells October in one paragraph;
  - each rung stands alone;
  - no rung ever names the triangle.
- ✅ **Outcomes Home / Stay / Court.** All three remain the Reader's choice in scene 8. The
  cooking tally restores letters only. The Guest's Cast identity follows the committed choice;
  Home and Court keep his dossier and memories but remove him from new Academy business.

## 2. Story scenes (`storyScenes[]`, one manifest atom each)

- ✏️ **The eight main scenes:** written and in the pack; the project owner's notes are next.
- ✅ **Convert to pack JSON:** ids, nodes, choices, `result`, `consequenceTags`, `braidText` on
  every choice, `report`/`reportAfterLiveDay` for readers who missed it, `roomID`, `castIDs`,
  `entities`, `tags`.
- ✅ **Cast memories, asides and gossip** on every scene, audited. The drafts list the main ones. October
  had 164 memories and 36 gossip lines; the audit tests hold the contract.
- ✅ **Recalls** (runtime 11) on October's `count-unbound:november-*` tags, for scene 5's three
  versions.
- ✏️ **Real-world crossings** (all four written, waiting on the project owner) (`missionInvitation` / `missionReturnPrompt` /
  `missionKeptResponse`); October had 4:
  - All Souls week: *Make something someone used to make for you.*
  - Week 2: *Rescue a recipe* (ask someone how they make the thing they make; write it down).
  - Week 3: *Feed someone* (a jar or a plate, given away).
  - Week 4: *Set a place* (one meal with a chair or plate for someone absent; no report needed).
  - 👤 the project owner signs off on every real-world ask.
- ✅ **Relics**, keepsakes only for readers who lived the route and did its crossing: the soul cake's cross; a scrubbed
  spoon; Soren's first slip; the white bowl's thorn.
- ✅ **December carry** (*The First of December*, `content_december.py`; the ending tags it leaves
  are listed in the scenes doc): a residue scene in Dec 1–7 that picks up the ending and hands it to the
  Long Watch.
- 🔧 **Serenity's surrendered memory:** her own row for the October key marked given away.
- ✅ ~~**Scene 8's gate:**~~ the project owner: the tally never gates the ending. Was: whether the page is restored, from the tally (see §9).

## 3. The world's daily life (beats)

- ✅ **Classes**: Boggle's *A Potato*, Vellum's *A Meal Is Fuel*, Ambrose's *Don't Hurry the
  Onions*. Still open: a check against the November curriculum lessons already in the app.
  (Min-seo is a student; her part is asking the Guest what it needs, in *The Rescue*.)
- ✅ **Letters**: Trencher's, Momort's (*Never the Other Thing*) and Serenity's.
- ✅ **A notice:** *Kitchen Law*, a keepable list of the house rules (October had Threshold
  Protocols). Feed the guest first. Never thank the ones who keep the house. Set a bowl.
- ⬜ **Participation prompts** on the beats that should be doors.

## 4. The Bleed

- ✅ **Articles** (`bleedArticles`): 4 news pieces plus 4 weekly recaps on days 10/17/24/29, the
  recaps 150 words or fewer. October had 8. News: *A Guest at the West Door*; *Letters Missing
  from The Middlemost Cookery*; *Supper Goes Flat on Martinmas*; *A Wish Said Aloud*.
- ✅ **Classifieds**, 12 morning-and-evening pairs. Tag `classified` with a `reply`. The app
  already reads these; Rabbit needs the build. Example: *LOST: the second half of the shepherd's
  pie. Last seen in the Cookery.*
- ✅ **Cast letters to the editor**, 18, tagged `cast-letter`, `cast:<slug>`, `cue:<cue>`.
  Ambrose, Vellum, Boggle, Min-seo and the regular voices, about the Guest and the food.
- ⬜ **`packet.bleedInstruction`.**
- ✅ **The Cookery count in the paper and on Book Today** ("214 letters missing, 17 restored from
  readers' kitchens").
- ✅ **Ambrose's chalkboard menu**, one sentence about the weather, in the Academy timetable box.
- ⬜ **Undertakings** (§8) feed the paper's Academy reports for free.

## 5. Radio

- ✏️ **DJ breaks**: five scripts in `ContentPacks/the-guest/RADIO-RECORDING.md`, not recorded (`radioBanters`), about 5 clips of 20–40 seconds on the existing stations
  (Thornwave, Faefi, Mothlight). Scripts go first in `RADIO-RECORDING.md`.
  - Ideas: Thornwave on the west door; Faefi on soul cakes; Mothlight at 3 a.m. on the Kitchens'
    light; a "don't thank it" PSA; Stir-up Sunday.
  - 👤 Recorded in ElevenLabs in the project owner's signed-in session; the caption must match the take.
  - 👤 the project owner listens on the device.
- ✅ **`packet.radioInstruction`.**
- ⬜ **Optional:** a `radioStationPack` with month-gated songs, or a small *Kitchen Wireless*
  station. It must include `"stations": []`.

## 6. Marginalia and art

- ✏️ **Directed notes**, 8 prompts in `ContentPacks/the-guest/art-prompts.json` (October had 8): handwritten marks at story beats. The soul cake; the west
  door; the scrubbed pots; the green coat's brass button; a missing letter; Soren's spoons; the
  brown bowl; the thorn.
- ✏️ **The month's drawing set**, 20 prompts in `art-prompts.json` (October had 20). Kitchen-stained:
  - stains and smudges: flour fingerprints, tea rings, grease spots, scorch marks;
  - kitchen things: wooden spoons, copper pots, onions, a halved loaf, a honey jar, an apple cut
    across to show its star;
  - the month's food: soul cakes, parkin, the treacle tin;
  - the story's objects: frost on glass, an iron latch, a thorn, candle stubs, the pudding in its
    cloth.

  They decorate the month's leaves and printed margins and fill Pagewright's This Month shelf.
- ✅ **Marginalia snippets:** 13 pencilings in `margins.reenchantedpack.json`, live while the Guest is here.
- ✏️ **Print plates**: 20 prompts (frontispiece, one per scene, five Cast portraits, six
  general) in `art-prompts.json`. October had 24.
- ⬜ **The issue's cover plates** (in `issue.json`).
- ✏️ **The Cookery leaf** (prompt `the-middlemost-cookery`): a page of *The Middlemost Cookery* with letters missing, for the
  editions and the paper.
- ✏️ **Art prompt files** written (`make_art_prompts.py`); next comes generation, then generation, optimisation under the 2 MiB
  publication cap, and contact sheets.
  - 👤 the project owner reviews the contact sheets.

## 7. Paper (the printed editions)

- ⬜ **The Record** (§1) is bound into the monthly.
- ⬜ **Edition play leaves** (October had 3: map, maze, journal). Ideas:
  - a *Rescue a Recipe* card leaf (journal form);
  - *Set the Table* (scrapbook form);
  - a coloring plate of the Kitchens;
  - a word ladder (COLD to WARM).

  Every leaf needs `eventOutcomeIDs`, even if it's empty.
  - 👤 the project owner approves.
- ✅ **Note prompts**, 15 (October had 15): the lined-space invitations. *What did the kitchen smell
  like tonight? Who did you feed? What does your house smell like on the one day a year it smells
  like that?*
- ✅ **The Month's Front Pages leaf.** Automatic from the paper.
- 🔧 **The printed Kitchen:** made recipes with the Reader's own margin notes. A signature in the
  annual book; later.

## 8. Cheap pack channels the app already reads

- ⬜ **The sentence helper** (`sentencepack.json`): a kitchen theme.
  - anchors: onion, kettle, bread, soup, oven, spoon, butter, pan;
  - senses: sizzle, steam, crackle, yeast;
  - verbs and crossing words;
  - starter templates: *Tonight the kitchen smelled of ___.*
- ✅ **Wonder lines** for the braid, 18, keyed to kitchen nouns: 32 words or fewer, no "I",
  no banned words.
- ✅ **Cast undertakings** (`margins.reenchantedpack.json` → `undertakings[]`): three five-beat
  ladders bound to the event, *Wicker Can't Cook*, *A Request to Examine the Guest* (Vellum) and
  *The Cookery Count* (Penny), each with a letter and a door. Planned list was:
  - Ambrose and the endpaper page;
  - Vellum's examination request;
  - Wicker learning to cook;
  - Soren's nine spoons;
  - Penny's inventory.
- ✅ **Kitchen spells as archetypes** (4: a cold evening, the dark coming early, bread and salt,
  a bowl set down at the full moon): *A Spell for a Cold Evening* and others, triggered by
  weather, dark and moon. They're repeatable Pages with no app release needed.
- ⬜ **Optional:** story forms for generated Kitchen scenes with Ambrose, and story consequences
  for them.

## 9. The Kitchen itself (app work: runtime bump + install)

- ✅ **`KitchenRecipe` and the Kitchen room** (see [kitchen-recipe-system.md](kitchen-recipe-system.md)): a Book division, the shelf, its rows.
- 🔧 **Recipe capture:**
  - *Rescue a Recipe*;
  - the inherited original kept untouched, with *our version* beside it;
  - the history of each time it's made (date, weather, who ate, what changed);
  - "I don't measure it" counts as a complete recipe.
- ✅ **The countersign:** *Made it · Made it badly · Not yet*, with the Reader's line printed back
  above the steps next time.
- ✅ **The tally** (restores letters only; it never decides an ending): made recipes from the
  archive restore the Cookery's letters and drive the Bleed count.
- 🔧 **Recipes come back:** unmade ones re-offered by Ambrose; favourites by weather ("let tonight's
  weather choose") and as gentle experiments ("is it the soup's fault?").
- 🔧 **Kitchen missions and Wicker dares:** the bundled registries.
- 🔧 **Pantry lore rows**, unlocked by use: rosemary, salt, bread and salt, honey, the apple's star.
  This is bundled lore.
- 🔧 **Photo recognition:** the Book sees the food in a photo. It confirms, never decides.
- **Later in the month or next year:** the jars (the one you give away, the one that waits until
  February) and the starter as a Cast member.

## 10. The recipes

- ⬜ **The corpus,** authored against tested sources under the house laws: allergens named,
  acidity-safe preserving, no generated recipes. The story's own come first: soul cakes, parkin,
  bonfire toffee, Martinmas bread, stone soup, soda bread, leek and potato soup, Christmas pudding,
  and the Hob's bowl. Then the rest of the Kitchen's 40.
- ⬜ **the project owner's mother's recipes, for everybody:**
  - faithful transcriptions;
  - 👤 photos of her handwritten pages (media assets);
  - 👤 how she's credited;
  - a safety pass (allergens; no ruled-out preserving method; tomatoes get their acid);
  - one short Book line each;
  - the All Souls page beside them.
- ⬜ **Other family recipes**, if offered: same treatment, with the cook's say.

## 11. Release and QA

- ✅ **Authoring manifest:** every scene, beat, article, radio break and mark as an atom, with
  placement, priority, audience, voice, interaction, occurrence, gates and dependencies;
  `phasePlans`; `coverageRequirements`; every atom `ready`.
- ⬜ **Floors for the pinned days:** Nov 1, 5, 11, 22, 26 and 30.
- ✅ **Lints and audits** (in `TheGuestPackTests`):
  - `StorySoFarTests`, the catch-up audit, `CastStoryMemoryAudit`;
  - the voice lints: no hinge, ritual or forgive in the margins; contractions; the Book has no
    hands.
- ✅ **Rehearse the whole shelf** (passes). Then
  `swift test --filter MonthlyIssueInstallability`, the signed candidate and a dry run.
- 👤 **Worker deploy** if `monthly-issues.mjs` changed (before publishing, or the shelf 503s).
- 👤 **Publish** (`scripts/ship_release.sh`).
- 👤 **Device QA on Rabbit:** install; the first scene appears; the map; a radio clip plays; the
  paper carries the month.
- ⬜ **App build with the runtime bump** on Rabbit before the pack that needs it.

## 12. the project owner's decisions

- 👤 Notes on the eight scenes.
- ✅ Trencher and Boggle: yes (written into scenes 2, 7, 8).
- ✅ Credit: "Gayle O'Brien, Mom". 👤 Photos of the typed binder (no photos ship).
- ✅ The Hob's name: Aiken Drum, revealed only if he stays. He joins the Cast as The Guest on
  introduction, with the same ID after the name reveal (runtime 12; Rabbit validation pending).
- 👤 Scope and timing: short foreshadow, or two drops (§0).
- 👤 Real-world crossings signed off.
- 👤 Print leaves and art approved.
