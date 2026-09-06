# The Count Unbound: Radio and marginalia production

5 September 2026. Copy from the [revised manuscript](count-unbound-creator-pack.md). These are recording and art specifications, **not installed assets**. [Runtime integration board](count-unbound-integration.md) defines access and retirement. Each clip and mark must be a native payload referenced by its issue atom; do not add it to an unrestricted evergreen pool.

## Radio recording handoff

Record one final file per row. The station and character IDs below exist in the source. Choose the existing character's voice in ElevenLabs; no voice IDs have been guessed and no paid generation has been requested. Paste only the quoted spoken text. Directions and effects belong in production, not in the spoken script.

Use the established MP3 or M4A workflow. Preserve a dry voice master, then make the final mixed clip; keep an exact caption transcript. Validate intelligibility against neighboring station audio on device. Only `four-came-home` requires stereo movement; voice itself can stay centered. Do not bake a station interstitial or the following song into a Count clip.

Every clip is once per issue/run, recorded on actual playback, never on selection into the queue. The existing fallback uses a short caption interval; verify that it is readable for these complete scripts. Recording availability and caption availability need distinct acceptance checks. A caption must contain the actual lines, not “Unscheduled banter clip 3.”

| Content / banter ID | Station ID | Speaker | Final export filename | Placement / closing trigger |
|---|---|---|---|---|
| `count-unbound.radio.thornwave-corners` | `thornwave` | Wicker Eddies (`wicker-eddies`) | `DJ_thornwave_count_unbound_corners_01.mp3` | Foreshadow September 24–30; expires October 1 |
| `count-unbound.radio.four-came-home` | `midnight-bindery` | Vivian Villanelle (`professor-vivian-villanelle`) | `DJ_midnight_bindery_count_unbound_four_home_01.mp3` | SETUP October 4–7, after Jump or safe report; expires before incident |
| `count-unbound.radio.serenity-awake` | `fae-fi` | Penny Blackletter (`penny-blackletter`) | `DJ_faefi_count_unbound_serenity_awake_01.mp3` | BUILDUP October 8–14, after incident or report; expires October 15 |
| `count-unbound.radio.wicker-one-sentence` | `thornwave` | Wicker Eddies (`wicker-eddies`) | `DJ_thornwave_count_unbound_one_sentence_01.mp3` | CLIMAX October 22–27, after wrong castle or report; expires October 28 |
| `count-unbound.radio.protocols` | `fae-fi` | Penny Blackletter (`penny-blackletter`) | `DJ_faefi_count_unbound_protocols_01.mp3` | AFTERMATH October 29–31, after naming or report; expires November 1 |

The manuscript names Midnight Bindery but not its speaker; Vivian is selected here because she is that station's registered host. This is a production assignment, not new plot. Midnight Bindery currently lives in `academy-night-band`; confirm that both subscription types expose the station so this clip does not become unreachable behind a second gate. No plot-critical fact may exist only on a station the Reader may never tune.

### DJ_thornwave_count_unbound_corners_01

Wicker: lightly amused, talking around an inconvenience. Nothing ominous; he does not know what the Jump will cause.

> Thornwave. They've padded the corners in Book Jumping again. Bring your elbows. This next one still has something to knock against.

Category: `gossip`. No effects required.

### DJ_midnight_bindery_count_unbound_four_home_01

Vivian: an ordinary, precise end-of-evening check. The interruption is small enough that listeners might lean closer.

> The listed names are home. The ribbons are tied. The source is shut.

Production: one footstep crosses the stereo field; paper rustles. Leave a brief listening pause.

> Hold on.

Category: `news`. Caption: “The listed names are home. The ribbons are tied. The source is shut. [A footstep. Paper rustles.] Hold on.” Do not record the bracketed caption as speech.

### DJ_faefi_count_unbound_serenity_awake_01

Penny: factual, carrying relief in the particulars. An Academy notice, without a dramatic bedside whisper.

> Serenity's awake. She's asked for her map and something that isn't soup. The East Stacks are closed. Send reports to me. Leave the Kitchens door clear.

Category: `news`. No effects required.

### DJ_thornwave_count_unbound_one_sentence_01

Wicker: makes himself say the whole admission. Let the first three sentences land without an ironic smile.

> I wrote the sentence. It's still there. Penny's keeping the original.

Production: a pause long enough for a chair to move; a restrained chair sound, if used, stays below the voice.

> Here's the track.

Category: `news`. The next track comes from the ordinary station queue, not a hardcoded song. Caption includes “[A pause.]” between the two spoken sections.

### DJ_faefi_count_unbound_protocols_01

Penny: precise about whose word Nightbound is. A filed notice with a practical final instruction.

> The Count's back in his source. Serenity has chosen Nightbound. I've checked the spelling with her. The new Jump notice is up in the Vault. Read the back.

Category: `news`. No effects required.

### Packaging and playback contract

For each row create an `AuthoredRadioBanter` with the exact atom ID, Count pack/event IDs, existing `stationID`, and a `RadioBanter` with the same ID, category, full caption, and a modest weight. Use native issue placement and receipt dependencies for spoiler gating; use `RadioBanter.Conditions` opening/closing instants as an additional playback-time boundary. Keep the time convention consistent with the issue publication policy.

The signed delivery manifest gets one `kind: media`, `scope: runtime` asset per final file, with exact bytes/hash. Native `banter.assetName` is `{{asset-path:MEDIA_ASSET_ID}}`; materialization supplies the complete managed file path. The new managed-audio lookup consumes that path. Do not append a second `.mp3` to the materialized value. Use a separate media ID such as `count-unbound.audio.protocols`, distinct from the stable content ID whose occurrence receipts survive a rerecording.

An old live clip should be excluded from eligibility at the end of its window even if the file remains for packaging reasons. `retiresAt` may delete it earlier than residue end only after all retained pack references are coordinated. Revalidate the queued clip at actual playout; this remains an implementation task. Replacing a recording/version must not make its content ID play again to someone who already heard it. A skip, failed audio decode, or caption-only presentation needs an explicit receipt policy before release; the current player marks `.played` before attempting audio.

## Marginalia art handoff

Eight directed issue marks. Their text is already authored. Create transparent art with the existing marginalia pack conventions, and inspect at actual folio size before marking ready. The Book's handwriting should feel physical and impatient, legible, never like a dashboard label. Do not ask generated art to carry tiny text reliably: typeset/compose the exact text through the existing renderer where possible.

| Stable mark ID suffix (`count-unbound.margin.`) | Exact text | Art direction | Gate / expiry |
|---|---|---|---|
| `listening-door` | Some doors have started listening back. | A thin door outline, one edge slightly lifted like an ear | One of the two foreshadow hints, September 24–30; no Dracula shape |
| `count-shadows` | Count names. Count shadows. Do both. | A neat row of ticks with one detached dark stroke | October 4–7, after Jump/report; stop when the incident is known |
| `complete-sits-down` | The list is full. Look under it. | A roster corner raised by a tiny drawn chair leg | October 8–21, after the flawed roster is known |
| `person-not-clue` | Put the map down. Ask Serenity. | A pencil stopped beside a folded map, space left clear | October 8–21, after incident/report; attach near investigation, not personal-health writing |
| `closed-books-loud` | I heard that one. It's shut. | One shut book with a small pressure line under its cover | October 15–21, after meeting/report |
| `three-books` | Three books want this corridor moved. None will take it. | Three book corners tugging at one crooked floor line | October 22–27, after wrong castle/report |
| `invitation-furniture` | The chair's asking without a mouth. | A chair turned towards the blank writing space | October 8–27; invitation lesson/finding known; cross-phase placement, one occurrence |
| `still-serenity` | NIGHTBOUND. Serenity's handwriting. Leave it that way. | Preserve a deliberate handwritten name; no correction marks | October 29–31, after naming/report; not an automatic November overlay |

Use native `AuthoredMarginaliaMark` fields: stable `id`, Count `packID`/`eventID`, actual `assetPackID`/`assetID`, target page types/source IDs/tags. The real asset names must match the art catalog; do not mark nonexistent assets ready. Use at most one issue mark per nine-leaf block, as the dresser already enforces. Occurrence defaults to once per run. The invitation-furniture mark needs a live-day range across BUILDUP and CLIMAX rather than two phase atoms with new identities.

A mark's `.delivered` receipt records that it reached a page, not that the Reader noticed, endorsed, or acted on it. Never use that receipt to award participation, romance, or a relic. Preserve a kept page's chosen appearance before retiring live media. The separate residue allowance does not keep these eight marks alive automatically.

No new images or audio were generated in this pass.
