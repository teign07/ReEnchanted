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
- **Pagewright:** every unlocked marginalia pack appears through the existing
  pack picker and mark trays.
- **Illuminated photos:** motif scoring chooses the most relevant unlocked pack;
  pack snippets join the existing marginalia library.
