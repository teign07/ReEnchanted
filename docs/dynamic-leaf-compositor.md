# Dynamic leaf compositor

The compositor makes individual leaves materially distinct without turning the
Book into a random-template feed.

> Page type supplies the grammar. The leaf supplies the handwriting.

## Pipeline

1. Resolve a broad `LeafVisualDialectID` from explicit Page-pack art direction,
   Page type, or semantic tags.
2. Use the stable Page document ID and leaf index to choose one composition
   from that dialect's allowed range.
3. Give the resolved composition to the paginator before text is measured.
4. Measure title, deck, body, handwriting, provenance, and media using that
   composition's actual type scale, line spacing, text measure, header height,
   and reserved margin.
5. Resolve a regional flow blueprint. Semantic blocks enter compatible hero,
   primary, secondary, margin, media, and provenance rectangles in reading
   order. Overflow walks the remaining regions, then continues on another leaf
   of the same Page.
6. Place marginalia from several candidate regions. Reject candidates that
   collide with measured ink, the title apparatus, the action footer, or a mark
   already accepted on the leaf.
7. Spend a strict decoration budget. If no safe placement exists, omit the mark
   rather than covering prose. A faint watermark is the only intentional
   content overlap.
8. Apply the stable material recipe: paper edge, foxing, fold, stain, bleed,
   ghosting, and other low-frequency accidents.
9. Between suitable, non-interactive Pages, occasionally bind an illustrated
   plate with no required prose. It can carry one large mark, a second smaller
   artifact, and a Book-authored penciling. It is a real leaf in the Page's
   sequence, not an overlay or a replacement Page type.
10. Score the bounded result for sparse continuation leaves and one-line
    orphans. A sparse continuation may be remeasured into honest room on the
    preceding continuous leaf; the alternate wins only when its score is
    better.
11. Treat input, chips, and a Gemma request as measured blocks. They share the
    final reading leaf when they fit and receive their own leaf only when the
    reading has actually used the paper.

## Regional typesetting

The compositor can set one continuous column or several independent measured
text fields. Regions are whitespace and reading structure, not visible app
cards. A faint rule, filing corner, or registration mark may explain the gap;
most region boundaries remain invisible.

- `continuous`: one generous literary column. Long prose and accessibility
  sizes prefer it.
- `heroPlate`: a strong opening field, a separate pencil-note field, and a
  quiet provenance line. Short Missions, quotations, and invocations may use
  it.
- `staggeredField`: upper and lower prose fields with slightly different edges,
  plus filing matter at the foot.
- `sectionedCabinet`: heading, evidence/body, and archival filing zones.
- `letterWithPostscript`: correspondence body, postscript, and a separate
  source/privacy field.

Every `FolioFragment` stores the exact rectangle measured by the paginator.
The renderer draws into that rectangle directly; it never asks the page-curl
transition canvas to infer another width. Paragraphs can split across regions,
but the semantic source order remains the accessibility reading order.

Alignment is resolved per block. A centered title does not force centered body
copy; long literary paragraphs may justify, short field notes may sit leading
or trailing, and handwriting can answer from the opposite margin. The chosen
alignment is stored on the fragment and used by both TextKit measurement and
rendering.

Page type limits the eligible patterns, content length decides whether an
expressive pattern has enough paper, and the stable document/leaf seed chooses
within that range. Continuation leaves are usually quieter. This produces
variety without turning the Book into a random template feed.

## Spatial recipes

The production spatial layer uses five restrained arrangements rather
than an unbounded random canvas:

- `heroPlate`: a centered opening hierarchy with room for one lower-field note
  or outer mark.
- `fieldRail`: a narrower working column with a real field-note rail.
- `cabinetRail`: an archival/specimen column with measured stamp space.
- `letterMargin`: correspondence with a quieter postage or handwriting margin.
- `quietColumn`: generous literary paper; foreground marks are rare and usually
  sit below the ink rather than beside it.

The selected arrangement reserves its paper before TextKit paginates. This may
increase a Page's leaf count. That is intentional: prose continues onto another
leaf instead of becoming smaller, clipping, or being covered by decoration.

A leaf's decoration budget is independent from its text density. Ordinary
leaves may carry handwriting plus one or two physical marks when the collision
map finds real paper for them. Some quiet leaves carry none. The occasional
illustrated plate has no text fragments at all and may spend the full three-mark
budget. Page type still controls the eligible vocabulary and density, so this
variety remains recognizably one family rather than decorative roulette.

Each rendered leaf then resolves exact semantic regions from the stored paper
size: header, ink bounds, preferred outer rail, opposite rail, lower open field,
watermark field, and action footer. Foreground assets and Book-authored
handwriting may occupy only a collision-free region. Watermarks alone may cross
the ink bounds, and remain faint.

## Current dialects

- `fieldJournal`: energetic but legible; heraldry, specimen labels, field
  ruling, handwritten interventions. Playful Missions and Wicker Dares live
  here by default. The visual reference discussed during implementation is one
  possible leaf in this family, not the universal Book layout.
- `correspondence`: letterheads, stamps, intimate leading measures, letter
  ruling.
- `weatherCabinet`: specimen plates, ledger structures, diagrams and measured
  labels.
- `archive`: quiet chapter marks, ghost text, restrained evidence furniture.
- `grimoire`: constellation structures, illuminated marks, denser shadow ink.
- `quotation`: generous space and typographic restraint.
- `atlas`: field and ledger structures with map/compass marginalia.
- `illuminatedPlate`: image-led, quiet supporting typography.
- `storybook`: chapter marks, heraldic or constellation title devices, literary
  prose.
- `plainLeaf`: the Book's ordinary paper; simple, flexible, and low-density.

## Content packs

`PageArchetype.leafVisualDialect` and `PageArchetype.leafRegionPattern` are
optional. A pack can set a dialect and, when its hierarchy genuinely requires
it, one of the regional patterns above. When omitted, the compositor infers
both from Page type, content length, leaf number, and tags. The existing
`symbolName`, archetype tags, `marginaliaPack`, and `marginaliaSnippets` supply
that dialect's specific vocabulary.

Content packs should add vocabulary before adding new dialects. A new moth,
stamp, pencil phrase, or motif belongs in the shared marginalia cabinet. Add a
new dialect only when the hierarchy and reading behavior are genuinely
different.

## Non-negotiable constraints

- Deterministic: the same Page and leaf retain their composition across
  relaunches.
- Readable: dynamic type remains authoritative; accessibility sizes fall back
  to leading text and no deliberately narrowed margin.
- Restrained: most leaves receive zero to two foreground decorations; selected
  field, grimoire, story, and illustrated leaves may receive three.
- Honest: Book-authored handwriting is never represented as reader writing.
- Continuous: overflow text is paginated into the next composed leaf of the
  same Page, never silently replaced by a different Page type.
- Ordered: regional geometry may be expressive, but VoiceOver retains the
  source block order and accessibility sizes return to one continuous column.
- Extensible: Pagewright, illuminated photos, and folio leaves continue to use
  the same illumination-pack vocabulary.
- Deep: Pages Rising binds nine Page documents initially. Its final leaf asks
  the existing Curator bench for nine more, appends them to the same binding,
  and turns to the first arrival instead of routing through Contents.
