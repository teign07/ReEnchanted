# Monthly content verification — 5 September 2026

The reusable local monthly runtime now has executed test and app-build evidence. The 6 September follow-up adds the subscriber delivery implementation and tests described below. This is not a release approval: production configuration/live-provider validation remain, and The Count Unbound has not been installed or enabled.

## Executed checks

- `swift test --jobs 2 --filter 'MonthlyIssue|AuthoredContentTests|BraidScenePlanTests'` compiled the shared runtime and tests. The initial 114-test run found two failures: the rehearsal fixture lacked production-count coverage requirements, so both release validation and signed installation correctly rejected it.
- Corrected the fixture's four declared production counts and regenerated its delivery hash/size. Extended the Python preflight to detect missing coverage and count matching ready atoms.
- `swift test --skip-build --filter 'MonthlyIssue|AuthoredContentTests|BraidScenePlanTests|WorldSystemsTests|RadioBanterTests|StandingOrderTierTests'`: **400 tests passed**, zero failures. This includes the corrected native fixture and installer.
- Added an actual file-retention regression: keep downloaded PNG bytes, keep the same mark twice, retire the managed source, decode the archived mark, and read the surviving bytes. It also rejects a source outside the managed directory. `swift test --jobs 2 --filter MonthlyIssueRehearsalTests`: **12 tests passed**, zero failures. Eleven overlap the previous run; there are **401 distinct tested cases** across the two successful runs.
- `python3 -m unittest discover -s scripts/tests -p 'test_monthly_pack.py'`: **12 tests passed**.
- `xcodebuild -project EnchantifyInsideCover.xcodeproj -scheme InsideCoverApp -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/reenchanted-monthly-derived -jobs 2 COMPILER_INDEX_STORE_ENABLE=NO CODE_SIGNING_ALLOWED=NO build`: **BUILD SUCCEEDED**. The generated app has the expected `com.openclaw.enchantify.insidecover` identifier, an executable, and both Share and Widget extensions. Existing compiler warnings remain. This was an unsigned build, not a device installation or launch.

Local logs: `/private/tmp/reenchanted-monthly-tests.log`, `/private/tmp/reenchanted-monthly-retention-tests.log`, `/private/tmp/reenchanted-monthly-build.log`. These temporary files may later be removed by the system.

## Synthetic Reader observations

The persona test wrote six reports under `/private/tmp/reenchanted-monthly-rehearsal`, each with 90 clock samples:

| Persona | Committed lesson nodes | Story-night pages |
| --- | --- | --- |
| Pin | enter → choose → pin-home | 5 |
| Thread | enter → choose → thread-home | 5 |
| Exit during lapse | enter only; unfinished episode dismissed | 5 |
| Late | none; public report only | 2 |
| Trash | none | 4 |
| Absent | none; no delivered receipts | 0 |

These are generated test observations, not Reader activity. They exercise the native Page compositor, commit method, scoped ledgers, and deterministic authored braid compositor; they do not run the UI or a language model.

## What remains besides authored content

1. **Staging and live-provider validation.** The [subscriber endpoint and client wiring](physical-book-backend/MONTHLY-ISSUES.md) are now implemented locally. Production URL/key, Apple credentials, token secret, and private R2 binding remain unset. Real Apple Sandbox purchase/restore/refund and Stripe test payment/ownership must be exercised before deployment. No older Bound Year ownership records need migration, as confirmed by the owner on 6 September; arbitrary membership IDs still cannot claim themselves.
2. **Device and literary rehearsal.** Exercise open/Keep/Trash/return, subscription change while a page is open, missing audio, real downloaded-image rendering, and actual model prose around a frozen monthly passage. The tests establish composition mechanics, not literary quality or device performance.
3. **Recording and bound-page proof.** Real Radio recordings, downloaded marginalia, and rendered physical/export Pages need their final media and visual checks.

Once distribution and the Reader rehearsal are complete, a new month should be a pack authoring/validation/media-production task rather than another runtime implementation project.

## Subscriber delivery follow-up — 6 September

- **403 focused Swift tests passed**, including exact HTTPS origin and explicit-denial versus offline-fallback policy.
- **15 monthly backend tests passed**: token tampering, installation binding, expiry, current Apple status, invalid proofs, independent providers/outages, Stripe ownership/payment/refund/dispute state, private shelf access, signed inventory, retirement, and the HTTP proof exchange. Apple/Stripe response policy uses mocks; unsigned-proof rejection also runs Apple's actual verifier.
- Existing membership/dispatch and gift test scripts passed.
- **iOS Debug build succeeded** after client authentication and token-renewal wiring; unsigned, no install/launch.
- Worker dry-run bundling passed. Actual workerd startup initially exposed a dependency attempting global-scope randomness. Moving Apple's library import inside the authorization request fixed it. An isolated `npm run test:monthly-runtime` probe loaded the actual verifier in workerd and rejected unsigned proof. The full local Worker also started and returned **401** for anonymous monthly manifest access. The temporary local server was stopped.
- No production endpoint, bucket, secret, or content was published. Workerd initialization tests do not establish Apple online certificate checks or actual billing integration.

Logs: `/private/tmp/reenchanted-monthly-auth-tests.log`, `/private/tmp/reenchanted-monthly-auth-build.log`, `/private/tmp/reenchanted-monthly-backend-tests.log`, `/private/tmp/reenchanted-monthly-workerd-test.log`.

## Publisher preparation follow-up — 6 September

- Added `scripts/prepare_monthly_release.py`: stages exact files, computes hashes/sizes/private routes, rejects overwriting an immutable asset ID with changed bytes, exports production inventory, and reports new/reused uploads and removed inventory. Preparation is offline and leaves no release directory on validation failure.
- `python3 -m unittest discover -s scripts/tests -p 'test_*monthly*.py'`: **24 tests passed** (12 existing authoring checks and 12 publisher checks). Includes unchanged release reuse, changed-ID enforcement, safe paths, source symlinks, lifecycle overlap, media retirement dependencies, invalid origins, draft content, and an empty shelf retirement manifest.
- Executed the new CLI against Issue Zero, then signed its prepared manifest with the existing Swift signer and a temporary test key. The actual Worker verifier accepted the envelope with local storage and a test session token, returned byte-identical manifest and asset bodies, and returned **404** for the asset at residue expiry. This verifies the tool/signature/server handoff, not hosted R2 or billing.
- `git diff --check` passed. No app source changed in this follow-up, so the app was not rebuilt or installed. No production keys were generated and no content was uploaded or deleted.
- There are no older Bound Year ownership records requiring migration. Removed that obsolete launch requirement; ownership enforcement for newly created memberships remains.

Temporary rehearsal artifacts: `/private/tmp/monthly-publisher-rehearsal-zgw2ffed/release`. They use `rehearsal.invalid`, a test key, and the fictional November 2027 fixture. They are not a publishable issue.

## Account-free verification follow-up — 6 September

Apple enrollment and real Apple billing checks are deferred at the owner's request.
This does not defer local content or private delivery testing.

- Re-ran the focused Swift suite: **403 tests passed**, including fixture installation/offline retirement, retained art, receipt persistence, terminal Keep/Trash, and braids.
- Extended backend coverage: **16 tests passed**, now including seventeen sequential downloads through the production Worker's actual HTTP routing while the checkout rate limiter would deny every call. File serving correctly avoids that limiter but still rejects anonymous access.
- New `npm run test:monthly-delivery` passed using the publisher CLI and isolated workerd with local R2/KV. It exercised 17 exact downloads, ownership/lapse denial, token expiry/renewal, early media expiry, and final retirement. No hosted services, billing calls, or uploads were used.
- Publisher/authoring tests: **24 passed**. Project plist validation and `git diff --check` passed.
- Added `Testing/MonthlyContent/MonthlySubscriptions.storekit`, recognized by Xcode's actual configuration editor with both plans. Added a dedicated local-purchase Debug scheme and an explicit ordinary shared scheme so adding a shared test scheme does not hide the previously auto-generated `InsideCoverApp` scheme. Confirmed the local scheme's StoreKit Run option in Xcode. The ordinary scheme has no StoreKit override.
- A standalone local StoreKitTest experiment failed before products loaded (`SKInternalErrorDomain Code=3` in the app-host attempt). Removed that experimental utility; no simulated purchase is counted as verified by that attempt. The Xcode app rehearsal is recorded separately when completed.

Logs: `/private/tmp/monthly-no-account-swift.log`, `/private/tmp/monthly-no-account-backend.log`. Repeatable commands and remaining external checks are in [the local rehearsal guide](../Testing/MonthlyContent/README.md).
