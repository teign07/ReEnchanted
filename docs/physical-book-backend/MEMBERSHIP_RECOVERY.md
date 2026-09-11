> Current checkpoint (September 11): recovery request, issuance, redemption and
> app restoration are wired in source. Both deployed recovery enable flags remain
> OFF. Local mocked integration tests pass; real enabled-Worker email delivery,
> Rabbit UI/relaunch checks and privacy-notice review are still required before
> enabling Reader recovery. Earlier sections below describe historical stages,
> including components that were unwired at the time. Tracking normalization and
> quote-independent tracking authorization are deployed separately.

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

## Gmail OAuth provisioned September 11

Created Google Cloud project ReEnchanted Mail (`total-biplane-508221-h0`),
configured its OAuth identity and dedicated web client, and added the sender
as a test user. Completed Google consent for only `gmail.send` under
`snow.potions@gmail.com`. A local callback validated state and used PKCE before
saving the refresh credential in owner-only local storage. The callback stopped
after success. Installed GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET and
GMAIL_REFRESH_TOKEN as Worker secrets; removed the temporary bulk-upload file.
No credential values belong in this document.

OAuth audience is still Testing. Resolve production consent configuration and
refresh-token longevity before treating this as an operational sender. Gmail API
activation was requested but its overview failed to load; a real delivery rehearsal
must still verify API enablement and mailbox delivery. Neither recovery nor Gmail
delivery enable flag was set. No email was sent during authorization/provisioning.
The Gmail adapter and public recovery changes remain undeployed and unwired.

## Actual Gmail delivery rehearsal September 11

Refreshed the protected OAuth credential and sent one explicitly authorized
plain-text test email from snow.potions@gmail.com to the same inbox, with
Reply-To help@reenchanted.app. Gmail returned HTTP 200 and message ID
`1a09012aeb8ae27b`. The Gmail UI independently showed the matching subject
“ReEnchanted sender rehearsal September 11” with the Inbox label and expected
body. This confirms Gmail API enablement and inbox arrival for this self-send.
It does not test the recovery adapter, deployed Worker sending, or a real code.
No recovery code, ownership change, payment or print job was involved.

Google Auth remains Testing. Branding currently has empty homepage, privacy
and terms links; Audience previously showed Publish app disabled pending
configuration. Testing refresh credentials expire seven days after consent:
https://developers.google.com/identity/protocols/oauth2
Complete accurate production branding/publication and reauthorize before using
this credential operationally. Neither mail nor recovery enable flag was set.

## OAuth publication and durable gift protection September 11

Current status supersedes the earlier Testing notes above. Saved the homepage,
privacy and terms URLs under reenchanted.app and its authorized domain. Google
Audience now explicitly shows **In production**, External, 1/100 OAuth users.
Google verification is not complete: the sender's authorization still presented
an unverified-app warning. Reauthorized the send-only grant after publication;
validated a refresh response with HTTP 200 and exactly gmail.send scope, and
confirmed Wrangler successfully uploaded the renewed GMAIL_REFRESH_TOKEN.
No additional email was sent. Neither recovery nor delivery was enabled.
The public privacy notice still needs review for the actual recovery flow before
Reader-facing delivery is enabled.

Source now records a permanent membership-gift marker in the same serialized
Durable Object as ownership. New bound-year gifts persist that marker before
publishing their gift record; existing gifts persist it before registering their
recipient. Marker write failures stop acknowledgment. Recovery preparation and
redemption reject marked gifts without depending on eventual KV propagation.
Discovering a legacy gift index also persists the marker, so a later missing or
stale index cannot reopen billing-contact recovery. Normal ownership reads gain
no new storage read; the additional work happens at gift creation/claim and
recovery only.

This is an additional safeguard, not complete issuance authorization. The future
trusted issuer must still validate Stripe subscription gift metadata and contact
provenance, including legacy memberships whose gift index has not been observed.
Gift recovery remains unsupported. Issuer throttling, durable delivery outcomes,
app recovery UI and end-to-end rehearsal remain outstanding. These source changes
have not been deployed. Focused ownership, recovery, Gmail adapter and checkout
suites passed 53 tests; the gift-flow suite also passed. No app build was run.

## Durable issuance foundation

Added the internal `membership-recovery-issuer.mjs` orchestration seam. It requires
both enable flags, a trusted recipient verifier, and serialization of the entire
operation in the membership ownership coordinator. It is not yet wired to that
coordinator or any public endpoint. No default verifier exists; callers cannot
supply a recipient through the request payload.

Before delivery, it prepares the destination-bound proof and persists a pending
attempt containing no email or plaintext code. It records accepted, rejected or
uncertain outcomes. Replaying the latest attempt never sends again, including
when the process stopped after delivery but before saving its outcome. Failed
reservation prevents sending. A bounded rolling timestamp history enforces a
15-minute cooldown and three attempts per 24 hours. These are per-membership
limits; public per-installation/IP limits and older-attempt replay handling still
need implementation before exposure. Accepted means provider acceptance only.

Six issuer tests plus the ownership, redemption and Gmail adapter suites passed
36 tests. Coverage includes failed reservation, lost final write, timeout,
rejection, cooldown/daily limits, gifts, disabled flags and changed destination.
Tests use mocked delivery only. Nothing was deployed, sent, charged or built.

### Older issuance retries

Issuance now retains outcomes for all retry IDs within their 24-hour validity
window, rather than only the latest request. An older retry cannot send again or
replace the newest recovery proof. Each ID has the format
`<13-digit Unix milliseconds>_<16-96 URL-safe random characters>`; the future
client must generate it once per deliberate request and reuse it unchanged on
network retries. IDs older than 24 hours or more than a minute in the future are
rejected before verification or storage. An expired request requires a deliberate
new attempt, not automatic ID replacement. This timestamp is a retry-lifetime
boundary, not authentication; existing ownership and rate-limit checks remain.

The rolling daily issuance limit bounds retained retry records. Pending outcomes
continue to replay as uncertain, including after a process restart or failed
final write. Eight issuer tests passed, including replay after a newer request,
unchanged latest proof, mismatched destination and expired/future IDs.
The issuer is still internal and unwired; trusted Stripe contact verification,
public request limits, app UI and end-to-end rehearsal remain outstanding.

### Trusted contact and coordinator wiring

The internal issue-recovery action now runs in the ownership coordinator's
existing serialized queue, keeping verification, reservation and delivery ordered
with transfers and gift markers. Its Gmail adapter is reused per coordinator.
Recipient selection reads the subscription and its referenced Stripe customer;
it checks membership ID, configured cadence/price, physical-fulfillment metadata,
account mode, gift metadata, customer identity/deletion and a valid contact.
No request-provided recipient is accepted. A cancelled membership can recover
ownership for management; recovery still grants no paid entitlement.

Thirty-two contact/issuer/ownership/redemption tests passed. Public issuance,
per-client abuse limits, app request/redemption UI and actual end-to-end delivery
remain unfinished; both enable flags remain off. No deployment or email occurred.
The user has now authorized builds and whole-worktree commits for this chat;
neither was performed in this step.

### Public request and app recovery flow

Added the gated POST /memberships/recovery/request route (and API-prefixed alias).
It requires the existing authenticated installation session and both network and
installation rate-limit checks. The bounded request parser accepts only membershipID
and attemptID. Eligibility denial returns the same generic acknowledgment as
accepted delivery; no recipient or provider message ID is returned.

The Bound Year panel now has request and code-redemption controls. Retry IDs are
saved across app relaunches; a deliberate new-request control clears the old ID.
Codes stay in transient secure-field state. After redeeming, the app fetches the
current membership, restores its cadence and original start-month anchor, and
reconciles paid access separately. No local ownership or payment grant is inferred
from requesting mail. Both Worker enable flags remain absent.

A full coordinator test with mocked Stripe and Gmail verified contact lookup,
concurrent request serialization, single-send behavior, restart replay and
redemption of the actual MIME-encoded proof. Durable storage contains neither
email address nor plaintext proof. Public endpoint tests cover session requirement,
caller-recipient rejection, device binding, rate limiting and disabled delivery.
Physical-device Debug build succeeded; no install, launch or real recovery email
yet. Before release, verify on-device recovery, interrupted redemption/status fetch,
privacy notice coverage and real enabled-Worker mail delivery. The user authorized
whole-worktree commits, including concurrent UI/performance changes.

### Interrupted redemption resume

The app now persists only the pending membership ID before submitting redemption.
If the response is lost, the app closes, or the following status lookup fails,
“Finish checking recovered membership” retries the authenticated membership read
without requesting email or transferring ownership again. That read still checks
current ownership on the server; merely saving an ID grants nothing. The pending
ID clears only after the restored membership has been reconciled and saved via
the existing callback. No plaintext code is persisted.

Interrupted-resume change passed the physical-device Debug build. Added an
unpublished privacy-page draft describing Google delivery and bounded recovery
records; deployment and review of that notice remain before enabling the service.
