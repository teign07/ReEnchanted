# Bound Year recovery on another device

Status: missing implementation; live-sales blocker. September 10, 2026.

The current Stripe membership is bound to the print desk installation identity.
`PhysicalBookInstallationIdentity` stores this in a device-only Keychain item.
The app's store restore action does not recover Stripe ownership. Copying the
Book's saved membership ID onto another installation cannot restore access.
An existing device retaining its identity is a different case from a new device.

## Required reader flow

Use the existing membership owner mapping and checkout client session. Add a
Bindery recovery action, without requiring a new subscription or another payment.
Recovery should verify control of the billing contact through a short-lived,
one-use link sent to the contact already recorded by Stripe. Never accept a
client-provided destination as the proof or reveal whether an entered email has
an account. Provide a support path when the original contact is unavailable.
Gift recipients require a separate verified recipient path: the purchaser's
billing email must not reclaim a membership already given away.

## Required implementation boundaries

- Resolve ownership and the authoritative recovery contact server-side. Keep
  membership IDs, email strings, copied saves and payment amounts insufficient
  as proof. Do not expose contact information to an unverified installation.
- Hash recovery secrets at rest; bind each challenge to one membership and
  destination installation, expiry and generation. Rate-limit requests and
  attempts. Keep links and credentials out of logs and normal status responses.
- Serialize issuance, redemption and ownership transfer through a Durable Object.
  KV alone cannot make one-use redemption and concurrent transfers atomic.
  Route access checks through the authoritative ownership result; explicitly
  handle KV propagation and crash recovery before enabling transfers.
- Preserve earned physical parcels, dispatch history, holds and printer receipts.
  Transferring ownership must never create a replacement print order or grant
  access to a refunded subscription. Re-read Stripe payment state for access.
- Invalidate the former device's future access and document the maximum remaining
  lifetime of already issued sessions. Keep replay and concurrent redemption
  idempotent for the winning destination and rejected for other destinations.
- Return the existing membership to the app, persist it before clearing pending
  recovery state, and reconcile entitlements through the existing helper.

## Acceptance evidence needed

Successful paid recovery on a new installation; old-owner denial; simultaneous
redemption; expired/replayed/wrong-installation links; refunded and canceled
memberships; gifted membership protections; provider and storage outages; crash
between transfer and app persistence; and unchanged historical parcel receipts.
Actual delivery of recovery mail needs an authorized transactional mail provider
and configured sender. No recovery emails were sent during the September 10 audit.

## Current deployed boundary rehearsal

`rehearse-membership-ownership.mjs PRIVATE_FIXTURE_FILE paid|refunded` checks the
original owner, a fresh installation, then the original owner again. The private
fixture contains only `installation` and `membership.membershipID` and must have
owner-only permissions. The command checks test mode before creating sessions;
it never changes billing, ownership or fulfillment and prints no credentials.
This is denial/ownership-preservation evidence, not successful recovery evidence.

## Staged serialized ownership foundation

`membership-ownership.mjs` now implements internal read/register operations in
`PhysicalBookOrderCoordinator`, serialized through its ownership queue. It
migrates an existing KV owner to coordinator storage without changing legacy KV,
rejects reassignment, and preserves the owner across restart and stale KV reads.
Storage failures fail closed. No transfer action or public endpoint exists.

The operation is now used by all public owner reads and registrations through
`membership-owner:<subscription ID>`, including gifted claims, membership
management and monthly session issuance. Legacy KV is consulted only during
migration, with no legacy authorization fallback when the coordinator fails.
No transfer endpoint exists yet. Recovery proof delivery and app UI remain
unbuilt; deployment of this foundation does not make recovery available.

Deployed September 10 as `4705fcbd-b8af-468a-8cd8-149c0dc8f93c` in test mode.
Existing paid gift-recipient ownership migrated and retained access; a fresh
installation was denied. Existing refunded ownership migrated and retained
membership-status access while monthly content stayed denied. Original owners
were rechecked after the foreign requests. No payment or parcel was changed.

Seven coordinator tests cover concurrency, restart, migration, storage failures,
legacy outages, malformed records and preservation of printer receipts. These
plus the existing checkout and monthly-access tests passed (48 total).

After wiring: 69 focused tests passed, plus the membership, gift and dispatch suites.

## Disabled internal proof lifecycle

Internal `prepare-recovery` and `redeem-recovery` operations are implemented,
but require `MEMBERSHIP_RECOVERY_ENABLED=true` in the coordinator environment.
That flag is not configured; these changes are not deployed. There are no public
routes. Do not enable the flag before trusted issuance and delivery are complete.

A challenge holds only a secret hash, destination installation, owner generation
and expiry (at most 15 minutes). Issuance replaces an earlier challenge. Redemption
changes the owner, increments generation and marks the challenge consumed in one
durable record write. Same-destination retries remain idempotent until expiry;
old proofs cannot reclaim a later ownership generation. No billing or parcel
records are modified. Existing monthly tokens retain their bounded lifetime.

This is a proof lifecycle primitive, not proof that a Reader controls an email.
The future trusted issuer must generate a cryptographically random secret,
store its hash via the internal operation, deliver the secret only to an
independently verified authoritative contact, and hash the presented secret at
the public redemption boundary. Never accept a public challenge hash as authority
to prepare recovery. Rate limiting, generic request responses, bounded input,
contact-change handling and app persistence are still required.

Gift-index presence rejects both issuance and redemption. The current KV gift
index is not sufficient as the sole future eligibility check: trusted issuance
must also verify authoritative gift provenance and prevent races with gift
claiming before transfers are enabled. Gift recipients need a distinct verified
recovery route. The configured alert-only email binding does not deliver Reader
recovery links. No mail was sent and no sender/provider was provisioned.

Seven additional tests cover disabled gating, concurrent/lost-response redemption,
wrong/expired/replaced proofs, failed transfer persistence, gifted memberships,
later ownership changes and lifetime bounds. All 56 focused ownership, monthly
access and checkout tests passed.

## Disabled public redemption boundary

`POST /memberships/recovery/redeem` (also under `/api/physical-books`) is now
implemented but disabled and undeployed. It requires an authenticated print-desk
session, the recovery rate limit, and a body of at most 2 KiB containing only
`membershipID` and `secret`. The installation comes from the authenticated
request, never from the body. The endpoint hashes the canonical 32-byte secret
before forwarding to the coordinator, returning only membership ID and recovery
confirmation with private/no-store caching. It grants no payment entitlement.

`createRecoveryChallenge` uses 32 cryptographically random bytes and a 15-minute
expiry. Its raw secret is intended only for a future trusted delivery adapter;
there is no public preparation or issuance endpoint. A caller-supplied hash
cannot request issuance. Verified-contact lookup, gift provenance checks and
mail delivery are still missing. Do not enable the recovery flag yet.

Local HTTP tests exercise unauthenticated rejection, wrong-device rejection,
success, retry, request limits, strict fields, disabled default and absence of
raw secrets in durable storage. All 59 focused recovery/ownership/monthly/checkout
tests passed. This does not establish real email delivery or app recovery.

## Gmail delivery adapter (disabled, not wired)

The user selected `snow.potions@gmail.com` as sender and `help@reenchanted.app`
as reply address. Cloudflare's active catch-all routes incoming help mail to that
Gmail account. Its outgoing Email Sending dashboard requires a paid upgrade;
none was purchased. The Codex Gmail connector is not backend authorization.

`gmail-recovery-delivery.mjs` uses Gmail's HTTPS send API, pinned to the specified
mailbox, with OAuth refresh credentials. It constructs a fixed plain-text MIME
message containing a pasteable recovery code. There is no link until a verified
app/link handler exists. Sender and reply address cannot be supplied by callers.
The trusted issuer must supply the verified recipient; this is not a public
mail-sending API. It is not yet imported into issuance and is not deployed.

Required protected Worker secrets: `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`,
`GMAIL_REFRESH_TOKEN`. Provision a dedicated Google OAuth client with the Gmail
API enabled and authorize the sender for `https://www.googleapis.com/auth/gmail.send`
with offline access. Keep the refresh token and client secret out of source,
chat, logs and app bundles. Confirm Google's consent/publication requirements
and token lifetime during provisioning; a testing-mode token is not a reliable
production credential. No credential has been obtained or installed yet.

`GMAIL_RECOVERY_DELIVERY_ENABLED=true` is a separate gate, currently absent.
Keep it and membership recovery disabled until trusted recipient verification,
issuer rate limits, gift protection and persistence of delivery outcomes are
wired. A timeout, server failure or malformed successful send response is
uncertain, not permission to send again automatically. Gmail acceptance is not
proof of inbox delivery. The issuer must retain that distinction.

The adapter caches short-lived access tokens and shares concurrent refreshes
within one instance. No credential or message body is included in returned
errors. Nine delivery tests plus ownership/recovery tests passed (26 total),
using only mocked HTTP; no messages were sent or credentials used.

API reference: https://developers.google.com/workspace/gmail/api/guides/sending
