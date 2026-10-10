# DESIGN.md — ReEnchanted launch video

Brand cheat sheet for a 60s launch trailer. Mood: an enchanted almanac at night —
deep cosmic navy/black, warm parchment surfaces, gold candlelight, a little fae shimmer.
Literary, hand-made, intimate. NOT slick SaaS, NOT Disney-cute. The older, quieter kind of magic.

## Color palette
- `--night: #070611` — primary background (deep near-black indigo)
- `--night-2: #0C0A16` / `#150F23` — layered panels, vignette depth
- `--parchment: #FDF4E2` — light surface / "kept page" cream
- `--parchment-2: #F3E4BF` — secondary parchment
- `--gold: #FFC874` — headline accent, candlelight (primary brand accent)
- `--gold-deep: #C9883F` — gold borders, ornaments
- `--gold-soft: #FFD89A` — glow highlights
- `--teal: #4CC0BD` — secondary accent (weather/system labels, "the Book reads it")
- `--violet: #8A72C4` — tertiary accent (fae / belief)
- `--ink: #2A2014` / `#241A0D` — text on parchment

Backgrounds are dark night by default; parchment used for "kept page" / quote / manifesto moments. Gold is reserved for headlines and glows — don't flood it.

## Typography
- **Fraunces** (serif, weights 400/600/800) — ALL display headlines. Big, warm, literary. This is the brand voice. Use 800 for hero, 600 for section heads. Slight optical italics feel right for pull-quotes.
- **Inter** (sans, 400–800) — body copy, labels, UI chrome, captions, eyebrows (uppercase, letter-spaced).
- Eyebrows: Inter 600, uppercase, ~0.18em tracking, gold or teal.

## Component styles
- Phone screens are real portrait captures (~590×1280) — present in subtle dark device frames with a soft gold rim-glow, gentle float/parallax. Don't crop the status bar awkwardly; mask top/bottom with vignette.
- "Kept page" cards: parchment with a faint deckled edge + soft drop shadow, small ✦ gold mark.
- Glows are radial, warm gold, low opacity — candle not neon.
- Ornaments: ✦ star, thin gold hairline rules, compass/almanac motifs.
- Border radius: generous (16–28px) on cards; phones keep their native radius.

## Do / Don't
- DO let type breathe on near-black; DO use slow, drifting motion (the Book "turns when you do"); DO punctuate real interactions with the actual game SFX.
- DO keep dust/star particles subtle and warm.
- DON'T use cold blue tech gradients, hard neon, fast strobe cuts, or emoji-as-UI.
- DON'T overcrowd a beat — one idea per beat, serif headline + at most one screen.
