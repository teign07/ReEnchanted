# Monthly issue playbook

From an empty folder to a live issue. Every step but the last is local and
reversible; only `--publish` touches the shelf readers download from.

## 1. Start the month

```bash
python3 scripts/monthly_issue.py new winter-lantern --title "The Winter Lantern" --year 2026 --month 12
```

This makes `ContentPacks/winter-lantern/` from the rehearsal pack that the Swift
suite validates: a world-event pack, `issue.json`, `marginalia/`, `audio/` and a
README checklist. Its story is example material, and every atom starts as
`draft`, so a release refuses it until each one is written and marked `ready`.

The event `calendar` in the pack **is** the schedule: foreshadow, live, residue
dates are derived from it for the manifest, so the app and the
shelf never disagree about when an issue is live.

## 2. Write it

The pack format and the placement contract are in
[monthly-content-runtime.md](monthly-content-runtime.md) and
[count-unbound-integration.md](count-unbound-integration.md); October
(`ContentPacks/count-unbound`) is the worked example of every channel. Media
references use `{{asset-path:<id>}}` and resolve through the `media` rules and the
`audio.files` recording sheet in `issue.json`.

The story happens to the Cast, so write down what each of them carries away:
`castMemories` on scenes, nodes, choices and dated record entries, and
`recalls` where a later scene should remember an earlier month. Every Cast
member on a scene's `castIDs` needs at least one memory from it.
[cast-story-memory.md](cast-story-memory.md) has the contract, and
`CastStoryMemoryTests` holds a pack to it.

## 3. Rehearse the whole shelf

```bash
python3 scripts/monthly_issue.py rehearse ContentPacks/count-unbound ContentPacks/winter-lantern
```

List **every issue still on the shelf**, not just the new one: the delivery
manifest is the whole shelf, and an issue dropped from it stops being served
(including its residue). The rehearsal stages, prepares and signs with a
throwaway key, then serves the result through the real Worker code at each
issue's foreshadow, live, residue and after-residue edges, checking
bytes and timing. Then run the native checks:

```bash
swift test --filter MonthlyIssue
```

## 4. Make the signed candidate

```bash
python3 scripts/monthly_issue.py release ContentPacks/count-unbound ContentPacks/winter-lantern \
  --previous ~/.reenchanted-publishing/releases/<last-published>/manifest.json
```

`--previous` lets the prepare step prove that no published asset ID changed
bytes (an asset ID is an immutable storage key; changed bytes need a new ID) and
report which files are new. The candidate lands in
`~/.reenchanted-publishing/releases/`, signed with the publisher key
(`~/.reenchanted-publishing/monthly-issue-private.key`).

## 5. Publish

```bash
scripts/publish_monthly_release.sh <candidate>            # dry run
scripts/publish_monthly_release.sh <candidate> --publish  # uploads, then reads back live
```

Assets go up first and the signed manifest last. A published manifest can be
replaced by publishing the previous candidate again.

## What the tools refuse

- Any atom not `ready`, or production counts outside an issue's declared
  coverage (`prepare_monthly_release.py`).
- Radio references that differ from the recording sheet, or a missing recording.
- An issue whose event has no `record` (a `historySentence` and at least one
  entry): the edition binds it as The Record.
- Overlapping live windows, unsafe asset IDs, wrong file suffixes, and changed
  bytes under a published asset ID.
- A signature that doesn't verify against the app's public key, or an asset
  whose size or digest differs from the manifest (publish script).

## Running a finished issue again next year

A monthly issue is one authored run (the validator rejects `annual`), so the
second run is a fork with new identity, not a replay:

```bash
python3 scripts/monthly_issue.py reissue ContentPacks/count-unbound --year 2027
```

This copies the pack to `ContentPacks/count-unbound-2027/` and changes only the
year-keyed identity: issue, run, pack and receipt-scope IDs, the shelf's asset IDs
(prefix `count-unbound-2027.`), `startYear`, `issueYear` and `eventStartYear` on
placement triggers, `Month 2026` strings, and file names that carry the year. Scene
and beat IDs keep their names. Then it prints what a script can't judge:

- **Years left in shipped JSON.** Usually generation dates; leave them.
- **Weekday drift.** The calendar dates are fixed but the weekdays move: October 1 is
  a Thursday in 2026 and a Friday in 2027, so there are five Sundays, not four. Every
  `Sunday` in the story text (and every Sunday-pinned window) needs a look.
- **Generators** that hardcode the year (`make_*.py`); only rerun them to regenerate art.

Then `rehearse` the fork and run `swift test --filter MonthlyIssue` (the suite
globs every `ContentPacks/*/issue.json`, so the fork is checked in place). Do the
fork in late summer, not on the day: weekday drift and engine drift are the
work, and both are cheaper to find in August. Keep the 2026 folder untouched and
in the tree; its tests are what tell you the engine still reads the pack.
