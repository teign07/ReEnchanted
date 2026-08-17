# The Bound Year — a quarterly print membership

A third rung above the Standing Order: four printed volumes a year, the last of
them the annual hardcover, sold on the web because Apple requires physical
goods to be sold there.

Written 2026-08-08, six weeks before the September 22 launch. Nothing here is
built yet — this is the plan, and the numbers behind it.

---

## The shape

| Rung | Price | Storefront | What it is |
|---|---|---|---|
| Free | — | — | The Book. Capture, keep, braid, every binding as a PDF. |
| **Standing Order** | $9.99/mo · $79.99/yr | App Store IAP | Every paid pack, plus one fresh pack a month. Digital only. |
| **The Bound Year** | $24.99/mo · $249/yr | Web · Stripe | Everything above, plus **four printed volumes**. |

The Bound Year ships **three seasonal softcovers and one annual hardcover**, in
that order, so the year lands on the best object rather than opening with it.

---

## Fulfilment: automatic, with a naming window that is not a gate

**Decided 2026-08-08.** A quarter closes, the volume binds, the Book shows the
reader what it made and what it wants to call the season — and **seven days
later it posts, whether or not they touched it.** Doing nothing is a complete
and correct answer.

### Why there is no "skip"

The first draft of this plan had a skip button. It was wrong twice over.

**It creates a debt.** In a box subscription, skipping means not being charged —
the skip *is* the refund. Here billing is annual and up front, so a skipped
volume is roughly $62 of value the member already paid for. You then owe them
either a credit (ugly to account for across a membership year) or nothing at all
(you kept the money and printed no book). There is no clean answer, so the
question must not be asked.

**And it argues against the Book.** From `PROJECT_OVERVIEW.md`: *"Trouble, grief,
fatigue, conflict, and difficulty are proof of life and deserve witness, care,
and transformation just as joy does."* An app that offers not to witness your
hard quarter is contradicting its own thesis. A hard season still gets bound —
that is not a consolation prize, it is the entire argument.

### What the window is for

Not permission. The Book showing its work before it commits ink, exactly as it
does with the season title and with a mark's evidence:

- **Name the season.** The highest-value thing in the window, and the reason it
  exists at all.
- **Confirm the address.** Four natural checks a year, no separate chore.
- **Add copies, or upgrade the binding** — see below.

### The one exception: hold, never skip

Rare, quiet, and it **defers rather than forfeits**. The volume is bound and
kept on the shelf, posted whenever they ask. Bereavement, illness, a season they
cannot look at yet. They lose nothing and nothing arrives at the worst possible
moment. Same shape as the grief valve and the one-tap rest in the feast
calendar.

---

### Built so far (2026-08-08)

- `SeasonTitler` — the Book proposes a season name **from evidence only**: a
  named thread that ran through it, a theme that held across more than one month
  ("one month is weather; two is a season"), or a recurring motif. Nothing to go
  on means no proposal — a quiet season is titled by its months and flattered
  with nothing. Every proposal carries its reason, so it is an argument the
  reader can disagree with rather than a word handed down.
- `SeasonalDispatch` + `SeasonalDispatchWindow` — the volume standing at the
  door. Seven-day window; **silence posts the book**; rename replaces the title
  and stops the Book arguing; hold clears `shipsAt` rather than passing it, so a
  held volume waits indefinitely and can still be named a year later; release
  grants a *fresh* window rather than shipping at once. Chosen upsell ids are
  deduplicated and sorted so the same choices always price identically — the
  Worker's amount check would reject an order that differed only by tap order.
- `SeasonalDispatchPageSourceAdapter` — the window surfaces as a Page, sharing
  the `.bindery` family with its own source (the weekly issue's pattern), so no
  199th page type. Distress-gated, because a parcel notice is never worth
  interrupting a hard day for. The copy says outright that it posts whether or
  not the reader does anything: it must not read as a permission slip.
- 27 tests across `SeasonalVolumeTests` and `SeasonalDispatchTests`.

### Still to build

1. **BookShop → Bindery shelf.** One-off physical books, web checkout. The
   smallest piece that earns money and needs no subscription machinery.
2. **`/options` catalogue + photo cover.** The zero-COGS upsell, on that
   checkout.
3. **The membership itself.** Stripe subscription mode on the Worker —
   **monthly *or* annual billing**, mirroring the Standing Order's two cadences
   — offer-code grant for the digital half, and the quarterly cycle that opens a
   dispatch window.
4. **Wiring the Page's actions** to the dispatch record and the Worker.

## Upsells: the catalogue lives on the server

The naming window is the natural upsell surface — the reader is already looking
at their own book, deciding what to call it.

**The catalogue and its prices live in the Worker, not the app.** Two reasons,
and the second is not optional:

1. **A new cover must not need App Store review.** If options are hardcoded in
   the app, every new cover art, foil treatment or binding is a release. On the
   server it is one row and a `wrangler deploy` — same day.
2. **The Worker already refuses client-supplied prices.** It computes the Stripe
   amount from its own policy and rejects any PaymentIntent that disagrees. An
   upsell priced in the app would simply fail the amount check. The server has
   to own the price, so it may as well own the whole option.

The app fetches options for a given volume and renders whatever it is sent. It
knows how to *display* an option; it never knows what one costs until it asks.

### Shape

```
GET  /options?variantID=…&pageCount=…   → [PrintOption]
POST /quote  { …, selectedOptionIDs: [String] }
```

`PrintOption`: `id`, `family` (`binding` | `finish` | `cover` | `copies`),
`title`, in-world `pitch`, `priceDeltaCents`, `appliesToVariantIDs`,
`requires` (e.g. a photo), and an optional `resultingVariantID` for options that
change the binding outright. The quote endpoint validates every selected id
against the same catalogue before pricing — an option the server does not
recognise is refused, exactly like an unknown print variant.

### The economics, and which ones to build first

| Upsell | COGS delta | Notes |
|---|---|---|
| **Cover from their own photo** | **$0** | Pure margin. Costs a render, nothing else. |
| **Cover from our art packs** | **$0** | Pure margin; also a reason to own packs. |
| Softcover → hardcover on a seasonal | ~$7–11 | Case wrap over perfect bound. |
| Cloth & foil upgrade | ~$4 | Linen wrap over case wrap. Best margin of the physical ones. |
| Extra copy (gift) | manufacturing + shipping | Half markup — cheap goodwill that drives gifting. |

**Build the zero-COGS ones first.** A custom cover from the reader's own
photograph is pure margin, needs no new print variant, and is the most personal
thing on the list — which makes it both the best business and the best product.
The binding upgrades can wait for the catalogue to prove itself.

**Shipments go out at the end of each quarter, never the start.** A monthly
member has paid $75 before the first volume costs us $15. That one choice
removes the cancel-after-shipment exploit without any policy language.

---

## What it costs to deliver

Per-page rate and shipping are measured, not estimated: `$0.0425/page` is the
6×9 standard-colour rate on 60# uncoated that both existing hardcovers use, and
`$7.99` is Lulu's real shipping quote. The perfect-bound base of `$3.20` is
derived from Lulu's published $5.54 for a 200pp B&W trade paperback and lands
within six cents, so it is well-founded but should be confirmed against the
sandbox before launch.

| | Cost |
|---|---|
| 3 × perfect-bound seasonal, 96pp | $21.84 |
| 1 × cloth-and-foil hardcover, 200pp | $22.91 |
| Shipping, 4 × $7.99 | $31.96 |
| **COGS per member-year** | **$76.71** |

Swapping the fourth softcover for the hardcover costs **$16/year**. It is the
best sixteen dollars in the business: the hardcover is the object people
actually want, and including it is most of what makes the tier feel generous.

**Shipping is 42% of COGS.** That is the whole argument for quarterly. At
monthly cadence, postage alone is $95.88/year and the same $249 nets $33
instead of $165 — twelve times the fulfilment for a fifth of the margin.

---

## Pricing

| Price | Stripe | Net/yr | Net/mo | **Members for $3k/mo** |
|---|---|---|---|---|
| $199/yr | $6.07 | $116.22 | $9.69 | 310 |
| $229/yr | $6.94 | $145.35 | $12.11 | 248 |
| **$249/yr** | $7.52 | $164.77 | $13.73 | **219** |
| $19.99/mo | $10.56 | $152.61 | $12.72 | 236 |
| **$24.99/mo** | $12.30 | $210.87 | $17.57 | **171** |

Annual at $249 against monthly at $299.88 is a 17% prepay discount — the same
logic as the digital ladder. It buys cash up front and eliminates churn.

### Why it reads as a steal

The anchor is honest. Full à-la-carte Books keep the existing $35
contribution-margin guarantee, with edition-aware floors: $49.99 for a monthly
softcover, $69.99 for a seasonal softcover, $89.99 for an illustrated
hardcover, and $99.99 for cloth-and-foil. The smaller weekly issue keeps a $15
contribution guarantee and a $19.99 floor. A long, expensive volume still uses
cost plus its full contribution margin; a floor can only raise that margin,
never eat it. Legacy app requests without an edition kind retain the old
$79.99 softcover floor so a saved checkout cannot change price underneath its
reader.

| | |
|---|---|
| 3 seasonal softcovers @ $69.99 | $209.97 |
| Annual cloth-and-foil hardcover @ $99.99 | $99.99 |
| **Four Books bought separately, before shipping** | **$309.96** |
| **Bound Year, paid monthly for a year** | **$299.88** |
| **Bound Year, paid yearly** | **$249** |

Both subscription cadences now cost less than the same four bindings bought
one at a time, even before à-la-carte shipping. The Digital Standing Order is
included as an additional gift rather than being used to manufacture the
discount claim.

But 20% is not a steal on its own. The lever that makes it one is the list
below: **give away freely the things that are free to duplicate, and never
discount the things that cost money.**

---

## What members get

### Things that cost us money

- Three seasonal volumes and the annual hardcover, shipped.
- Extra copies at half markup — cheap goodwill that quietly drives gift sales.

### Things that cost us nothing

These carry most of the perceived value and none of the COGS.

1. **A founding number.** Low numbers are scarce forever. Scarcity is already
   the mechanism in the Chosen register; this is the same move with a ledger
   entry instead of a page.
2. **Name in the colophon** of every volume printed for them.
3. **The Reader's Mark** — numbered, shown in the app *and* printed on the
   colophon page. Deliberately not a separate physical object: a wax seal is a
   fifth shipment and a fifth chance to go missing.
4. **A dedication page** the member writes themselves, bound into their own
   hardcover. Costs nothing, and it is the page they will photograph.
5. **A members-only pack each season.** Authoring time, zero marginal cost, and
   it uses the pack machinery that already exists across all seven families.
6. **First read** on every new pack before it reaches the Goblin Market.
7. **A voice in the Cast** — members name a thing, or choose a season's theme.
8. **A radio dedication** each season, through the existing banter system.
9. **A hand on the Bindery.** Members can override the EditionCurator's
   selection and choose what gets bound. Nothing to build but a door.
10. **The full PDF archive** of every past volume, theirs whether or not the
    membership stands.

---

## Where each tier is sold, and why both can appear in the app

**Yes — both can be surfaced in the app.** The reasoning matters, because it
determines how the tier must be described.

**Apple requires this split.** Guideline 3.1.5(a): goods consumed outside the
app *must not* use in-app purchase. The Bound Year could not be an IAP even if
we wanted it to be — it is four printed books. Physical goods have always been
sellable and linkable outside the app, worldwide, with no Apple commission.

**So the framing is not a workaround, it is the rule, and it is also true:**
The Bound Year is a subscription to printed books. The digital Standing Order
rides along as an included benefit. Describing it that way keeps it under
3.1.5(a) in every storefront, rather than depending on the US-only external
link allowances that followed the 2025 Epic injunction.

**The digital half is granted through Apple's own machinery.** On purchase, the
member is emailed an App Store **subscription offer code** granting a free year
of the Standing Order. Offer codes are Apple's supported mechanism for exactly
this — access obtained outside the store — so no digital entitlement is being
routed around them.

**The strongest position we hold:** every digital thing in the Bound Year is
independently purchasable through IAP at $9.99/$79.99. Nothing digital is
available *only* by paying us directly. The web tier therefore cannot be
characterised as selling digital goods outside IAP — it sells books, and
includes something we already sell through Apple.

### Rules for the in-app surface

- Describe the Bound Year by its **objects** — the volumes, the binding, the
  shipping. The digital benefit is a line item, not the pitch.
- Never compare prices to IAP, never suggest it is cheaper to buy outside, and
  never disparage in-app purchase. This is where apps get rejected.
- The Standing Order stays fully purchasable in-app, always.

App Review guidelines move. This reflects them as of August 2026, and the
framing above is the conservative reading — worth a note to review if the first
submission draws a question.

---

## The path to $3,000/month

Not everyone takes the top rung, and they do not need to:

| | Count | Net/mo |
|---|---|---|
| Standing Order, annual | 250 | $1,417 |
| The Bound Year, $249 | 120 | $1,648 |
| | **370 readers** | **$3,065** |

Against **530 readers** if we only ever sell digital. The print tier is not
mainly a margin play — it is what reaches the number with a third fewer people,
which is the real constraint on a one-person launch.

---

## Operations

- **Lulu drop-ships.** No warehouse, no packing. Fulfilment is an API call the
  worker already knows how to make.
- **~876 shipments/year at 219 members.** At a 2–5% failure rate that is 20–40
  reprints and lost-package conversations a year. Fine for one person. Monthly
  cadence would be 2,600 shipments and up to 130 problems — a part-time job
  nobody asked for, and the quiet argument for quarterly that has nothing to do
  with margin.
- **Cash flow is favourable.** $249 collected up front; the first object ships
  ~90 days later.
- **Thin first volumes are handled by the quarter-end rule.** A member who
  joins in January has 90 days of material by their first shipment. Do not
  shorten that window.

---

## Open questions

1. **International.** The pricing policy is literally named `standardUS` and
   there is no VAT handling. Lulu prints regionally, so this is solvable, but
   the Bound Year is US-only until it is solved. Decide whether to launch
   US-only or delay for international.
2. **Softcover print specs do not exist yet.** Both existing `PrintSpec`s are
   hardcovers. A perfect-bound variant needs new geometry (bleed-only cover
   margin, no case wrap allowance), an entry in the worker's `ALLOWED_VARIANTS`
   allowlist, and cover rendering in `MonthlyEditionPDF`. Saddle stitch was
   costed and **rejected**: it saves ~$2/year, caps at ~48 pages, and therefore
   cannot carry a 96-page seasonal volume.
3. **`PhysicalBookVariant.from(_:)` derives the variant id from a binary
   `coverTreatment` check.** It silently mislabels the moment a third spec
   exists. Fix before adding any variant.
4. **Seasonal editions do not exist as a binding.** Weekly, monthly and annual
   do. A seasonal volume composed from three monthly editions is moderate work
   — `EditionCurator` already knows how to sample.
5. **Recurring billing on the worker.** It handles one-shot PaymentIntents
   today; a subscription mode is new.

---

## Decisions (locked 2026-08-08)

1. **Quarterly, not monthly.** Shipping is 42% of COGS and does not shrink with
   a thinner object. Monthly costs 79% of the margin at the same price.
2. **The annual hardcover is included**, and ships fourth.
3. **$24.99/mo or $249/yr.** Fewest members to the goal at a price the audience
   demonstrably pays — Fairyloot is ~$420/year for books that are not theirs.
4. **The Standing Order survives at $9.99/$79.99.** International readers,
   readers who do not want objects, price laddering, and an unambiguous
   IAP path all depend on it.
5. **Sold as a print subscription, on the web, everywhere.** Not as a US-only
   external-link play.
6. **Shipments at quarter end.**

Everything about money stays simple, clear, and fair — that is the brand.
