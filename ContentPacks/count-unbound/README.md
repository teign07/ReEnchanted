# The Count Unbound: implementation draft

This is an unpublished partial October issue. The editorial source is
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
| After the last lesson | Oct 30–31 | Proposed November occasion, not a confirmed pairing |

The supervised Jump uses the real BookJumpEngine and expires at the start of
October 8. The class ribbon works without a personal finding. Selected anchors
come from actual recent Reader sentence contributions. Saved nodes resume their
chosen route; Keep and Trash retire content through durable receipts.

Crossing acceptance never invents a completed observation. Kept returns retain
the authored acknowledgement. The climax follows completed same-issue/same-run
finding evidence to its actual Reader sentence, quoting it once. Missing or
unavailable evidence uses Ambrose's empty chair. A preparation interpretation
changes the fictional threshold, never the observation. Saved strategy maps
Terms to Terms, Hunt to Rule, and Gambit to Ruse; absent strategy leaves all
three final methods available.

The pack requires runtime 8 for directed, phase-spanning marginalia; runtime 7
first added the opened ending's separate continuation window. It also uses cross-scene choice carry-forward, authored finding
insertion, and observation revisits. Older runtimes must not silently ignore
these behaviors.

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
two letters, four class Pages, two November residue Pages, and the Week Three
finding callback from the editorial manuscript. The opening filename is
retained for continuity, although the working draft now extends through the ending.

`public-record.reenchantedcasebook.json` is the authored December 1 public
history. The local casebook adds only proven private participation to that
record. `stage_release_draft.py` gathers the issue, art, casebook, and exact
five recording paths into a schema-2 delivery template. For an offline staging
check with the delivered recordings:

```bash
python3 ContentPacks/count-unbound/stage_release_draft.py \
  --output /private/tmp/count-unbound-draft
```

The draft does not sign, upload, or publish anything. With all atoms ready,
run the shared `prepare_monthly_release.py` and signer
against a fresh staged directory and the chosen private Worker origin.

Still required: finding callbacks in preparations; a full app walkthrough of
the interrupted-climax recovery;
Radio listening/caption and device checks for Bleed, letters, classes, and residue; complete app
walkthroughs, generated-braid quality, and customer physical-edition proof. The
four phase plans and production-count checks are in place; release validation
now passes with the five recordings. Synthetic monthly and seasonal interiors establish
the paired-observation layout, and older kept observations are searchable. The pack
remains unpublished despite passing full-issue release validation. It is neither bundled
nor remotely published. Local StoreKit rehearsals are not App Store billing
verification and create no real charge.
