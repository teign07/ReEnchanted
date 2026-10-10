# The public Book's monthly marginalia

The website shares the app's permanent cabinet and the selected monthly pack.
The introduction and Curse explanation use small illustrated turns; the quiet
pages, encounters and extra margin drawings all draw from the same shuffled
pool. Drawings are used once in each reading. Reflow deals the remaining drawings
again from the same place, so resizing does not exhaust the cabinet. If the pool
runs out, additional decorative marks are omitted rather than repeated.

## Change the month by hand

Edit `LandingPage/marginalia-theme.json`:

- `enabled`: use `false` for the permanent cabinet alone.
- `pack`: repository-relative path to the app's `*.reenchantedpack.json`.
- `artDirectory`: repository-relative directory containing the pack's PNG art.

The exporter selects doodles tagged `monthly-content`, skips directed-only
handwritten notes, and keeps each drawing's immutable app asset ID. By default,
the PNG filename is the last component of that asset ID plus `.png`. For another
naming convention, add a `files` object mapping complete asset IDs to filenames.

Run `python3 scripts/sync-web-marginalia.py`, then inspect the opening and a few
quiet pages in a browser. The normal `scripts/deploy-landing.sh` workflow also
runs this exporter before publication. Generated WebPs live in
`LandingPage/assets/book/monthly-marginalia/`; the generated shelf is
`LandingPage/marginalia-catalogue.js`. Do not edit the generated catalogue by hand.

There is no automatic date switch: selecting the next pack is deliberate, so an
unfinished future issue cannot become public just because the month changed.
Changing drawing bytes still requires a new immutable asset ID in the app pack.
The website export does not change or publish the app's monthly release.

## Replace a damaged permanent cutout

Keep the app's logical asset name, but save the replacement PNG with a versioned
filename (for example, `MarginaliaShell-v2.png`) inside its existing imageset and
update that imageset's `Contents.json`. The exporter gives the drawing a matching
versioned WebP URL, so browser caches cannot bring the damaged image back. The
reading and ambient marks resolve their artwork through the generated catalogue.
Run the exporter after the change; it retires the old unversioned cabinet export.
