# Going live — the checklist

Everything buildable without the paid Apple Developer account is built and
green. This is what is left, in the order it unblocks things.

Nothing below needs a code change unless it says so. The app reads all of it
from configuration, on purpose, so the fee is the only real decision left.

---

## 1. Apple Developer Program — $99/year

Unblocks items 2, 3 and 4.

## 2. Apple Pay — a plist key, no build

Already written and dormant: `PaymentSheet` picks it up the moment an
identifier exists, and behaves exactly as it does today when one does not.

1. Create a merchant identifier — `merchant.com.openclaw.enchantify` or similar.
2. Add the **Apple Pay** capability to the app target.
3. In Stripe → Settings → Payments → Apple Pay, register that merchant id and
   let Stripe issue the certificate.
4. Add to `InsideCoverApp/Info.plist`:
   ```xml
   <key>ApplePayMerchantIdentifier</key>
   <string>merchant.com.openclaw.enchantify</string>
   <key>ApplePayMerchantCountryCode</key>
   <string>US</string>
   ```

For a device test before the plist lands:
```sh
defaults write com.openclaw.enchantify.insidecover applePayMerchantIdentifier "merchant.com.openclaw.enchantify"
```

**Why it matters:** without it a reader hand-types a card number, an expiry, a
CVC and a full postal address to buy a keepsake. With it, Face ID.

## 3. App Store Connect — subscription prices

The in-app strings are only the offline fallback shown before StoreKit answers.
The real prices live here, and changing them needs no build.

- Create the **monthly** auto-renewable in the same subscription group as the
  existing annual.
- Set **$9.99/month** and **$79.99/year** on the existing product ids in
  `BookShopCatalog.standingOrderTiers`.
- Configure the **30-day introductory free trial** on both.
- Paste the Terms and Privacy URLs into the group localisation.
- Set every content pack to **$6.99**, and do not go below it. That is the
  lowest price at which a year of packs ($83.88) costs more than the annual
  ($79.99). At $5.99 break-even is 13.4 packs against the twelve the sub
  actually delivers, so the shelf would undercut the subscription no matter
  what the paywall says. Raise the annual and this floor moves with it —
  `BookShopCatalog.archivePackPrice`, guarded by `ArchiveWindowTests`.

## 4. Bound Year production proof and offer codes

The prepaid parcel contract is now implemented in source. Stripe keeps the full
shipping destination outside the Book archive; the Worker verifies an earned
season, accepts parcel-scoped interior/cover uploads, serializes the season's
Lulu submission, and never creates a second PaymentIntent. The app refreshes
monthly paid-through state at launch and marks a dispatch posted only after Lulu
accepts it.

Before real money, deploy this Worker revision and prove one complete sandbox
year-path: subscribe, change address, force an earned season/window, upload both
PDFs, submit, retry, and confirm exactly one Lulu job. Also verify a stopped
monthly membership still receives a season it fully earned.

A second contract still blocks real money. A Bound Year member is entitled to everything the Standing Order gives,
and the compliant way to hand that over is an App Store **subscription offer
code** for a free year, emailed on signup.

- Generate one-time-use codes for the annual Standing Order product.
- Send one with the membership receipt.

Until the sandbox parcel proof and digital grant both exist, a Bound Year member
cannot reliably receive both halves of the promise. **Do not open the Bound Year
for real money before both are production-verified.** The Worker enforces this
with `BOUND_YEAR_LIVE_SALES_ENABLED = "false"`; leave it false until then.

---

## 5. Stripe — the Bound Year prices

Independent of Apple; can be done any time.

1. Create two recurring prices for the Bound Year — monthly and annual.
2. Add them as Worker secrets:
   ```sh
   cd docs/physical-book-backend
   npx wrangler secret put STRIPE_BOUND_YEAR_MONTHLY_PRICE
   npx wrangler secret put STRIPE_BOUND_YEAR_ANNUAL_PRICE
   ```

Without these the membership endpoints return **503 `membership_not_configured`**
and the app says the Bound Year isn't open yet. That is deliberate: it fails
closed rather than guessing a price.

## 6. Lulu — sandbox to production

The Worker is pointed at Lulu's sandbox and `CHECKOUT_MODE = "test"`. Both must
flip together — the Worker refuses to run with a live Stripe key against a
sandbox printer, and vice versa.

In `wrangler.toml`:
```toml
LULU_API_BASE_URL = "https://api.lulu.com"
LULU_AUTH_URL = "https://api.lulu.com/auth/realms/glasstree/protocol/openid-connect/token"
CHECKOUT_MODE = "live"
```
Then `npx wrangler secret put STRIPE_SECRET_KEY` with the live key, and
`npx wrangler deploy`.

Check `/health` reports `productionReady: true` before taking a real order.

---

## Already done, for the record

| | |
|---|---|
| Prices | $9.99/mo · $79.99/yr in code; $35 book markup, deployed |
| Bindings | Softcover default; hardcover and cloth-foil as upsells |
| Extras | Server-owned catalogue; photo covers working |
| Checkout | Paying is the last action; the press runs itself |
| Bound Year | Subscribe, update parcel address, cancel, and prepaid seasonal dispatch in source; deployment proof and digital offer code still blocked above |
| Cancellation | Apple's sheet for the Standing Order; in-app for the Bound Year |
| Worker | Deployed — memberships, options, orders, webhooks |

## One thing to decide, not configure

The **Bound Year cancel** works in-app today. The **Stripe customer portal**
does not exist, so a member who deletes the app has no self-serve route left.
Either build the portal or accept handling those by email — it is rare, but it
should be a decision rather than a surprise.
