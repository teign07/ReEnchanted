# Monthly edition plates

Each month's pack commissions its own illustrations for the printed books, so
every issue looks like that month and the Cast files aren't the only pictures.
The books find them by file name. A month with none prints with the Book's
standing art, so a missing plate never breaks a binding.

## What a month commissions

| Plate | File name in `plates/` | Size | Where it prints |
|---|---|---|---|
| Frontispiece, 1 | `frontispiece.png` | portrait, 1500 × 2250 px or larger | Full page before the monthly's Almanac |
| One per story scene | `scene.<scene id>.png` | landscape, 2400 × 1600 px | Under the chapter head in the Month's Tale; above the scene in the weekly; as the weekly's facing chapter plate |
| The month's Cast, 4–6 | `cast.<cast slug>.png` | portrait, 1500 × 2250 px | The monthly's Cast pages and the weekly's Cast plates, in place of the standing portrait |
| General plates, 6–8 | any other name, e.g. `lanterns-in-the-kitchens.png` | either, 2400 px on the long side | Weekly chapter plates and filler plates on short weeks |

Scene ids are the `id` of each `storyScenes` entry in the pack's
`*.reenchantedevents.json`. Cast slugs are the Cast's usual ids (`serenity-brown`,
`wicker-eddies`, `penny-blackletter`, `professor-permancer`, `ambrose-trencher`, `soren-ng`).

## Style

- The same hand as the Cast plates: ink and watercolour, warm cream paper, a little foxing.
- No words in the picture. The book sets the captions.
- Leave a soft margin; every plate gets a white mat and a gold rule.
- Print-safe colour: no pure black, no neon. The paper is 80# coated and takes colour well.
- Scene plates show the scene's moment, not its ending. A reader may meet the picture before the words.

## Shipping them

Put the files in the pack's `plates/` folder and add one line to `issue.json`:

```json
"plates": { "prefix": "<pack-slug>.plate.", "directory": "plates" }
```

`scripts/monthly_issue.py` stages every PNG or JPEG in that folder as
publication media (`<pack-slug>.plate.<file stem>`). No pack file has to mention
them, and no JSON schema changes, so an older app can't fail to install the month
because of them. Rehearsed 2026-10-10: the Worker serves them at every window and
the installer files them under the names the books read.

**Size: the phone refuses any publication file over 2 MB, and a month installs
all or nothing.** The script therefore re-encodes any plate over the limit as a
high-quality JPEG at 2400 px (quality 90 down to 70) and refuses the release if
one still won't fit. Hand over the full-size PNGs; the script does the rest.

## October 2026 (Count Unbound): the list

Frontispiece, then one plate per scene the month tells:

- `scene.academy.school.chair-first` — The chair that gets there first
- `scene.academy.school.sentence-coat` — A sentence with its coat off
- `scene.academy.school.wrong-way` — The wrong way to the classroom
- `scene.count-unbound.scene.sunday-jump` — Sunday Book Jump Club
- `scene.count-unbound.scene.east-stacks` — The East Stacks Incident
- `scene.count-unbound.school.map-room` — The map with room left
- `scene.count-unbound.scene.man-reading-himself` — The Man Reading Himself
- `scene.count-unbound.scene.wrong-castle` — The Wrong Castle
- `scene.count-unbound.strategy` — Which preparation?
- `scene.count-unbound.scene.future-tense` — A Future Tense
- `scene.count-unbound.scene.first-nightbound-morning` — The First Nightbound Morning
- `scene.count-unbound.protocols.threshold` — Threshold Protocols

Cast in October: `cast.serenity-brown`, `cast.wicker-eddies`, `cast.penny-blackletter`,
`cast.professor-permancer`, `cast.ambrose-trencher`.

Six general plates of October at the Academy: lanterns in the Kitchens, fog on the
North Stair, the East Stacks after the shelves fell, the Great Hall at supper, a
window in the Vault of Doors, the Labyrinth's map half-drawn.

## Proofs

`EditionProofHarness` writes placeholder plates (`PLATE · …`) into the proof
folder and points `EditionPlates.proofDirectory` at them, so every proof shows
where real plates land.
