# Print value audit — is the paper worth the money?

Written 2026-09-30. Question: do the nightly braid and every physical product earn
what we charge, measured per printed page? bj's rule added during the audit:
**no blank pages, except where space is warranted.**

## How this was measured

- **Prices and costs** come from code, not memory: `lulu-quote-worker.mjs`
  (`minimumProductPriceCentsPerCopy`, `retailMarkupSubtotalCents`, `EDITION_PAGE_CAPS`),
  `PrintSpec` in `Shared/MonthlyEdition.swift`, `BoundYearPricing`.
  Lulu cost is $0.1389/page plus a base of $1.98 softcover, $10.68 case, $14.99 linen, $3.78 saddle.
  Shipping is **$6.88/parcel, implied** by the `pageCap` comment's $124 member-year figure
  (three 112pp softcovers + a 208pp linen + four parcels). Not a live Lulu quote.
- **Page counts** come from the Sept 24 proofs in `output/edition-proofs/`, rendered by
  `EditionProofHarness` from a synthetic year (229 days, 631 pages). Their braids are fixture
  prose of about 110 words, not device braids.
- **A real braid is 150–260 words** (`BraidScenePlan.deviceHonestBand`, cap 260 on phone-class
  hardware). Measured: about 290 words fill a printed leaf, and a ~110-word braid took
  0.55 of a page. **Model: a 200-word braid takes 0.75 printed page (range 0.6–0.95).**
- Reader profiles: *engaged* = 25 braid nights a month, *devoted* = 30, *light* = 12.
  Non-braid content is about 16pp in a monthly, 11pp per chapter in a seasonal, 8pp per chapter in an annual.
- Fees: Stripe 2.9% + 30¢ on à la carte (added to the customer's total by the Worker);
  subscriptions absorb Stripe plus 0.7% billing.
- Scratch model: re-run from the tables below; assumptions are labelled, none are hidden in the prices.

## The nightly braid, at page level

| | Printed pages per braid | Braids per printed leaf |
|---|---|---|
| Proof (fixture, ~110 words) | 0.55 | ~2 |
| Real braid, 200 words | 0.75 | ~1.3 |
| Real braid, 260 words | 0.95 | ~1 |

A full month of 30 braids is **about 22 pages**. That is 24% of the monthly cap (92) and
about 60% of a realistic monthly book. A season is about 68 pages of braid, inside its 112 cap.
**A year of braids is about 270 pages; the annual cap is 208.**

## Per product, per printed page (customer pays shelf + shipping + Stripe)

### Monthly softcover, $49.99 floor, 32-page press minimum

| Reader | Content pp | Printed pp | Blank pp | Customer pays | $ per printed page | $ per content page |
|---|---|---|---|---|---|---|
| 9 braids (the proof) | 23 | 32 | 9 | $58.82 | $1.84 | $2.59 |
| 12 braids (light) | 25 | 32 | 7 | $58.82 | $1.84 | $2.35 |
| 25 braids (engaged) | 35 | 36 | 1 | $58.82 | $1.63 | $1.69 |
| 30 braids (devoted) | 38.5 | 40 | 2 | $58.82 | $1.47 | $1.53 |

- The price is a floor, not a function of pages: a thin month pays the same $58.82 as a thick one.
- Contribution is $43 on a 32pp book (87% of shelf price). Direct from Lulu the same paper costs about $14.
- **The monthly proof is 11 blank leaves of 32 (34%).** They are trailing ruled "Notes" leaves
  (`blankEndpaper`), added only to reach Lulu's 32-page minimum.
- Per-braid view: the book's braids cost the reader about $1.20–$1.60 each by page share, and
  the whole book about $2.35 per night bound for a light reader.

### Seasonal softcover, $69.99 floor

| Braids/mo | Printed pp | Customer pays | $ per page |
|---|---|---|---|
| 9 | 60 | $79.40 | $1.32 |
| 12 | 66 | $79.40 | $1.20 |
| 25 | 96 | $79.40 | $0.83 |
| 30 | 108 | $79.40 | $0.74 |

Sound for an engaged reader. Thin seasons are the weak case. Caps (112) are never hit.

### Annual cloth & foil hardcover, $99.99 floor, cap 208

Customer pays $110.27 for 184–208 pages: **$0.53–0.60 a page**, the best value in the catalogue
and competitive with Storyworth (next section). But:

| Braids/mo | Braids earned | Braids printed | Share |
|---|---|---|---|
| 12 | 144 | ~141 | 98% |
| 20 | 240 | ~141 | 59% |
| 25 | 300 | ~141 | **47%** |
| 30 | 360 | ~141 | **39%** |

The cap leaves about 106 pages for braids after chapter furniture. `EditionPrintFitting` trims
braids last (halving, floor 8 per chapter), so an engaged reader's hardcover holds **under
half their nights**, while every braid section's printed note still reads "Every night of the
month, in the order it happened" (`MonthlyEdition.swift` ~line 2546; only the archive section
re-titles itself when sampled). That sentence is false in the printed annual. It needs an
honest caption or a bigger cap.

### Weekly saddle-stitched, $19.99 floor, $15 contribution

The Oct 8–14 proof (7 kept pages) is 20 leaves; about **14 carry one sentence or less**
("The other scraps": one line, "One-Sentence Souvenir": one sentence, a blank white leaf behind the
worksheet, ornament-only endpapers). Customer pays about **$29.56: $1.48 per printed page, $4.22
per night, $7+ per page that actually reads.** This is the one product I would not sell as built.

### The Bound Year, per member-year

| | Annual $249 | Monthly $24.99 × 12 = $299.88 |
|---|---|---|
| COGS at an engaged reader (3 × 96pp softcover + 208pp linen + 4 parcels) | $117 | $117 |
| Fees | $9 | $14 |
| Net | **$122 (49%)** | **$168 (56%)** |
| Pages delivered | ~500 | ~500 |
| $ per page | **$0.50** | **$0.60** |
| Same four books bought separately | $309.96 shelf; $348 with shipping and fees | |
| Saving vs separate | 20% shelf; 28% landed | **3% shelf; 14% landed** |

Worth it on the page-level view: half a dollar a page for illustrated, personalised, hardbound
work, at a 49–56% margin. Three caveats:

1. **A monthly payer hands over $75 before the first volume ($22 COGS) arrives**, at the close of
   season one. That protects us; it is a long time to pay for nothing in hand. Free digital
   removed the old "something each month" (the Standing Order is gone).
2. **The annual repeats the seasonals.** Seasons one to three are months 1–9; the annual binds all
   12. About three quarters of the hardcover is nights the member already holds. Fine as an
   heirloom, but the "four volumes" promise is fewer unique pages than it sounds.
3. **The annual's cap truncates braids** (above), so the heirloom is the least complete of the four.

## Outside reference points (verify before quoting)

- Day One printed journals: $19.99 for 50 colour pages, then $0.10 a page (hardcover +$3.75),
  5.5×8.5. ([Day One](https://dayoneapp.com/guides/day-one-ios/book-printing/))
- Storyworth: $109 for a colour hardcover of up to 300 pages with a year of prompts, free shipping;
  extra copies $79. ([Storyworth](https://help.storyworth.com/en_US/book-pricing)) About $0.26–0.36 a page.
- The free alternative is our own: the app makes print-ready 6×9 PDFs
  (`exportPrintReadyEdition`), so a reader can print the same interior elsewhere for about
  $14 (36pp) to $22 (95pp) landed. **Paper has to beat the free PDF plus DIY printing**, since
  monthly stories and the braid itself are now free on the phone.

| Per page | Day One | Storyworth | Our monthly | Our seasonal | Our annual | Bound Year |
|---|---|---|---|---|---|---|
| $ | 0.25–0.40 | 0.26–0.36 | 1.47–1.84 | 0.74–1.32 | 0.53–0.60 | 0.50–0.60 |

## Verdicts

| Product | Verdict | Why |
|---|---|---|
| Bound Year annual ($249) | **Keep; strongest offer.** Fix cap and duplication | $0.50/pp, 28% under separate, 49% margin |
| Bound Year monthly ($24.99) | **Keep; make the first 90 days feel paid** | 3% off at shelf; $75 before the first book |
| Annual hardcover à la carte ($99.99) | **Keep; fix truncation** | Best $/page, yet prints under half an engaged year |
| Seasonal à la carte ($69.99) | **Keep** | $0.83/pp when engaged; $1.3 when thin |
| Monthly softcover ($49.99) | **Fix before selling** | $1.84/pp for a 32pp book that is a third blank |
| Weekly ($19.99) | **Rebuild or withdraw** | One sentence per leaf; $4.22 a night |

## The blank-page rule

Blank or near-blank leaves in the proofs (under 20 characters of text, or under 250):

| Proof | Leaves | Blank | Sparse | Cause |
|---|---|---|---|---|
| Monthly | 32 | 11 | 4 | ruled padding to the 32 minimum |
| Seasonal | 58 | 0 | 7 | stubs, dividers |
| Annual | 198 | 3 | 24 | padding, 12 chapter dividers, 2-line stubs ("Kept, Not Bound") |
| Weekly (Oct) | 20 | 1 | 14 | one line per leaf, blank reverse, ornament endpapers |

Sources of emptiness, and what each should become:

1. **Press-minimum padding** (`blankEndpaper` in three writers; weekly pads with ornament-only
   leaves before the colophon). Padding up to 11 leaves is the biggest offender.
2. **Sparse leaves**: a section opener with five lines ("What This Month Was"), a stub section,
   a one-sentence souvenir on its own leaf.
3. **Braid leaves**: about a third of each leaf is empty because items flow but do not pack.

Proposed order of operations for a short edition, stopping as soon as the press minimum is met:

1. **Relax `EditionCurator`'s sampling** and bring back the set-aside pages (the proof left out 5
   quotes, a braid and a sky note). This is the reader's own material, not filler.
2. **Breathe the layout**: one braid per leaf at larger type, with a plate, before adding pages.
3. **At most two "Notes" leaves** (a heading and rules): warranted, a real place to write.
4. **If it is still short, the edition is too thin for a softcover.** Offer a saddle-stitched
   booklet (4-page minimum, cheaper) or steer to the season. Do not bind and pad.

Step 4 needs a Worker change: saddle stitch is allowlisted for weekly only
(`CALENDAR_BOOK_VARIANTS`, `GIFT_PRESS_PAGE_COUNTS`) and the two sides must move together.

## Recommendations

1. **Zero trailing padding; enforce with a test** over the proof harness (no leaf with under N
   characters and no art, except a designated notes leaf and a tear-out worksheet's reverse).
2. **Price the monthly by its pages, not by a floor.** Day One's shape (base + per page) is honest.
   At $39.99 the contribution on a 36pp monthly is still $33, just under today's $35 guarantee,
   so the guarantee itself would have to move. This changes `minimumProductPriceCentsPerCopy` in the Worker and `PhysicalBookPricingPolicy` in lockstep.
3. **Fix the annual cap and its caption.** Options: raise the annual cap (each +50pp adds $6.95 COGS);
   set braids at 10pt for the annual only (about 0.45 page each: 365 braids ≈ 165pp); or change the
   note to "a chosen third of the year's nights". At 260pp the cloth annual costs about $51,
   well under its $99.99 shelf price.
4. **Weekly: withdraw à la carte or rebuild** to two reading leaves a day or a denser editorial
   shape; the present shape sells 7 sentences for $29.56.
5. **Make month one of the monthly Bound Year feel bought**: a bound welcome volume (about $8–10
   COGS) on joining, or a first-season dispatch at month two.
6. **Keep the Bound Year annual at $249.** The numbers do not argue for raising it, and the
   cap fix makes the heirloom the complete thing it claims to be.

## Open questions

- Are the Sept 24 proofs still representative? Commits touching the writers since then are
  the casebook and map work; re-run `--smoke-edition-proofs` after any fix.
- Real shipping: replace the $6.88 implied figure with a live Lulu quote per destination
  (the linen annual already fails Lulu quotes in Canada).
- Real braid length on-device: pull a month of actual device braids into the harness, since every
  per-braid figure here scales with it.
- How much is a braid worth when the phone shows the same text for free? Untested with readers.
