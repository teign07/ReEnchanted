# Printing and publishing verification

Last checked: September 9, 2026. The checkout backend, required Lulu title,
privacy-safe failure diagnostics, and stable status-refresh identity are deployed
to the existing test Worker, version `49b5e6be-6636-40b2-bb43-0005f1420420`, including
the operator reconciliation, one-book gift payment rechecks, and refunded-payment
safeguards, gift/membership parcel support and verified refund closure described below.
Five simulated Stripe payments succeeded; no real money moved. The corrected
Worker returned Lulu sandbox job `332000`, and a retry returned the same job.
All paid rehearsal subscriptions have renewal disabled. The original failed
one-off rehearsal was fully refunded in Stripe test mode and its payment alert
resolved. Its durable hold and uncertain printer attempt remain intact.

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

The original paid-without-print marker was subsequently resolved by the verified
refund workflow below. Lulu payment automation, shipment/tracking, physical manufacture and
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
The first launch attempt was denied with iOS `Locked`; a later launch-only retry
succeeded. The current build is installed and launched on Rabbit.

## Operator hold and refund reconciliation

Protected one-off routes now inspect an order, set a durable hold, and close a
fully refunded payment. Operator actions share the fulfillment queue, so holding
an order cannot race an awaited print submission. Holds survive restarts and have
no automatic reset. Closure reads the PaymentIntent, expanded charge and paginated
refunds directly from Stripe; pending/partial refunds, disputes, foreign IDs and
wrong test/live environments cannot clear alerts. It preserves any Lulu attempt
or receipt. A printer review remains necessary independently of a refund.

Resolution is durable before KV publication/alert deletion, and retries repair
failed writes. Late or stale payment markers cannot reopen a resolved alert.
The quote's contact and delivery details are redacted after verified closure.
Nine reconciliation tests and the existing print, security, membership, gift,
and checkout suites pass. New print submission also checks the expanded charge
and rejects partial/full refunds, disputes and unsettled or mismatched payments.
This workflow deliberately rejects gift payments: their redemption coordinators
and entitlement handling require a separate implementation.

The user authorized replacing the unavailable operator token. The replacement is
stored with owner-only permissions at
`/Users/bj/.config/reenchanted/physical-book-admin-token` and installed as the
Worker's `PHYSICAL_BOOK_ADMIN_TOKEN`. Its value was never logged. Stripe and Lulu
credentials were not changed. `reconcile-order.mjs` reads this private file,
checks the environment and performs only inspect/hold/close operations.

Real sandbox verification: quote `204fbf20-45b0-40b8-ae2b-6d50612031aa` was held,
then its USD 45.92 simulated payment refunded through Stripe's test dashboard.
The deployed Worker independently confirmed `fullyRefunded: true`, published
`fully_refunded`, and removed it from the alert queue. A delayed `/orders` request
returned `409 order_on_hold`. The original missing-receipt attempt was preserved.
No real funds moved, and no replacement print was created by reconciliation.
The second quote, `4bc11240-825a-41c6-9014-d21a11c702c3`, was also held after Lulu
job `332000` had been canceled. Its USD 45.92 test payment was fully refunded and
independently verified by the Worker. Repeating closure of the original quote
returned the same resolution timestamp. Both one-off test payments are now
refunded, with both durable holds and all printer history retained.

## Gift payment revocation and temporary PDF retention

September 8: ordinary book gifts now recheck the original Stripe payment at
creation, claim/reclaim, readiness lookup, and before a new Lulu submission.
The shared validator rejects partial/full refunds, disputes, unpaid or mismatched
charges, wrong checkout mode and incorrect paid allowances. Gift readiness is a
read-only projection, preserving claimed ownership through payment interruptions.
Already-submitted gifts retain their printer receipts if later refunded. No
background app polling was introduced. Support must still coordinate refunds
with a printer review; a payment check is not atomic with an external refund.

Passed `test:gifts` with creation-after-refund, disputed readiness and purchase
retry, nine denied-payment states at claim and redemption, Stripe outage,
recovery, and receipt replay after a full refund. All denied redemption cases
assert zero Lulu creates. `test:preview`, the 16 print-submission/reconciliation
regressions, membership/dispatch suites and 20 membership-checkout tests passed.
`test:gift-claim-runtime` also passed in real local workerd storage after permitting
localhost listening; its Stripe response is mocked and it contacts no provider.
No new app build, payment confirmation or print job was required for this pass.
After deployment, `rehearse:sandbox-preflight` passed: aligned Stripe test/Lulu
sandbox, live sales closed, repeated checkout closure and delayed-create refusal
for memberships and Bound Year gifts, plus an authenticated Lulu manufacturing
and shipping quote. This is deployed preflight evidence; the new refund scenarios
above use mocked Stripe responses.

Remote R2 inspection found only the default seven-day incomplete-multipart rule;
`expiresAt` metadata did not cause deletion. Added and read back the enabled
`expire-private-print-files` rule for `physical-books/`, expiration age three days,
in `reenchanted-physical-book-files`. The original multipart rule remains enabled.
This includes membership uploads. Capability URLs still expire at 48 hours;
automatic object deletion has a one-day buffer and is asynchronous. The rule was
verified, but actual aging/deletion has not yet been observed. Cleanup runs in R2,
without scanning files on app requests or adding a Worker cron. See
[Cloudflare's lifecycle timing](https://developers.cloudflare.com/r2/buckets/object-lifecycles/).
The README contains the provisioning and verification commands for future buckets.

## Gift and membership parcel support

September 9: implemented protected inspection and durable holds for ordinary
book gifts (looked up from the payer's PaymentIntent) and prepared membership
seasons. Both route to the existing fulfillment Durable Object and share its
queue. Holds survive restarts, block fulfillment even when a receipt was cached,
and retain all existing printer history. They do not call Stripe or Lulu.
Responses omit gift names, addresses, claim and dispatch tokens, manuscript URLs
and tracking capabilities. Saved order status is historical; it is not a fresh
printer status check.

Seven `test:parcel-support` tests passed, covering both parcel types, admin
rejection before reads, private-field omission, restart/idempotency, write failure,
unknown/mismatched records and provider modes, in-flight submission ordering, and
isolation between unrelated parcels. The combined 23 support, reconciliation and
print-submission tests passed, as did the gift and membership/dispatch regressions.
Deployed version `7ba7d6c3-5dc6-4c64-b87c-92089d1e9e5e` passed read-only
checks of both new route families: anonymous requests return 401, authenticated
unknown parcels return 404, and Stripe test/Lulu sandbox alignment plus closed
live-sales gates remain intact. No actual parcel hold, payment or print job was
created by this preflight. Positive hold/race scenarios above used local mocks.
The new `reconcile-parcel.mjs` helper has strict argument validation, private-token
file permissions and the same explicit live-mode gate as one-off reconciliation.

Holds stop future printing for a selected parcel. The later refund-closure pass
below also closes refunded gift claims. Whole-membership support actions and
verified replacement decisions remain open; no automatic release or reprint was added.

App PDF source check: checkout reads its prepared interior's actual page count
and rerenders the cover using dimensions returned with the Lulu quote. The
monthly writer pads to the binding's page multiple and rejects oversized volumes.
The PDFs currently under `output/pdf/` remain synthetic backend fixtures. This
pass did not generate or visually validate native app PDFs, and ran no app build.

## Verified gift and membership refund closure

September 9: `close-refunded` now supports ordinary book gifts and prepared
membership parcels through their existing support coordinators. It requires a
preexisting permanent hold and reads settled refund proof directly from Stripe.
Gift proof binds the original PaymentIntent and paid allowance. Seasonal membership
proof validates the subscription, configured price, calendar anchor, all three
billing months, invoice/PaymentIntent/charge identity, amounts/currency and settled
refund records. It scans through the end of the bounded invoice history so a second
unrefunded invoice for the same months cannot be missed. Annual and monthly billing
are covered. Membership closure is for the selected parcel only.

Gift closure publishes a separate permanent marker instead of rewriting the claim
record. Gift inspection, claim/reclaim and purchase recovery honor this marker even
after a stale claim write. Durable resolution is saved before KV publication;
repeating closure repairs publication failure while retaining the original date.
Printer holds, uncertain submissions and receipts survive every closure. These
routes never issue a Stripe refund or call Lulu, and introduce no background app
polling. Partial/pending refunds, disputes, incomplete or inconsistent proof and
provider outages cannot report success.

Deployed version `49b5e6be-6636-40b2-bb43-0005f1420420` passed endpoint checks:
anonymous inspection/closure requests return 401 and authenticated unknown gifts
or membership parcels return 404. Sandbox alignment and closed live-sales gates
remain intact. No existing parcel, refund or payment was changed in this preflight.

Passed 33 support/reconciliation/print-submission tests, including both monthly and
annual season closure, missing months, unrefunded duplicate coverage, foreign
invoices/payments, proration/truncation, Stripe outages and failed KV publication.
A valid three-page monthly invoice history also passed.
The gift flow suite additionally exercised actual Worker closure routes followed
by a stale claim write, proving reader gift status and recovery remain closed.
These refund scenarios use mocked Stripe data. Gift, membership/dispatch, and
preview regressions passed. The real local workerd gift-claim race test passed
with mocked providers. No app build or native PDF visual proof occurred.

## Read-only PDF structural preflight

September 9: added `scripts/check_print_pdfs.py` and 12 passing regression tests.
The local checker binds an exported interior/cover pair to the saved server
quote's page count and exact cover dimensions. It detects missing interior bleed,
wrong cover/interior counts or sizes, encryption, crop/rotation/scaling differences,
interactive form widgets, parse failures and unembedded fonts used to paint text,
including fonts inside Form XObjects. Unused resources do not trigger font failures.
Reports use fixed finding codes, dimensions and SHA-256 hashes; no extracted text,
addresses, payment fields or delivery capabilities are emitted. Inputs are never
rewritten. No app or backend request-path work is added.

The existing synthetic sandbox pair passed: 32 interior pages at 450 x 666 pt,
one cover spread at the provider's 892 x 666 pt. Result:
`output/pdf/sandbox-structural-check.json`. The minimal non-secret technical quote
is `docs/fixtures/print-rehearsal-quote.json`. This establishes structural checks
only; it does not establish native rendering, visual quality or a new provider
validation. Font program validity, image quality, transparency/color, safety
margins, actual bleed artwork, spine/foil positioning and narrative order still
need independent checks.

No native PDF was found in the existing Monthly Reader QA simulator's app data.
Rabbit was unavailable. UI inspection was blocked by the locked Mac; an unlock
request is pending. No app build, payment, refund, print job or deployment was
performed in this pass. Export/visual review of native app PDFs remains open.

## Native weekly PDF rehearsal and cover repair — September 9, 2026

The unlocked Monthly Reader QA simulator's existing installed app completed its
native weekly binding and physical-file preparation. No build, payment, upload,
quote request or print submission was performed. Rabbit was not used.

The app group was backed up before temporarily moving the Reader Week anchor and
adding seven synthetic August 24–30 pages. The UI selected the latest closed week,
Issue 2 (August 31–September 6), containing three existing synthetic monthly-story
rehearsal pages; it did not bind the seven newly added pages. After export, the app
was stopped and the complete original app group restored. All eight original files
were verified byte-for-byte against the backup and fixture additions removed.

Unmodified native exports are in `output/pdf/native-weekly-rehearsal/`:

- `reading-copy.pdf`: 7 pages, 612 × 792 pt.
- `interior.pdf`: 40 pages, 450 × 666 pt; structural inspection passed.
- `cover.pdf`: one spread, 882 × 666 pt; basic structural inspection passed using
  its measured size, **not** independently verified Lulu dimensions.
- `interior-structure.json` and `cover-structure.json`: local checker results.

Rendered contact sheets of all 40 interior pages were inspected. The sparse
fixture produces repeated source passages and many lightly filled pages; this
is not evidence of editorial readiness for a real Reader's week. Page 34 is the
intentionally protected reverse of the activity leaf on page 33. Larger and
media-rich fixtures still need inspection for truncation and image quality.

The rendered cover failed visual review: its back-panel gradient painted across
the front artwork/title, and its weekly text used dark reading-page ink over a
dark cover wash. Source inspection confirmed that `drawVerticalWash` did not clip
horizontally to its supplied rectangle. `MonthlyEditionPDF.swift` now clips that
shared monthly/volume drawing primitive inside a saved graphics state; weekly
front/back text uses the existing light cover-text and gold palette instead.
The weekly back footer also receives higher opacity. This adds no network work
or image processing and applies to both PDF and shared cover-preview drawing.

Validation: Swift frontend parsing, `git diff --check`, and all 12 Python PDF
checker tests passed. Parsing is not typechecking or a build, and checker tests
do not exercise UIKit drawing. The saved PDFs are **pre-fix failure evidence**;
the repaired renderer still needs a newly built app export and visual review.
Then obtain a quote for the actual binding/page count, regenerate with its exact
cover dimensions, run the pair checker, and obtain Lulu validation. No native
provider validation or physical proof is claimed.

## Sandbox follow-up — September 9, 2026

The deployed no-payment preflight passed again: Stripe test / Lulu sandbox aligned,
live sales closed, both Bound Year test prices configured, durable cancellation
for membership and gift attempts, and successful Lulu manufacturing/shipping quote.
No payments were confirmed or print jobs submitted by this preflight.

A separate synthetic quote for the native 40-page saddle-stitched weekly binding
returned 882 × 666 pt from Lulu. Non-secret technical expectations are saved in
`docs/fixtures/native-weekly-rehearsal-quote.json`. The existing pre-fix native pair
passes the independent quote-matched structural check in
`output/pdf/native-weekly-rehearsal/quote-matched-structure.json`; it still fails
cover visual review and must not be printed.

All 53 focused checkout, parcel support, reconciliation and print-submission tests
passed. Three additional parcel support fault-injection cases then passed (20
parcel-support tests total): gift/membership durable-resolution write failures,
and membership KV publication failure followed by coordinator restart. These prove
that holds and printer receipts survive and retries publish the same resolution.
The local workerd gift-claim runtime probe also passed its concurrent claim and
failed publication scenario. These are local failure tests, not provider refund
or invoice-race rehearsals. No Worker deployment was needed for test-only changes.

## Fresh repaired native export — September 9, 2026

With explicit user authorization, the current worktree built successfully for the
Monthly Reader QA iOS simulator using the Local Purchases scheme. Build log:
`/private/tmp/reenchanted-cover-repair-build.log`. Installation and launch also
succeeded. The same three-page synthetic closed week was bound through the app UI,
then “Set this book for the post” generated the native print files. No address was
entered in the app, payment confirmed, manuscript uploaded, or print job submitted.

`output/pdf/native-weekly-repaired/` contains unmodified native `interior.pdf` and
`cover.pdf`, plus `structure.json`. The 40-page interior and single cover spread
pass checks against the independent Lulu sandbox quote. Rendering the cover
confirmed that front artwork/type are no longer overwritten and the back text
is legible. This is a verified repair of those two defects, not a complete
manufacturing approval: full interior regression review, bleed/color/image checks,
other bindings and page counts, and Lulu file validation remain open. The cover
uses “Issue No. 2” as its main title while the interior uses “What Wouldn't Leave”;
that editorial distinction was observed, not changed in this repair.

After copying the exports, the app was stopped and the original app group restored.
All eight backed-up files were verified byte-for-byte and fixture additions removed.

## Lulu validation of repaired native weekly files — September 9, 2026

The repaired app-generated files were uploaded through the deployed private
print-file service under a fresh synthetic weekly quote. Delivery downloads were
verified byte-for-byte with SHA-256 before sending their capability URLs to Lulu.
Lulu sandbox validation-only endpoints returned **NORMALIZED**, with no reported
errors, for interior 974663 and cover 974664. The interior was recognized as 40
pages and the requested `0600X0900.FC.PRE.SS.060UW444.MXX` package was explicitly
included in its accepted package list. No payment or print job was created.

`output/pdf/native-weekly-repaired/lulu-validation.json` records non-secret result
fields and the SHA-256 of each validated native artifact. Provider normalization
is now verified for this specimen; it does not prove other bindings/page counts,
full editorial quality, physical color/bleed, or delivery. Existing automatic R2
retention applies to these synthetic uploads. Temporary local credential removed
after use; no secret was rotated. No app build or backend deployment in this pass.

## Checkout closure interruption coverage — September 9, 2026

All 23 membership-checkout tests pass, including three new failure cases:

- Membership and gift cancellation each lose the final durable `checkout-closed`
  write after the provider invoice was voided. After coordinator restart, retry
  records the closure without another void, and delayed opening remains blocked.
- A gift payment wins the attempted invoice void. After restart, checkout returns
  the same membership and gift claim token with verified payment; cancellation
  refuses to discard it. Exactly one subscription exists.

These exercise production coordinator code with injected Stripe responses and
storage failures. They do not establish a fresh real-Stripe invoice race or an
app process crash. No provider calls, charges, builds, or deployment in this pass.

## Real Stripe test-clock lifecycle — September 10, 2026

A disposable Stripe test-clock customer and subscription used the configured
monthly price (`price_1UDBjrE80ArNx7J9p2acRpvE`, USD 24.99) and only Stripe's
`pm_card_visa` / `pm_card_chargeCustomerFail` simulated methods. Provider reads
verified test mode. The initial invoice and first renewal succeeded. A later
renewal with the declining method produced `past_due`, an open invoice with zero
paid, and `requires_payment_method`. Paying that same invoice with the successful
test method restored the subscription to active and the invoice to paid.

Cancellation at period end kept the subscription active until the advanced
boundary, then produced `canceled`. The invoice count remained three: no fourth
renewal invoice appeared. The canceled fixture remains for provider evidence.
Non-secret observations are in `docs/fixtures/stripe-clock-lifecycle-result.json`.

This subscription was created directly through Stripe for its test-clock support;
it was not linked to an app installation. This proves provider lifecycle behavior,
not deployed entitlement transitions, webhook receipt, cross-installation recovery,
or the simultaneous payment/void race. Those integration checks remain open.
No real card was used, no live payment made, and no print job created. No app
build or backend deployment occurred in this pass.

## Cached digital access repair — September 10, 2026

Source tracing found that background membership reconciliation ignored
`paymentVerified` and advanced `paidThrough` from an unverified billing period.
The shop's denial also affected only the transient grant; cached refresh could
restore access. Both paths now use `BoundYearMembership.reconcile`, persist a
separate optional digital verification result, and advance paid-through only
with verified payment. A server denial survives save/reload without rewriting
historical payment dates. A later verified response can restore digital access.
Terminal canceled status takes precedence over a retained scheduled-cancellation
flag, matching the observed Stripe test-clock response.

Regression tests cover denial/save/reload/recovery and terminal cancellation.
Swift frontend parsing and diff hygiene passed. After explicit build authorization,
the compiled StandingOrderTierTests passed all 15 tests, including denial persistence
and verified recovery. All 23 BoundYearMembershipTests also passed, covering the
existing physical eligibility and dispatch behavior. Logs are in
`/private/tmp/reenchanted-access-repair-tests.log` and
`/private/tmp/reenchanted-access-physical-regression.log`. This is compiled core-test
evidence; a rebuilt iOS app and end-to-end entitlement rehearsal remain open.

## iOS access-repair build and launch — September 10, 2026

The current worktree built successfully with the Local Purchases scheme for the
Monthly Reader QA simulator. Log: `/private/tmp/reenchanted-access-ios-build.log`.
Installation and launch succeeded. The existing test membership save initially
had no `digitalPaymentVerified` field; after the app's background refresh it
persisted `true`, preserving active status and the same paid-through date. The
field remained true after terminating and relaunching the app. No fixture/save
injection or payment changes were used. Both refresh call sites compile against
the shared reconciliation method.

This establishes the real app's verified-positive backend refresh and older-save
compatibility. Revoked/failed verification in the actual app, offline relaunch,
and shop-screen transitions remain separate runtime checks; compiled core tests
cover denial persistence and recovery but do not replace those rehearsals.
No charge, print order, or backend deployment occurred.

## Persisted denial with unavailable membership endpoint — September 10, 2026

The installed repaired iOS app was exercised with a backed-up simulator save.
The fixture retained active status and its future paid-through date, explicitly
set `digitalPaymentVerified=false`, and included a stale `bound-year-digital`
owned-pack entry. A process-only launch argument redirected the physical-book
endpoint to `https://127.0.0.1:1/quote`, preventing successful membership refresh.
This simulates an unavailable billing endpoint, not whole-device offline mode.

The first launch removed the stale grant and retained the denial. After termination
and a second launch with the same unavailable endpoint, the saved verification was
still false and the owned-pack grant remained absent. This verifies cached denial
handling in the actual app; it does not exercise receipt of a new server denial,
the shop presentation, or other independent digital subscriptions.

The app was stopped, and all eight original app-group files were restored and
verified byte-for-byte. The endpoint override was a launch argument, not a saved
preference. No real payment changes, new build, or print order occurred.

## Fresh membership denial through native networking — September 10, 2026

The installed simulator app began with its original verified membership save.
A localhost-only fixture server supplied a session envelope and an active
membership response with `paymentVerified=false` and a future billing-period end.
The existing DEBUG endpoint override was supplied as a process launch argument.
The server observed the membership request; the app persisted a false verification
and removed `bound-year-digital`. This exercises URLSession, response decoding,
background reconciliation and saved entitlement removal without injecting denial
into the save. It is a local server fixture, not a Stripe refund/webhook proof.

Shop visual inspection was blocked by the locked Mac; user unlock was requested.
The test server was stopped and all eight original app-group files restored and
verified byte-for-byte. No build, real payment change or print order occurred.

## Shop presentation after fresh denial — September 10, 2026

After unlocking the Mac, the installed simulator app was launched against the
same localhost denial fixture, starting from a newly backed-up original save.
The Bookshop's Standing Order entry no longer showed the Included badge. Opening
that entry displayed “Not open. The free Book carries on regardless.” and the
separate monthly/annual subscription options. No purchase control was activated.
This verifies native UI presentation after a local-server denial; real Stripe
revocation/webhook integration remains distinct. The Bound Year still showed
Standing, consistent with the fixture's active billing status despite failed
payment verification.

The app was stopped, the local test server stopped, and all eight original
app-group files restored and verified byte-for-byte. No build, purchase or print
submission occurred in this pass.

## Monthly access payment-check consistency — September 10, 2026

The monthly-session exchange accepted zero-paid invoices and allowed a live-mode
membership in test mode, unlike the membership-status verifier. It now requires a
positive paid amount, nonnegative refund amount below the charged amount, and an
explicitly matching Stripe mode. Tests cover zero-paid, negative refund, live in
test, and missing-mode responses. All 17 monthly-access tests passed; the local
workerd Apple-verifier probe also passed. No deployment in this pass.

Webhook tracing confirms that the current handler processes PaymentIntent events;
it does not directly revoke membership sessions on charge-refund or dispute events.
The monthly-session exchange rereads Stripe on issuance. Existing bounded sessions
are not synchronously revoked by this change. Real Stripe refund-to-session-denial
and the propagation window remain to rehearse; local rejection tests are not that
provider evidence.

## Deployed monthly-access repair and missing secret — September 10, 2026

The payment-check repair deployed as Worker version
`3227d6ae-b770-4a04-91aa-ddca113297df` after 76 focused backend tests passed.
The sandbox preflight passed with Stripe test/Lulu sandbox aligned and live sales
closed. A new local session-expiry regression also passed (18 monthly tests):
refund blocks new sessions while an already-issued session lasts until its exact
10-minute expiry. This is local timing evidence, not a real refund rehearsal.

A deployed check using an existing paid rehearsal owner revealed HTTP 503
`monthly_access_not_configured`. Secret inventory confirmed that
`MONTHLY_ISSUE_SESSION_SECRET` was absent. A random signing secret was added using
Wrangler without displaying its value or rotating other credentials. Repeating
the real endpoint check then returned HTTP 200 and a session bounded to ten minutes;
a different installation attempting the same membership received HTTP 403.
The secret update followed the code deployment, so the recorded code version is
not claimed as the final post-secret deployment identifier.

No new payment, refund, print job or app build occurred. A real Stripe refund to
session-denial rehearsal remains outstanding; session issuance now works in the
deployed sandbox rather than only in local tests.

## Real Stripe test refund denies new monthly access

September 10: refunded the existing synthetic purchaser membership's $24.99
Stripe test charge in full through the Stripe connector. Before mutation, verified
`livemode: false`, the fixture subscription and monthly price, its paid invoice,
the invoice payment's matching PaymentIntent and charge, and disabled renewal.
The deployed endpoint granted the owner a session (200) and denied an unrelated
installation (403) before the refund.

Stripe returned a succeeded refund; a separate charge read confirmed
`refunded: true` and `amount_refunded: 2499`. Subsequent authenticated requests to
the deployed Worker returned membership `paymentVerified: false` and monthly
session 403 `monthly_subscription_required`. Evidence:
`docs/fixtures/stripe-refund-access-result.json`.

This establishes real test-provider refund-to-deployed-access-denial evidence.
It does not establish immediate webhook revocation, app runtime presentation for
this refund, or physical parcel refund closure. Previously issued content tokens
retain their bounded lifetime of at most ten minutes. The synthetic purchaser
fixture is now refunded and must no longer be used as a paid-access positive
control. The separate gift and app rehearsal memberships were not refunded.
No real money moved, no Lulu job was created, and no app build was performed.

## New-installation ownership boundary

September 10: added `rehearse-membership-ownership.mjs` and ran it against the
refunded purchaser fixture and the separate paid, claimed gift membership.
For the paid fixture, owner status/access passed 200/200; a fresh installation
received 403/403; the owner still received 200/200 afterward. For the refunded
fixture, the owner retained status access (200) but content stayed denied (403),
and the fresh installation received 403/403. No ownership, payment or parcel
was changed. The script passed syntax checking and diff hygiene passed.

Source inspection confirms a remaining implementation gap: device-only Keychain
identity does not provide Stripe membership recovery on another device, and the
store restore action does not transfer Stripe ownership. This is a live-sales
blocker, not a completed recovery feature. `MEMBERSHIP_RECOVERY.md` records the
required proof, gift-recipient protections, atomic transfer, app persistence and
acceptance cases. No app build or recovery email was sent.

## Staged membership ownership coordinator

September 10: added serialized internal ownership read/register operations to the
existing Durable Object class, with one-time legacy-owner migration and no
transfer endpoint. Seven new tests cover competing registrations, stale legacy
reads, restarts, failed persistence, unavailable/corrupt legacy data, cross-ID
routing and preservation of unrelated print receipts. All 48 focused ownership,
membership checkout and monthly-access tests passed. Public authorization still
uses the existing mapping; the new operation is staged and not deployed. See
`MEMBERSHIP_RECOVERY.md` for the required complete migration before transfers.
No provider mutation, app build or recovery email occurred in this pass.

## Ownership authority wired and deployed

September 10: all owner reads and registrations now route to the stable
`membership-owner:<subscription ID>` Durable Object. This includes checkout,
gift claims, membership management and monthly sessions. Existing KV records
are migration inputs only; no authorization fallback reads KV during an outage.
Apple proof remains independently usable during an ownership-service outage.
Updated failure injection targets durable owner persistence rather than old KV
writes. All 69 focused tests passed, plus membership, gift and dispatch suites.

Deployed version `4705fcbd-b8af-468a-8cd8-149c0dc8f93c`; test mode and live-sales
closure remained configured. Deployed rehearsals confirmed paid recipient
migration (owner 200/200 status/access, foreign 403/403, owner again 200/200)
and refunded purchaser migration (owner 200/403, foreign 403/403, owner again
200/403). This proves existing-provider fixture migration and access boundaries,
not new-device recovery. Proof delivery, transfer and app recovery remain.
No app build, provider payment mutation, print submission or email occurred.

## Disabled internal recovery lifecycle

September 10: implemented internal challenge preparation and redemption behind
an unconfigured recovery flag. Owner and consumed proof are persisted in one
record, preserving idempotent retry and preventing a split-write crash window.
Wrong destination, expiry, replacement, replay after a later transfer, write
failure and gift-index protection have tests. All 56 focused ownership, monthly
access and checkout tests passed. These additions are not deployed. There is no
public recovery route or verified-contact delivery; the feature remains disabled.
No email, payment, parcel mutation or app build occurred. See
`MEMBERSHIP_RECOVERY.md` for remaining issuance and gift-race requirements.

## Disabled public recovery redemption boundary

September 10: added secret generation/hash helpers and an authenticated,
rate-limited redemption endpoint with bounded strict input. Destination identity
comes from the client session; only a hash reaches coordinator storage. Recovery
returns ownership confirmation, not a billing grant. Local HTTP tests exercised
missing session, wrong device, successful redemption and retry. All 59 focused
recovery, ownership, monthly-access and checkout tests passed. The recovery flag
remains unconfigured and this work is undeployed; verified-contact issuance,
delivery and app UI are still missing. No email, charge, printing or app build.

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
   and sandbox provider rehearsals of the new refund closure. Full-refund closure
   is implemented; broader operational recovery remains. Never clear an uncertain submission merely because a search is
   empty. A replacement parcel needs a verified decision, not an automatic retry.
4. Verify the configured Stripe test prices, tax behavior, webhook delivery and
   actual R2 deletion after the configured retention age. The deployed sandbox
   purchase → PDF upload → Lulu acceptance → status/receipt flow has passed for
   synthetic PDFs; repeat with app-generated artifacts. Exercise cancellation and earned parcels
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

### Shipment tracking normalization (September 11)

Source now reads tracking from Lulu print-job line items and status messages,
including multiple URLs, carrier and tracking number. A shared normalizer carries
only shipment fields through durable print receipts and all order responses.
Status refresh persists shipment details and retains known tracking when a later
response omits it. Legacy trackingURL remains supported. Both app order panels
render all parcels; optional shipments decode older saved orders. Saved-order
refresh already writes the returned Codable order locally.

Thirty tracking, parcel-support and submission tests passed; order-preview tests
also passed after persistence wiring. Swift source parsing and diff hygiene passed.
No app build, visual QA, deployment or real shipment occurred. Split-shipment UI,
relaunch persistence and a shipped sandbox job still need end-to-end rehearsal.
Carrier notifications and a complete order-history surface are not established by
these changes. Recovery issuance remains disabled and unfinished as documented
in MEMBERSHIP_RECOVERY.md.

### Order-status endpoint tracking regression

Extended the existing authenticated order-preview rehearsal with realistic
line-item and nested-message shipments. Both parcels, carrier names and numbers
reach the customer response. A subsequent delivered response without tracking
retains both saved parcels. A foreign checkout token receives 401 without links.
This found and repaired missing status mappings: DELIVERED now maps to delivered,
IN_PRODUCTION to inProduction, and CANCELED/CANCELLED to cancelled rather than
falling back to submitted or failed. Production errors still map to failed.

The complete order-preview rehearsal passed with mocked providers, followed by
30 tracking/submission/parcel-support tests. No live provider operation, app build
or deployment was performed. Device rendering and real sandbox shipment evidence
remain separate outstanding checks.

### Combined recovery/tracking checkpoint

Deployed Worker version 016cb0ea-a900-4240-89bb-f9b99c62ffd8 with Stripe test mode,
Lulu sandbox and both recovery switches absent. Live HTTP probes independently
confirmed request and redeem return 503 membership_recovery_disabled. Worker
reported 18 ms startup during deployment. No real money, print job or recovery
email was created by this deployment/check.

Final physical-device Debug build succeeded after persistent retry-ID changes.
46 focused recovery/tracking tests and 42 membership-checkout/monthly tests passed;
membership, gift and order-preview scripts also passed. This is build and mocked
runtime evidence, not device visual QA or enabled-Worker recovery evidence.
Rabbit was unavailable; the user has it at work and will connect it at home.
Device install/launch, real sandbox shipment tracking and recovery UI rehearsal
remain pending. No need to ask again for build/whole-worktree commit authorization.

### Tracking access survives quote cleanup

A read-only request against saved sandbox job 332000 returned quote_not_found:
its original quote was already unavailable. This exposed tracking's dependency on
quote retention. New stored orders now preserve a separate non-expiring capability
hash bound to payment, quote and print-job IDs. Customer responses never contain
that hash. Status refresh authenticates against it; legacy orders migrate only
while their original quote remains verifiable. Existing orders with missing quotes
cannot be automatically reclaimed from a known payment/print-job identifier.

Order-preview regression now removes the quote and confirms authenticated refresh
still returns both parcels. Original foreign-token checks remain. Submission and
parcel-support suites also passed. The old cancelled rehearsal cannot establish
actual shipped-carrier behavior and was not altered or reordered.
