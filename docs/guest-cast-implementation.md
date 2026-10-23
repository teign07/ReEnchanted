# The Guest joins the Cast

2026-10-19. Implemented, built in Release and installed/launched on Rabbit. November pack and
worker publication remain separate; hands-on story and illustration QA is still pending.

## The Reader's decision

The Guest is a Cast member when introduced, not someone who waits for December to become one.
He is called **The Guest** until the Stay ending reveals **Aiken Drum**. All three endings remain
available. Cooking restores the Cookery's letters and never chooses an ending.

The existing staged ID, `visitor-the-guest`, is permanent. A name reveal doesn't create another
person, move the memories or reset Belief and relationships. The earlier proposed `aiken-drum`
entity is not needed.

## What is connected

- **Canon and voice:** a character entity, interests, faults, beliefs, goals, hand-authored voice
  card and a voice evaluation alongside Ambrose. Generated scenes must leave the name, history,
  Offer and ending to the authored November scenes.
- **Relationships:** eight edges, to Ambrose, Boggle, Serenity, Min-seo, Vellum, Thorne, Penny and
  the Book. Min-seo remains a student. Thorne's allegiance stays ambiguous.
- **Dossier and illustration:** a bespoke Book-voiced introduction, an ending-specific addendum,
  a reference-library profile, fallback profile and the bundled `LabyrinthCharacterTheGuest`
  image set. Both names resolve to this same portrait. The image says only *The Guest*.
- **Authored memory:** the Guest witnesses all eight main scenes. Separate choice memories keep
  the Reader's offered or withheld name, both answers to the Offer and each ending. The public
  Record carries his arrival and never reveals his name or chooses an ending.
- **Ordinary memory, gossip and asides:** his existing entity ID passes through the normal Cast
  memory harvest and projection. His authored asides use the real portrait; gossip shortens his
  name to *The Guest*, never *The*. The existing ledger keeps memories after pack retirement.
- **The living Academy:** a Kitchen haunt at every hour, without student quarters or a class.
  Month-specific staging still takes precedence. Stay makes him a resident. Home and Court
  remove him from the active roster and prevent staging from adding him back as a visitor.
- **The Cast shelf:** the known roster retains his page and relationships after he leaves.
  Opening it uses the ordinary Cast illustration Page and living record, including his memories.
  He isn't recruited for new scenes, letters, autonomous business or spoken asides while absent.
- **Illustration rotation:** his plate and interleaf can't precede his introduction. Explicit
  portrait lookup remains available for old Pages and print. The monthly Cast divider and patron
  plate use the same asset instead of guessing a filename from `visitor-the-guest`.
- **Chat knowledge:** the Guest's character, relationship and illustration entries are withheld
  before introduction. The known character changes name after Stay; departure is explicit.

`GuestCastState` is a rebuildable projection of authored-content receipts and frozen Cast story
memories. Nothing new is persisted. Vault load, mutation and saving refresh the projection.
An opened story scene or known public event can introduce him. Putting a scene on the desk
cannot. A committed Bowl choice or a first-hand frozen ending memory chooses his state; a
report and hearsay cannot. With no chosen ending, his ordinary physical presence ends with
November, while the known dossier stays.

The initial dossier describes what the Book can observe on arrival. It doesn't reveal his name,
Court allegiance, Serenity's Offer or the ending. A kept Page remains frozen in the usual way;
the current Cast page can append what happened later.

## Compatibility

The app and offline authoring tool are now runtime **12**. The revised November world-event pack
is version **2**, asset `the-guest.runtime.v2`, and requires runtime 12. Its issue, event, scene,
node, choice, staging and consequence identities stay intact.
Install the corresponding app before publishing this revision. October's pack is unchanged.

No worker code changed here. The live deployment check earlier on October 19 found its latest
deployment on October 11 and a health response without the newer shipping-country fields.
The worker update remains a separate reviewed deployment, including the later printer-cash code.

## Verification and remaining gates

- Passed: Swift syntax parsing of changed app/core sources and test files; JSON/asset checks;
  November release preflight; 13 offline pack-tool tests; eight November Cast content tests;
  durable-identity migration check; deterministic pack regeneration; whitespace checks.
- Added: `GuestCastTests`, including real Cast memory harvesting on all three Bowl choices,
  post-retirement persistence, vault round trip, introduction/name gates, hidden art, historical
  dossiers, relationships, Kitchen residence and absence after departure. Updated the existing
  canonical voice and dossier counts.
- Passed: native Guest Cast (14), November pack (15), curator (169) and Cast story-memory (24)
  tests. The initial full run compiled and ran 4,966 tests (five skipped), finding three failures:
  two old Chapter assumptions and a role-prefix name audit. Those were corrected and all affected
  suites rerun clean; the entire suite was not rerun after those corrections.
- Passed: current-checkout Release build; all 1,981 snapshotted inputs unchanged through build;
  app, Share and Widget signatures/profiles; bundled Guest portrait and reference-library checks;
  upgrade installation and launch on Rabbit. Evidence is in
  `/private/tmp/ReEnchanted-Rabbit-20261019-Guest/deployment-evidence.json`. The same app process
  remained alive for 77.5 seconds; no new app crash, app CPU-resource or Jetsam report appeared.
  Source inputs were still unchanged at observation. Launch checks don't establish feature
  behavior, visual quality or performance.
- **Pending on Rabbit:** meet the Guest; open his map marker and Cast page; inspect the full
  illustration, memory and relationship sections; confirm no name before Stay; exercise all three
  endings in a rehearsal save; restart; confirm the same identity and correct Kitchen presence.
- **Pending separately:** the rest of November's art, recorded radio, Family recipe contributor's transcribed recipes,
  scene review and publication. The broader Serenity memory-surrender feature remains separate;
  this Cast addition doesn't implement it.

## Illustration provenance

Generated with the built-in imagegen tool. Style reference:
`docs/field-book-mock/a/AmbroseTrencher.jpg`. Runtime output:
`InsideCoverApp/Assets.xcassets/LabyrinthCharacterTheGuest.imageset/LabyrinthCharacterTheGuest.jpg`
(883,744 bytes; JPEG quality 85 from the generated PNG). The generated original remains in the
image-generation library. The runtime JPEG was opened and visually inspected after conversion.

Generation prompt:

> Use case: illustration-story. Create ONE finished square character dossier illustration for ReEnchanted's living Book. The attached image is a STYLE REFERENCE ONLY: match its aged parchment collage, expressive graphite and fine ink drawing, restrained watercolor, little pinned paper notes, wax and botanical evidence, hand-lettered title. Do not reproduce its cook or his face. Subject: THE GUEST, an ancient household spirit arriving at the Academy Kitchens on All Souls. A small solitary person, only as tall as a grown cook's elbow, in an oversized rain-dark moss-green hooded coat with worn brass buttons and a ragged hem. Face stays completely hidden inside deep hood shadow; TWO very clean small hands visible, one holding a simple round currant soul cake with a cross cut on top. An empty low wooden stool, a single scrubbed copper pan and west-door iron latch can appear as small marginal evidence, not a big room scene. Their posture is patient, polite and unsettling, centuries of wear in the coat; this is not a cute gnome, baby, elf, leprechaun or horror monster. A faint smear of frost along the far edge of the page, warm firelight low across the cloth. Character fills most of the square dossier with full body visible. Palette moss green, tarnished brass, soot, warm old paper. Title text exactly 'The Guest'. Small legible notes, only these phrases: 'Clean hands.' 'The west door.' 'No crumbs.' 'Nobody thanked it.' A tiny brass-button study. No Aiken Drum, no revealed name, no Court insignia, no allegiance, no unhooded face, no additional characters, no extra fingers, no modern items, no glossy digital art. The same tactile antique dossier style and quality as the reference, with less crowded annotation around the short figure.
