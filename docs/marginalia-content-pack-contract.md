# Marginalia content-pack contract

The Book has one shared cabinet of physical marks. Pages Rising, Pagewright,
and illuminated photos all read from `IlluminationPackRegistry`; do not add a
surface-specific decoration registry.

## Adding marks to a Page pack

A `PageArchetypePack` may add two optional fields:

- `marginaliaPack`: images the pack contributes to the shared cabinet.
- `marginaliaSnippets`: short Book-authored pencilings selected by motif.

An archetype may also set `leafVisualDialect` when its visual family needs
explicit art direction, and `leafRegionPattern` when its hierarchy genuinely
requires a particular flow grammar. Otherwise Page type, content length, leaf
number, and tags choose both automatically.

`leafRegionPattern` accepts `continuous`, `heroPlate`, `staggeredField`,
`sectionedCabinet`, or `letterWithPostscript`. It controls measured text flow,
not decoration coordinates. Existing packs remain valid when it is absent.

Inside a complete archetype entry, the optional art direction looks like:

```json
{
  "leafVisualDialect": "fieldJournal",
  "leafRegionPattern": "heroPlate"
}
```

Existing `.reenchantedpack.json` files remain valid when both fields are absent.
For a JSON pack, the embedded `marginaliaPack` uses the existing
`IlluminationAssetPack` shape. Empty asset kinds are empty arrays.

Every asset may also include optional `leafTraits`. This is art direction, not
a fixed coordinate: the folio still measures the actual ink and rejects any
collision. Existing assets remain valid without it.

- `semanticRole`: `ornament`, `scribble`, `watercolor`, `botanical`,
  `portrait`, `fieldNote`, `map`, `sigil`, `texture`, or `fastener`.
- `aspectRatio`: width divided by height. This lets a long botanical stem stay
  long instead of being forced into a square stamp.
- `preferredAnchors`: any of `upperLeading`, `upperTrailing`, `middleLeading`,
  `middleTrailing`, `lowerLeading`, `lowerTrailing`, `lowerField`, or
  `watermark`.
- `supportedDialects`: the same dialect IDs accepted by
  `leafVisualDialect`. Omit it to allow every dialect.
- `crop`: `contain` or `fill`.
- `blend`: `normal`, `multiply`, `screen`, or `overlay`.
- `visualWeight`: usually `0.6` through `1.7`; affects physical size and ink
  presence, not selection probability.
- `allowsTextOverlap`: reserve for faint watermarks. Ordinary illustrations
  should leave it false or omit it.
- `tintStrength`: `0` through `1`. Values below `0.5` preserve the supplied
  color instead of receiving the Page accent.
- `subjectTags`: cast IDs, plant names, places, motifs, and other resolver tags
  that should not clutter the public asset name.
- `shelf`: where Pagewright files this mark for browsing. Almost always omit
  it — see *Shelves* below.

The example below is the marginalia fragment to merge into a complete Page-pack
manifest.

```json
{
  "marginaliaPack": {
    "id": "nocturne-folio-margins",
    "displayName": "Nocturne Folio Margins",
    "version": "1.0",
    "author": "The Goblin Index Empire",
    "availability": "bundledFree",
    "supportedTemplates": ["academy_field_study", "rest_and_quiet"],
    "backgrounds": [],
    "paperScraps": [],
    "stamps": [],
    "doodles": [
      {
        "id": "nocturne-moth-pencil",
        "assetName": "NocturneMothPencil",
        "kind": "doodle",
        "tags": ["nocturne", "moth", "night", "dream"],
        "supportedTemplates": ["academy_field_study", "rest_and_quiet"],
        "defaultOpacity": 0.7,
        "canTint": true,
        "leafTraits": {
          "semanticRole": "watercolor",
          "aspectRatio": 0.72,
          "preferredAnchors": ["lowerLeading", "lowerField"],
          "supportedDialects": ["fieldJournal", "storybook"],
          "crop": "contain",
          "blend": "multiply",
          "visualWeight": 1.25,
          "allowsTextOverlap": false,
          "tintStrength": 0.2,
          "subjectTags": ["moth", "nocturne-cast"]
        }
      }
    ],
    "tape": [],
    "overlays": [],
    "fallbackPhrases": {}
  },
  "marginaliaSnippets": [
    {
      "id": "night-counted-back",
      "text": "The night counted back.",
      "title": null,
      "tags": ["nocturne", "night", "dream"],
      "packID": "nocturne-folio-margins",
      "weight": 1.0
    }
  ]
}
```

Bundled packs may name images in the app's asset catalogs. User-imported JSON
can currently arrange shipped asset names but does not import arbitrary image
bytes; adding a safe file-backed asset loader is a separate delivery feature.

## Selection rules

- Page archetype `tags` are also marginalia motifs. A pack author does not need
  to repeat them elsewhere.
- A Pack Page prefers the `marginaliaPack` belonging to its source pack.
- Other Pages choose across unlocked packs by type, metadata motifs, and tags.
- Selection is stable for the Page document and leaf index. Relaunching does
  not move the stain or change the moth.
- Texture and edge wear may be common. The compositor can combine handwriting
  with two marks when the leaf's dialect and collision map allow it; quieter
  leaves still omit them. Illustrated breath leaves may use one large asset
  with a smaller companion rather than prose.
- A generated snippet is always the Book's pencil voice. It must never be
  represented as something the reader wrote.

## Where additions appear

- **Pages Rising:** deterministic marks, snippets, material wear, and occasional
  textless illustrated plates, with the pack's own cabinet preferred for its
  Pages.
- **Pagewright:** every unlocked marginalia pack is merged into the shared mark
  shelves. There is no pack picker on the tray; provenance is a chip on the
  mark itself. (The *Printed marks* picker in Materials still exists, but it
  only chooses which pack the renderer decorates with on its own.)
- **Illuminated photos:** motif scoring chooses the most relevant unlocked pack;
  pack snippets join the existing marginalia library.
- **Bound editions (PDF and print):** `EditionMarginalia` composes each leaf
  from the same cabinet. Leaf *kind* — opener, section opener, reading, plate,
  divider, closing, colophon — sets the budget, the eligible regions, and the
  `semanticRole`s that leaf actually wants, so a colophon asks for a seal and a
  section opener asks for a specimen. Motifs come from the edition's own theme,
  constellations, section and item tags, prose (read with the folio's
  `semanticMotifs`), and the month it was bound in.

  A printed page cannot be scrolled away from, so the placement rules are
  stricter than on screen. Marks are composed in the two moments they are
  provably safe: before the prose, into regions outside the reading column;
  and after it, into the open paper below the last line. A candidate that
  collides with measured ink is dropped, never nudged. Marks tagged `anatomy`
  are excluded entirely — the character shelves ship ears and hands as
  construction pieces, and a detached one reads as a mistake on paper.

## Shelves

Pagewright browses the cabinet by `MarkShelf`, not by `IlluminationAssetKind`.
Kind decides how a mark composites; shelf decides where a person holding
scissors goes looking for it. A pack does not normally declare a shelf:
`MarkShelf.shelf(for:)` reads the tags a pack already authored.

The permanent shelves are `academyDesk`, `handwriting`, `marginFolk`, `inklings`,
`pressedAndGrown`, `skyAndNight`, `shore`, `wayfinding`, `creaturesAndCompany`,
`sealsAndLabels`, `paper`, `fastenings`, `flourishes`, and `wear`.

How the cascade files a mark, in order:

1. An authored `leafTraits.shelf`, if it names a permanent shelf.
2. `academy-tip` → **Academy Desk**. Curriculum scraps stay small and findable;
   their class, professor, and action tags still drive compositor relevance.
3. `handwritten` → **Handwriting**. The hand outranks the subject: an Academy
   note about the moon is somebody's handwriting first.
4. `goblin`, `pixie`, `fae`, `sprite`, `imp`, `scribe`, `character`, `portrait`,
   or `anatomy` → **Margin Folk**. Character families stay whole, including
   their own punctuation.
5. Kind `tape` → **Fastenings**; `background` or `overlay` → **Wear**. Function
   beats subject for the marks that are not pictures: botanical tape is tape.
6. Subject: botanical, sky, shore/weather, wayfinding, creatures.
7. Otherwise by kind — stamps to **Seals & Labels**, scraps to **Paper** — and
   for doodles, wear tags to **Wear**, `flourish`/`ornament` to **Flourishes**,
   label tags to **Seals & Labels**, and everything left to **Inklings**.

Two rules for pack authors:

- **Tag honestly and skip `shelf`.** A pack that ships a bee doodle tagged
  `bee` lands on Creatures & Company with no extra work. Set `shelf` only when
  a mark's own tags would file it wrongly.
- **No shelf may exceed 60 marks.** `MarkShelfTests` enforces it across every
  bundled pack. When it trips, split the family — do not raise the ceiling.
  That ceiling is the whole point: the tray it replaced had one category
  holding 219 marks and a cap that hid 139 of them.
- **Watch the Margin Folk tags.** `goblin`, `pixie`, `fae`, `sprite`, `imp`,
  `scribe`, `character`, `portrait`, and `anatomy` are read as a *character
  family* and are checked before subject, so they reroute a mark off the shelf
  its subject would have earned. Tagging a toadstool `fae` for its folklore
  filed the mushroom under Margin Folk and pushed that shelf over its ceiling.
  Say the folklore in a word the cascade does not spend — `fairy-ring`,
  `folklore` — and let the plant stay a plant.

## Occasional marks: This Month

A mark whose `placementTrigger` names `months`, `activeWorldEventIDs`, or
`worldEventPhases` is *occasional*. It does not sit on a permanent shelf where
nobody would connect it to what is happening. Instead:

- While its gate is open it appears on **This Month**, shown first, under the
  live event's `WorldEventPhase.scene` in the Book's voice.
- Once the gate closes it settles onto **Past Months**. It never disappears —
  a scrapbook that deletes the reader's materials when a season turns is a
  scrapbook nobody trusts with anything.
- The Drawer never deals from Past Months.

Only the *time* half of the trigger decides this. `IlluminationPlacementTrigger`
gained `allowsOccasion(_:)` for exactly that: a mark gated to both September and
`semanticTagsAny: ["harbor"]` is on This Month all September, and the subject
gate still governs whether the folio may place it on a given Page.

Tag occasional marks with the same convention the snippets use —
`event:<event-id>` and `event-phase:<phase-id>` — so the resolver and the
shelves agree about what a mark belongs to.
