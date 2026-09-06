# Monthly content without a paid Apple account

The reusable content runtime, publisher, and local private delivery tests run
without Apple enrollment or real purchases. Apple's [local StoreKit testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)
also supports products defined in a local configuration instead of App Store
Connect. Local StoreKit transactions cannot prove a real Apple subscription to
the hosted server.

## Executable local checks

From the repository root:

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*monthly*.py'
swift test --jobs 2 --filter 'MonthlyIssue|AuthoredContentTests|BraidScenePlanTests|WorldSystemsTests|RadioBanterTests|StandingOrderTierTests'
```

From `docs/physical-book-backend`:

```bash
npm run test:monthly
npm run test:monthly-runtime
npm run test:monthly-delivery
```

The delivery rehearsal prepares Issue Zero through the publishing CLI, signs its
exact bytes with an ephemeral key, seeds isolated local R2/KV, and exercises the
actual monthly session and serving implementation inside workerd. It checks 17
byte-identical downloads, private response headers, anonymous/foreign ownership
denial, expired membership denial, token expiry/renewal, individual media expiry,
and end-of-issue retirement. Billing responses and the clock are fixtures. The
test-only Worker is a separate entry point with no production bindings. The
production Worker does not import its seed route, clock override, or fixtures.
Nothing is uploaded; the temporary server and files are cleaned up on completion.

## Local purchase UI rehearsal

`InsideCoverApp - Local Purchases` is a dedicated shared Debug scheme pointing
at `MonthlySubscriptions.storekit`. The ordinary app scheme and production
verification are unchanged. The configuration includes the actual monthly and
annual Standing Order IDs in one subscription group, using current fallback
prices of $9.99/month and $79.99/year. These are test prices, not App Store
Connect product configuration. Bound Year remains independent Stripe membership.

1. Open `EnchantifyInsideCover.xcodeproj` in Xcode, select the local-purchases
   scheme and an iOS simulator. Under Edit Scheme → Run → Options, verify
   `MonthlySubscriptions.storekit` is selected.
2. Run from Xcode and open the Bookshop. Test each plan, cancellation of the
   purchase sheet, then Restore. Record the visible outcome separately from
   entitlement state.
3. Use Xcode's StoreKit transaction manager to refund, expire, and renew the
   simulated subscription. Verify content eligibility reconciles and kept Pages
   survive. Local purchases must not be accepted as Apple server proof.
4. Test the offline fixture/installer with the native rehearsal suite separately;
   the real delivery endpoint will reject Xcode-local proof. No server bypass
   was added to make a fake purchase appear paid.

On this machine, a standalone StoreKitTest command and an ad-hoc macOS test app
both failed before product loading: `SKInternalErrorDomain Code=3` while saving
the configuration in the app-host attempt. This is **not a passed purchase test**.
The unsupported standalone utility was removed; use the dedicated Xcode scheme
for the remaining UI rehearsal. The local engine failure is separate from paid
Apple enrollment. Do not interpret the green mocked-provider tests as proof of
local StoreKit or sandbox purchase execution.

## Remaining external checks

- Apple enrollment/App Store Connect products, Sandbox purchases, restore,
  refunds, and online certificate/current-subscription verification.
- Hosted private storage and configured signing keys, plus real Stripe test-mode
  ownership/payment checks. These need service configuration, not an Apple fee.
- Device/Simulator Reader and media rehearsal, followed by actual authored media
  and bound-page proof. No real Reader observation or physical proof is claimed
  by the automated tests above.
