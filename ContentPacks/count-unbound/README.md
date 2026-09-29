# The Count Unbound: published October issue

Published to the monthly shelf on September 27, 2026 as `count-unbound-2026-10`.
The signed manifest and all 37 currently available Reader downloads match the
release. The editorial source is
`docs/count-unbound-creator-pack.md`; the September 20 product decision supersedes
its extra sentence-permission controls: submitting a sentence makes it material
for the Reader's story, braid, and printed books. Reader words and Book-authored
fiction retain separate provenance.

## Implemented narrative

| Content | Window | Interaction |
| --- | --- | --- |
| The chair that gets there first | Oct 1–7 | Seating choice and continuation |
| A sentence with its coat off | Oct 2–7 | Read/keep |
| The wrong way to the classroom | Oct 3–7 | Route choice and continuation |
| Sunday Book Jump Club | Oct 4–7 | Invitation, safety check, intervention, return; outside route |
| Leave me something to hold | Offer Oct 2–7; return through Oct 31 | First crossing |
| The East Stacks Incident | Oct 8–14 | Three responses and continuation |
| An Invitation Without Words | Offer Oct 8–14; return through Oct 27 | Second crossing and optional fictional interpretation |
| The map with room left | Oct 10–14 | Optional school/relationship scene |
| The Man Reading Himself | Oct 15–17 | One of three questions and shared continuation |
| The other side | Offer Oct 15–21; return through Oct 27 | Third crossing; no earlier attendance required |
| Which preparation? | Oct 18–21 | Terms, Hunt, or Gambit; only chosen preparation visited |
| Go back once | Oct 22–28; return through Oct 31 | Select earlier observation; keep second visit |
| The Wrong Castle | Oct 22–27 | Three rooms and shared discovery |
| A Future Tense | New offer Oct 28; opened route resumes through Oct 31 | Carried strategy, resolution, withdrawal and closing |
| The First Nightbound Morning | Oct 29–31 | Naming and new protocols |
| Threshold Protocols | Oct 30–31 | Full keepable notice; also in The Record |
| Return relic | Oct 30–31 | One method-specific trace, only after a lived Weeks One–Three finding and the encountered ending |
| The two looks | Oct 30–31 | One response quoting the actual Week Four sentence pair after Nightbound |
| After the last lesson | Oct 30–31 | Proposed November occasion, not a confirmed pairing |
| An evening in November | Nov 1–7 residue | Only the suggested occasion opens; one further choice records its consequence |

The supervised Jump uses the real BookJumpEngine and expires at the start of
October 8. Its unfinished invitation gets a fresh automatic offer each day from
October 4 through October 7; merely serving or opening it does not retire it.
Completion or explicit dismissal closes it. Each node offers once per day, while
node advancement can continue immediately in the same sitting. The class ribbon
works without a personal finding. Selected anchors
come from actual recent Reader sentence contributions. Saved nodes resume their
chosen route; Keep and Trash retire content through durable receipts.

Crossing acceptance never invents a completed observation. Kept returns retain
the authored acknowledgement. The climax follows completed same-issue/same-run
finding evidence to its actual Reader sentence, quoting it once. Missing or
unavailable evidence uses Ambrose's empty chair. A preparation interpretation
changes the fictional threshold, never the observation. Saved strategy maps
Terms to Terms, Hunt to Rule, and Gambit to Ruse; absent strategy leaves all
three final methods available.

Earlier revisions introduced the opened ending's continuation window (runtime
7) and directed, phase-spanning marginalia (runtime 8). The pack also uses
cross-scene choice carry-forward, authored finding insertion, and observation
revisits. Older runtimes must not silently ignore these behaviors.

Runtime 9 introduced the finding-based Gambit option, which appears only
while its kept Reader sentence is available; the later two-looks leaf quotes
only an actual paired return. The three relic leaves require a completed
pre-climax finding and the corresponding final method. The October suggestion
carries to one November residue scene without deciding Serenity's partner.
This issue now requires runtime 10 so a sentence kept directly from a mission
return is archived as Reader-authored evidence for those later callbacks.
`paper.editionplay.json` and its generated, path-verified maze are delivered
as small publication assets, retained after the live issue retires. The weekly
premiere and October monthly edition may
bind them; the monthly book also receives a writable personal threshold leaf.
The definitions freeze into bound editions before temporary files retire.

## October marginalia cabinet

`margins.reenchantedpack.json` now holds two kinds of art in the same native
cabinet. Eight handwritten Count notes are `directedOnly` and appear only at
their story beats. Twenty transparent October drawings are available from the
first through the last day of October, with no story or Pagewright achievement
gate: bat, black cat, witch hat, two pumpkins, lantern, broom, cauldron,
spiderweb, candle, key, crow, moth, crescent moon, oak leaf, maple leaf, acorn,
apple, mushroom, and marigold. Pagewright files them on **This Month** and
labels their issue; the ordinary leaf decorator and edition marginalia composer
may place them only on October leaves. The marks are restrained to existing
collision-safe leaf slots; not every leaf receives one.

`make_seasonal_marginalia.py` deterministically renders the twenty 220px PNGs,
the contact sheet, and the corresponding native cabinet entries. Each PNG's
media ID is `count-unbound.seasonal.<filename-stem>`. A signed issue delivery
must list all twenty as media alongside the page-archetype pack, with the same
scope and compatible retirement dates. The original eight directed notes need
their separate `count-unbound.mark.*` media IDs. No monthly issue is bundled or
published by this source change. Retaining October art for later unbound
seasonal or annual composition still requires a separate archival delivery
decision; kept decorated Pages already preserve their actual art bytes.

## Verification and release boundary

`REHEARSAL.md` separates core tests, builds, simulator UI evidence, and unresolved
interaction checks. `IMPLEMENTATION.md` tracks outstanding production work.
`RADIO-RECORDING.md` contains the five authored recording scripts; the five
compressed recordings are in `audio/` and their content atoms are ready.
`complete_small_media.py` synchronizes the four Bleed reports,
two letters, four class Pages, two November residue notices, the carried November occasion, and the Week Three
finding callback from the editorial manuscript. The opening filename is
retained for continuity, although the working draft now extends through the ending.

The Academy's public account of the run is the event's `record` inside
`opening.reenchantedevents.json`; it binds into October's edition as The
Record, and a Reader who took part gets their receipt beside it.
`stage_release_draft.py` gathers the issue, art, and exact
five recording paths into a schema-2 delivery template. For an offline staging
check with the delivered recordings:

```bash
python3 ContentPacks/count-unbound/stage_release_draft.py \
  --output /private/tmp/count-unbound-draft
```

The draft does not sign, upload, or publish anything. With all atoms ready,
run the shared `prepare_monthly_release.py` and signer
against a fresh staged directory and the chosen private Worker origin.

The September 27 signed candidate passed full-issue release validation and the
publisher dry run verifies all 38 assets. Production Gemma has generated a Count
braid on Rabbit; its Reader sentence and authored passages survived an isolated
SwiftData save/reload and the app's weekly/monthly/seasonal/annual PDF writers.
Exact protected-passage duplication discovered there is fixed and covered by a
regression test. See `REHEARSAL.md` for the distinction between new inference
and the publication-only replay, and for rendered-page evidence.

The five authored Radio breaks may recur with regular station mixing during
their own windows; a one-hour cooldown prevents immediate repetition. Wicker's
repeat and expiry passed a simulator walkthrough. The combined September 27
Release player, including the latest Curator and print changes, is installed
and visibly launched on Rabbit. A physical listening review remains open.

September 27 ordinary-discovery QA promoted the Sunday Book Jump to the issue's
milestone and repaired Curator reservation and launch stabilization. The current
pack SHA-256 is `7fce1b1ef2bbc4935322c0ffa951db9b567d40c0e8f86b12c42800f88c1056c6`;
the matching candidate is now signed at
`~/.reenchanted-publishing/releases/2026-09-27-count-unbound-2026-10-candidate`.
Its runtime asset matches the source byte for byte and was published with the
other 37 signed assets on September 27. The playable
Sunday entry reached the ninth Page of a fresh post-guidance QA folio through
ordinary page turns, with both entry choices available. See `REHEARSAL.md` for
the temporary calendar shift and limits of that proof.

Terms/Hunt finding callbacks, carried climax choices, and the Terms/Rule relics
now pass isolated app walkthroughs, including Keep and retirement on relaunch.
The actual saved callbacks and relics also pass the app's four edition PDF writers
and rendered-page review. That proof repaired duplicate event prose, background
scraps crossing narrow print text, long-story clipping, and crowded weekly excerpts.
Remaining Reader follow-up: repeated-day missed-beat behavior and human listening
to the Count Radio recordings on a device. Sunday, Monday, and the closing
boundary have app evidence. Playback, fallback, repeat, and
expiry have already passed simulator rehearsals. The ordinary Reader-operated
nightly save now passes in an isolated two-day QA library; sustained October
cadence remains unproven.
One fresh Release fixture on Rabbit took 29.7 seconds for Gemma generation and
32.2 seconds through archive and PDF exports, with nominal thermal state. This
does not establish sustained multi-night performance. Customer manufacturing proof belongs to physical-publishing
readiness; no customer print is established by the local PDFs. The pack is
remotely published and is not bundled into the app. This content publication
does not release the app to the App Store or enable live billing. Local StoreKit rehearsals are not App Store billing
verification and create no real charge.
