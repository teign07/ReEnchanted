# Physical Book Quote Backend

The iOS app must not store Lulu credentials. The BookShop quote button calls a
server endpoint that owns:

- Lulu API credentials
- live Lulu shipping/manufacturing quote calls
- Stripe payment intent creation, and verification that a settled intent
  matches the server's own expected total before anything is printed
- signed Stripe webhook reconciliation with replay protection and monotonic
  payment-success state
- server-owned, expiring quotes; the client cannot choose prices or rewrite a
  paid order after the quote is issued
- private R2 print files exposed only through random, expiring Worker delivery
  URLs
- Lulu submission serialized by a PaymentIntent-scoped Durable Object so
  concurrent retries cannot print twice
- dual-rate-limited 15-minute client sessions bound to both the installation
  and connecting network, with no extractable backend secret shipped in the app
- delivery address, phone, postal code, and contact email erased from the quote
  record as soon as Lulu accepts the print job
- a scheduled paid-without-print reconciliation ledger with protected operator
  status and optional HTTPS alert delivery
- Bound Year addresses held by Stripe rather than the Book archive, plus
  earned-season verification and membership-scoped Lulu submission that never
  creates a second charge

The display policy is mirrored in Swift, but payment authority lives here. Lulu's
stored manufacturing quote, the stored shipping option, and the server's markup
produce the Stripe amount. Prices submitted by the app are ignored.

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
STRIPE_SECRET_KEY="sk_live_..."
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

Checkout has a separate launch switch and environment lock:

```toml
CHECKOUT_MODE = "test" # or "live"
PHYSICAL_BOOK_ORDERING_ENABLED = "false"
BOUND_YEAR_LIVE_SALES_ENABLED = "false"
```

Leave ordering disabled until the webhook is configured. Test mode requires a
Stripe test/restricted-test key and Lulu sandbox URLs. Live mode requires a
Stripe live/restricted-live key and Lulu production URLs. Payment creation,
manuscript upload, preview, and fulfillment all fail closed if the selected
mode does not match both providers. Only then should the launch switch become
`"true"`.

`BOUND_YEAR_LIVE_SALES_ENABLED` is an additional production-only gate. Sandbox
membership work remains testable while it is false, but live membership signup
returns `503 bound_year_live_sales_disabled`. Do not turn it on until one full
prepaid parcel has passed in sandbox and the promised Standing Order offer-code
grant exists. Status, address changes, cancellation, and parcels already owed
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
coordinator, the launch switch, and environment alignment. It does not expose
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

Membership dispatch preparation returns its own random
`X-Membership-Dispatch-Token`. The Worker derives the only included binding
from the verified season index (three softcovers, then the cloth hardcover),
rejects paid extras in the prepaid path, and serializes submission by
membership plus season. Stripe is fetched again at submission, so an address
change is honored without persisting the street in the Book or the dispatch
record.

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
print-file delivery capabilities and their R2 objects expire after 48 hours.

## Hosted Print Files

Lulu print jobs need temporarily fetchable PDF URLs plus MD5 checksums. The
Worker hosts generated PDFs in a private Cloudflare R2 bucket:

1. Create an R2 bucket, for example `reenchanted-physical-book-files`.
2. Bind it in `wrangler.toml` as `PHYSICAL_BOOK_FILES`.
3. Keep the bucket private. The Worker derives delivery links from the HTTPS
   origin that received the upload; do not configure an `r2.dev` public domain.

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
      "pod_package_id": "0600X0900.FC.STD.CW.060UW444.MXX",
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

While Lulu API access is still pending, use the preview endpoint to validate
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

Once Lulu credentials are approved, send the same request body to `/orders` to
submit the real print job.

## Starter

`lulu-quote-worker.mjs` is a small Cloudflare Worker fetch handler. It keeps the
Lulu-specific mapping in one file while the iOS app continues to use the shared
Swift quote/order contract.
