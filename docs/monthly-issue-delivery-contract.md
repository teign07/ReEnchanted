# Monthly Issue Delivery Contract

This contract keeps a living monthly Book small without turning old issues into
replayable downloads. Count Unbound content is intentionally not specified
here; it will use this reusable machinery when its authorship is ready.

The [monthly content runtime guide](monthly-content-runtime.md) covers the runtime-2 authoring workflow, node receipts, accepted missions, braid passages, and production inventory tooling.

The [monthly delivery guide](physical-book-backend/MONTHLY-ISSUES.md) defines the implemented access exchange, short-lived installation-bound tokens, private R2 routes, and staging configuration. Publisher signatures and installation authorization are separate checks. All asset URLs use the same Worker HTTPS origin at `/monthly-issues/assets/ASSET_ID`; the client refuses credential-bearing redirects and cross-origin requests.

## Product law

- A monthly issue may be **foreshadow**, **live**, **residue**, **sealed**, or a
  published **casebook**.
- Only a live issue accepts participation.
- The app may hold runtime assets for every issue whose foreshadow-through-
  residue envelope contains now, plus the next issue. This is normally current
  plus next and may briefly be previous residue plus current plus next.
- Once residue ends, that issue's runtime and media leave the managed shelf.
- A published casebook is small, textual, read-only, and not an episode.
- The current open shelf grants every installation monthly access; the preserved
  paid gate can be restored if the offer changes. Access changes do not erase reader-owned
  Pages, evidence, personal relics, or locally frozen casebooks.
- Bundled packs remain a valid shipping and offline fallback path.

## Signed envelope

The manifest endpoint returns JSON shaped as:

```json
{
  "keyID": "monthly-issues-2027-01",
  "payload": "BASE64_OF_EXACT_MANIFEST_BYTES",
  "signature": "BASE64_OF_ED25519_SIGNATURE"
}
```

The signature covers the decoded `payload` bytes exactly. The client does not
parse and re-encode the payload before verification. The decoded payload is a
`MonthlyIssueDeliveryManifest` using ISO-8601 dates:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2027-08-20T12:00:00Z",
  "allowedAssetHosts": ["issues.reenchanted.app"],
  "issues": [
    {
      "id": "example-2027",
      "packID": "example",
      "title": "Example Issue",
      "liveStartsAt": "2027-09-01T00:00:00Z",
      "liveEndsAt": "2027-10-01T00:00:00Z",
      "foreshadowStartsAt": "2027-08-25T00:00:00Z",
      "residueEndsAt": "2027-10-08T00:00:00Z",
      "casebookAvailableAt": "2027-11-01T00:00:00Z",
      "assets": []
    }
  ]
}
```

Issue and asset IDs are globally unique within a manifest. Live intervals may
not overlap. Calendar boundaries must be monotonic:

```text
foreshadowStartsAt <= liveStartsAt < liveEndsAt
liveEndsAt <= residueEndsAt <= casebookAvailableAt
```

The endpoint and every asset URL must use HTTPS. Asset hosts must appear in the
signed `allowedAssetHosts` list; the manifest host is also trusted for assets.

## Asset records

Each `MonthlyIssueDeliveryAsset` declares:

- a stable `id`;
- `kind`: `worldEventPack`, `pageArchetypePack`, `storyFormPack`,
  `storyConsequencePack`, `radioStationPack`, `sentenceBuilderPack`, `editionPlayPack`, `casebook`,
  or `media`;
- `scope`: `runtime`, `publication`, or `casebook`;
- HTTPS `remoteURL` and a path-free `fileName`;
- lowercase or uppercase hexadecimal `sha256` of the downloaded source bytes;
- exact `byteCount`;
- `isRequired`, defaulting to true;
- optional `retiresAt` (runtime assets only), an exclusive earlier retirement
  instant within the issue envelope. Without it, runtime files last through residue.

JSON filenames must retain the existing registry suffix for their kind. A
casebook must use `.reenchantedcasebook.json` and `scope: casebook`. Pack JSON
may refer to a delivered media destination with
`{{asset-path:ASSET_ID}}`. Replacement happens only after every destination is
resolved, and the materialized JSON is decoded as its declared pack type before
installation.

`publication` is for small, read-only edition play definitions and their media.
It is available from foreshadow onward and remains on the signed shelf for
later monthly, seasonal, and annual binding. It never activates story physics.
Removing an issue from the signed shelf retires these assets through the same
managed installation ledger; runtime assets still retire after residue.

Limits are deliberately strict:

| Limit | Ceiling |
|---|---:|
| One runtime or media asset | 180 MiB |
| One publication asset or casebook | 2 MiB |
| Entire managed shelf | 350 MiB |

## Installation and pruning

The coordinator refreshes after launch, foreground entry, StoreKit entitlement
changes, and local pack-access changes. It verifies a newly downloaded envelope
before caching it. If the network fails, it may use only the last cached
envelope that still passes signature verification.

For every desired asset the installer verifies URL, filename, size, SHA-256,
and decoded type, writes atomically, and marks the file excluded from device
backup. Managed files live beneath:

```text
Application Support/MonthlyIssueDelivery/Content/
```

They are kept outside Documents so they do not appear as reader files. Existing
Documents-based imports still work and are never treated as managed inventory.

`installation-state.json` is the sole pruning authority. Removal is allowed
only when all of these are true:

1. the asset appears in the previous managed installation state;
2. its ID is absent from the new signed plan;
3. its target is inside the managed Content directory; and
4. its filename begins with `reenchanted-managed-`.

No glob, pack suffix, or event ID is sufficient authority to delete a file.

The coordinator serializes refresh transactions across network awaits and skips
superseded queued requests. It retires obsolete managed assets before downloading replacements,
so a required next-issue download failure does not retain expired inventory.
Managed pack discovery also checks the current monthly-access policy before reading
that directory; deletion is not the access-control boundary. A usable verified
manifest is still required to calculate the pruning plan.

For the Count integration audit, remaining lifecycle work, and recording handoff,
see [the runtime board](count-unbound-integration.md) and
[media production sheet](count-unbound-media-production.md).

## Runtime and casebook behavior

The world-event ledger records a beat only when its surface is actually served.
Reports may acknowledge missed live beats, but do not become participation.
Foreshadow and residue never become participation. Existing negotiations,
Story choices, and other event instruments may establish participation through
their own action receipts or event-tagged reader evidence. A new authored beat
door establishes participation only when all of these are true:

1. it has an authored `participationPrompt` on a live beat;
2. the resulting Page contains reader contribution; and
3. the event is still live when the contribution is committed.

At the live-to-residue boundary, reconciliation freezes exactly one casebook.
For a participant it may preserve the outcome, history sentence, and IDs of
their evidence Pages. For anyone else it is third-person rumor with no reader
evidence IDs and no relic. The Almanac can open a published casebook, but its
surface declares `readOnlyPublication`; the UI supplies Close and suppresses
participation, Keep, and shelf-mark actions.

## Authored graph and native Book seams

Each issue pack carries its own `MonthlyIssueAuthoringManifest`. The manifest
is the release checklist and the runtime graph: every deliverable is a stable
content atom with a lifecycle placement, optional live phase ID and universal
phase role, audience and narrative voice, production status, priority,
interaction kind, occurrence policy, dependency list, and composable gate.
The gate is shared with ordinary authored content, so an issue atom may depend
on exact dates or hours, weekday, moon phase, weather, sleep signals, recent
Pages or tags, absence, place, permissions, world-event state, or prior content
receipts. Missing real-world evidence never becomes a fictional fact.

The manifest points into the Book's existing native objects instead of making
a monthly mini-app:

- `AuthoredStoryScene` becomes a normal Story Page. It may be complete prose,
  an arbitrary prewritten choice set with authored consequences, a reader
  response, an evidence return, or a field mission. A fully authored scene is
  never extended by generation.
- `AuthoredBleedArticle` is inserted verbatim into a scheduled Bleed edition
  and frozen into that edition's surface metadata before the press run.
- `AuthoredRadioBanter` enters the selected station's ordinary banter bag and
  records a played receipt after audio starts. Caption fallback records delivery.
- `AuthoredMarginaliaMark` directs one installed illumination asset onto an
  eligible leaf. The density ceiling is one directed issue mark per nine-leaf
  published block. Temporary downloaded assets retire with their delivery
  window. Keeping a decorated Page freezes its mark definition and preserves
  managed image bytes in the keepsake store; retirement does not erase that
  archived Page. Permanent bundled cabinet assets have their own lifecycle.
- Existing Page archetypes and world-event beats remain valid references for
  simpler doors, reports, letters, classes, and other established Page types.

`MonthlyIssueContentResolver` is the single eligibility path for all of these
channels. Delivery, opening, action, completion, keeping, and Radio playout use
the same idempotent receipt ledger. Consequently an `untilOpened`,
`untilActed`, once-per-phase, once-per-run, once-ever, or bounded-repeat atom
retires the same way no matter which Book surface carried it. Participation is
recorded only from an actual contribution or choice during the live window,
never from ownership, delivery, opening, a report, foreshadow, or residue.

Release validation rejects an incomplete required graph, broken or future
dependencies, cycles, invalid lifecycle placement, unsafe residue voice,
missing native objects, underspecified choice scenes or field missions, and
phase or coverage plans that do not meet the declared issue budget. The
synthetic-clock authoring simulator then walks the same resolver and ledgers at
morning, evening, and night for active, late, absent, and lapsed personas. It is
an authoring instrument for inspecting the six-week envelope. It does not
replace native test execution, actual UI/audio checks, or server authorization.

## Release configuration

Ordinary monthly releases download content files separately; they do not require
an App Store update. The installer reuses unchanged verified files and downloads
the full bytes of each changed file. Temporary packs, Radio files, and marginalia
retire automatically according to their delivery dates. Kept Pages and retained
artwork survive. New runtime capabilities or a signing-key rotation require an
app release. These mechanisms are implemented; the hosted delivery configuration
and live-provider rehearsal are still required before launch.

### Prepare a monthly release

Use `scripts/prepare_monthly_release.py` before the existing signer. Keep source
assets at `SOURCE_ROOT/ISSUE_ID/fileName`, using the IDs and filenames in the
delivery manifest template. The template supplies the full shelf inventory and
lifecycle dates. The tool fills in hashes, sizes, allowed hosts, and private URLs;
authors do not need to type checksums or download routes.

```bash
python3 scripts/prepare_monthly_release.py /publishing/shelf-template.json \
  --asset-root /publishing/sources \
  --origin https://WORKER-ORIGIN \
  --previous /publishing/last-published/manifest.json \
  --output /publishing/new-release
```

Use `--first-release` instead of `--previous` only for the first publication.
The previous file is the last published decoded manifest, not an edited template.
Preserve published manifests as release history. Asset IDs are permanent object
keys: never reuse a previously published ID for different bytes, even after it
has left the shelf. The tool checks this against the supplied previous manifest.
Content/node/choice IDs are separate durable story identities; use
`monthly_pack.py migration OLD_PACK NEW_PACK` when revising an existing story.

Preparation writes a new directory with:

- `manifest.json`: exact unsigned bytes for the existing signer;
- `assets/ASSET_ID`: all listed source files, ready for private object storage;
- `release-report.json`: new uploads, unchanged files, byte totals, and IDs no
  longer listed;
- `production.csv`: the authored content inventory, including Radio captions
  and recording metadata when present.

It refuses overlapping live dates, bad retirement windows, unsafe paths, missing
assets, invalid world-event release preflight, broken media references, and media
that would retire while a referencing pack still needs it. It streams file copies
and checksums; a failed preparation removes its staging directory. It never
overwrites a release directory, invokes a compiler, signs, uploads, or deletes
published objects. Native Swift validation and Reader rehearsal remain necessary;
this tool does not duplicate every native pack decoder or validate image/audio
quality.

After review and native validation, sign `new-release/manifest.json` using the
command below, writing `new-release/manifest.envelope.json`. Upload the report's
new assets to the private bucket at `assets/ASSET_ID` **first**, verify the uploaded
bytes, and replace `manifest.envelope.json` **last**. Reused files must already
exist in that bucket with their published bytes. Retain the previous envelope and
assets for rollback; the Worker can hold the previous verified inventory for up
to 30 seconds. `noLongerListed` is an inventory report, not a deletion command.
Device cleanup is automatic, independently of when old server objects are
removed. Never apply a bucket-wide expiry rule to retained casebooks or assets
still referenced by a published manifest.

### Signing configuration

The release Info.plist supplies:

- `MonthlyIssueManifestURL`: the HTTPS signed-envelope endpoint;
- `MonthlyIssueManifestPublicKey`: the Ed25519 public key's 32 raw bytes,
  base64-encoded.

Debug or TestFlight can override them with UserDefaults keys
`monthlyIssueManifestURL` and `monthlyIssueManifestPublicKey`.

The private signing key must live in the publishing environment, never in the
repository, app bundle, manifest host, or client defaults. Key rotation ships a
new public key in an app release before the publishing service begins signing
with its paired private key. A release with blank or invalid configuration is
safe but delivery-disabled: bundled content remains available and no unsigned
manifest is accepted.

The repository publisher utility preflights the same structural rules and signs
the manifest's exact bytes:

```bash
xcrun swift scripts/sign_monthly_issue_manifest.swift generate-key \
  /secure/monthly-issue-private.key /secure/monthly-issue-public.key

xcrun swift scripts/sign_monthly_issue_manifest.swift sign \
  /publishing/manifest.json /secure/monthly-issue-private.key \
  monthly-issues-2027-01 /publishing/manifest.envelope.json
```

`generate-key` refuses to overwrite either key and writes the private key with
owner-only permissions. The public file's base64 text becomes
`MonthlyIssueManifestPublicKey`. Upload only the signed envelope and its
checksum-matched assets. Never upload either key file; the public key belongs in
the app release configuration, not beside a mutable manifest.

## Acceptance evidence

Before turning on a production endpoint:

1. sign a fixture and prove a one-byte payload mutation is rejected;
2. walk previous residue, current live, next foreshadow, sealing, and casebook
   publication with an injected clock;
3. walk active participant, passive subscriber, late arrival, absent returner,
   and lapsed subscriber;
4. prove lapsed access clears only managed runtime/casebook files;
5. prove a user-imported pack and reader-owned evidence survive that clearing;
6. inspect the Almanac casebook on device and prove it has no replay or Keep
   affordance; and
7. record build, focused tests, install, launch, calendar simulation, and visual
   QA as separate evidence. Static parse alone does not satisfy this gate.
