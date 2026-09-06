# The Count Unbound: runtime integration board

**Historical first-pass audit.** The subsequent reusable runtime work is documented in [Monthly content runtime](monthly-content-runtime.md). Read that guide for implemented graph progress, catch-up, braid passages, live revalidation, retained marks, and authoring tools; the open items below record the earlier audit, not the current source inventory.

5 September 2026. Source audit and first implementation pass; **not a released or installed Count pack**. The [revised manuscript](count-unbound-creator-pack.md) is the copy source. The [editorial notes](count-unbound-editorial-notes.md) own Jump, evidence, and romance design. This board supersedes the older graph's one-crossing schedule for implementation.

## What changed in this pass

- `AuthoredContentOccurrencePolicy.untilResolved` keeps an offer eligible after delivery, opening, and an intermediate action. Keep, completion, or Trash ends that offer for its issue/run. Opening is not completion. Existing until-opened/until-acted offers now also respect Trash. Native adapters must opt into the new policy; existing once-per-run packs keep their behavior.
- The app's main surface dismissal handler persists `.dismissed`, including authored attachments, before removing the surface. Existing Keep handling already persists `.kept`. A trash receipt does not qualify as participation.
- Monthly curation withholds an already-tagged issue offer when its manifest/reference disappears. This operates on candidates, not the archived `BookPage` collection. It is not yet a guarantee that every retained folio insertion or open sheet has been invalidated.
- Managed monthly pack discovery requires either subscription, independent of a downloaded payload's `availability` flag. Cleanup can lag without making those files freely discoverable.
- Apple restoration explicitly filters revoked, expired, and upgraded transactions. Bound Year digital access uses the recorded paid-through/end dates, with local checks on foreground and reconciliation after a remote membership refresh. A cached active status is no longer an unlimited digital grant. This does not change physical shipment eligibility.
- A delivery asset may declare optional `retiresAt`, exclusive. Runtime assets otherwise retire at residue end. Casebook assets cannot use this temporary-retirement override. An earlier date must be within the issue envelope. Eligibility still uses atom gates: a prefetched file is not a scene invitation.
- Coordinator refreshes are serialized across network awaits, and superseded queued requests are skipped. An older download cannot commit after a later cleanup transaction. The coordinator retires obsolete managed files before attempting replacement downloads. A failed next-issue download no longer prevents this retirement. The installation ledger and managed-directory checks remain the only deletion authority.
- Radio accepts materialized managed audio paths, including their existing extension, only with monthly access and containment in the managed directory. Bundled/imported audio continues using its existing lookup.

Verification: Swift syntax parsing passed for changed sources and tests. Regression cases were added for offer disposition, orphan candidates, both subscription types, paid-period boundaries, early asset retirement, retirement followed by an offline replacement failure, and managed audio lookup. Tests, type checking, app build, StoreKit/Stripe integration, device playback, and rendered folio behavior have **not** been run in this pass. The user has not authorized a build.

## Access: implemented checks versus release proof

`standing-order` is the Apple digital subscription. `bound-year-digital` is the separate digital grant derived from the physical membership. Either grants managed monthly access. An individual pack ID does not grant access to managed monthly files. Ending one subscription must not revoke the other.

This is local enforcement, not proof of production access control. The inspected app plist has empty `MonthlyIssueManifestURL` and `MonthlyIssueManifestPublicKey`; runtime defaults can override them. No configured production delivery was demonstrated. The downloader uses ordinary HTTPS URLs and a signature. A signature authenticates the publisher's bytes; it does not authenticate a subscriber to the download server. If files must be inaccessible outside subscribed clients, delivery needs backend entitlement verification and expiring download authorization as well.

Remaining access work:

1. Exercise Apple purchase, restore, expiration, refund, upgrade, offline launch, and switching between both subscriptions. The digital grant is still cached in the vault; establish the verified offline lifetime and refresh behavior explicitly. The new Bound Year rule stops at the last known paid-through date while offline; any grace extension must come from an explicit billing policy.
2. Exercise the new serialized delivery queue during subscription loss, regrant, and failed downloads. Access checks withdraw discoverable content immediately; physical cleanup may wait for the active transaction. Verify that the final installed state matches the newest request.
3. Recheck entitlement at choice/evidence commit, queued Radio start, and mutable story-sheet entry. Protect live actions as well as initial candidate generation.
4. Gate pack schema/minimum app version before distribution. Older clients do not understand `untilResolved`; do not send the new policy to them indiscriminately.

## Placement contract

Every authored item needs a stable ID, native reference, opening trigger, closing trigger, prerequisite receipt, occurrence policy, late-reader behavior, and retained consequence. These belong in `MonthlyIssueAuthoringManifest`, not scattered date checks in individual views. Use `productionStatus: draft` until native payload, gates, and branch behavior are ready. The Count is not currently registered as a bundled pack and the manuscript has not been serialized into a release pack.

The four phases remain:

| Role / phase ID | Live days | Exact progress start |
|---|---|---|
| SETUP / `school-hours` | October 1–7 | `0` |
| BUILDUP / `uninvited` | October 8–21 | `7 / 31` |
| CLIMAX / `reciprocal` | October 22–28 | `21 / 31` |
| AFTERMATH / `nightbound` | October 29–31 | `28 / 31` |

Below, date ranges include the listed last day; encode closing at the next day's midnight, exclusive. Use event `liveDay` for reader-local weekly placement. Signed delivery timestamps are absolute instants: settle the publication timezone and travel policy before signing the pack so file retirement cannot preempt a local live window. Do not use rounded progress constants or ISO week-of-year for October's four crossings.

| Content | First offer / last live offer | Prerequisite and disposition |
|---|---|---|
| `academy.school.chair-first` | October 1 / 7 | No prior knowledge; optional choice; until resolved |
| `academy.school.sentence-coat` | October 2 / 7 | No attendance requirement; opens Week One; until resolved |
| `academy.school.wrong-way` | October 3 / 7 | Introduces Soren; no romantic commitment; until resolved |
| `academy.school.ribbon-lesson` | October 4 / 7, before entering Jump | Real authored-Jump entry or explicit stay-out; until resolved |
| `count-unbound.scene.sunday-jump` | October 4 / 7 | Explicit entry; multi-node authored Jump; outside path receives report |
| `count-unbound.scene.east-stacks` | October 8 / 14 | Jump encountered **or safe history report**; no fabricated attendance |
| `count-unbound.school.map-room` | October 10 / 14 | Incident encountered or reported; optional social scene |
| `count-unbound.scene.man-reading-himself` | October 15 / 17 | Incident knowledge; one question and shared continuation |
| `count-unbound.interlude.terms-supper`, `.hunt-autopsy`, `.gambit-paper-room` | October 18 / 21 | Meeting known; selected strategy chooses one, not all three |
| `count-unbound.scene.wrong-castle` | October 22 / 27 | Meeting or catch-up known; optional Week Three finding |
| `count-unbound.scene.future-tense` | October 28 / 28 | Explicit final method; actual eligible evidence optional; one composed ending |
| `count-unbound.resolution.terms`, `.rule`, `.ruse` | Inside `future-tense` only | Branch fragments, never three independent curator pages |
| `count-unbound.scene.first-nightbound-morning` | October 29 / 31 | Return encountered or public report; no invented personal relic |
| `count-unbound.relationship.after-lesson` | October 30 / 31 | Naming encountered; one private social invitation or neither |

These windows are the integration proposal: the manuscript supplies opening dates; this board makes first-offer and close decisions explicit. Late readers receive compact safe reports before new live scenes. They are not fed an overdue queue. A dismissed scene can be acknowledged by a later report without replaying the dismissed page or claiming the Reader watched it. Required knowledge needs a report receipt, not `.delivered` for a page merely placed on the desk.

School scenes become evergreen only through a deliberate non-October placement and copy variant. Reuse their stable identity if the intended policy is once-ever; do not accidentally repeat an October introduction under a different ID.

## Weekly crossings: offering and returning are different states

| ID suffix (`count-unbound.mission.`) | First-offer window | Last accepted live return | Consequence |
|---|---|---|---|
| `hold-place` | October 1–7 | October 7 | Exact true detail; may anchor an explicitly chosen Jump only if available at entry |
| `invitation-without-words` | October 8–14 | October 27 | Actual observation plus optional permission to quote; may shape the invitation |
| `other-side` | October 15–21 | October 27 | Actual reverse-side finding; gives Penny an observation to investigate |
| `go-back-once` | October 22–31 | October 31 | Actual revisitation; two dated reader sentences facing each other |

Closing an offer window retires the unsolicited invitation. An already accepted mission needs a separate return route through its later deadline. A phase-only gate cannot express both states; Week Two and Week Three accepted returns cross into CLIMAX. Extend the existing mission/receipt seam instead of loosening the first-offer gate for everyone. Keep should end an offer, not mark real-world fieldwork complete. Trash must not earn evidence or resurrect the invitation under another surface ID. Explicit Undo/reopen needs its own behavior and tests.

No return deadline forces someone to perform an activity. A late real sentence remains ordinary reader work; it cannot retroactively alter the October 28 ending. A missed week does not block later weeks.

## Temporary media and removal

Foreshadow is September 24–30: at most two hints, no bite, living anchor, or future ending. Live offers stop November 1. Residue is November 1–7: at most two explicitly authored reactions, receipt or rumor as appropriate; no new participation. November 8–30 is sealed. The public Casebook appears December 1. Those two residue atoms still need distinct authored copy and IDs; do not leave all October media running for another week.

Keep the small-media native references in the [recording and marginalia sheet](count-unbound-media-production.md). No month-specific Radio clip belongs in an evergreen station's unrestricted banter array. No directed October mark belongs in the global random marginalia pool.

At a boundary, stop eligibility immediately using the local clock. Then invalidate queued offers, injected decorations, delayed Radio breaks, and open action sheets. Prune eligible managed files separately. `retiresAt` lets speech and live-only art leave November 1 while a small lifecycle/residue pack remains until November 8. Split files accordingly; deleting a whole pack on November 1 would also delete its residue definitions. Do not retire a media file while a retained pack still requires it.

**Still missing:** Radio keeps an eligibility snapshot, including a pending banter across an interstitial. It needs a fresh gate/receipt check at actual playback. Directed marginalia writes attachment metadata onto a candidate; cached decorations need expiry/revocation cleanup without deleting the underlying reader page. The orphan-candidate fix is only one part of this. Track original decoration metadata so removing a temporary mark restores any prior dressing.

Pagewright's permanent cabinet and kept pages have a different lifetime from unsolicited monthly overlays. Freeze the selected art/audio-derived caption needed by a kept artifact into its retained representation before pruning the original file. Verify the live folio, Keep, archive reader, PDF compositor, and bound edition; a surviving metadata path to a deleted PNG is not preservation. Temporary downloaded audio need not become permanently replayable just because its transcript appeared in a kept page.

The new retirement pass works with a verified plan even if replacement assets fail to download. If neither a usable cached signed manifest nor delivery configuration exists, it cannot invent a pruning plan. Atom gates must still prevent expired content surfacing offline. Longer-term, persist verified retirement timestamps with installed assets so clock-based cleanup can run independently of configuration changes.

## Story mechanisms still needed before release

- **Authored Book Jump:** reuse the actual session and return mechanics with fixed authored nodes and supervised policy. Existing active Jump survives; offer the outside-report path. The Sunday scene has more than one decision point; one `AuthoredStoryScene` choice array does not implement it.
- **Fact receipts and branch commits:** distinguish desk delivery, opened text, witnessed scene node, chosen action, completed scene, and public report. Keep alone must not imply all choices occurred. Persist choice plus consequence idempotently before advancing the node. Reopening or reinstalling must not award the effect twice.
- **Nightly braid:** include encountered story turns and exact lived returns in the existing braid context; mark coverage only when the saved braid wins. A story-only evening, cancellation, rewrite, and midnight crossing all need coverage behavior. Active phase text must not leak unencountered plot or a rival's private feelings.
- **Public and private endings:** everyone shares Dracula's return, Serenity's Nightbound naming, and the Protocols. Personal method, relic, invitation quotation, and future romance require their own evidence. Never infer a chosen ending from touch count alone.
- **Early closure:** the calendar ends pressure for everyone; a reader finishing an authored branch earlier needs a run-scoped conclusion receipt that closes remaining live offers without pretending the public date advanced. Do not use deleting a downloaded file as the narrative ending signal.
- **Durable continuity:** preserve Nightbound, Protocols, and private relationship/choice history after runtime pack removal. Their canonical IDs and successor-month dependencies must outlive the source files. Export only encountered private material; public Casebook history must not expose somebody else's romance route.
- **Late/absent readers:** freeze safe history even when someone returns after the whole month or loses access near the boundary. Reconcile before pruning definitions. Joining in the final week opens the current story with a report, not four weeks of homework.
- **Release pipeline:** serialize and validate the Count native pack, resolve every media reference, run synthetic-clock personas, sign the delivery manifest, publish behind the chosen access policy, and test migration/version compatibility. Assets/copy are not “ready” solely because a document contains them.

## Required verification when builds are authorized

Exercise dates just before, at, and after each opening/closing boundary, including midnight, offline foreground, and a pending Radio interstitial. Test no subscription, digital only, physical+digital only, both, expiration/refund, and an individual pack purchase. Exercise Keep, Trash, explicit Undo, app restart, pack version update, repeated action commit, late mission return, incomplete Jump, and missed climax. Compare participant, observer, late subscriber, and lapsed subscriber histories. Finally inspect the actual folio and one rendered physical edition after temporary files have been pruned.
