# Physical Book Quote Backend

The iOS app must not store Lulu credentials. The BookShop quote button calls a
server endpoint that owns:

- Lulu API credentials
- live Lulu shipping/manufacturing quote calls
- future Stripe payment intent creation
- future hosted print-file URLs and Lulu print-job submission

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
npx wrangler secret put PHYSICAL_BOOK_API_TOKEN
```

Create an order KV namespace before production deploys:

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
defaults write com.openclaw.enchantify.insidecover physicalBookAPIToken "..."
```

For TestFlight/App Store builds, add the same URL as
`PhysicalBookQuoteEndpointURL` in `InsideCoverApp/Info.plist`, and add your
Stripe publishable key as `StripePublishableKey`. If the Worker has
`PHYSICAL_BOOK_API_TOKEN` configured, add the matching app value as
`PhysicalBookAPIToken`.

## Required Secrets

Configure these only on the backend:

```sh
LULU_CLIENT_KEY="..."
LULU_CLIENT_SECRET="..."
STRIPE_SECRET_KEY="sk_live_..."
PHYSICAL_BOOK_API_TOKEN="..."
LULU_API_BASE_URL="https://api.sandbox.lulu.com"
LULU_AUTH_URL="https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token"
ZIP_CITY_LOOKUP_BASE_URL="https://api.zippopotam.us"
```

This repo's Worker config defaults to Lulu sandbox/dev credentials while the
integration is being proven. For production Lulu credentials, switch the base URL
to `https://api.lulu.com` and the auth URL to
`https://api.lulu.com/auth/realms/glasstree/protocol/openid-connect/token`.

`ZIP_CITY_LOOKUP_BASE_URL` is optional. When the app asks for a quote with only
state/ZIP, the Worker resolves the city before calling Lulu's cost endpoint.
If the lookup is unavailable or does not return a city, the quote request fails
with a clear setup/validation error instead of guessing.

## Setup Health

After deployment, check the non-secret setup report:

```sh
curl https://reenchanted-physical-books.YOUR_SUBDOMAIN.workers.dev/health
```

The response reports booleans for Lulu credentials, Stripe, API token, public
print-file base URL, R2 upload binding, and KV order storage. It does not expose
secret values. `productionReady` should be `true` before accepting real orders.

## Protected Endpoints

When `PHYSICAL_BOOK_API_TOKEN` is configured on the Worker, the following
endpoints require `Authorization: Bearer ...`:

- `POST /payment-intents`
- `POST /print-files/interior`
- `POST /print-files/cover`
- `POST /orders/preview`
- `POST /orders`
- `GET /orders/:luluPrintJobID`

The quote endpoint remains unauthenticated so the app can ask Lulu for live
shipping/manufacturing prices before checkout. For deployment, configure the
same token in the app as `PhysicalBookAPIToken` or the `physicalBookAPIToken`
user default.

## Hosted Print Files

Lulu print jobs need public, fetchable PDF URLs plus MD5 checksums. The Worker
can host generated PDFs in Cloudflare R2:

1. Create an R2 bucket, for example `reenchanted-physical-book-files`.
2. Bind it in `wrangler.toml` as `PHYSICAL_BOOK_FILES`.
3. Configure `PUBLIC_PRINT_FILE_BASE_URL` to the public/custom domain serving
   that bucket.

The app uploads each generated PDF with:

- `POST /print-files/interior`
- `POST /print-files/cover`
- or the same paths under `/api/physical-books/`

Required headers:

- `Content-Type: application/pdf`
- `X-Edition-ID: edition-2026-06`
- `X-Source-MD5: 0123456789abcdef0123456789abcdef`

The response is `PhysicalBookHostedPrintFile`:

```json
{
  "kind": "interior",
  "sourceURL": "https://files.example.com/physical-books/edition-2026-06/interior-0123456789abcdef0123456789abcdef.pdf",
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
must be able to read the files to produce the physical book. The current R2
serving model uses long, content-addressed public URLs. Treat those URLs as
private links, not as access-controlled documents.

Before upload or final submission, the iOS app should explicitly disclose that
the print files leave the device and are shared with Lulu, the third-party
print-on-demand provider. If stronger manuscript privacy is required, the next
backend step is to replace public R2 serving with short-lived signed URLs or an
authenticated fetch proxy that Lulu can access only during order submission.

## Order Storage

Bind a Cloudflare KV namespace as `PHYSICAL_BOOK_ORDERS` before accepting real
orders. The Worker stores successful Lulu print-job responses by Stripe
PaymentIntent id, so retrying the same paid order returns the existing order
instead of creating another Lulu print job.

Local development and smoke tests can run without the binding, but production
deploys should configure it in `wrangler.toml`.

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
