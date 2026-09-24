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
and casebook dates are derived from it for the manifest, so the app and the
shelf never disagree about when an issue is live.

## 2. Write it

The pack format and the placement contract are in
[monthly-content-runtime.md](monthly-content-runtime.md) and
[count-unbound-integration.md](count-unbound-integration.md); October
(`ContentPacks/count-unbound`) is the worked example of every channel. Media
references use `{{asset-path:<id>}}` and resolve through the `media` rules and the
`audio.files` recording sheet in `issue.json`.

## 3. Rehearse the whole shelf

```bash
python3 scripts/monthly_issue.py rehearse ContentPacks/count-unbound ContentPacks/winter-lantern
```

List **every issue still on the shelf**, not just the new one: the delivery
manifest is the whole shelf, and an issue dropped from it stops being served
(including its casebook). The rehearsal stages, prepares and signs with a
throwaway key, then serves the result through the real Worker code at each
issue's foreshadow, live, residue, after-residue and casebook edges, checking
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
- A casebook whose `publishedAt` is not on its calendar day, or whose pack or
  run doesn't match.
- Overlapping live windows, unsafe asset IDs, wrong file suffixes, and changed
  bytes under a published asset ID.
- A signature that doesn't verify against the app's public key, or an asset
  whose size or digest differs from the manifest (publish script).
