# Wicker's chaos sigils

Fourteen original ink monograms, November 7, 2026. These are Wicker's
fictional intentions, drawn through a real sigil-construction method. They
are not copies of historical seals.

## Method and lore

Austin Osman Spare describes simplifying and combining alphabetic forms in
*The Book of Pleasure* (1913), “Sigils. Belief with Protection.”
Phil Hine's *Condensed Chaos*, version 1.2, “Sigil Magick,” pages 31–33,
describes writing an intention, removing repeated letters, and building a
glyph from what remains. His example of casual sigil doodling during a
boring talk closely fits Wicker's habit of drawing in books.

These designs remove spaces and repeated letters, retaining vowels. Each
row records the seed used in the image brief. Shared, rotated, and simplified
strokes deliberately obscure the sentence. The final shapes are original
interpretations generated with the built-in ImageGen tool.

- [Spare's primary text](https://www.brainwashed.com/nww/words/pleasure.html)
- [Hine's primary text, PDF](https://samim.io/dl/condensed_chaos.pdf)
- Local canon: `docs/lore-bible.md`, Wicker's dossier in
  `Shared/BookReferenceLibrary.json`, and the existing Wicker handwriting.

Wicker's wrong-door key, distrust of theatrical certainty, appetite for the
last word, and Thornwave broadcasts ground the first eight marks. “Enough”
is an intention about his fault of taking experiments too far; it does not
declare that he has overcome it.

The final six respond to the requested protections and noticing. The Curse
is the Grey/Rut of Routine: forgetting, cynicism, and autopilot. The marks
keep colour, identity, and a return route; then turn toward looking twice,
small living things, and being awake inside a day. They add no game mechanic,
reader diagnosis, historical claim about these particular drawings, or
promised change to the reader's circumstances.

| Mark | Construction intention | Deduplicated letters |
| --- | --- | --- |
| The Wrong Door | I OPEN THE WRONG DOOR | `IOPENTHWRGD` |
| The Hidden Hinge | I FIND THE HINGE IN THE RULE | `IFNDTHEGRUL` |
| Borrowed Certainty | I SEE THE TRICK BEHIND THE THRONE | `ISETHRCKBNDO` |
| Unbought | MY WILL IS MY OWN | `MYWILSON` |
| The Last Laugh | I KEEP THE LAST LAUGH | `IKEPTHLASUG` |
| The Unwritten Name | THE PAGE FORGETS MY NAME | `THEPAGFORSMYN` |
| Thornwave | I HEAR THE TRUTH IN THE STATIC | `IHEARTUNSC` |
| Enough | I STOP BEFORE THE SMALL THING BREAKS | `ISTOPBEFRHMALNGK` |
| Colour Stays | I KEEP THE COLOUR THE GREY WOULD TAKE | `IKEPTHCOLURGYWDA` |
| Keep My Name | I HOLD MY NAME THROUGH THE GREY | `IHOLDMYNAETRUG` |
| The Way Back | I FIND MY WAY BACK FROM THE GREY | `IFNDMYWABCKROTHEG` |
| Look Twice | I LOOK AGAIN BEFORE I NAME THE THING | `ILOKAGNBEFRMTH` |
| The Small Living Thing | I NOTICE THE SMALL LIVING THING | `INOTCEHSMALVG` |
| Awake Inside the Day | I AM AWAKE INSIDE THIS DAY | `IAMWKENSDTHY` |

## Integration

The Core Margins Pack, version 1.1, contains the entire set as free,
year-round doodle assets with explicit sigil traits and subject tags.
They use the existing selection and placement machinery:

- Ordinary reading leaves and quotation/marginalia interleaves use
  `LeafDecorationLibrary`, including its rest, density, and collision rules.
- Illuminated photographs and enchantments use the same catalogue and retain
  exact asset names in saved composition plans and their rendered exports.
- Quote cards already draw from the Core Margins doodle/stamp pool.
- Pagewright has a permanent **Wicker's Sigils** shelf with all fourteen
  available together, including search, suggestions, and manual placement.
- The shared `MarginaliaDeck.regular` print deck now takes these assets from
  the Core catalogue, covering editions, Field Books, and keepsakes.
- The older fixed Wicker Dare card style uses four of his marks directly.
- Sigils remain available to the existing folio artifact inspector.

The image-only illustration, place, and photograph interleaves keep their
full-frame layouts. The marginalia and quotation interleaves are the layouts
that carry additional automatic marks.

## Optimization and provenance

Original transparent PNGs are preserved in
`output/wicker-chaos-sigils-2026-11-07/masters/`.
App copies trim empty exterior pixels, fit the ink within 512 × 512 pixels,
and add twelve transparent pixels per side. Their proportions and alpha
channel are preserved. No paper rectangle or painted background is included.
PNG metadata is stripped.

All fourteen app assets total **1,013,537 bytes**. The largest is about 101 KiB.
A further lossless PNG compression pass was accepted only when decoded RGBA
pixels matched the resized derivative exactly. No lossy colour quantization
was used. Both large and 64-pixel proofs were visually inspected on the Book's
paper colour. Decoding all fourteen simultaneously would hold 13,056,960
bytes of raw RGBA data; this is a calculated upper bound for these images,
not a measurement of runtime memory.

The [production record](art-provenance/wicker-chaos-sigils-2026-11-07.json)
retains exact prompts, intentions, reference artwork, master paths, crop/size
settings, and master/asset SHA-256 hashes. The review sheet is
`output/wicker-chaos-sigils-2026-11-07/sigils-proof.jpg`.

The regression suite checks cabinet and print reachability, safe placement
traits, semantic routing, ordinary-leaf and interleaf encounters, and
illuminated-plan preservation. Device rendering is a separate validation.
