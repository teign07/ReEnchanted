# Edition enrichment: Tarot cards

Implemented at source level on October 29, 2026. No build or native PDF render
has been run for this change.

The monthly edition can carry one illustrated retrospective page, **The cards
that kept finding you**. It selects up to three cards with at least two dated
appearances, across actual interleaf visibility receipts and Tarot readings.
Each card has its installed artwork, name, separate interleaf/reading counts,
and dates. It adds no interpretation or claim that a recurrence predicts or
explains the Reader's life.

The weekly issue has a simpler **A card from your week** inset: one card's
artwork, name, and interleaf/reading counts, in spare closing-page space. It
prefers the most frequent card but can include a single actual appearance;
the monthly page still requires recurrence. The selection is frozen in the
kept `WeeklyIssue`, so later receipts do not change an already-bound issue.
Older saved issues decode without an inset and are not backfilled on reprint.

## Evidence

- Interleaf candidates do not count. The existing visible-leaf and visible-mark
  hooks record the actual card asset after it appears.
- One card on the same boundary on the same local day counts once. Layout
  refreshes and revisiting that boundary that day do not inflate its count.
- Readings record a card when the Reader turns it over. The reading/card ID
  deduplicates reopening and later saving the reading.
- Saved typed reading artifacts can supply historical readings, using their
  original draw date. Copies of the same reading do not add to its count.
- The old interleaf last-seen cache cannot recover historical frequencies.
  No counts are invented from it. The printed page says it counts only the
  appearances for which the Book has dates.
- New local receipts contain card ID, source, date, and a deduplication ID.
  They contain no question, response, or reading prose. Boundary IDs are hashed.
- Selection uses a half-open calendar month, deterministic tie-breaking,
  and ignores unknown cards or malformed reading metadata. The chosen summary
  and timezone are saved inside the edition's optional keepsake field.

## Page and cost contract

- At most **one content page**. A physical binding may need an additional
  rounding page; ordinary binding geometry and quoting still apply.
- No new assets, generated prose, network calls, or paid services.
- Weekly slices continue to omit the full monthly keepsake page. The single
  weekly card uses the closing page's existing art space in the Tale, or spare
  space after the closing text in the magazine fallback. It is omitted when
  the allotted rectangle is too small. The drawing helper cannot begin a page
  or advance a cursor. No weekly page allowance, monthly cap, binding
  specification, price, or margin changes.
- The Tarot page is the first thing removed by monthly print fitting, before
  archive sections or Reader days. It is also expendable in Handbook fitting.
- Seasonal and annual enrichment, complete spread reproductions, QR media,
  and Ruin pages remain separate increments.

## Validation still needed

`TarotEditionTests` covers source combination, duplicate receipts and saved
copies, calendar bounds, ranking, missing evidence, old-edition decoding,
weekly exclusion of the full monthly page, and fitting without removing Reader
material. Weekly tests also cover a single appearance, combined source counts,
weeks crossing a month boundary, and frozen/older-issue decoding. The tests
are added but unrun because running them requires a build.

After a requested build, review native PDF output with one, two, and three
qualifying cards; confirm print rounding and a cap-tight month's fitting;
exercise visible versus preloaded interleaves, card turns, reopening,
and local persistence across app restart. Check the weekly inset with roomy
and crowded closing pages in both Tale and magazine layouts, requiring exactly
the same page count with and without the inset. A physical proof remains distinct
from PDF layout verification.
