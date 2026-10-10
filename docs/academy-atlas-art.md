# Academy illustrated atlas

Generated with the built-in image generation tool on 2026-10-09. Four original
1024 × 1536 parchment plates, copied into versioned AcademyAtlas imagesets in
the app asset catalogue. The raster plates contain architecture only; all
room labels, Cast names, footprints, story closures, and Reader doors remain
live app layers. The floor coordinates in AcademyIllustratedAtlas were
surveyed from the output rather than assumed from prompt coordinates.

Art direction: a master engraver's secret school atlas on warm honey vellum;
irregular sepia nib strokes, ochre washes, carved stone, ornate book borders,
roots, ivy and distinctive rooms. Roofless map composition, no UI, no people,
no baked-in footprints or lettering. Quiet central floors for live names.
Four leaves: School & Gardens, the Undercroft, the Upper Rooms, Tower & Stacks.

## Saved plates

- [School & Gardens](../InsideCoverApp/Assets.xcassets/AcademyAtlas-ground-v1.imageset/AcademyAtlas-ground-v1.png)
- [The Undercroft](../InsideCoverApp/Assets.xcassets/AcademyAtlas-undercroft-v1.imageset/AcademyAtlas-undercroft-v1.png)
- [The Upper Rooms](../InsideCoverApp/Assets.xcassets/AcademyAtlas-upper-v1.imageset/AcademyAtlas-upper-v1.png)
- [Tower & Stacks](../InsideCoverApp/Assets.xcassets/AcademyAtlas-labyrinth-v1.imageset/AcademyAtlas-labyrinth-v1.png)

## Integration and verification

AcademyIllustratedAtlas projects the existing chart onto four leaves with
39 permanent floor registrations. Room IDs, people, Pages, closures and
the passage graph remain intact. Every level shows its resident count;
Find a name focuses the correct leaf. Marked cross-level passages and room
notes navigate the same graph. My Dorm follows the bound Chapter's upstairs
door without inventing an interior. Reader Anchor chambers extend north
of the Stacks plate. Monthly borrowed rooms unfold beneath their entrance
leaf. The Misfiled Days shelf still moves between three daily alcoves.

Walking is split into timed stretches on each leaf, including departures,
arrivals, intermediate floors, and journeys that leave and return to one
leaf. Permanent passage routes follow a survey of the illustrated corridors;
the plates contain no baked-in labels or footsteps. Recent departures are
reconstructed for up to four minutes when the map opens. Route length,
purpose, and each person's stable pace determine the walk's duration; quiet
hours have no invented hallway occupants. Story arrivals and releases keep
their exact timestamps. Find a name focuses the current corridor or landing
and describes a walker as on the way to their destination.

Source verification: Swift frontend parsing and git diff --check passed.
All four asset-catalogue references resolve. All 18 combinations of six
Reader home placements and three daily shelf alcoves have in-bounds floor
areas and no overlaps on the same leaf. A browser registration study with
room labels and deliberate Cast layout fixtures was visually inspected;
it is not native app or device evidence. Fifteen new Academy regression tests
cover room/Cast preservation, Binding, Anchors, stairs, borrowed rooms,
journey partitions, return trips, the daily shelf, and believable hallway
journeys on reopening. The existing lunch-departure test now checks the whole
journey lifetime. These tests have not
run. No app build or Rabbit installation was performed for this iteration,
following bj's instruction to build only when asked. Rabbit retains the
2026-10-08 vector campus build until a new build/install is requested.

Full production prompts follow. These describe intended placement; the
generated images, not prompt coordinates, determine the final surveyed floor.

## ground

Use case: illustration-story. Asset type: full-bleed portrait parchment map plate for a magical living book app. Create a magnificent hand-illustrated antique map of a fictional Academy inside an infinite library, seen STRICTLY FROM ABOVE as roofless rooms and courtyards. Vertical 2:3 canvas, highest detail. A master engraver's copperplate etching, warm honey vellum, irregular sepia nib strokes, tiny ochre washes, delicate cross-hatched masonry, imaginative ancient architecture. Beautiful aged edges, subtle fold marks, an ornate compass, books becoming architectural borders, miniature ivy and marginal flourishes. Feels like a treasured wizard's secret atlas, with its own original design. NO computer CAD look, no straight boxed flowchart, no isometric perspective, no UI, no people, no footprints, no text or lettering anywhere (live labels will be added in the app). Intricate drawing along walls; LIGHT QUIET EMPTY parchment in the middle of EACH room for live moving names.
LAYOUT IS ESSENTIAL: all coordinates are percentages of the full image (x from left, y from top), sizes width x height. Create exactly these distinctive chambers, with generous winding stone cloisters connecting their doorways. Centers and usable floor areas: at (50,36),32x16: Great Hall, long carved banquet hall with tables confined to edges and a broad empty middle; (52,57),22x10: circular Binding Hall with candles on perimeter; (20,35),22x18: cruciform Inkworks, quills and desks around perimeter; (79,34),20x18: open Momentum Yard with curved colonnade; (18,56),23x13: cozy Book Burrow with hearth, shelves and deep armchairs along edges; (17,72),18x10: Rain Room with fine raindrop ink and roof gutter around empty floor; (50,18),12x10: grand spiral North Staircase. Five Chapter common rooms around the lower cloister: Emberheart (35,75),16x10 with fireplace; Mossbloom (59,75),16x10 with plants; Tidecrest (79,75),16x10 with scalloped round windows; Riddlewind (39,89),19x10 with large shared table tucked toward edge; Duskthorn (64,89),19x10 thorn-shaped bay windows. Gardens along the right: open field gate (90,54),12x8; walled garden (79,61),19x10; secluded garden (89,89),12x10. Two quiet reserved expanses of parchment (22,16),24x12 and (79,15),24x12 for rooms arriving from other books. Keep these empty. The page fills the image with no outside tabletop, no shadows around a physical sheet. Ornate modest border inside outermost 3%, clean flat warm parchment beyond.

## undercroft

Use case: illustration-story. Asset type: full-bleed portrait parchment map plate for a magical living book app. Create a magnificent antique roofless top-down floor map of THE UNDERCROFT beneath a magical Academy, portrait 2:3 canvas, highest detail. Master copperplate engraver's hand on warm honey vellum, fine irregular sepia nib, ochre wash, etched arches, tiny cross-hatched masonry, subtle stains and fold marks. A treasured wizard's secret atlas with its own original design. Labyrinthine stone passages, cellars, buried roots and book-spines blending into decorative borders. NO modern CAD, no block diagram, no isometric view, no text, no people, no footprints. The entire page is flat parchment without any tabletop. Crucially the central floor of each chamber is quiet LIGHT EMPTY parchment for live names; decorative furniture rests near walls.
Exact normalized layout as percent of full image, x left/y top: Still Room centered (50,30), width30 height16, a serene round chamber with five stone resting niches along edge. Resonance Chamber centered (50,60), width40 height21, an extraordinary scalloped music chamber with organ pipes and flowing etched sound ripples confined to perimeter. Bibliophonic Hall centered (20,46), width23 height18, acoustical vaulted library hall with spiral bookshelves around edge. Kitchens centered (79,44), width25 height18, a grand old vaulted kitchen with ovens, copper pots and hearths along sides, empty central work floor. Pantry centered (79,69), width20 height13, shelves of jars around outer walls. Join them with believable winding vaulted passages, broad pale walkable centers; carve stair landings into upper and outer doors. Leave (24,79),width26 height14 as clear reserved parchment for a temporary room. An ornamental academy seal and compass at the lower margin; no letters at all. Great rich artistry, readable map, no new significant room in empty central areas. Outer 3% flat vellum border with restrained book-root scrollwork.

## upper

Use case: illustration-story. Asset type: full-bleed portrait parchment map plate for a magical living book app. Create a magnificent antique roofless top-down map of the UPPER ROOMS of a magical Academy inside a vast library. Portrait 2:3 canvas, highest detail. Master copperplate etching on warm honey vellum, fine irregular sepia nib, pale ochre washes, age marks and paper folds. Dense exquisite ornament around walls; quiet LIGHT EMPTY parchment in every room's middle for live Cast names. Fantastical gently asymmetrical architecture, slender staircases, airy cloisters and bow windows. This should feel like a treasured wizard's secret atlas, completely original, no CAD appearance, no block diagram, no perspective, no people, no footprints, no text anywhere. No tabletop, full page fills frame.
Exact chamber positions in percent of image x from left/y from top, width x height: Glint Hall center (50,28),34x18, luminous circular observatory hall with windows and small star instruments near walls; Spark Annex (79,28),18x13, inventive octagonal laboratory with filigree rods along edges; Old Reading Room (20,28),20x13, bay windows and corner bookshelves; Faculty and Staff Quarters (28,48),30x13, a beautiful grouped sleeping wing with small partitioned alcoves near perimeter and shared open center; Guest Rooms (73,48),22x12, guest sleeping wing. Leave clear small PRIVATE door alcove at (50,49),12x6. Five dormitory wings, every one distinct, connect via sweeping galleries: Emberheart centered (18,68),25x12 with hearth motifs; Mossbloom (50,68),25x12 with climbing plants; Tidecrest (81,68),25x12 with scalloped windows; Riddlewind (32,86),25x12 with interwoven balcony; Duskthorn (67,86),25x12 with thorn tracery. Beds are TINY alcoves along outside walls; each wing has an open spacious center for animated names. A tiny empty private doorway below each dorm wing, not a sixth bedroom interior. Quiet reserved parchment near (22,12),24x10 for a future room. Warm beautiful majestic delicate hand artistry, not grids. Modest book-scroll border within outer 3%.

## labyrinth

Use case: illustration-story. Asset type: full-bleed portrait parchment map plate for a magical living book app. Create a magnificent antique strictly top-down roofless floor map of THE TOWER AND THE LABYRINTH STACKS surrounding a magical Academy. Portrait 2:3 canvas, highest detail. A master copperplate engraver drew this secret atlas on warm honey vellum: exquisite irregular sepia nib linework, pale ochre washes, subtle fold marks, delicate crosshatching, architecturally believable but impossibly immense library. Tower stair spirals, bookcases bending into graceful mazes, arched landings, tiny handwritten-looking abstract flourishes but NO ACTUAL TEXT or letters. No people, no footprints, no UI, no tabletop, no modern CAD, no isometric perspective. The room centers must be LIGHT EMPTY floor parchment for live names.
Exact layout in percent of full image x from left/y from top, width x height: Outer Stacks at (50,15),width46 height13, an open threshold lined by towering bookcase edges, several doors on north face opening onto blank parchment; central Stacks gallery at (50,43),width43 height20, a grand sinuous library atrium with shelves on perimeter and quiet open floor middle; Headmistress Tower at (22,68),width25 height18, exquisitely detailed circular stone tower floor with a delicate spiral stair along perimeter, clear center; East Stacks at (80,43),width20 height17, book-lined gallery opening east; Vault of Doors at (79,69),width24 height17, strange vaulted chamber lined with mismatched ornate doorways, clear center; Quillquarium at (52,79),width23 height14, glassy arcaded aviary with tiny quills around perimeter and a small drawbridge; a little movable shelf alcove (20,39),width20 height7, for misfiled days. Leave clear reserved parchment (22,19),width24 height12 and (76,22),width24 height12 for borrowed rooms. Connect rooms with broad paler serpentine library passageways. Outer perimeter scrolls, book-spine illustrations and exquisite compass rose lower left, but quiet plain centers. A piece of extraordinary narrative cartography, detailed and coherent. Outer 3% flat warm vellum.
