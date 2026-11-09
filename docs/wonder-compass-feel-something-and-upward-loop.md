# Wonder Compass: "feel something" and the upward loop

Applied 2026-11-09 to `Shared/BookReferenceLibrary.json` (`wonderCompass`). Prompted by a GTA 6 hype video that cited three studies the book already used. It also suggested angles the book hadn't taken. Sources were checked against the papers, not the video.

| Location | What changed | Source |
| --- | --- | --- |
| Read This First | After "gray, brittle, and bored": the shock study told in full, then "We’d rather feel pain than feel nothing at all." on its own line, then scrolling as tiny zaps (crumbs). The "three things" list is untouched, since the landing page mirrors it. | Wilson et al., 2014, *Science* |
| Read This First | Before "This tool makes Tuesdays suck less": the Compass is a circle because new places → better days → more new places. | Heller et al., 2020, *Nature Neuroscience* |
| Ch 4A, The Safety Trap | Chosen fear: benign masochism and the haunted-house study (mood lifted most for people who arrived tired, bored or stressed). Hand the Caveman a scare you picked. | Rozin et al., 2013; Kerr, Siegle & Orsini, 2019, *Emotion* |
| Ch 5, N-E-S-W | Main telling of the loop: "Why a loop, and not a list?" First-time places carried the effect over plain variety. It's the Rut's whirlpool spinning the other way, and the Compass hands you a first time every turn. | Heller et al., 2020 |
| Ch 6A, after the color count | The Sky Test: autopilot only looks up for weather. | Book's own practice (leans on Killingsworth & Gilbert, 2010) |
| Ch 10, Numbing vs. Resting | The full shock telling became a callback ("Remember the button from the start of this book?"), keeping the Rest reading: the quiet, not only boredom. | Wilson et al., 2014 |
| Ch 14, the Diagnostic | The game you're good at: practiced tasks invite mind-wandering, so give the game something your hands don't know yet. | Mason et al., 2007, *Science* |
| Ch 22, Novelty Dopamine Boost | It ran both ways; the Four-Hour Vacation is one big, cheap push on the loop. | Heller et al., 2020 |

## Notes & References

- Read This First: added The Shock Study (full citation; 12/18 men, 6/24 women; the authors' reading vs. the book's) and an Upward Loop pointer.
- Chapter 4: added Chosen Fear (Rozin; Kerr: 262 adults, 100-person EEG subsample, no comparison group).
- Chapter 5: added Why the Compass Is a Loop (lagged analyses; correlational; places only; extending to any first time is the book's application).
- Chapter 6: added The Sky Test as the book's practice, not a tested measure.
- Chapter 14: added Practiced Tasks & Mind-Wandering (lab tasks, not games).
- Chapter 22: Heller note corrected. 132 recruited, 122 analyzed. First-time places outpredict variety. Only positive mood moved.

## Verification

- JSON round-trips byte-identically (`indent=2`, `ensure_ascii=False`, trailing newline). Only `body` changed, in seven chapters (Read This First, 4A, 5, 6A, 10, 14, 22) and Notes & References.
- `swift test --filter 'WonderCompassContentsTests|WonderCompassFormattingTests|LoreAndPlateVoiceTests'`: 26 tests, 0 failures.
- No build was run. No previews changed (every addition sits past the stored preview text).
