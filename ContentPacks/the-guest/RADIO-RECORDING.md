# The Guest recording sheet

Status: all five recorded by bj in ElevenLabs on 2026-10-25 (originals on his Desktop), converted
to 64 kbps mono MP3 leveled to about -18 LUFS in `audio/`, and wired in through
`content_radio.py`: `radioBanters`, one manifest atom each, and the `audio` rule in `issue.json`.
Captions are the scripts exactly, without the pause tags. Still owed: a listening check on Rabbit.

Use the existing character voices (the same ones as October). Record speech separately from
effects; stage directions are not spoken. Drop each take into `ContentPacks/the-guest/audio/` under
the filename below, in any format ElevenLabs exports; the pack copies are converted to 64 kbps mono
MP3 at 44.1 kHz, leveled to about -18 LUFS, like October's.

| Clip | Voice | Filename | Direction |
| --- | --- | --- | --- |
| forty-cakes | Wicker | `DJ_thornwave_the_guest_forty_cakes_01.mp3` | Amused, a little uneasy under it; the last line is a joke he half means. |
| kitchen-notice | Penny | `DJ_faefi_the_guest_kitchen_notice_01.mp3` | A filed notice, read fast and exact; the bees line deadpan. |
| three-in-the-morning | Euphony | `DJ_mothlight_the_guest_three_am_01.mp3` | Quiet, late, warm; the last line slower, nearly a lullaby, still a warning. |
| wish | Wicker | `DJ_thornwave_the_guest_wish_01.mp3` | Pleased with himself, hiding it; "So do the rest of us" lands soft. |
| the-bowl-is-washed | Penny | `DJ_faefi_the_guest_bowl_washed_01.mp3` | Relief in the particulars; brisk on Trencher's line. |

The foreshadow clip (forty-cakes) plays Oct 28–31, so it has to be in the pack published by Oct 27.
The stable content ID (`the-guest.radio.<name>`) stays in the JSON; the `the-guest.audio.*` ID
identifies the replaceable recording.

**`the-guest.radio.forty-cakes` — Wicker on Thornwave, foreshadow:** "Thornwave. Trencher's
baking soul cakes. Forty of them. I asked him who they're for. He said 'whoever knocks'. Nobody
knocks on the Kitchens. There's no door there anybody uses." A beat. "Here's one with a bolt on
it."

**`the-guest.radio.kitchen-notice` — Penny on Fae-Fi, guest-right:** "Fae-Fi, and a notice from
the Kitchens. There's a new kitchen hand. Don't thank it. Don't leave it clothes. If you really
have to say something, say you're grateful, and then go and do the washing up. That's it. That's
the notice. Here's a song about bees."

**`the-guest.radio.three-in-the-morning` — Euphony on Mothlight Beats, the offer:** "Mothlight.
It's very late. The Kitchens' light is on again. If you're down there at this hour, and something
at the sink is kind enough to offer you anything at all, finish your soup first." A pause.
"Always finish your soup."

**`the-guest.radio.wish` — Wicker on Thornwave, after Stir-up Sunday:** "I stirred the pudding.
I made a wish. Not telling you. Penny says it has to hang in a cloth till Christmas before it
counts." A beat. "So do the rest of us. Here's the track."

**`the-guest.radio.the-bowl-is-washed` — Penny on Fae-Fi, residue:** "Fae-Fi. The bowl's back on
the dresser, washed and dry. Nobody saw who washed it. Trencher says that's how it's meant to be,
and he'd like his kitchen back now, please. Here's something warm."

## Integration boundaries

| Clip | Station | Gate before playback | Remove live offer |
| --- | --- | --- | --- |
| forty-cakes | `thornwave` | Foreshadow window only | When the live event begins |
| kitchen-notice | `fae-fi` | `guest-right` phase | End of `the-offer` |
| three-in-the-morning | `mothlight-beats` | `the-offer` phase, night hours | End of `the-offer` |
| wish | `thornwave` | Stir-up Sunday completed or its report received | End of issue |
| the-bowl-is-washed | `fae-fi` | Residue only | End of residue |

Each line is spoiler-safe for every ending: the residue clip doesn't say whether the Guest went
home, stayed, or went back to the Court, and Serenity's choice is never mentioned on air. Mark
each clip heard through the existing radio receipt path; don't infer it from story attendance.
