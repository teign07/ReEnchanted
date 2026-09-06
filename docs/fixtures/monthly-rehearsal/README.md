# The Door Between Leaves — Issue Zero

A complete native pack fixture for the monthly-content foundation. It is **not** included in app resources, registered as bundled content, installed, or published. Its one-shot clock is November 2027; tests use UTC. Production event calendars use the Reader's calendar, so staging must align its signed delivery envelope with the chosen rehearsal clock.

## Files

- `school-door.reenchantedevents.json`: four phases, five scenes, seven manifest atoms. The lesson has an entry, two choices, and two authored return leaves. The separate crossing opens during Setup and accepts a return through live-day index 27.
- `delivery-manifest.json`: unsigned test payload with the fixture's actual SHA-256 and byte count. `rehearsal.invalid` is intentionally non-resolving. The Swift installer test creates an ephemeral signing key in memory and supplies fixture bytes through the real installer's fetch seam; it does not contact a service or write production keys.
- `personas.json`: active pin/thread branches, late arrival, exit during a subscription lapse followed by regrant, Trash, and absence.
- `production.csv`: exported IDs, placement, occurrence, gates, dependencies, crossing-return data, and the full Radio caption.

The Radio line is deliberately caption-only. Marginalia reuses a bundled core mark. This exercises those native instruments without requiring ElevenLabs recordings or new art. Actual audio playback, downloaded-image rendering, and print/export layout still need their own device/artifact checks.

## Expected routes

| Reader | Expected observations |
| --- | --- |
| Pin | `enter → choose(pin) → pin-home`; only the pin passage reaches the braid |
| Thread | `enter → choose(thread) → thread-home`; only the thread passage reaches the braid |
| Crossing | Accepted once from November 2; no completed return until November 10 |
| Late arrival | November 22 assembly carries the public lesson report; no invented node, choice, jump, or participation |
| Exit during lapse | Enter November 8 at 09:00; lapse at noon; leave at 18:00; regrant November 9 preserves dismissal; later assembly can report the missed lesson |
| Trash | Lesson is dismissed without committing its entry; later assembly uses authored public history |
| Absent | No delivered or participation receipts |
| Ending | Keeping the ending from November 29 concludes live delivery; already bound passages remain |

`minimumLiveDay`, `maximumLiveDay`, and `reportAfterLiveDay` use zero-based day indexes. Gates are inclusive at their numeric bounds; catch-up begins after its stated day. Optional `missionReturnNotBefore` is the synthetic Reader's decision to bring back evidence, not a new content gate.

## Checks that do not build

From the repository root:

```sh
python3 scripts/monthly_pack.py check docs/fixtures/monthly-rehearsal/school-door.reenchantedevents.json --release
python3 scripts/monthly_pack.py inventory docs/fixtures/monthly-rehearsal/school-door.reenchantedevents.json --output /private/tmp/monthly-rehearsal-production.csv
python3 -m unittest discover -s scripts/tests -p 'test_monthly_pack.py' -v
```

Changing the fixture bytes requires updating its delivery asset's hash and byte count. Use `monthly_pack.py asset FILE`; the Python regression verifies agreement. The Python preflight checks structure and references; it is not a Swift decoder or a full native release validator.

## Native rehearsal, when a build is authorized

Run `MonthlyIssueRehearsalTests` alongside `MonthlyIssueNativeContentTests`, `MonthlyIssueAuthoringTests`, `AuthoredContentTests`, and the monthly-delivery cases in `WorldSystemsTests` using the repository's test runner. These tests decode the checked-in pack, apply native release validation, use the production Page compositor and node-commit method, resume serialized progress, exercise signed installation/local retirement, and inspect selected-branch braid receipts.

Optionally set `REENCHANTED_REHEARSAL_REPORT_DIR` to an output directory before running the tests. The persona test writes six JSON reports containing per-sample eligibility, delivered/accepted/completed/reported/node/braid receipts, final jump state, and the authored story-night pages. These are synthetic fixtures, never actual Reader evidence. No output files are written unless this variable is set.

`MonthlyIssueAuthoringSimulator.run` accepts initial content/lifecycle ledgers, jump state, and braid days for a relaunch rehearsal. Optional persona fields select node choices, delay real-world evidence, choose Trash, model caption-only Radio, and model a lapse/regrant or early exit. It runs in memory and never installs content or updates the app vault.

Status, 5 September 2026: native release validation, both branch rehearsals, saved-state recovery, signed installation/retirement, and kept downloaded-art retention passed. The first native run caught omitted coverage requirements that Python had missed; the fixture now declares its production counts and preflight rejects that omission. The iOS Debug app build passed with signing disabled. No device walkthrough, real audio playout, model literary rehearsal, or print proof has occurred. See [verification evidence](../../monthly-content-verification.md).
