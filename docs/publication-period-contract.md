# Publication Period and Edition-Play Contract

Pinned 2026-08-23.

## What the Bindery binds

The Bindery always names an exact, completed interval. It never infers “the
last one” again after the reader has made a choice.

| Edition | Clock | Default | Reader may choose | Final binding gate |
|---|---|---|---|---|
| Weekly issue | Reader Week: seven days from the first real Keep | Newest completed nonempty Reader Week | Any completed nonempty Reader Week | The week has closed |
| Monthly edition | Calendar month | Newest completed nonempty month | Any completed nonempty month | The month has closed |
| Seasonal edition | Fixed calendar blocks: Jan-Mar, Apr-Jun, Jul-Sep, Oct-Dec | Newest completed nonempty block | Any completed nonempty block | All three months have closed |
| Annual edition | Calendar year | Newest completed nonempty year | Any completed nonempty year | The year has closed |
| Bound Year dispatch | Three-month blocks from the membership anniversary; every fourth dispatch covers the whole membership year | Earliest closed, earned, unresolved dispatch | Steering changes cover, dedication, title, address, or hold; it does not substitute a calendar edition | The dispatch is closed and paid for |

Current periods may be previewed as gathering. They cannot be finally bound.
Empty completed periods remain honest gaps and do not receive filler.

## Permission is not a notification

A completed period with one curated page is bindable when the reader asks.
Recommendation thresholds only decide whether the Book knocks:

- weekly: two curated pages;
- monthly: three curated pages;
- seasonal and annual: one curated page.

An invitation may expire. Binding permission does not. Rebinding creates a new
rendering of the same period identity and replaces that period's current shelf
copy; it does not consume or hide the period.

## The clock updates itself

Eligibility is derived from the archive and the date, not stored as a stale
“current month” flag. The app reconsiders it:

- after launch hydration;
- whenever the app returns to the foreground;
- just after the local day turns;
- after a Keep or import changes the archive.

Reader Weeks get one persisted epoch: the local calendar day of the first real
Keep and the time zone in which that boundary was established. Importing an
older archive later cannot renumber already-lived issues.

## Content packs contribute play; templates own placement

Each monthly content pack contributes authored `EditionPlayLeaf` definitions
to one catalogue. A leaf declares:

- stable id and content-pack version;
- cadence and event occurrence;
- form, footprint, and template slot;
- finished reader-facing copy;
- prompts, answer key, and optional artwork asset.

The binding freezes the selected definitions as `BoundEditionPlayLeaf`
snapshots. Later copy changes affect later bindings only.

The compositor, not the content pack, owns geometry:

| Template | Reserved play placement |
|---|---|
| Weekly | One `weeklyInterruption` after the contents; a bleed-through form receives a blank reverse |
| Monthly | `afterWorldEvent`, `readerWorktable`, then `beforeClosing`; at most two pool leaves with different forms |
| Seasonal | One `seasonFinale` spread after the month chapters |
| Annual | One `readerLastWord` leaf immediately before the final colophon |

Facing spreads reserve gutter-safe fields. Coloring and cut-out rectos receive
blank reverses. Answer keys print inside the same artifact near the colophon.

## What never feeds back

The app stores which authored leaves were bound. It does not store whether the
reader colored, solved, pasted, cut, wrote, contradicted, or ignored them.
There is no scan-back prompt, completion state, achievement, OCR pass, or Book
callback. The bound edition is the destination.

## Adding the next month

1. Author the content master, including answers and physical footprint.
2. Add one `EditionPlayContentPack` manifest and its named assets.
3. Use existing forms and slots where possible. A genuinely new physical form
   earns one compositor implementation shared by every cadence.
4. Add selection and snapshot tests.
5. Render screen and exact 6 x 9 PDFs. Inspect every leaf and reverse.
6. Print a physical proof for pencils, markers, cutting, gutter reach, show-
   through, and signature order.

## Evidence still required for this change

Static parsing and project-file validation do not prove the PDFs. Before the
September packet is called finished it still needs:

- test execution;
- a rendered weekly, monthly, seasonal, and annual PDF inspection;
- page-order and blank-reverse checks;
- an exact 6 x 9 print-interior preflight;
- a physical coloring and writing proof.
