# Count Unbound recording sheet

Status: five recordings have been delivered, compressed for the monthly pack, and marked `ready`. The issue remains unpublished. The captions still need a listening check against the recorded speech and a device playback rehearsal.
Use the existing character voices. Record speech separately from effects; stage directions are not spoken.
The delivery copies are in `ContentPacks/count-unbound/audio/` with the exact filenames in `docs/count-unbound-media-production.md`. The stable content ID stays in the JSON; the separate `count-unbound.audio.*` ID identifies the replaceable recording. Duration and asset digest come from the delivered files; the final audio URL is assigned only during release preparation.

**`count-unbound.radio.thornwave-corners` — Wicker, foreshadow:** “Thornwave. They've padded the corners in Book Jumping again. Bring your elbows. This next one still has something to knock against.”

**`count-unbound.radio.four-came-home` — Euphony on Mothlight Beats, after the Jump:** “The listed names are home. The ribbons are tied. The source is shut. Hold on.” This is the delivered mono take; no separate footsteps or paper-rustle effects are captioned.

**`count-unbound.radio.serenity-awake` — Penny, after the incident:** “Serenity's awake. She's asked for her map and something that isn't soup. The East Stacks are closed. Send reports to me. Leave the Kitchens door clear.”

**`count-unbound.radio.wicker-one-sentence` — Wicker, after the castle:** “I wrote the sentence. It's still there. Penny's keeping the original.” A pause long enough for a chair to move. “Here's the track.”

**`count-unbound.radio.protocols` — Penny, after naming:** “The Count's back in his source. Serenity has chosen Nightbound. I've checked the spelling with her. The new Jump notice is up in the Vault. Read the back.”

## Integration boundaries

| Clip | Gate required before playback | Remove live offer |
| --- | --- | --- |
| thornwave-corners | Foreshadow window only | When live event begins |
| four-came-home | After committed Jump return or truthful catch-up report | Before East Stacks incident window |
| serenity-awake | East Stacks completed or its report received | End of BUILDUP |
| wicker-one-sentence | Castle completed or its report received | End of CLIMAX |
| protocols | Nightbound naming completed or its report received | End of issue |

The windows and story/report dependencies are now in the manifest. Mark each clip heard through the existing radio receipt path; do not infer it from story attendance. Expiry removes live playback eligibility, not already-kept reader history. Audio, captions, character voice, and receipt attachments still need a final device rehearsal.
