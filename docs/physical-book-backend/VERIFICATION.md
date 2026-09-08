# Printing and publishing verification

Last checked: September 8, 2026. The checkout backend, required Lulu title,
privacy-safe failure diagnostics, and stable status-refresh identity are deployed
to the existing test Worker, version `7cfc7b61-0522-4aa8-8967-d16179c5bb43`.
Five simulated Stripe payments succeeded; no real money moved. The corrected
Worker returned Lulu sandbox job `332000`, and a retry returned the same job.
All paid rehearsal subscriptions have renewal disabled. The original failed
one-off rehearsal remains protected for reconciliation; it was not reset.

## Stripe and simulator rehearsal

After dashboard sign-in, switched from live mode to test mode and verified the
account matches the app's test publishable key. Created the empty test catalogue's
Bound Year prices, matching `BoundYearPricing`: USD 24.99/month and 249/year,
exclusive tax, Books product tax code. Their non-secret IDs are in wrangler.toml.
The Worker's previous credential failed checkout; replacing it with the verified
test key allowed the same saved attempt to continue. No live key was used.

Passed against real Stripe test APIs and the deployed Worker:

- Opened an unpaid annual subscription, resumed the same payment, closed the
  checkout, and verified `incomplete_expired`, invoice `void`, and PaymentIntent
  `canceled` directly in Stripe.
- Confirmed a monthly payment with `pm_card_visa`; resumed the same subscription
  with `paymentVerified: true`. Close unpaid checkout rejected the paid attempt.
- Confirmed an annual gift with `pm_card_visa`; recovered the same claim token,
  claimed from a second synthetic installation, verified recipient access, and
  rejected another claimant. The gift has no automatic renewal.
- Stripe reported zero pending webhooks for both API payments. The Worker's KV
  contained the gift payment's `stripe-events/<eventID>` success receipt, proving
  signature verification and delivery through the existing configured endpoint.

Passed in the installed app on the isolated Monthly Reader QA simulator:

- Entered a synthetic monthly form, interrupted the app with checkout pending,
  relaunched, and found Continue with the original details preserved.
- Continue opened PaymentSheet with its TEST label. The documented 4242 test
  card completed payment; the app showed Standing and cleared pending checkout.
- Stopped renewal in the app, restarted again, and verified "Standing until
  Oct 7, 2026; then it closes without another charge" with no pending checkout.
- Direct Stripe lookup found exactly one customer, one subscription, and one
  successful USD 24.99 test payment for the simulator identity; renewal was off.

All customer details were synthetic. These checks do not establish Lulu PDF
acceptance or manufacture, earned-season dispatch, app gift-link recovery after
a crash, or every failure injection between local persistence writes.

## Deployed no-charge preflight

Follow-up PDF rehearsal: prepared `output/pdf/sandbox-interior.pdf`, a synthetic
32-page fixture with 450 x 666 pt pages (6 x 9 trim plus bleed), embedded fonts,
no encryption, and visually inspected opening pages. This fixture is generated
with ReportLab; it does not validate the app's native PDF compositor. Obtained a
32-page softcover sandbox quote and generated `output/pdf/sandbox-cover.pdf` at
Lulu's returned 892 x 666 pt dimensions, with embedded fonts and a visually
inspected cover. Both files uploaded through the Worker's private R2 path.
Capability downloads matched their SHA-256 hashes and returned `no-store`.
The canonical order preview used those uploaded files.

The one-off PaymentIntent succeeded using Stripe's simulated `pm_card_visa`;
its `livemode` was false and amount/currency matched the saved quote. Submission
to `/orders` returned `409 print_submission_uncertain`. Repeating the same saved
order also returned 409; the durable coordinator searches for a matching receipt
and never issues a replacement POST for an uncertain attempt. No receipt was
saved locally. Keep this original attempt intact for reconciliation.

After explicit approval to use sandbox credentials and manual Mac unlock, the
direct API lookup also returned zero exact matches for the original quote. Its
durable guard remains intact: an empty listing alone does not authorize replacement.
The original discarded HTTP response cannot be reconstructed. A separate synthetic
contract probe reproduced the failure with `400` and
`line_items[0].title: This field is required.` Adding only the title returned
`201`, job `331999`; Lulu subsequently reported `UNPAID` and line item `ACCEPTED`,
with successful file validation. That separate fixture was canceled through Lulu's
documented status endpoint, which returned `CANCELED`.

Standalone validation IDs `972843` (interior) and `972844` (cover) both reached
`NORMALIZED` with null errors. Lulu detected 32 interior pages. These checks used
the private uploaded PDF URLs, and local digest verification preceded validation.

The deployed fix carries the edition title from the app into the canonical quote
and seasonal preparation, then into Lulu's required line-item field. Older clients
and gift passes without a title use `ReEnchanted`. Empty, oversized, and invalid
titles fail before payment. The saved quote's title wins over a changed order body.
Tests cover title validation, legacy fallback, one-off fulfillment, and seasonal
title propagation. Gift fulfillment uses the same canonical quote path.

A fresh, separately labeled Worker rehearsal used the corrected title, synthetic
address, and PDFs. Its Stripe payment succeeded with `livemode: false`; `/orders`
returned job `332000` and the repeated request returned the same receipt. The
authenticated status route succeeded. Its first refresh exposed changing order ID
and creation timestamp; the follow-up fix preserves the saved receipt fields and
maps Lulu `ERROR` to `failed`, with regression tests.

The deployed refresh fix was verified on job `332000`: its app order ID, payment
reference, and creation date stayed equal to the saved receipt. A direct KV read
returned 404 for this quote's paid-without-print marker, confirming the successful
submission left the queue. Lulu reported its line item `ACCEPTED` with successful
validation. The unpaid synthetic job was then canceled, and the Worker's status
route correctly returned `failed` while preserving receipt identity. Both synthetic
Lulu jobs are canceled, neither was paid to Lulu, and no real production occurred.
The temporary Lulu credential file and copied credential were cleared after use.

Failed submissions now retain a bounded diagnostic containing only
the failure category, available HTTP status, and allowlisted schema field paths.
The same safe diagnostic is logged; provider prose and arbitrary object keys are
excluded. Diagnostic-storage failure leaves the original pre-request marker in
place. Seven print-submission tests pass, including HTTP rejection, malformed or
missing receipts, network loss, diagnostic-storage failure, safe receipt recovery,
and privacy checks. `npm run check` and `npm run test:preview` also pass. This repair
is deployed but cannot reconstruct the old failure's discarded details.

The original paid-without-print reconciliation marker must remain unresolved
until the original submission/payment is accounted for; this run did not inspect
or clear it. Lulu payment automation, shipment/tracking, physical manufacture and
the app-native PDF compositor are not established by these synthetic fixtures.

`node rehearse-sandbox-preflight.mjs` passed against the deployed Worker:

- Verified aligned Stripe test credentials and exact Lulu sandbox endpoints,
  with production readiness and live Bound Year sales false.
- Opened an expiring session with a synthetic installation ID.
- Closed empty membership and gift checkout attempts through the real Durable
  Object binding; repeated closure succeeded and later create requests returned
  `checkout_closed`. These attempts never create a Stripe customer/subscription.
- Authenticated with the real Lulu sandbox and obtained manufacturing/shipping
  estimates plus the cover-dimension response for a synthetic 120-page book.
  No reader manuscript or real contact/address data was used.
- The initial check found both membership prices missing. After configuring the
  verified test catalogue, the final run passed with `boundYearTestReady: true`
  and both price-presence checks true.

The preflight never calls payment confirmation, manuscript upload, print-order,
or email endpoints. It creates temporary session/quote records and durable closed
attempt markers in the existing test infrastructure. It does not prove a paid
Stripe transaction, invoice cancellation, webhook delivery, R2 upload, Lulu PDF
validation, or physical production. The local regression suites also passed
after adding membership-specific readiness checks.

## Current environment

The deployed `reenchanted-physical-books.snow-potions.workers.dev/health` returned
`testReady: true`, `productionReady: false`, `checkoutMode: test`, environment
alignment true and the live Bound Year sales gate false. The checked-in Worker
configuration uses Lulu's sandbox. The app points at that Worker with test
checkout and a Stripe test publishable key.

The health response reported Stripe Tax and membership customs encryption as
unconfigured. Health establishes configuration presence, not successful provider
transactions, individual membership price configuration, PDF acceptance, or
physical manufacture. The monthly manifest URL and public signing key in the
app remain empty; hosted monthly delivery is still launch work independent of
Apple enrollment.

## Repairs and local evidence

- Membership ownership is enforced before Stripe access on all seven read/write
  operations, including both print-file kinds and both route prefixes. Valid
  sessions from a second installation and missing ownership records are rejected.
  One-off orders also authenticate the quote capability before returning a cached
  receipt; knowing a PaymentIntent ID cannot expose another reader's tracking.
- Seasonal parcels require closed seasons and actual paid invoice coverage for
  all three months, matched to the configured price and test/live environment.
  Tests cover full refunds, disputes, zero invoices, pending payments, wrong
  products, foreign subscription lines, prorations, malformed periods and gaps
  between paid monthly invoices. Paid historical seasons remain available after
  cancellation or a later failed renewal. Calendar-month accounting includes
  normal billing on the 21st, and invoice pagination can find an older paid year.
- All three print paths use a durable attempt/receipt inside the existing order
  coordinator. Tests simulate an accepted Lulu job followed by a lost response,
  an isolate restart, a failed local order write and a failed durable receipt
  write. Retries never create a replacement job; a saved or uniquely recovered
  receipt finishes the original parcel. Fuzzy, duplicate and incomplete searches
  remain unresolved. The pre-request durable write must succeed before Lulu is
  contacted. Changed submission payloads are rejected.
- Durable Lulu receipts omit shipping data. Stripe membership API responses use
  a pinned schema, and upstream error text cannot expose addresses or emails.
- Membership and Bound Year gift checkout now resume from saved attempt IDs and
  Durable Object steps. Provider mocks cover concurrent requests, altered bodies,
  lost customer/subscription responses, lost durable receipts, failed ownership
  writes, and gift-index write repair. Known IDs remain recoverable beyond 24
  hours; an unknown result older than the 23-hour retry window stays blocked.
- Membership status and gift readiness/claims verify settled Stripe payment,
  configured product and environment. A previously ready gift is rechecked before
  claim. Trials, zero invoices, refunds, disputes, pending payments and unrelated
  subscriptions/products fail the claim tests.
- The app saves unfinished forms in device-only Keychain before networking,
  provides Continue actions, retains stable attempt IDs across retries, checks
  payment before granting access, and saves the last gift link before clearing
  checkout. Request fingerprints/IDs in preferences contain no raw addresses or
  client secrets. Test/live endpoint scopes are distinct. Known pre-payment
  validation failures allow correction; uncertain requests stay saved.
- Gift claim/decline decisions now use the existing Durable Object with a durable
  reservation before KV publication. Tests cover competing installations,
  claim/decline races, failed durable writes, failed KV writes and restarts.
  Readiness queries no longer write stale lifecycle snapshots back to storage.
  A separate local workerd probe passed with real SQLite-backed Durable Object
  storage, concurrent claim requests and an injected KV publication failure.
  It uses a fake gift ledger and makes no Stripe or Lulu calls.
- Unpaid checkout closure voids only the unpaid initial invoice of an incomplete
  subscription, then checks Stripe's terminal state before acknowledging closure.
  Tests cover both membership and gift routes, a payment winning the race, lost
  cancellation responses, unknown/processing payments, and cancellation arriving
  before a delayed create request. Twenty checkout/claim tests pass.

Passing local checks:

```sh
npm run check
npm run test:pricing
npm run test:preview
npm run test:print-submission
npm run test:membership-checkout
npm run test:gift-claim-runtime
npm run test:memberships
npm run test:gifts
npm run test:monthly
```

These use mocked providers, plus real local cryptographic checks. They do not
establish a Stripe/Lulu end-to-end sandbox purchase. The focused
`PhysicalBookOrdersTests` suite passed 21 tests, including store recreation,
concurrent attempt reuse, and decoding an older response without inventing a
payment grant. After the shared build directory became available, the Swift test
rerun passed all 21 tests, including the saved form contract. The Debug simulator
app build also passed, typechecking the new Continue and Close unpaid checkout
screens. Installation on the isolated Monthly Reader QA simulator succeeded.
The subsequent Keychain/PaymentSheet/provider evidence is recorded above.
The new invoice history work runs only during preparation and
submission; it is not part of normal Book rendering or startup.

September 8 device verification: the complete current workspace built successfully
with `InsideCoverApp`, Debug, for connected Rabbit (iPhone 15), using
`/private/tmp/ReEnchanted-Rabbit-Print-20260908`. The bundle identifier, executable,
Widget extension and Share extension were verified; installation on Rabbit
succeeded. The focused `PhysicalBookOrdersTests` suite passed 22 tests, including
title round-trip and decoding a saved quote that lacks a title. Build log:
`/private/tmp/reenchanted-rabbit-print-build.log`; test log:
`/private/tmp/reenchanted-print-title-swift-tests.log`. Device build/install are
separate from the synthetic backend checks and do not establish on-device checkout
or physical PDF quality.
The first launch attempt was denied with iOS `Locked`; Rabbit needs unlocking
before a launch-only retry. No rebuild or reinstall is required for that block.

## Next work, before declaring the pipeline ready

1. Finish app gift-link recovery before sharing, unpaid closure from the app,
   and precisely injected crashes between local persistence writes. The normal
   interrupted membership, payment and restart flow now passes. Rehearse a
   payment winning an invoice-closure race against Stripe. Older unknown
   Stripe results remain saved for support instead of silently opening another
   subscription. Confirm that app bookkeeping survives a crash between
   recording the membership, clearing Keychain and retiring its attempt.
2. Extend the passing deployed gift claim checks with failure injection; finish historical
   paid-through and offline revoked-access presentation, and verify existing
   subscription recovery on a new installation. The local concurrency tests do
   not replace those provider/runtime lifecycle tests. Keep live Bound Year sales
   closed until they pass.
3. Finish the operator workflow for unresolved submissions, including membership
   and gift alert coverage, status/tracking refresh, verified ownership recovery,
   and refunds. Never clear an uncertain submission merely because a search is
   empty. A replacement parcel needs a verified decision, not an automatic retry.
4. Verify the configured Stripe test prices, tax behavior, webhook delivery and
   private R2 lifecycle; run the deployed sandbox purchase → PDF upload → Lulu
   acceptance → status/receipt flow. Exercise cancellation and earned parcels
   with Stripe test clocks. No Apple developer enrollment is needed for this
   backend work. The matching Worker and verified test prices are deployed;
   Stripe membership/gift payments and a signed webhook receipt now pass.
5. Inspect actual generated interiors and covers for each offered binding and
   relevant page counts. Check trim, bleed, spine, jacket/flaps, foil limits,
   image resolution, page ordering and the final rendered narrative. Obtain
   Lulu's validation and then inspect a physical proof before live fulfillment.
6. Complete live credentials, tax/customs configuration, operational support and
   explicit launch gates. Apple StoreKit production verification and authored
   monthly pack integration remain separate work.

Existing caveats to resolve deliberately: zero-payment/credit-funded and
manually marked-paid invoices do not automatically earn physical parcels;
retired Stripe prices need an explicit entitlement policy if price IDs change;
the app's local season calendar and UTC server closure need boundary rehearsal.

Provider references: [Lulu's published API specification](https://api.lulu.com/api-docs/openapi-specs/openapi_public.yml)
documents paginated print-job search; the code additionally requires an exact
parcel reference. [Stripe invoice listing](https://docs.stripe.com/api/invoices/list)
and [idempotent requests](https://docs.stripe.com/api/idempotent_requests) inform
the invoice proof and the remaining checkout retry work.
