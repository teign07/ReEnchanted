# Pricing & cost sheet, 2026-10-03

**Evidence level:** live Lulu *sandbox* quotes through the deployed Worker (no charge, synthetic addresses), at the real caps in `Shared/MonthlyEdition.swift:4468` (weekly 48 / monthly 128 / seasonal 176 / annual 256). Shipping = cheapest Mail option. Not established: live Lulu availability, tax/VAT/GST, customs, physical proofs, reprint rate. US figures use a Belfast, ME address.

> **2026-10-11: the paper changed to 60# uncoated white** (premium colour; package IDs `…FC.PRE.<binding>.060UW444…`).
> Lulu sandbox quotes put it at 12.59¢ a page against 13.89¢ on 80# coated, with the same base per binding and
> the same cover and spine sizes. Making each book below now costs less: monthly 128pp $18.11, seasonal 176pp
> $24.15, annual linen 256pp $47.22, annual illustrated 256pp $42.91, weekly 48pp $9.82. Shelf floors are
> unchanged by choice (bj: "premium, but not over expensive"), so seasonal and annual margins rise by $2.29 and
> $3.33; prices that follow cost (weekly, monthly above its floor) fall on their own. A member-year costs about
> $10 less to deliver.

## 1. Per-parcel cost (USD)

| Item | Make | Ship US | Ship CA | Ship UK |
|---|---|---|---|---|
| Monthly softcover 128pp | 19.77 | 6.78 | 12.50 | 5.22 |
| Seasonal softcover 176pp | 26.44 | 7.14 | 12.83 | 5.22 |
| Annual linen 256pp | 50.55 | 8.47 | quote FAILS | 5.22 |
| Annual illustrated 256pp | 46.24 | 8.23 | 13.82 | 5.22 |

## 2. Bound Year subscription (3 seasonal softcovers + 1 annual, shipping folded in)

Cost per member-year: US 159.76 / UK 150.75 / CA 177.87 (illustrated annual).

| Plan | Revenue | US net after Stripe fees | UK net | CA net |
|---|---|---|---|---|
| $249/yr | 249.00 | ~82 (33%) | ~91 | ~64 |
| $24.99/mo | 299.88 | ~128 (43%) | ~137 | ~110 |
| $279/yr (proposed) | 279.00 | ~111 (40%) | ~120 | ~93 |

Net $3K/month = $36K/yr: ~440 members on $249/yr, ~280 on $24.99/mo, ~325 on $279/yr (US).
Costs are at page caps, i.e. worst case. A 128pp seasonal costs 19.77 not 26.44.

## 3. A la carte editions (shipping and tax separate pass-through, per `PhysicalBookPricing`)

| Edition | Product price | Our margin | Margin % | Delivered US (incl. ship + card fee) |
|---|---|---|---|---|
| Weekly 48pp (estimate) | 25.45 | 15.00 | 59% | ~33 |
| Slim monthly 72pp (estimate) | 39.99 | 28.01 | 70% | ~48 |
| Monthly 128pp | 54.77 | 35.00 | 64% | 63.70 |
| Seasonal 176pp | 69.99 | 43.55 | 62% | 79.75 |
| Annual illustrated 256pp | 89.99 | 43.75 | 49% | 101.47 |
| Annual linen 256pp | 99.99 | 49.44 | 49% | 112.01 |

Weekly and slim shipping are estimates (not quoted). The prices are floors (`minimumProductPriceCentsPerCopy`) with a $35 minimum contribution.

## 4. Reasonableness checks

- A la carte year equivalent (3 seasonal + annual) = $309.96 product, ~$340 delivered. Subscription $249 is ~27% under, $299.88 is ~12% under. The discount ladder is sane; the $249 annual discount is the expensive one (-$46 vs monthly pay).
- Per-page prices are consistent: monthly 0.43, seasonal 0.40, annual 0.39 per page.
- A la carte margins are 49-70%; the subscription is the volume tier at 33-43%. Annual hardcover is the thinnest a la carte item (49%).
- Monthly softcover as a $24.99 subscription loses money (cost $26.55 delivered at cap). At ~$39.99 it nets ~$12/mo (30%).

## 5. Recommendations (bj decides)

1. Keep $24.99/mo. Raise or restructure the $249 annual (~$279) or drop the annual discount.
2. Keep the quarterly structure; monthly softcover subscription only as a later ~$39.99+ tier after proofs.
3. Canada: hold or add a regional surcharge (~$20-25/yr) until linen annual quotes; illustrated works.
4. Budget 3-5% for reprints/refunds and add Stripe Tax before judging margin; UK VAT needs an accountant.
5. Confirm checkout already folds shipping into the $249/$24.99 (code comment at `MonthlyEdition.swift:4466` implies it; I have not traced it).
