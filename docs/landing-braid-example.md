# The public braid example

The website's `#nightly-braid` section shows **The bakery**, the saved braid from
23 October in the heavy October development simulation. Its format remains
kept Pages, that night's braid, and later Pages beside a later braid passage.

The Reader is synthetic. These are actual saved outputs from the app's braid
pipeline over that simulated Reader's Pages, not a person's private archive.
The public section labels this distinction. Its braid wording is unchanged.

## Sources

- `InsideCoverApp/EditionProofHarness.swift`: `FieldBookFixture` supplies the
  heavy October diary and other Pages; its `braid-days` export supplied the lab.
- `Tests/InsideCoverCoreTests/BraidMonthLabTests.swift`: the simulation runner
  uses the app's planner, wonder braid, repairs and audit, with model turns
  handed to the local Gemma lab server.
- `docs/fixtures/real-braids-october-2026.json`: original complete saved braids.
- `docs/fixtures/landing-braid-example-october-2026.json`: the selected inputs
  copied from the October days export, the earlier souvenir, the resolved
  Academy world beat, both saved braids, and the later Reader Pages. Keeping
  these inputs here makes the public example traceable without temporary files.

## What is displayed

The earlier memory is the 2 October bakery souvenir. The three 23 October
kept Pages are the bakery cat note, the Book's **Mirror, Mirror** Page (labelled
as Book fiction), and the Reader's diary about mapping the street by smell.
The leaning Academy rooms are separate fictional world context, not an
additional Reader-authored Page.

The follow-up uses the 27 October quip and 30 October diary, followed by two
verbatim paragraphs from the 30 October saved braid, **The back step**. It is
labelled as an excerpt, not as a generated weekly synthesis.

`first-reading.js` draws its before/after demonstration from this same HTML:
`data-proof-receipt` selects the cat note and `data-proof-excerpt` selects the
last three sentences of the paragraph in which the bakery memory returns.
The full paragraph remains in the main braid. It must not retain the former
invented return-slot demonstration or introduce another copy of the prose.

These development outputs include best-effort audit findings in the saved
fixture. The public example demonstrates an actual run, not a claim that all
generation quality gates passed or that it proves an outcome for real Readers.
