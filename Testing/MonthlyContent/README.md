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
Xcode saved the configuration in its current version 5 format during the
rehearsal; product IDs, prices, and periods remain the same.

1. Open `EnchantifyInsideCover.xcodeproj` in Xcode, select the local-purchases
   scheme and an iOS simulator. Under Edit Scheme → Run → Options, verify
   `MonthlySubscriptions.storekit` is selected.
2. Run from Xcode and open the Bookshop. Test each plan, cancellation of the
   purchase sheet, then Restore. Record the visible outcome separately from
   entitlement state.
3. In Xcode's StoreKit transaction manager, explicitly select the simulator's
   `InsideCoverApp` entry before changing transactions. Test refund and Restore.
   To test expiration, temporarily set Configuration Settings → Subscription
   Renewal Rate to `Any Renewal Every 30 Seconds`, then create a new monthly
   purchase with `Don't Renew`. Existing transactions retain their original
   expiration dates. Leave the Standing Order page open and observe access close;
   restore `Real Time` afterward. Separately verify content eligibility reconciles
   and kept Pages survive. Local purchases must not be accepted as Apple server proof.
4. Test the offline fixture/installer with the native rehearsal suite separately;
   the real delivery endpoint will reject Xcode-local proof. No server bypass
   was added to make a fake purchase appear paid.

Executed on 6 September 2026 using Xcode's dedicated scheme and the iPhone 17 Pro
simulator (iOS 26.5):

- The app built and launched. Xcode recognized both products and the selected
  StoreKit configuration.
- The monthly purchase showed the Xcode no-charge confirmation and succeeded.
  The app changed from “Not open” to “Open and standing through Apple.”
- “Change or stop” opened Apple's `Edit Subscription [Xcode]` sheet. Switching
  to annual produced a successful test purchase and selected the annual plan.
- Canceling annual renewal succeeded. Current app access remained open, as
  expected for cancellation before the paid-through date.
- Refunding the annual test transaction closed access. Restore reported no prior
  bindings and did not reopen it.
- Creating another active monthly test transaction and invoking Restore reported
  “1 binding restored”; the Standing Order page showed active Apple access.
- A new monthly transaction with a 30-second duration and `Don't Renew` expired
  in the transaction manager. With the app's Standing Order page left open, its
  state changed to “Not open” without navigation, relaunch, or a Restore tap.
  Restore afterward reported no prior bindings and did not reopen access.
- A second simulator build and launch included the corrected seasonal-access
  copy, verified in the Bookshop and Standing Order page. The configuration was
  returned to `Real Time`; no active test subscription remains. Rabbit was not
  used for purchases or transaction changes.

These observations establish the local purchase and entitlement UI; they do not
establish downloaded-content removal or kept-Page retention through the UI.
A prior standalone StoreKitTest command and an ad-hoc macOS test app failed before product
loading (`SKInternalErrorDomain Code=3` in the app-host attempt). That utility was
removed. Launching the actual iOS app from Xcode resolved the local product and
purchase path; no billing or verification bypass was added.

## Isolated Reader and media rehearsal

Use a separate Simulator Book: Keep and Trash are real saved actions. The
`--smoke-monthly-content` entry point is compiled only for Debug simulators. It
requires an actual current local StoreKit entitlement, verifies a signed fixture,
and installs through `MonthlyIssueAssetInstaller`. It does not bypass the hosted
server's Apple checks or ship a test key/content in app resources.

1. Prepare local input from the repository root:
   `node Testing/MonthlyContent/prepare-reader-rehearsal.mjs /private/tmp/monthly-reader-input`.
   The script rebases Issue Zero so today falls in BUILDUP, signs four assets
   with an ephemeral key, and copies an existing goblin illustration and Fae-Fi
   recording into file-backed media. It uploads nothing. Run it once per fresh
   rehearsal; rerunning moves the test calendar and creates a new signing key.
2. Install the app in a fresh simulator and copy that input directory to its
   Documents directory as `MonthlyRehearsal`. Purchase a no-charge monthly plan
   using the local-purchases scheme. Use `simctl get_app_container` after each
   Xcode install to locate the current container; its UUID can change.
3. In Edit Scheme → Run → Arguments, add `--smoke-monthly-content lesson`.
   Launch from Xcode. The entry point opens the next eligible lesson node using
   the saved ledger and normal Page controls. Keep the entry, choose a branch,
   and keep its return. Relaunching must resume rather than reset the scene.
4. After lesson completion, use `--smoke-monthly-content radio-hinge` for the
   caption-only bulletin or `--smoke-monthly-content radio-recorded` for the
   recorded fixture. These select an eligible break through the actual Radio
   player and receipt path; they do not manufacture completion or play receipts.
   Use `--smoke-monthly-content loose-leaf` for a separate disposable scene.
   Let its sheet wait, turn to it in the folio, and Trash it. Relaunch with the
   same argument to check that the saved dismissal prevents another offer.
   Use `--smoke-monthly-content reading-leaf` to verify direct folio Keep with
   an empty optional margin on a scene with no choice or response requirement.
5. Remove or disable the launch argument when finished. Refund the local test
   subscription to exercise managed-file cleanup and check the retained Page.
   Retirement dates and Keep/Trash are separate cases; do not treat an access-loss
   test as proof of a calendar transition.

Validate the prepared input without launching the UI:

```sh
REENCHANTED_SIMULATOR_FIXTURE_DIR=/private/tmp/monthly-reader-input \
  swift test --jobs 2 --filter MonthlyIssueRehearsalTests
```

The optional prepared-fixture test is skipped when that variable is absent.
All 17 rehearsal tests passed with it set, and the broader monthly/Radio/page
regression run passed 406 tests with zero failures. Simulator builds, installation,
and launch passed. The actual UI kept `enter`, previewed `pin` without committing
it, then kept `choose → pin-home` and completed the supervised jump. The return
scene showed its inline Keep button. Relaunch resumed the saved node instead of
replaying the entry. Radio recorded `played` for the file-backed recording and
`delivered` for the caption-only bulletin; this is playback-path evidence, not an
auditory quality review of the recording.

Reinstalling the app exposed a real stale-container-path bug in retained art.
Monthly media now resolves its two managed storage directories into the current
sandbox when read. The test Book's original kept goblin survived the reinstall,
and its archived media reference resolved to an existing file after the fix.
Automated tests also move the container, remove the downloaded source, and read
the retained copy. They retain access and existence checks for Radio. No archive
scan or extra download is added to page turns. The folio rehearsal build also
passed; its launch hook keeps eligible test leaves reachable while launch
curation refreshes the regular desk.

The 7 September final UI checks passed: Trash saved `dismissed`, and relaunch
refused to offer that scene again. A reading-only leaf showed an optional margin
and enabled Keep without input; Keep preserved its authored prose with an empty
Reader reply. Refunding the local monthly purchase while the app ran cleared all
four managed downloads and the installation ledger, while the kept pages and
the SHA-256-verified retained goblin survived. The rehearsal argument is disabled
and the test subscription is refunded. Calendar retirement is separately covered
by the automated tests; the refund proves access-loss cleanup.

## Remaining external checks

- Apple enrollment/App Store Connect products, Sandbox purchases, restore,
  refunds, and online certificate/current-subscription verification.
- Hosted private storage and configured signing keys, plus real Stripe test-mode
  ownership/payment checks. These need service configuration, not an Apple fee.
- Final authored media presentation, timed caption visibility, actual model prose
  around frozen monthly passages, and bound-page visual/physical proof. The local
  simulator operator checks above do not establish real Reader response or
  production-device performance.
