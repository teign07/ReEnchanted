# Reusable monthly content runtime

5 September 2026. Source implementation guide. The Count Unbound remains an authored manuscript; it is not installed, bundled, or enabled by this work. This guide supersedes the infrastructure gaps in the first-pass [Count integration board](count-unbound-integration.md). The [delivery contract](monthly-issue-delivery-contract.md) owns signing, download integrity, storage, and retirement.

## Rehearsal and recovery follow-up

The [Issue Zero fixture](fixtures/monthly-rehearsal/README.md) now contains a complete four-phase native pack, delivery payload with matching hashes, production CSV, and six synthetic Reader personas. It is outside app resources and remains uninstalled.

The simulator now uses the production authored Page compositor and node-commit method. It records selected nodes, invitation acceptance, delayed evidence returns, public catch-up, caption versus audio delivery, early conclusion, and nightly braid coverage. It can resume saved ledgers/jump state and export its observations through the native rehearsal tests. It does not simulate UI taps, real recordings, or server authentication.

New supervised visits freeze the exit receipt in the active jump. Returning after pack removal no longer needs a live catalog to dismiss that issue/run's unfinished scene. Visits saved before this field existed still use catalog-based recovery when available. Committed node receipts also freeze their next node, so changing a choice route in a pack does not rewrite an existing choice; removing the target still requires a deliberate migration.

After build authorization, the focused native suite passed 400 tests; an additional artwork-retention regression brought the distinct tested set to 401. Twelve Python tooling tests passed. The complete iOS Debug app build also succeeded with signing disabled. The first native run caught missing coverage requirements in the rehearsal fixture; the fixture and Python preflight are corrected. See [verification evidence](monthly-content-verification.md) for commands, limits, and remaining release work.

## The existing instruments

Keep one `WorldEventPack` with an `authoringManifests` entry linking its native objects. Use the existing Story Page, Page archetype, Radio, Bleed, and marginalia adapters. Every temporary object needs an atom in the manifest. Do not put a monthly line into a permanent station or mark registry without a temporary atom controlling its exposure.

The live dramatic form remains **SETUP → BUILDUP → CLIMAX → AFTERMATH**. Weeks are date gates within those phases. An authored month may have four crossings without inventing four more phases. A medium need not appear in every phase.

Use `minimumRuntimeVersion: 2` for the new graph/mission runtime. The installer validates native manifests in release mode and rejects unsupported versions. Old clients need a compatible server manifest; adding a field to a pack cannot teach an already shipped client this runtime.

## Disposition, continuation, and missions

| Intent | Authoring contract | Durable observation |
| --- | --- | --- |
| Scene stays available until chosen or passed | `occurrence.kind = untilResolved` | Keep/completion/Trash resolves the issue/run atom |
| Multi-leaf scene | `scene.nodes`, first node is entry | `nodeCompleted` with stable node and choice IDs |
| One scene per phase | `oncePerPhase` | Receipts scoped to phase |
| Deliberately recurring ambient material | `repeatable` with cooldown or maximum | Each delivered occurrence has its own identity |
| Invitation followed by a real-world return | `fieldMission`, `untilResolved`, `missionReturn` | Invitation Keep records `accepted`; evidence return records completion |
| End the month's live offers early | `concludesRun: true` on the ending | `concluded` closes live atoms except explicit `survivesConclusion` |

A node contains `id`, `title`, `body`, `prompt`, and authored `choices`. Its optional `nextNodeID` is the default route. A choice's `nextNodeID` overrides that default; omitting it inherits the default. To end one choice while other choices continue, route it to a separate terminal node. All choice results are authored. Merely previewing a choice does not commit progress or spend its consequences. Keep commits the selected route; Trash ends that atom without fabricating a completed scene.

Node IDs, choice IDs, content IDs, issue IDs, and routes are persistent save identities. New node receipts freeze the selected next node at Keep. Correcting prose is different from redirecting a route that someone has already chosen. The offline migration command flags both removed identities and changed routes. For a genuinely new story, use a new issue identity.

`missionReturn` contains its own `placement` and `gate`. Author a crossing as its own atom with `missionReturnPrompt`, separate from a node/choice graph; dependencies connect it to the surrounding scenes. A return can span the remaining live event by omitting phase identity, or name a matching phase ID and role. It cannot reopen participation in residue. The original invitation closes on acceptance; it does not keep resurfacing. Its return gets a separate surface identity and uses `missionReturnPrompt` as the displayed question. Authored text or an invitation Keep is not proof that the Reader did the real-world action. Evidence still requires the Reader's response through the existing contribution model.

The next eligible leaf is supplied to the existing desk replacement flow after Keep. Intermediate nodes do not resolve the whole atom or impose a rest on the next node. Runtime checks revalidate live offers at opening, action, and Keep; a foreground maintenance pass also removes stale cached surfaces and temporary decorations. Explicit kept-page reads remain outside temporary retirement.

## What reaches the nightly braid

Put a short, self-contained `braidText` on a scene/node, or on a choice when its outcome needs different wording. A committed choice wins over the node/scene default. The receipt freezes that exact text, so a later pack replacement cannot rewrite the Reader's past.

The native scene planner now receives those committed passages as protected fiction, separately from Reader evidence. Its existing single generation writes an opening and a continuation; the compositor inserts the complete authored passages between them, before the ritual closing. It does not ask the model to rewrite canon or emit special markers. A malformed paragraph layout or another braider uses deterministic insertion before the closing; with an empty body, the authored passages stand alone. The model sees at most six passages with a 1,200-character context excerpt per passage; publication keeps the full frozen strings. Authors should still keep `braidText` concise.

The encountered monthly story takes the scene planner's world strand for that night, without adding a second scheduled world event. An archived monthly scene's raw body and choice are excluded from the planner's ordinary fiction inputs to prevent duplicate telling. Its atomic Reader sentences, photographs, and recordings remain available. This is composition at paragraph boundaries, not arbitrary sentence-by-sentence interleaving. Model adherence and literary quality still need an actual mixed-day Reader rehearsal.

Saved receipt tags prevent later nights from repeating the passages and make binding idempotent; an explicit rewrite retains the original receipt set. At most six new passages are bound in one night, in recorded order; the remainder stay pending. Only committed scene/node outcomes and public reports qualify, never invitation acceptance or a preview. With no captured Pages, the app can produce an authored story-night page without generating the story.

Unreached monthly phase packets are excluded from the braid's active-event context. Catch-up has its own public `scene.report`; it does not invent attendance, a romantic choice, a crossing, or a relic. A `reportThenContinue` dependency may use that text only after the source's earlier phase, or after an explicit `reportAfterLiveDay`. Live-day indexes are zero-based, matching event gates: `reportAfterLiveDay: 6` means history becomes available on the eighth calendar day. Reading or keeping the report records `reported`, which remains distinct from actual completion. Authors must place report deadlines after the events described.

## Authored Book jumps

A scene can declare `jump: AuthoredJumpDefinition` with a stable episode ID, work, guide, and a fictional anchor. Nodes or choices can declare `jumpAction` using the existing start/advance/stabilize/return vocabulary. The existing Book-jump state holds the supervised visit; there is no parallel jump ledger.

The graph validator checks that routes do not advance before starting, start twice, or finish with a doorway still open. The runtime refuses to replace a Reader's existing jump. Supervised advancement has no normal escalation charge, souvenir debt, or borrowed-rule reward. The ordinary Spine return remains available from the first depth. An early return dismisses the unfinished authored episode using the exit identity frozen at entry; downstream story should offer an authored public catch-up where appropriate. Expiry safely returns the jump without a loss of Belief.

## Temporary art and Radio

A `pageArchetypePack` can contribute a `marginaliaPack` to the existing illustration cabinet. The authored mark points to its asset pack and asset ID. Deliver image/audio bytes as `media`; use `{{asset-path:ASSET_ID}}` in the native JSON. The installer replaces it with a managed local path and refuses unresolved placeholders. Use immutable, versioned or content-hashed filenames for changed artwork, so image caches never confuse new bytes with old art.

Downloaded marginalia uses an asynchronous, downsampled image loader with a 24 MiB cache. Keeping a decorated Page freezes the asset definition and copies managed art into `MonthlyIssueKeepsakes`, addressed by the bytes' hash. Reusing the same mark does not make a new file per Keep. Temporary asset retirement therefore does not erase the archived mark. Its media entry is preserved for storage/export but excluded from the folio's ordinary photograph rail.

Radio checks eligibility again at actual playout, including subscription state and phase. A successful audio start records `played`. Missing/unplayable audio uses the existing caption route and records `delivered`, not a fictitious audio play. Captions remain for a reading interval based on their word count, bounded to 8–45 seconds. Dependencies that genuinely require hearing a recording should require `played`; ordinary delivery dependencies also accept a caption.

Export the production inventory before recording. It includes atom IDs, station, asset reference, full caption, phase/lifecycle, occurrence policy, gate, dependencies, mission-return data, and early conclusion flag. Keep the caption faithful to the recording. The authored voice and line-by-line acting notes remain editorial work; the CSV is the implementation handoff, not a substitute for them.

## Swap/publish procedure

1. Author the native objects and complete their manifest matrix. Explicitly supply the nonoptional Codable fields when writing JSON, including empty arrays; Swift property defaults do not make arbitrary JSON keys optional.
2. Run `python3 scripts/monthly_pack.py check PACK.json` during drafting. Use `--release` before distribution. This is a structural preflight, not a complete Swift-schema validator.
3. For a revision of an existing issue, run `python3 scripts/monthly_pack.py migration OLD.json NEW.json`. Review every identity/route warning; do not silently migrate committed branches.
4. Run `python3 scripts/monthly_pack.py inventory PACK.json --output production.csv`. Record the identified Radio lines and create the named marginalia.
5. Run `python3 scripts/monthly_pack.py asset FILE` for each deliverable's filename, SHA-256, and byte count. Put those source-byte values into the signed delivery manifest. The script does not hold signing keys or publish anything.
6. Keep runtime JSON available through the last scene/report/return that needs it. Give temporary media an exclusive `retiresAt` where appropriate; otherwise runtime assets retire at residue end. A shared image/audio file must survive every atom referencing it. Retain small casebook matter separately.
7. Publish through the configured signed delivery service. Packs are staged/installed using the existing serialized coordinator. Expired assets are retired from the local installation ledger even if replacement downloads fail. Foreground/day-boundary maintenance retries cleanup; the active-app sweep checks live visibility every 30 seconds. iOS suspension can delay deletion until the next wake, but does not turn an expired atom into an eligible offer.
8. Exercise the transition matrix below before enabling the issue for subscribers.

## Performance and release evidence

The new live sweep visits desk, bench, insertions, and the open sheet. It uses a cached catalog with dictionary lookup; its gate context does not fall back to registry/file discovery. It does not decode packs, download assets, scan archived media, or regenerate fiction on the timer. Catalog loading runs on a utility task after delivery/access changes. Image decoding happens on a utility task and is cached. Remaining receipt scans are in memory. No on-device timings or frame-rate claims have been measured.

Completed checks after the user's build authorization: 400 focused native tests passed, then all 12 rehearsal tests passed with the new downloaded-art retention test (401 distinct native tests across the runs). Twelve Python tooling tests passed. The iOS Debug app, Widget, and Share extension build succeeded with signing disabled. Protected braid placement, idempotence, bounded context, public reports, mixed Reader contributions, pending overflow, and old plan decoding are now executed regressions. No install, device QA, live billing verification, or model/print proof is implied.

Before release, verify:

- Digital purchase/restore/refund/expiry and Bound Year paid-through expiry; either valid subscription must independently retain access. StoreKit schedules a recheck at known expiration, and foreground/active checks reconcile Bound Year dates.
- Open → preview → Keep → next leaf; duplicate Keep; Trash; relaunch; phase transition while a sheet is open; acceptance just before an invitation closes; real-world return later in the month.
- Late arrival with public report, every branch of supervised entry/return, early exit and subsequent regrant, and expiry while offline.
- A queued Radio line crossing a phase/access boundary, missing audio caption behavior, retained art after cleanup, and actual rendered bound-edition/export output.
- A failed next-issue download, retirement with no network, update during a slow download, unsupported client version, and a new month arriving while the app stays open.

The [subscriber delivery implementation](physical-book-backend/MONTHLY-ISSUES.md) now extends the existing Worker with a proof exchange and private manifest/media routes. The client supplies verified Apple transaction proofs or its Bound Year membership identity through the existing installation session, then uses a short-lived server token. Explicit denial clears temporary content; transient failures preserve verified offline inventory. The Worker checks Apple current status or verified Stripe ownership and payment independently. The production URL/public key, Apple credentials, token secret, and private R2 binding still need staging configuration and real-provider validation. This local implementation has not been deployed. Recording, device, literary, and print proof remain separate.
