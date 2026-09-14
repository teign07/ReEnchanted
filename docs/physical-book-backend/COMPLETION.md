# Sandbox completion checklist

Current as of September 14, 2026. This is the active checklist; VERIFICATION.md
and MEMBERSHIP_RECOVERY.md retain historical evidence and superseded todo lists.
Live sales and general Reader recovery remain closed.

## Verified foundations

- Monthly pack runtime: install/update, entitlement gates, story commitments,
  authored braid integration, retirement, and retained Reader material. Local
  StoreKit/simulator tests passed. Count Unbound is not integrated.
- Stripe test purchases, renewal cancellation, refunds and gift ownership have
  provider evidence. Local coordinator tests cover lost replies, failed storage,
  concurrent claims, and payment winning a cancellation race.
- Native weekly PDF repair has fresh export, visual and Lulu validation evidence.
  Other bindings still require their own physical/editorial proof pass.
- Recovery delivered a real email and transferred an unpaid test membership via
  the deployed backend. Old-owner denial, safe retry and unpaid access denial passed.
- Rabbit recovery UI: readable form, invalid-code rejection, unavailable-service
  response and saved-request survival through restart passed. Code is not persisted.
- Tracking: multiple parcels, partial updates, legacy receipts, safe links and
  authenticated refresh after quote cleanup have passing automated coverage.
- Operator refund/hold workflows preserve uncertain printer attempts and receipts.
- R2 retention: the three-day physical-books/ expiration rule is enabled. Direct
  remote reads of both previously uploaded September 9 native rehearsal PDFs now
  return "The specified key does not exist". This confirms the aged objects are
  gone, rather than merely observing expired public delivery links.
- September 13 final deployed preflight passed: aligned Stripe test/Lulu sandbox,
  live sales closed, durable membership/gift checkout closure, and printer quotes.
- September 13: 90 focused recovery/ownership/checkout/parcel-support tests passed;
  the real local workerd gift-claim concurrency/failed-publication probe passed.

## Remaining bounded engineering rehearsals

| Check | State and next action |
| --- | --- |
| Paid recovery on Rabbit | Passed September 13. One approved email delivered; Rabbit redeemed the existing paid non-gift test membership through the normal UI. Former simulator membership refresh returned HTTP 403. Both recovery switches are OFF again and the scope expired. No charge or print order. |
| Recovery persistence after transfer | Passed normal termination/relaunch on Rabbit: membership ID, stopped-renewal end date, and included digital access remained. Method-level disk failure/queued-write tests already pass; exact interruption during the save remains separate. |
| Former-owner display | Passed on the updated Monthly Reader QA simulator. Confirmed ownership denial removes Standing/Included, shows Not standing in this Book, and hides address/billing controls. Saved membership reference and recovery remain available; network failures retain their separate cached-status behavior. |
| Parcel UI and relaunch | Passed September 14 with a synthetic 30-day-old receipt: two carriers, tracking numbers and links loaded after full simulator termination/relaunch. Fixed submitted-receipt deletion, stripped delivery/contact fields, retained the protected status capability, and repaired contrast. No real carrier delivery is implied. |
| Checkout/gift app interruption | Target only the remaining local persistence boundaries. Provider-response/storage injection passes; do not relabel it an app crash test. |
| Simultaneous payment/invoice closure | Local race injection and independent Stripe lifecycle tests pass. A real provider race remains unverified; retain this limitation explicitly if it cannot be reproduced deterministically. |

Stop adding speculative hardening once these bounded checks are accounted for.
Fix demonstrated failures and record the exact evidence level for anything that
requires an external event or a later release rehearsal.

## Separate release and content work

- Apple developer enrollment, App Store Connect configuration, real Apple Sandbox
  purchase/restore/refund and production verification.
- Live Stripe/Lulu credentials, business tax/customs settings and deliberate
  activation review. No live charges or manufacturing are authorized by sandbox QA.
- Physical print proofs and real carrier shipment/delivery. Sandbox acceptance
  cannot establish print color, binding quality, shipping or delivery.
- Count Unbound authored content, recordings/marginalia and literary rehearsal.
- Edition-by-edition editorial and visual audit, including all offered bindings,
  relevant page counts, covers/spines/jackets, typography and narrative quality.

These do not need to prevent content work while live fulfillment stays closed.
