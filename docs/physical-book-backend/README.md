# Physical Book Quote Backend

See [the active sandbox completion checklist](COMPLETION.md) for current status,
remaining rehearsals, and separate release gates.

The iOS app must not store Lulu credentials. The BookShop quote button calls a
server endpoint that owns:

- Lulu API credentials
- live Lulu shipping/manufacturing quote calls
- Stripe payment intent creation, and verification that a settled intent
  matches the server's own expected total before anything is printed
- destination-aware Stripe Tax calculation for sales tax, VAT, and GST, with
  the calculation committed to Stripe's tax ledger only after payment succeeds
- signed Stripe webhook reconciliation with replay protection and monotonic
  payment-success state
- server-owned, expiring quotes; the client cannot choose prices or rewrite a
  paid order after the quote is issued
- private R2 print files exposed only through random, expiring Worker delivery
  URLs
- Lulu submission serialized by a parcel-scoped Durable Object, with a durable
  attempt written before the external request and a minimal receipt afterward
- dual-rate-limited 15-minute client sessions bound to both the installation
  and connecting network, with no extractable backend secret shipped in the app
- delivery address, phone, postal code, and contact email erased from the quote
  record as soon as Lulu accepts the print job
- a scheduled paid-without-print reconciliation ledger with protected operator
  status and optional HTTPS alert delivery
- Bound Year addresses held by Stripe rather than the Book archive, plus
  earned-season verification and membership-scoped Lulu submission that never
  creates a second charge
- gift claim records that hold only names, an explicit note, broad destination
  facts and fulfillment state; the recipient's private Pages arrive only with
  the recipient's later print order

The display policy is mirrored in Swift, but payment authority lives here. Lulu's
stored manufacturing quote, the stored shipping option, and the server's markup
produce the Stripe amount. Prices submitted by the app are ignored.

See [verification and remaining launch work](VERIFICATION.md) for the current
evidence. Passing local provider mocks or `/health` does not establish a real
Stripe payment, a Lulu-accepted PDF, or a physically inspected book.

The quote contract carries `editionKind`. A monthly perfect-bound softcover has
a $49.99 product floor; a seasonal, annual, or special softcover has a $69.99
floor. Illustrated hardcovers remain $89.99, cloth-and-foil remains $99.99,
and weekly stitched issues remain $19.99. Requests from older app versions that
do not carry an edition kind retain the former $79.99 softcover floor so an old
saved quote cannot be repriced after it was shown to its reader. Manufacturing
cost can still lift any product above its floor to preserve the contribution
margin.

## App Endpoint

Set one of these to the HTTPS endpoint that accepts `PhysicalBookQuoteRequest`
and returns `PhysicalBookQuote`:

- `PhysicalBookQuoteEndpointURL` in `InsideCoverApp/Info.plist`
- `physicalBookQuoteEndpointURL` in app `UserDefaults`

Example:

```sh
defaults write com.openclaw.enchantify.insidecover physicalBookQuoteEndpointURL "https://example.com/api/physical-books/quote"
```

## Cloudflare Worker Setup

Install dependencies:

```sh
cd docs/physical-book-backend
npm install
```

For local testing, copy the template and fill in sandbox or production Lulu
credentials:

```sh
cp .dev.vars.example .dev.vars
npm run dev
```

For deployed secrets:

```sh
npx wrangler secret put LULU_CLIENT_KEY
npx wrangler secret put LULU_CLIENT_SECRET
npx wrangler secret put STRIPE_SECRET_KEY
npx wrangler secret put STRIPE_WEBHOOK_SECRET
npx wrangler secret put PHYSICAL_BOOK_ADMIN_TOKEN
npx wrangler secret put MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY
```

Create the quote/order KV namespace before production deploys:

```sh
npx wrangler kv namespace create PHYSICAL_BOOK_ORDERS
```

Deploy:

```sh
npm run deploy
```

After deploy, Cloudflare prints a Worker URL. Put that URL in the app as the
quote endpoint.

For a local device/debug install:

```sh
defaults write com.openclaw.enchantify.insidecover physicalBookQuoteEndpointURL "https://reenchanted-physical-books.YOUR_SUBDOMAIN.workers.dev"
defaults write com.openclaw.enchantify.insidecover stripePublishableKey "pk_test_..."
defaults write com.openclaw.enchantify.insidecover physicalBookCheckoutMode "test"
```

For TestFlight/App Store builds, add the same URL as
`PhysicalBookQuoteEndpointURL` in `InsideCoverApp/Info.plist`, set
`PhysicalBookCheckoutMode`, and add the matching Stripe publishable key as
`StripePublishableKey`. Do not put Lulu credentials, Stripe secret keys, or an
app-wide bearer secret in the bundle. The rate-limited `/sessions` bootstrap
returns a random 15-minute session; later calls additionally use the
quote-scoped checkout capability.

## Required Secrets

Configure these only on the backend:

```sh
LULU_CLIENT_KEY="..."
LULU_CLIENT_SECRET="..."
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."
PHYSICAL_BOOK_ADMIN_TOKEN="..."
LULU_API_BASE_URL="https://api.sandbox.lulu.com"
LULU_AUTH_URL="https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token"
ZIP_CITY_LOOKUP_BASE_URL="https://api.zippopotam.us"
```

This repo's Worker config defaults to Lulu sandbox/dev credentials while the
integration is being proven. For production Lulu credentials, switch the base URL
to `https://api.lulu.com` and the auth URL to
`https://api.lulu.com/auth/realms/glasstree/protocol/openid-connect/token`.

Use a Stripe test key with the sandbox examples above. Change Stripe and Lulu
together only for an explicitly authorized live launch.

Run `npm run rehearse:sandbox-preflight` for a bounded deployed check. It requires
aligned test providers and closed live sales before opening a short-lived session,
closing empty membership/gift attempts, rejecting delayed creates, and requesting
a synthetic Lulu quote. It never confirms payment or submits print files/jobs.
The health report's `boundYearTestReady` additionally requires both membership
price IDs; `testReady` alone only describes the general print infrastructure.
Price presence still needs verification against the actual Stripe test catalogue.

Checkout has a separate launch switch and environment lock:

```toml
CHECKOUT_MODE = "test" # or "live"
PHYSICAL_BOOK_ORDERING_ENABLED = "false"
BOUND_YEAR_LIVE_SALES_ENABLED = "false"
STRIPE_TAX_ENABLED = "false"
```

Leave ordering disabled until the webhook is configured. Test mode requires a
Stripe test/restricted-test key and Lulu sandbox URLs. Live mode requires a
Stripe live/restricted-live key and Lulu production URLs. Payment creation,
manuscript upload, preview, and fulfillment all fail closed if the selected
mode does not match both providers. Only then should the launch switch become
`"true"`. Live checkout additionally requires `STRIPE_TAX_ENABLED = "true"`;
the Worker reports production as not ready and refuses payment while tax is
off.

Before enabling tax, configure the business origin and every active tax
registration in Stripe Tax. One-off books use Stripe's `Books` product tax code
(`txcd_35010000`), weekly saddle-stitched issues use `Periodicals`
(`txcd_35020200`), and delivery uses `Shipping` (`txcd_92010001`) by default.
The Bound Year Price's Product must also have the correct physical-publication
tax code and tax behavior in Stripe. Its subscription uses automatic tax and
validates the delivery location before opening the first invoice.

Lulu's quoted tax is a printer/fulfillment cost paid by ReEnchanted; the Worker
folds it into delivery. It is deliberately not presented as VAT or sales tax.
Stripe Tax owns the reader-facing tax line. Registering, remitting, OSS/IOSS,
and importer-of-record obligations are still business/legal setup, not something
the Worker can infer; expand destinations only after those registrations and
fulfillment terms are confirmed.

Lulu currently requires a recipient customs tax identifier for print jobs sent
to Brazil, Chile, and Mexico. The app asks for CPF/CNPJ, RUT, or RFC only when
the destination needs it. A one-off order keeps the compact identifier in its
short-lived quote and erases it with the address after Lulu accepts the job.
Bound Year parcels need it months later, so the Worker encrypts it with
`MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY` in the restricted order store, refreshes a
500-day expiry only while parcels are still being prepared, and never returns
it to the app or places it in the Book archive. Use a randomly generated secret
of at least 32 characters and keep it stable while any such membership is
active.

## Publication recipes

Calendar bindings and special editions deliberately converge before proofing.
`PublicationEditionRecipe` declares a special edition's identity, editorial
sources, minimum useful source count, eligible bindings, a-la-carte status, and
gift status. `PublicationHouseBuilder.specialEdition` turns its selected
sections into the same `MonthlyEdition` artifact used by the cover, dedication,
PDF, quote, tax, checkout, and fulfillment pipeline.

The initial catalogue leaves two doors open:

- **The People You Kept** — kept people, relationship receipts, reader letters,
  and relevant kept pages
- **Letters from the Labyrinth** — cast letters, cast notes, and marginalia

Adding another special edition should therefore be catalogue work plus an
editorial source collector. It must not add a parallel checkout or fulfillment
route. The recipe's `bindingKinds` is enforced by the Print Studio, so a future
edition can offer only the physical forms that suit its material.

Weekly issues are the one calendar-specific physical form: a-la-carte,
saddle-stitched, four-page folded signatures, and no more than 48 interior
pages. Every archived issue remains available from its reading copy and from
Print Studio. The physical editor aims for 20 pages when a week is quiet, 24
when it is modest, and 32 for an ordinary full issue. Forty-eight remains a
technical ceiling rather than a target to pad toward.
The Worker repeats the hard limits before quoting so an altered client cannot
purchase an impossible booklet. Validate the exact Lulu package ID and both
generated PDFs against Lulu's sandbox template before enabling live weekly
orders.

`BOUND_YEAR_LIVE_SALES_ENABLED` is an additional production-only gate. Sandbox
membership work remains testable while it is false, but live membership signup
returns `503 bound_year_live_sales_disabled`. Do not turn it on until one full
prepaid parcel has passed in sandbox. The Standing Order offer-code grant is no
longer a launch dependency while monthly digital content is free. Status,
address changes, cancellation, and parcels already owed
remain available while new live sales are shut.

`ZIP_CITY_LOOKUP_BASE_URL` is optional. When the app asks for a quote with only
state/ZIP, the Worker resolves the city before calling Lulu's cost endpoint.
If the lookup is unavailable or does not return a city, the quote request fails
with a clear setup/validation error instead of guessing.

## Setup Health

After deployment, check the non-secret setup report:

```sh
curl https://reenchanted-physical-books.YOUR_SUBDOMAIN.workers.dev/health
```

The response reports booleans for Lulu credentials, Stripe, the admin token, private
print delivery, R2 and KV bindings, rate limiting, the Durable Object
coordinator, protected membership-customs storage, the launch switch, and
environment alignment. It does not expose
secret values. `readyForConfiguredMode` must be `true` for testing, and
`productionReady` must be `true` before accepting real orders.

## Stripe Webhook

Create a Stripe webhook endpoint at:

```text
https://reenchanted-physical-books.YOUR_SUBDOMAIN.workers.dev/stripe/webhook
```

Subscribe it to these PaymentIntent events:

- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `payment_intent.canceled`

Store that endpoint's `whsec_...` signing secret as `STRIPE_WEBHOOK_SECRET`.
The Worker verifies Stripe's signature against the unmodified request body,
enforces a five-minute timestamp window, binds payment amount, currency, quote,
edition, package, and shipping metadata, and keeps a 30-day event replay ledger.
Webhook state is authoritative for payment reconciliation; printing still
requires the reader's explicit final order submission and uploaded print proofs.

Subscription events are deliberately not subscribed. Bound Year memberships
are never trusted from webhook state: every grant (monthly shelf session, parcel
dispatch, recovery contact) re-reads the subscription and its latest invoice,
PaymentIntent and charge from Stripe at the moment of use, so a cancellation,
refund or dispute takes effect on the next read without a webhook. Every such
check also requires Stripe's `livemode` to match `CHECKOUT_MODE`; any mode
other than exactly `test` or `live` accepts nothing (`checkout-mode.mjs`).

## Protected Endpoints

`POST /sessions` is the only public bootstrap. It is dual-rate-limited and
returns a 15-minute capability bound to the installation identifier and
Cloudflare-provided connecting address. There is deliberately no bearer secret
inside the distributed app: such a value is extractable and cannot establish
reader identity. Checkout calls use the short session as their bearer token,
and later calls also require the quote-scoped `X-Checkout-Token` capability:

- `POST /quote`
- `POST /payment-intents`
- `POST /print-files/interior`
- `POST /print-files/cover`
- `POST /orders/preview`
- `POST /orders`
- `GET /orders/:luluPrintJobID`
- `POST /memberships` and `GET /memberships/:id`
- `POST /memberships/:id/cancel` and `POST /memberships/:id/shipping`
- `POST /memberships/:id/dispatches/:seasonKey`
- `POST /memberships/:id/dispatches/:seasonKey/print-files/{interior|cover}`
- `POST /memberships/:id/dispatches/:seasonKey/orders`
- `POST /gifts/books` and `POST /gifts/bound-year`
- `GET /gifts/:claimToken`, `POST /gifts/:claimToken/claim`, and
  `POST /gifts/:claimToken/decline`
- `POST /gifts/:claimToken/orders`

Membership dispatch preparation returns its own random
`X-Membership-Dispatch-Token`. The Worker derives the included binding from the
verified season index: three softcovers, then either the promised
cloth-and-foil annual or its equally included illustrated hardcase when a
photograph or plate must print. It rejects paid extras in the prepaid path and
serializes submission by membership plus season. Stripe is fetched again at
submission, so an address change is honored without persisting the street in
the Book or the dispatch record.

All membership reads, address changes, cancellations, preparations, uploads and
submissions also require the installation ownership written by checkout or gift
claim. A subscription ID plus an unrelated valid print session is insufficient.
Missing ownership records fail closed; recovery must independently verify the
reader before moving ownership.

Membership and Bound Year gift creation require `X-Purchase-Attempt-ID` (a saved
UUID v4). The app saves the original form in device-only Keychain before the
first request and keeps a random attempt ID keyed by an opaque request fingerprint.
The endpoint, checkout mode, installation and purchase kind scope the attempt.
Unfinished forms have an explicit Continue action; transient failures never clear
them. Only known validation failures before Stripe access let the reader correct
the form. No street address or Stripe client secret is stored in preferences.

`POST /memberships/checkout/cancel` and
`POST /gifts/bound-year/checkout/cancel` use the same session and attempt header.
They close only the original unpaid checkout, even when new sales are disabled.
An incomplete subscription's unpaid first invoice is voided, and Stripe must
confirm `incomplete_expired` before local recovery state may clear. Already-paid,
processing or unidentified payments remain saved. A lost response is recovered
by rereading Stripe. A durable closed marker prevents a delayed create request
from reopening the old attempt. The app exposes this as Close unpaid checkout;
canceling a paid membership still uses its separate end-of-period route.
See [Stripe's subscription invoice lifecycle](https://docs.stripe.com/billing/invoices/subscription).

The existing Durable Object serializes each checkout, saves its original request
hash and date, and records Stripe customer/subscription IDs after each step.
Uncertain steps retry with the same Stripe idempotency key for at most 23 hours;
older uncertain steps require operator recovery instead of risking a new charge.
Known IDs can be read after that window. Ownership and gift-index write failures
are repaired on retry, and one saved claim token produces one gift. Changed
request bodies or price configuration cannot reuse the old attempt.

Checkout responses and membership status include `paymentVerified`. The app
checks this server proof before recording a paid membership or granting access;
a billing-period end is never newly treated as paid without verification. Gift
readiness and claims verify the settled payment again, including refunds and
disputes. A gift link is saved in Keychain before the pending purchase clears,
and the last created link remains available from the Gift Shelf.

Gift claims and declines are serialized by a claim-scoped instance of the existing
Durable Object. Its durable decision is reserved before publishing to KV or the
monthly ownership ledger. A failed KV write cannot let another installation win
the same gift after a restart. The original winner can resume publication.
Readiness checks return a view of current payment state without overwriting gift
lifecycle records, so a late read cannot erase a claim or revive a declined gift.

Deploy the updated Worker before testing the updated app against it: older
Workers do not return `paymentVerified`, and older clients do not supply purchase
attempt IDs. This contract intentionally fails closed during a version mismatch.

The season must have closed. Entitlement is proved from settled Stripe invoices
for the configured membership price and environment, covering all three calendar
months. A billing-period end alone proves nothing. Fully refunded or disputed
payments, zero-payment trials, unpaid gaps, and prorations do not earn a parcel.
Canceling, or becoming past due later, does not erase an already paid season.
The invoice schema is pinned to Stripe `2024-06-20`; invoice reads stop once the
three months are covered, with a maximum of twelve pages of 100 invoices.
Complimentary, credit-only and manually marked-paid invoices require a separate
verified fulfillment policy; this path does not silently treat them as payments.

Every print path (one-off, gift and prepaid season) writes a durable submission
attempt before contacting Lulu. A saved receipt can finish local recording after
a storage failure. A lost response leaves the attempt intact across restarts.
A later retry searches Lulu for the server's parcel reference and accepts only
one exact match in a complete result set. Empty, fuzzy, duplicate or incomplete
results stay blocked as `print_submission_uncertain`; absence is never permission
to create a replacement job. A changed address or payload returns
`print_submission_changed`. Investigate these in the Bindery and Lulu before
changing any durable state. There is deliberately no automatic reset/expiry of
an uncertain attempt. Durable records contain a payload hash, reference, time and
minimal receipt, never Lulu's full shipping response.

Preparation also asks Lulu's `cover-dimensions` endpoint for the exact
page-count/SKU canvas and returns those print points to the app. The interior is
therefore rendered first; the cover is composed only after Lulu has named the
real spine, board-wrap, or jacket-and-flap width. Linen annuals upload a dust
jacket PDF and carry separately validated `foil_stamp_title_text` /
`foil_stamp_author_text` fields in the Lulu print job. Their combined text is
restricted to 42 supported characters; artwork is never represented as foil on
the front board.

The Worker applies both per-installation and hashed per-network rate limits, so
rotating a caller-supplied installation identifier cannot bypass the network
limit. The installation identifier lives in the iOS keychain rather than user
defaults, but remains an abuse-control signal rather than proof of identity.
Do not remove the Cloudflare rate-limit binding.

## Reconciliation and PII Lifecycle

Stripe success writes a PII-free `paid awaiting print` marker. A cron runs every
15 minutes; after 30 minutes without a Lulu submission it records an alert in
KV, emits a PII-free Worker error event, and emails the fixed, verified address
configured by the `SECURITY_ALERT_EMAIL` binding. The email contains only an
incident fingerprint, timestamps, and the checkout environment—not customer
contact details, shipping details, quote IDs, or PaymentIntent IDs. An optional
HTTPS hook in `SECURITY_ALERT_WEBHOOK_URL` receives the same minimized alert.
Inspect the live queue with:

```sh
curl -H "Authorization: Bearer $PHYSICAL_BOOK_ADMIN_TOKEN" \
  https://reenchanted-physical-books.YOUR_SUBDOMAIN.workers.dev/admin/reconciliation
```

The admin response contains quote and PaymentIntent IDs, never addresses or
contact details. Configure log alerts on `physical_book_paid_without_print` if
no webhook is used. Successful Lulu submission clears the marker and immediately
redacts email, street address, city, postal code, and phone from the stored quote.
An unpaid or failed checkout retains delivery details for at most 24 hours; a
plain quote retains them for only 15 minutes. The remaining post-payment,
redacted capability and payment binding expires after 90 days. Private
print-file delivery capabilities expire after 48 hours. R2 objects become eligible
for automatic deletion after three days; the buffer preserves the full delivery
window. Deletion is asynchronous, not an exact-hour guarantee.

## Hosted Print Files

Lulu print jobs need temporarily fetchable PDF URLs plus MD5 checksums. The
Worker hosts generated PDFs in a private Cloudflare R2 bucket:

1. Create an R2 bucket, for example `reenchanted-physical-book-files`.
2. Bind it in `wrangler.toml` as `PHYSICAL_BOOK_FILES`.
3. Keep the bucket private. The Worker derives delivery links from the HTTPS
   origin that received the upload; do not configure an `r2.dev` public domain.
4. Configure the prefix-scoped expiration rule below. Worker deployment does not
   install bucket lifecycle rules. Inspect existing rules first; preserve unrelated
   rules and the default incomplete-multipart cleanup.

```sh
npx wrangler r2 bucket lifecycle list reenchanted-physical-book-files
# Add once, if absent:
npx wrangler r2 bucket lifecycle add reenchanted-physical-book-files expire-private-print-files physical-books/ --expire-days 3
npx wrangler r2 bucket lifecycle list reenchanted-physical-book-files
```

This covers ordinary, gift, and membership print uploads under `physical-books/`.
The bucket performs cleanup without a per-request scan or a Worker cleanup cron.
Cloudflare says expired objects are typically removed within 24 hours of their
expiration, with possible delays. See [R2 object lifecycle behavior](https://developers.cloudflare.com/r2/buckets/object-lifecycles/).
The object's `expiresAt` custom metadata describes delivery-link expiry; metadata
alone does not delete a stored PDF.

`PRINT_FILE_DELIVERY_BASE_URL` is an optional HTTPS override for local or proxy
testing. Production normally leaves it unset so a stale hostname cannot leak
into a Lulu job.

The app uploads each generated PDF with:

- `POST /print-files/interior`
- `POST /print-files/cover`
- or the same paths under `/api/physical-books/`

Required headers:

- `Content-Type: application/pdf`
- `X-Edition-ID: edition-2026-06`
- `X-Quote-ID: <server quote id>`
- `X-Source-MD5: 0123456789abcdef0123456789abcdef`
- `X-Source-SHA256: <64-character digest verified by the Worker>`

The response is `PhysicalBookHostedPrintFile`:

```json
{
  "kind": "interior",
  "sourceURL": "https://print.example.com/print-files/delivery/<random capability>",
  "md5": "0123456789abcdef0123456789abcdef",
  "byteCount": 123456
}
```

### Privacy and Manuscript Handling

Physical book ordering is not local-only. To print a book, the app uploads the
generated interior and cover PDFs to the print backend, and those PDFs are made
available to Lulu so Lulu can manufacture and ship the book.

The transport path uses HTTPS, and R2 storage is encrypted at rest by the cloud
provider, but this is not end-to-end manuscript encryption: the print provider
must be able to read the files to produce the physical book. The R2 bucket stays
private. Lulu receives a random Worker capability URL that expires after 48
hours and is returned with `no-store` caching.

Before upload or final submission, the iOS app explicitly discloses that
the print files leave the device and are shared with Lulu, the third-party
print-on-demand provider.

## Order Storage

Bind `PHYSICAL_BOOK_ORDERS` and the SQLite-backed
`PHYSICAL_BOOK_ORDER_COORDINATOR` Durable Object before accepting real orders.
KV stores authoritative quote/file/order records; the Durable Object serializes
fulfillment for each Stripe PaymentIntent.

The service fails closed when storage, coordination, or rate limiting is absent.

## Endpoint Contract

### Gift lifecycle and support

`POST /gifts/books` converts a succeeded maximum-size checkout for the chosen
calendar edition and binding into a single claim key. The giftable catalogue is
one saddle-stitched weekly issue, or a monthly, seasonal, or annual edition in
softcover, illustrated hardcover, or cloth-and-foil hardcover. Finalization is
idempotent for that quote and PaymentIntent, and the full pricing address is
redacted as soon as the gift is sealed. A claim-key-encrypted address box remains
only to prefill the recipient's parcel label locally. `POST /gifts/bound-year`
opens one annual subscription with `cancel_at_period_end=true`; it cannot silently
renew into a second year.

The recipient inspects, claims, or declines through the claim-key endpoints.
A one-book recipient later submits a fresh quote and their own print files to
`POST /gifts/:claimToken/orders`; the Worker enforces the paid edition span,
binding, span-specific page ceiling (48 weekly, 200 monthly, 400 seasonal, 800
annual), destination, allowance, installation claim, and one-time redemption. It
never accepts a second payment from the recipient.

One-book gift creation, claims (including repeat claims), and new printer
submissions check the original Stripe payment and expanded charge. Full or partial
refunds, disputes, unsettled payments, wrong mode/identity, and an allowance
mismatch block fulfillment. Readiness checks show `paymentPending` without
rewriting durable gift ownership. Provider outages fail closed. Already-submitted
orders keep their receipts after a refund. These are event-bound checks, not
background polling on ordinary Book use.

For support and refunds, the restricted KV contains non-PII lookup indexes at
`book-gifts/payment/:paymentIntentID` and
`book-gifts/membership/:subscriptionID`, each pointing to the stored claim-token
hash. Refunds are performed to the original payment method in Stripe after
confirming the gift is unclaimed or declined and no print job was submitted;
then use the verified parcel refund-closure action below. Never ask a reader to email
private Pages to locate a gift.

Operations must track the promised ship date for every paid physical order. If
an order cannot ship by that date, or within 30 days when no date was promised,
contact the purchaser for affirmative delay consent or cancel and issue a full
refund. Lulu asks for visible damage, print-defect, or wrong-item claims within
30 days of its shipment date, so support should open the Lulu claim immediately
even where ReEnchanted's reader-facing policy gives the customer a later window.

Request body: `PhysicalBookQuoteRequest` from `Shared/PhysicalBookOrders.swift`.

Response body: `PhysicalBookQuote` from `Shared/PhysicalBookOrders.swift`.

The backend should keep shipping and tax as pass-through line items, then use
the app's pricing policy to show the customer total:

```swift
PhysicalBookPricing.priceBreakdown(request: request, shippingCents: option.price.cents)
```

Order creation accepts `PhysicalBookOrderRequest` at `POST /orders` or
`POST /api/physical-books/orders`. It maps to Lulu's print-job payload:

Before calling Lulu, the Worker retrieves the Stripe PaymentIntent named by
`paymentIntentID` and requires:

- `status: "succeeded"`
- amount/currency match the server recomputed total
- quote, edition, variant, package, and shipping metadata match the order

```json
{
  "external_id": "quote-123",
  "contact_email": "reader@example.com",
  "shipping_level": "MAIL",
  "line_items": [
    {
      "external_id": "quote-123-item-1",
      "title": "The Door That Was Only a Door",
      "pod_package_id": "0600X0900.FC.PRE.CW.080CW444.MXX",
      "quantity": 1,
      "interior": {
        "source_url": "https://cdn.example.com/interior.pdf",
        "source_md5sum": "0123456789abcdef0123456789abcdef"
      },
      "cover": {
        "source_url": "https://cdn.example.com/cover.pdf",
        "source_md5sum": "abcdef0123456789abcdef0123456789"
      }
    }
  ],
  "shipping_address": {
    "name": "Reader",
    "street1": "1 Harbor St",
    "city": "Belfast",
    "state_code": "ME",
    "country_code": "US",
    "postcode": "04915",
    "phone_number": "844-212-0689"
  }
}
```

Order status lookup accepts `GET /orders/:luluPrintJobID` or
`GET /api/physical-books/orders/:luluPrintJobID` and maps Lulu statuses into
`PhysicalBookOrder.Status`.

Quotes and seasonal preparations accept `editionTitle` (up to 255 characters),
which becomes Lulu's mandatory line-item `title`. The stored quote is authoritative
at submission. Old clients without a title use `ReEnchanted`; an explicitly empty
or invalid title is rejected before payment. Status refresh preserves the original
app order ID, payment reference, and creation timestamp.

Payment intent creation accepts `PhysicalBookPaymentIntentRequest` at
`POST /payment-intents` or `POST /api/physical-books/payment-intents`. The
Worker recomputes the total from the quote request and selected shipping option,
then creates a Stripe PaymentIntent with `automatic_payment_methods` enabled.
The app receives only:

```json
{
  "id": "pi_123",
  "clientSecret": "pi_123_secret_abc",
  "amount": { "currencyCode": "USD", "cents": 4099 },
  "quoteID": "quote-123",
  "selectedShippingOptionID": "MAIL"
}
```

## Lulu Payload Preview

### Holding and resolving a refunded one-off order

The existing admin token protects three operator routes (also available under
`/api/physical-books`):

- `GET /admin/reconciliation/:quoteID` reads a payment summary and durable
  submission/hold state without returning customer details or file URLs.
- `POST /admin/reconciliation/:quoteID/hold` permanently stops further submission
  through that payment's coordinator. It queues behind any in-flight submission;
  inspect its result before deciding what to do at Lulu. It does not cancel a job
  already at the printer and has no automatic release/reset operation.
- `POST /admin/reconciliation/:quoteID/close-refunded` verifies a full successful
  refund directly with Stripe, then resolves the payment alert and redacts the
  quote's delivery details. It requires a durable hold, keeps the printer attempt
  intact, and can safely be repeated after storage/network failures. Pending or
  partial refunds and disputes remain open. A printer review remains separate.

No route issues a refund or creates a replacement parcel. First inspect and hold
the order; investigate/cancel any existing Lulu job as appropriate; make the
approved refund in Stripe; then close the refunded payment. These routes reject
gift payments because holding a purchaser's quote would not stop a recipient's
separate redemption coordinator. Gift and prepared membership parcels use the
separate verified closure workflow below.

The operator helper uses a private file containing the existing admin token:

```sh
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-order.mjs inspect QUOTE_ID
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-order.mjs hold QUOTE_ID
# After Stripe confirms the approved full refund:
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-order.mjs close-refunded QUOTE_ID
```

The file must have mode 600 (or stricter). The helper never prints the token,
refuses redirects, checks aligned provider environments, and requires `--allow-live`
for live mode. `npm run test:reconciliation` covers authorization, holds, refund
proofs, restart/retry behavior, privacy and late reconciliation markers.

### Previewing the printer request

Use the preview endpoint to validate
that the app/backend order contract becomes the exact print-job payload Lulu
expects:

```sh
npm run test:preview
```

The endpoint accepts the same `PhysicalBookOrderRequest` as live order creation:

- `POST /orders/preview`
- `POST /api/physical-books/orders/preview`

It does not call Lulu or Stripe. It validates hosted PDF URLs and 32-character
MD5 checksums, then returns:

```json
{
  "mode": "preview",
  "quoteID": "quote-123",
  "luluPrintJobPayload": {
    "external_id": "quote-123",
    "contact_email": "reader@example.com",
    "shipping_level": "MAIL",
    "line_items": []
  }
}
```

With the matching paid test checkout, submit the same request body to `/orders`
to exercise the configured sandbox. Never reset an uncertain submission to retry
it: the durable attempt blocks duplicate printing. Safe failure diagnostics retain
only HTTP status and known field paths, excluding raw provider error text. See
`VERIFICATION.md` for actual sandbox evidence and remaining live-launch work.

## Starter

`lulu-quote-worker.mjs` is a small Cloudflare Worker fetch handler. It keeps the
Lulu-specific mapping in one file while the iOS app continues to use the shared
Swift quote/order contract.
# Monthly content delivery

This Worker also contains the subscriber-only monthly shelf. See [MONTHLY-ISSUES.md](MONTHLY-ISSUES.md) for request flow, configuration, tests, and verified ownership migration. It remains unconfigured until the monthly private bucket and verification credentials are supplied; physical checkout configuration alone does not enable it.

### Inspecting or holding gift and membership parcels

The one-off reconciliation route does not control gift redemption or prepaid
seasonal dispatch. Use their actual fulfillment coordinators through these
admin-token-protected routes (also available under `/api/physical-books`):

- `GET /admin/parcels/gifts/:paymentIntentID`
- `POST /admin/parcels/gifts/:paymentIntentID/hold`
- `POST /admin/parcels/gifts/:paymentIntentID/close-refunded`
- `GET /admin/parcels/memberships/:membershipID/:seasonKey`
- `POST /admin/parcels/memberships/:membershipID/:seasonKey/hold`
- `POST /admin/parcels/memberships/:membershipID/:seasonKey/close-refunded`

Gift lookup starts from the original purchaser's Stripe PaymentIntent ID, using
the private receipt index. Membership lookup requires an existing prepared
seasonal dispatch; `2026-S06` denotes the season beginning in June 2026. Neither
route requires a claim link, manuscript, address, or recipient credentials.
Inspection returns only identifiers, dates, the durable submission diagnostic,
and saved printer receipt/status. The status is the saved status, not a fresh
Lulu lookup. No Stripe or Lulu call is made by inspection or hold.

```sh
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-parcel.mjs inspect gift pi_EXAMPLE
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-parcel.mjs hold gift pi_EXAMPLE
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-parcel.mjs inspect membership sub_EXAMPLE 2026-S06
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-parcel.mjs hold membership sub_EXAMPLE 2026-S06
```

The helper defaults to test mode and requires `--allow-live` for live mode. A
hold is durable, idempotent and serialized with that parcel's fulfillment. If
submission was already in progress, the hold waits for it and exposes any saved
attempt/receipt; it cannot withdraw a request already sent to Lulu. After the
hold succeeds, future fulfillment requests are blocked across restarts. Existing
attempts and receipts are preserved. Holding one season does not hold other
seasons, cancel a subscription, revoke digital ownership, or stop gift claiming.

After placing the hold and completing the approved refund in Stripe, use:

```sh
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-parcel.mjs close-refunded gift pi_EXAMPLE
PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path/admin-token node reconcile-parcel.mjs close-refunded membership sub_EXAMPLE 2026-S06
```

Closure reads Stripe directly and requires the existing durable hold. A gift must
have a fully settled refund of its original paid allowance. A membership season
requires refunded invoices covering all three months, using the configured price,
subscription identity and billing cadence. One annual invoice can cover the whole
season; monthly billing requires all three months. All relevant payments must be
fully refunded, including any duplicate coverage. Missing months, pending/partial
refunds, disputes, foreign payment/invoice identities, prorations, truncated lines,
or incomplete history leave the case unresolved. The operator-only invoice walk
is capped at 12 pages and 24 relevant payments; it fails closed at those bounds.
Credit-funded and manually marked-paid invoices need separate review.

A successful closure stores a durable payment resolution and publishes a separate
permanent KV marker. Retry the same closure if publication fails. Gift reads and
claims honor the marker without overwriting a concurrent claim record. Membership
closure applies only to the selected parcel; it does not cancel the subscription
or change digital ownership. All holds and printer attempts/receipts remain intact.
A financial resolution is not printer cancellation. The API never creates refunds,
releases holds, submits replacement books, or calls Lulu during closure.

The proof uses the pinned [Stripe invoice schema](https://docs.stripe.com/api/invoices/object?api-version=2024-06-20)
and [PaymentIntent invoice identity](https://docs.stripe.com/api/payment_intents/object?api-version=2024-06-20).

 `npm run test:parcel-support` covers both coordinator types, authorization,
privacy, restart persistence, write failure, receipt retention and submission races.

### Local structural check for exported print PDFs

Before uploading a newly exported interior/cover pair, run the read-only checker
with `pypdf` installed in the selected Python environment:

```sh
python3 scripts/check_print_pdfs.py \
  --quote /private/path/saved-quote.json \
  --interior /private/path/interior.pdf \
  --cover /private/path/cover.pdf \
  --report /private/path/print-check.json
```

Run this command from the repository root. The quote must be the server response
for these exact files (or a rehearsal state containing that response at `quote`).
It checks interior count against the quote, 6 x 9 inch trim plus bleed (450 x 666
points), and a single cover spread at the exact returned cover dimensions. It
also detects encryption, page rotation/scaling, differing crop boxes, interactive
form widgets, unreadable PDF structure and unembedded fonts used in painted text,
including nested Form XObjects. Unused font resources do not cause false failures.

Exit codes: 0 means these structural checks passed; 1 means findings; 2 means
invalid input/report path. The report contains sizes, hashes and fixed finding
codes, without manuscript text, quote capabilities, addresses or payment details.
The input PDFs are never rewritten. This is an offline operator check, not work
added to page turns, checkout requests or the Worker.

A pass does **not** validate layout, actual bleed artwork, image resolution,
transparency/color reproduction, font program validity, narrative order, spine or
foil placement. Render and inspect the native app files, run Lulu validation and
obtain a physical proof before launch. See [Lulu's PDF creation settings](https://help.lulu.com/en/support/solutions/articles/64000255519-pdf-creation-settings).

`docs/fixtures/print-rehearsal-quote.json` preserves only the technical dimensions
from the successful synthetic sandbox rehearsal, for checking its PDFs without
using the private saved checkout state. It is not a new quote or authority to print.
Run regression tests from the root with:

```sh
python3 -m unittest discover -s scripts/tests -p test_check_print_pdfs.py -v
```
