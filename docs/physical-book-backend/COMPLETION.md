# Sandbox completion checklist

Current as of September 13, 2026. This is the active checklist; VERIFICATION.md
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
| Paid recovery on Rabbit | In progress. Existing paid non-gift test membership selected; renewal stopped, charge unrefunded. User approved one email and transfer onto Rabbit. The test customer billing email is updated; no recovery email has been sent yet. Rabbit mirroring currently requires the phone to be locked. Recovery remains disabled. |
| Recovery persistence after transfer | Verify actual Rabbit restoration and relaunch. Method-level disk failure/queued-write tests already pass; exact process interruption during the save remains separate. |
| Parcel UI and relaunch | Exercise multiple saved parcels through the app. Backend contract/storage tests pass; real shipped-carrier evidence remains open. |
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
