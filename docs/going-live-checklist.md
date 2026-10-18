# Going live — the checklist

Last updated: 2026-10-14. Goal: testers on TestFlight, and any tester who wants
paper can pay real money for it.

## Recommended rollout order — October 14

1. **Individual Apple enrollment now.** The project decisions and saved moving
   copy are ready. Complete Apple's verification and membership purchase, then
   wait for active membership.
2. **Internal TestFlight first.** Apply the prepared app identity under the paid
   team, verify the Book migration, complete signing and App Store Connect
   metadata, and produce/upload the first beta when bj requests the build.
   Keep its physical checkout in test mode against a matching test backend.
   TestFlight distribution does not itself require live Stripe/Lulu checkout.
3. **A small external reader cohort after the core walkthrough.** Check fresh
   onboarding, model download and skipped download, writing/Keep/rereading,
   the delivered monthly story, backup, and supported-device behavior. Complete
   Beta App Review. Before reader invitations, ensure paper purchasing is
   clearly unavailable until it is ready; never present a test checkout as a
   real sale. Any promised printed thank-you needs approved terms, funding,
   timing and a physical proof of the offered edition.
4. **Prepare printing alongside beta testing.** Finish the staging Worker and
   complete sandbox fulfillment/retry/cancellation rehearsal, deployed printing
   cash protection, current quotes and physical proof. Preserve the rule that
   customer-funded printing waits for confirmed deposited cash and a reserved
   complete printer bill. Complimentary books have no customer payment, so
   they require their own approved funding source.
5. **Open US paper sales after those gates pass.** Obtain bj's explicit live
   activation approval, configure live providers and the app together, and
   verify a genuine paid/fulfilled order. Enrollment or a working beta is not
   payment or print-quality proof.

October's signed content publication is already recorded as shipped and
verified on October 3. Check its delivery in the first beta; it does not need
another first publication. Future monthly content can continue through the
existing publishing process independently of payment activation.

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

## A. Enrollment readiness (bj)

Project decisions are ready for individual enrollment as of October 13.
Device walkthroughs, TestFlight review, and physical-print proof remain release
gates; they do not need to be finished before starting Apple enrollment.

1. **Individual enrollment — decided by bj, October 13.** Start as an
   individual to keep setup cheap and easy. Forming an LLC and enrolling as an
   organization are deferred; revisit later if useful. The seller name on the
   App Store is public. EU storefront availability remains a separate decision;
   trader distribution requires published contact details (address, phone, email).
2. **App identity — prepared.** The `rename/app-reenchanted-book` branch
   prepares `app.reenchanted.book`, extensions `.widgets` and `.share`, and
   App Group `group.app.reenchanted.book`. The current checkout still uses
   `com.openclaw.enchantify.insidecover`. Apply the rename only after the paid
   membership is active, preserving the concurrent working-tree changes.
3. **Account prerequisites.** Use an Apple Account with two-factor
   authentication and the owner's legal name; Apple verifies contact and
   identity information before the membership purchase. Individual enrollment
   displays the owner's legal name as the seller. See
   [Apple's enrollment requirements](https://developer.apple.com/programs/enroll/).

**Before installing the renamed app:** in the old app, Seal a copy (the
whole-Book `.aar`) and preserve it outside the app. Install the renamed app,
Open a sealed copy, and verify the Book after reopening. Keep the old app until
the new one shows everything. This migration is not a prerequisite for paying
the membership fee.

October 13: Rabbit's metadata export failure is fixed and verified on-device.
The [repair and verification](sealed-copy-container-metadata-20261013.md)
record a successful export, clean extraction, valid vault/preferences and a
saved archive outside the app. A verified copy is in ignored local
`output/book-backups/Rabbit-Book-2026-10-13-1557.aar`. Restoring it into the
renamed app still needs its own verification; keep the existing app meanwhile.

## B. Apple enrollment and first TestFlight

1. Enroll as an individual ($99/yr); complete Apple's verification and purchase.
   Wait for active membership before applying the prepared rename and setting
   up signing.
2. Register the three bundle IDs and the App Group; turn on HealthKit,
   App Groups, Increased Memory Limit for the app ID.
3. Create the App Store Connect record. Free Apps agreement only (no IAP).
4. Fill App Privacy from `docs/AppPrivacyInventory.md`; review notes and age
   rating from `docs/AppStoreReviewPacket.md`.
5. Once bj requests the build, archive a Release from a clean, merged `main`.
   Verify the app and both extensions under the paid team, install and exercise
   the renamed app with the migrated Book, then upload to internal TestFlight.
   Complete the fresh-install and core-reader smoke tests before inviting
   external testers (external testing needs Beta App Review). Device proof
   must cover the current source, including the latest ink timing; earlier
   device runs do not validate later edits.
   The first internal beta retains test payment settings. Release switches to
   live checkout only at the separately approved commerce cutover in §D.
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
     `payment_intent.*` events plus `payout.failed` and `payout.canceled`) and its
     `STRIPE_WEBHOOK_SECRET`.
   - Live Bound Year prices (verified 2026-10-04, product `prod_VNlSYl6tXvpa0B`):
     monthly `price_1UMzw0E80ArNx7J9NAQFMsiZ` ($24.99),
     annual `price_1UMzvqE80ArNx7J98TFV09ZW` ($279). Drop the test legacy price.
   - **Stripe Tax**: registrations in the Stripe dashboard, then
     `STRIPE_TAX_ENABLED = "true"`. Production readiness requires it.
   - `MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY` (≥32 chars) for non-US parcels.
   - **Printing cash gate**: deploy the bank-confirmation and reservation
     correction, then verify its authenticated `/admin/printing-cash` routes.
     Live payouts must be standard automatic USD bank payouts, and the live key
     needs **Payouts: read** and **Balance: read**, including expanded charge
     sources. Confirm an actually received bank deposit and protect only the
     proceeds available for printing after other obligations. Stripe `paid`,
     old KV marks and `payouts/last-scan` reporting `ok: true` do not authorize
     printing by themselves. Verify a fresh Lulu tax-inclusive quote is reserved
     before one job is created, concurrent parcels cannot reuse that cash, and
     a later failed payout blocks release. The correction has local synthetic
     regressions; deployed and real bank evidence remain owed. See the
     [cash gate procedure](physical-book-backend/README.md#authenticated-bank-confirmation).
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
  Lulu accepts it. It waits for a confirmed bank deposit and reserved printing
  cash first (payout arrival is usually about two business days;
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
