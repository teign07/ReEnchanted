# Subscriber-only monthly delivery

Implemented locally, 6 September 2026. This extends the existing physical-book Worker; it does not introduce an account system, duplicate billing, or another deployed service.

## Request flow

1. The app obtains the existing installation-bound print-desk session.
2. `POST /monthly-issues/session` exchanges that session plus `{ signedTransactions: [JWS], membershipID?: string }` for a token valid for at most ten minutes, capped by paid-through expiry. Proofs are bounded to two signed transactions and 64 KiB total request bytes.
3. Apple proof uses the official `@apple/app-store-server-library`: verify the signed transaction and Apple certificate chain (online certificate checks enabled), ask the App Store Server API for current subscription status, verify the returned transaction, and require the same original transaction, expected bundle/product, active state, unexpired paid-through date, and no revocation/upgrade. The configured Apple environment is explicit; Sandbox access is disabled unless checkout mode is test. No unverified JWT decoding grants access.
4. Bound Year proof requires an installation ownership record plus a fresh Stripe subscription read. The configured Bound Year price, physical fulfillment metadata, active state, paid-through date, and live/test environment must agree. The latest invoice must be paid; a nonzero payment needs a succeeded PaymentIntent and a paid charge that is neither fully refunded nor disputed. A Stripe-confirmed zero-payment invoice is permitted. Other payment arrangements without that verifiable shape fail closed. The monthly read explicitly pins `Stripe-Version: 2024-06-20`, matching the [period fields](https://docs.stripe.com/api/subscriptions/object?api-version=2024-06-20) and [invoice payment field](https://docs.stripe.com/api/invoices/object?api-version=2024-06-20) it validates; it does not inherit the account's changing default. Checkout records ownership after creating the membership; a gift records the recipient installation at claim. Either provider may grant access while the other is unavailable.
5. `GET /monthly-issues/manifest` and `GET /monthly-issues/assets/ASSET_ID` require the short token and matching installation ID. Both responses are private/no-store. The HMAC token contains an installation hash, expiry, scope, and nonce; no email, payment details, or Book content. Its signing secret is separate from the publisher's Ed25519 key.
6. The Worker verifies the stored publisher envelope and serves only manifest-listed assets for current envelopes, the next issue, or published casebooks. Earlier per-asset retirement remains exclusive. The private bucket has no public download domain. The server caches verified inventory for at most 30 seconds; date gates are evaluated per request. Asset IDs are global immutable storage keys. Use a new ID for changed bytes.
7. The app sends credentials only to the exact configured HTTPS origin and refuses redirects. Token renewal during an install uses the same transaction. Explicit 401/403 denial clears temporary managed content and the cached envelope. Network failures and transient service errors may use the verified cached envelope and installed bytes. A bad signature, a missing route, and a redirect do not qualify as offline fallback. Kept Pages and retained artwork are outside this cleanup.

Revocation can take up to the remainder of the ten-minute token lifetime to affect downloads. No tokens or transaction proofs are persisted by the client. Apple verification happens during delivery refresh, not on a UI timer or per media file. The existing foreground entitlement reconciliation remains responsible for the local Reader experience.

The proof exchange uses the existing rate limiter. Individual authorized files do not use the print desk's 12-request/minute limit, which would prevent an atomic pack containing more than twelve files from ever installing.

## Configuration before staging

Use the existing Worker origin. The app's print endpoint and monthly endpoint must have the same origin. Set:

- App `MonthlyIssueManifestURL`: `https://WORKER-ORIGIN/monthly-issues/manifest` (no query or fragment).
- App `MonthlyIssueManifestPublicKey` and Worker `MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY`: the publisher Ed25519 public key, raw 32 bytes encoded as base64.
- Worker secret `MONTHLY_ISSUE_SESSION_SECRET`: an independently generated random secret of at least 32 characters.
- Worker private R2 binding `MONTHLY_ISSUE_FILES`. Store `manifest.envelope.json` and `assets/ASSET_ID`. Do not enable public R2 access. This binding is intentionally not pointed at a guessed production bucket in wrangler.toml.
- `MONTHLY_APPLE_ENVIRONMENT`: `Sandbox` or `Production`.
- Apple credentials: `MONTHLY_APPLE_PRIVATE_KEY` (App Store Server API P8 text), `MONTHLY_APPLE_KEY_ID`, `MONTHLY_APPLE_ISSUER_ID`, and `MONTHLY_APPLE_APP_ID` (required in Production).
- `MONTHLY_APPLE_ROOT_CERTIFICATES`: JSON array of base64 DER Apple root certificates obtained from Apple's certificate authority. These are public trust anchors, not credentials. Never accept trust anchors from a request.
- Existing Stripe Bound Year price IDs and secret remain independent. Test and live environments must use their matching billing keys and products.

No production values, credentials, R2 binding, or content were published in this pass. Absent configuration fails closed. Worker Node compatibility is enabled for Apple's verifier. See [Apple's library](https://github.com/apple/app-store-server-library-node) and [Cloudflare's Node compatibility reference](https://developers.cloudflare.com/workers/runtime-apis/nodejs/).

Prepare each release with the [offline publishing workflow](../monthly-issue-delivery-contract.md#prepare-a-monthly-release). It derives private routes and checksums, stages exact files, exports recording inventory, and reports new versus reused uploads. Upload assets first and the signed manifest last. Monthly content updates do not require an app download; new runtime capabilities still require an app release.

## Membership ownership and restore

There are no older Bound Year ownership records to migrate (confirmed 6 September 2026). New checkout and gift claim establish ownership through the existing installation identity. Do not add a self-service endpoint that records an arbitrary supplied membership ID as owned. Device changes for Bound Year require verified transfer/recovery; the current app has no account-based identity service. Apple subscriptions continue to use Apple's purchase restoration and signed transaction proof on each installation.

The existing physical checkout's installation identity is stored in Keychain. This change reuses that identity rather than creating a second identifier. Gift claim records the recipient, not the purchaser, as the monthly recipient. Ownership records hold no Reader prose.

## Validation

- `npm run test:monthly`: token/authentication, provider policy, invalid Apple proof, current status, private storage, retirement, HTTP exchange, and proof-size regressions. Provider policy tests use controlled Apple/Stripe responses; a real library test rejects unsigned transaction input.
- `npm run test:memberships` and `npm run test:gifts`: existing checkout/dispatch and gift regressions.
- `wrangler deploy --dry-run --outdir /private/tmp/reenchanted-monthly-worker`: bundle only, no deployment.
- `npm run test:monthly-runtime`: isolated local workerd probe with no production bindings. The actual Apple library loads inside a request and rejects unsigned input. Its import must stay inside the handler: a transitive dependency initializes randomness and cannot run at global scope in workerd.
- `npm run test:monthly-delivery`: offline publisher through signed inventory, real local workerd/R2/KV, seventeen byte-identical downloads, ownership denial, token expiry/renewal, and media/issue retirement. Provider responses are fixtures; the separate test entry point is never part of the deployed Worker.
- Swift monthly suite covers same-origin credentials and fallback policy as well as the monthly runtime. App build checks the StoreKit and transport wiring.

Still required before launch: real Apple Sandbox purchase/restore/refund, Stripe test subscription and recipient ownership, configured private R2 download, offline return, and device Reader/media/literary rehearsal. A mocked API response is not proof of live billing authority.

Apple enrollment is currently deferred. Continue with the [account-free rehearsal setup](../../Testing/MonthlyContent/README.md), including the separate Xcode local-purchase scheme. Xcode-local transactions do not carry the Apple server authority required by the hosted endpoint; do not accept them as a substitute for real subscriber proof.
