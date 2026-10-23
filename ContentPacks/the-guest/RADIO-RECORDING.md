# The Guest recording sheet

Status: scripts written 2026-10-19, nothing recorded yet. The clips aren't in the pack: each goes
into `radioBanters` (with a `media` rule in `issue.json`) only once its take exists, and the
caption must match what was actually said.

Use the existing character voices. Record speech separately from effects; stage directions are
not spoken. Deliver each take as `the-guest.audio.<name>.m4a` into `ContentPacks/the-guest/audio/`.
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
