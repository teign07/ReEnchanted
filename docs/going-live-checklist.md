# Going live — the checklist

Last updated: 2026-10-11. Goal: testers on TestFlight, and any tester who wants
paper can pay real money for it.

Everything below reads from configuration on purpose. The app side is already
split: **Debug builds stay on Stripe test + Lulu sandbox; Release builds
(TestFlight, App Store) take their payment settings from three build settings**
on the InsideCoverApp target:

| Build setting | Debug | Release (at cutover) |
| --- | --- | --- |
| `PHYSICAL_BOOK_CHECKOUT_MODE` | `test` | `live` |
| `STRIPE_PUBLISHABLE_KEY` | `pk_test_…` | `pk_live_…` |
| `PHYSICAL_BOOK_ENDPOINT` | test Worker | production Worker |

Info.plist reads them as `$(…)`. Release currently still carries the test values,
so nothing changes until the cutover below.

The Worker can run only one mode at a time and refuses a mismatched app. So the
cutover needs **two Workers**: a staging one in test mode for Debug builds, and
the production one in live mode for Release.

---

## A. Decide before paying Apple (bj)

1. **Individual or organization.** The seller name on the App Store is public.
   Because printed books are sold, EU storefronts require trader contact
   details (address, phone, email) to be published. Options: Maine LLC + free
   D-U-N-S, then enroll as an organization; or enroll as an individual and
   leave EU storefronts off at first.
2. **Bundle ID** `com.openclaw.enchantify.insidecover` is permanent once the app
   record exists. Keep it or change it now. Changing it orphans the Book on
   Rabbit unless it's migrated.

## B. Apple (bj, after paying)

1. Enroll ($99/yr).
2. Register the three bundle IDs and the App Group; turn on HealthKit,
   App Groups, Increased Memory Limit for the app ID.
3. Create the App Store Connect record. Free Apps agreement only (no IAP).
4. Fill App Privacy from `docs/AppPrivacyInventory.md`; review notes and age
   rating from `docs/AppStoreReviewPacket.md`.
5. Archive a Release build from a clean, merged `main`; upload; internal
   TestFlight; then external (needs Beta App Review).
6. Optional: Apple Pay (§E).

## C. Worker + Stripe + Lulu (Codex; it has the accounts)

1. ~~**Alert inbox.**~~ Done 2026-10-11: `/health` → `testReady: true`.
2. **Staging Worker** for Debug builds: a wrangler `[env.staging]` with its own
   name, KV/R2/D1/Durable Object bindings, test Stripe secret + webhook
   secret, Lulu sandbox credentials, the test Bound Year price IDs, and
   `MONTHLY_ISSUES_OPEN_TO_ALL` plus the monthly-issue secrets so the shelf
   works in Debug too. Deploy it; `/health` → `testReady: true`.
3. **One full sandbox proof on staging** (still owed from §4 of the old list):
   subscribe to the Bound Year, change address, force an earned season,
   upload both PDFs, submit, retry, confirm exactly one Lulu job. Also verify a
   stopped membership still receives a season it fully earned.
4. **Production cutover** on the main Worker, all together:
   - `LULU_API_BASE_URL = "https://api.lulu.com"`,
     `LULU_AUTH_URL = "https://api.lulu.com/auth/realms/glasstree/protocol/openid-connect/token"`
     and production `LULU_CLIENT_KEY` / `LULU_CLIENT_SECRET`.
   - `CHECKOUT_MODE = "live"`, live `STRIPE_SECRET_KEY`.
   - New live webhook endpoint (`/stripe/webhook`, the three
     `payment_intent.*` events) and its `STRIPE_WEBHOOK_SECRET`.
   - Live Bound Year prices (verified 2026-10-04, product `prod_VNlSYl6tXvpa0B`):
     monthly `price_1UMzw0E80ArNx7J9NAQFMsiZ` ($24.99),
     annual `price_1UMzvqE80ArNx7J98TFV09ZW` ($279). Drop the test legacy price.
   - **Stripe Tax**: registrations in the Stripe dashboard, then
     `STRIPE_TAX_ENABLED = "true"`. Production readiness requires it.
   - `MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY` (≥32 chars) for non-US parcels.
   - **Payout gate** (no parcel reaches Lulu before its money is in the bank):
     the live Stripe account's payouts must be **automatic**, and the live key
     needs **Payouts: read** and **Balance: read**. After the first cron, KV
     `payouts/last-scan` must read `ok: true` (test verified 2026-10-11).
   - `/health` → `productionReady: true`.
   - `BOUND_YEAR_LIVE_SALES_ENABLED = "true"` only after step 3 passed.
5. Hand back the **live publishable key** (`pk_live_…`), the **staging Worker
   URL**, and the production URL if it moves to a custom domain
   (e.g. `books.reenchanted.app`, which also takes the account handle out of
   the app binary).

## D. App cutover (Claude, once C.5 lands)

- Debug: `PHYSICAL_BOOK_ENDPOINT` → staging URL.
- Release: `PHYSICAL_BOOK_CHECKOUT_MODE = live`, `STRIPE_PUBLISHABLE_KEY = pk_live_…`,
  endpoint → production.
- One real low-cost order from a Release build on Rabbit, refunded after
  Lulu accepts it. It waits for its payout first (about two business days;
  a new live account's first payouts take 7–14 days). Do not refund before
  Lulu accepts it, or the proof never reaches the press.

## E. Apple Pay (optional, after the fee)

1. Merchant identifier, e.g. `merchant.com.openclaw.enchantify`.
2. Apple Pay capability on the app target.
3. Stripe → Settings → Payments → Apple Pay: register it; Stripe issues the cert.
4. Info.plist: `ApplePayMerchantIdentifier` and `ApplePayMerchantCountryCode = US`.
   `PaymentSheet` picks it up; nothing else changes.

## Still a decision

The Bound Year can be cancelled in-app, but there is no Stripe customer portal,
so a member who deletes the app has no self-serve route. Build the portal or
handle it by email at hello@reenchanted.app.

## Already done

| | |
|---|---|
| Monetization | Free app, free monthly stories; printed books + Bound Year via Stripe (physical goods, no IAP) |
| Public Margins | Closed for launch (`PublicMarginsAPI.isAvailable = false`) |
| Privacy | `PrivacyInfo.xcprivacy`, inventory and public policy updated 2026-10-11 |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` |
| Worker | Deployed: memberships, options, orders, webhooks, monthly shelf |
| Live Stripe prices | Created and verified 2026-10-04 |
| Payout gate | Every parcel waits until its money is paid out to the bank (35fabf9f, deployed in test 2026-10-11; R2 print files 31 days) |
