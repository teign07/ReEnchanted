# Landing page: social card + performance plan

Goal: when the landing page link is shared on X/iMessage/Discord it renders a proper
preview card, and the page loads ~2.5MB instead of ~8.5MB. **No redesign, no copy
changes, no layout changes.** Every step below is mechanical; follow it literally.

All work happens in `LandingPage/` (plus this doc's verification steps).
**Do not commit or stage anything** — the working tree has unrelated in-flight changes.
Leave the diff for BJ to review.

`SITE_URL` below is `https://reenchanted.app`. **TODO(BJ): replace with the real domain
before deploy if different.** It appears only in the meta block of Task 1, nowhere else.

---

## Task 1 — Fix `<head>` metadata in `LandingPage/index.html`

The head currently has charset, viewport, description, theme-color, title, fonts,
stylesheet (lines 1–16). Make two edits:

**1a.** Replace the title line

```html
<title>ReEnchanted - Real Life, ReEnchanted</title>
```

with

```html
<title>ReEnchanted — a living book for ordinary days</title>
```

**1b.** Immediately AFTER the `<meta name="theme-color" content="#070611">` line, insert:

```html
    <link rel="canonical" href="https://reenchanted.app/">
    <link rel="icon" href="./favicon.svg" type="image/svg+xml">
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="ReEnchanted">
    <meta property="og:title" content="ReEnchanted — a living book for ordinary days">
    <meta property="og:description" content="A free, magical iPhone book that turns the day you actually lived into pages you can keep. Play with pages. Keep some. Read your story.">
    <meta property="og:url" content="https://reenchanted.app/">
    <meta property="og:image" content="https://reenchanted.app/assets/og-card.jpg">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="ReEnchanted — a living book for ordinary days">
    <meta name="twitter:description" content="A free, magical iPhone book that turns the day you actually lived into pages you can keep.">
    <meta name="twitter:image" content="https://reenchanted.app/assets/og-card.jpg">
```

Keep the existing `<meta name="description">` as is.

---

## Task 2 — Create `LandingPage/favicon.svg`

Create the file with exactly this content:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="14" fill="#070611"/>
  <text x="32" y="44" font-size="36" text-anchor="middle" fill="#ffc874">✦</text>
</svg>
```

---

## Task 3 — Generate the OG card image

**3a.** Create `LandingPage/og-card.html` with exactly this content (it reuses the
site's palette and fonts; do not restyle it):

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,600;0,9..144,800;1,9..144,400&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  * { margin: 0; box-sizing: border-box; }
  body {
    width: 1200px; height: 630px; overflow: hidden;
    background: #070611;
    background-image:
      radial-gradient(900px 600px at 12% 8%, rgba(255, 200, 116, 0.14), transparent 60%),
      radial-gradient(700px 500px at 88% 92%, rgba(120, 100, 220, 0.12), transparent 60%);
    display: flex; flex-direction: column; justify-content: center;
    padding: 0 96px;
    font-family: "Fraunces", serif;
  }
  .kicker {
    font-family: "Inter", sans-serif; font-weight: 600; font-size: 22px;
    letter-spacing: 0.28em; text-transform: uppercase; color: #ffc874;
    margin-bottom: 28px;
  }
  h1 {
    font-size: 120px; font-weight: 800; line-height: 1.02; color: #fdf4e2;
  }
  h1 .gold { color: #f5b356; }
  .sub {
    margin-top: 34px; font-size: 34px; font-style: italic; color: #b9b3cd;
  }
  .star { position: absolute; color: #ffc874; opacity: 0.9; }
</style>
</head>
<body>
  <div class="kicker">✦ A living book for ordinary days</div>
  <h1>Real Life,<br><span class="gold">ReEnchanted</span></h1>
  <div class="sub">Play with pages. Keep some. Read your story.</div>
</body>
</html>
```

**3b.** Capture it with headless Chrome (Chrome is installed at this path):

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --window-size=1200,630 --virtual-time-budget=8000 \
  --screenshot="$PWD/LandingPage/assets/og-card-raw.png" \
  "file://$PWD/LandingPage/og-card.html"
```

**3c.** Convert to JPEG and remove the raw PNG:

```bash
cd LandingPage/assets
sips -s format jpeg -s formatOptions 82 og-card-raw.png --out og-card.jpg
rm og-card-raw.png
```

**3d.** Read `assets/og-card.jpg` with the Read tool and confirm it shows the
headline in cream/gold serif on a dark background (i.e., fonts loaded — if the text
rendered in a default serif, re-run 3b with a higher `--virtual-time-budget`).
Keep `og-card.html` in the repo so the card can be regenerated.

---

## Task 4 — Lazy-load below-the-fold images in `LandingPage/index.html`

Rule: every `<img>` tag in `index.html` gets `loading="lazy" decoding="async"` added
to its attributes, EXCEPT these, which must stay eager (do not touch them):

- the six `<img class="hero-screen" ...>` tags
- `assets/screens/keep-page.jpg` and `assets/screens/margins.jpg` (hero float cards)
- the four `assets/glow/*.png` marginalia images near the top
- `<img id="lore-figure-img" ...>` (has no `src`; JS drives it)

Two images already have `loading="lazy"` — don't double-add; just add
`decoding="async"` if missing. Do not change any other attribute, and do not
reorder attributes on lines you touch.

There are ~42 `<img>` tags total, so roughly 30 tags get the attributes.

---

## Task 5 — Compress oversized images

All of these were checked: none has an alpha channel, and every reference lives only
in `index.html` and/or `app.js` (never `styles.css`). Work in
`LandingPage/`.

**5a. Convert big PNGs to resampled JPEGs** (phone screenshots displayed at ≤400 CSS px;
800px wide is retina-safe):

```bash
cd LandingPage
for f in \
  assets/screens/character-zara-finch \
  assets/screens/character-lysander-mosswood \
  assets/screens/character-marginalia-goblin \
  assets/screens/character-wicker-eddies \
  assets/screens/wonder-chapters-core \
  assets/screens/wonder-chapters-rest \
  assets/screens/book-of-you-braid-proof \
  assets/screens/story-page-weather-prose \
  assets/screens/story-page-weather-choices ; do
  sips -s format jpeg -s formatOptions 75 --resampleWidth 800 "$f.png" --out "$f.jpg" && rm "$f.png"
done
```

**5b. Convert the five talisman PNGs to JPEG** (already small in pixels, keep size):

```bash
for f in assets/art/LabyrinthTalismanEmberSeal assets/art/LabyrinthTalismanMossClasp \
         assets/art/LabyrinthTalismanTideGlass assets/art/LabyrinthTalismanWindCipher \
         assets/art/LabyrinthTalismanDuskThorn ; do
  sips -s format jpeg -s formatOptions 78 "$f.png" --out "$f.jpg" && rm "$f.png"
done
```

**5c. Recompress oversized JPEGs in place** (via temp file):

```bash
for f in assets/screens/boggle assets/screens/search-stacks-empty \
         assets/screens/search-stacks-results assets/screens/search-stacks-reading ; do
  sips -s format jpeg -s formatOptions 75 --resampleWidth 800 "$f.jpg" --out "$f.tmp.jpg" \
    && mv "$f.tmp.jpg" "$f.jpg"
done
```

**5d. Update references.** For every basename converted in 5a/5b (14 files), replace
`<basename>.png` with `<basename>.jpg` in BOTH `index.html` and `app.js`. Expected
reference counts (verify after replacing — grep for each basename, there must be zero
`.png` hits left):

| basename | index.html | app.js |
|---|---|---|
| character-zara-finch | 0 | 3 |
| character-lysander-mosswood | 0 | 1 |
| character-marginalia-goblin | 0 | 1 |
| character-wicker-eddies | 0 | 2 |
| wonder-chapters-core | 0 | 1 |
| wonder-chapters-rest | 0 | 2 |
| book-of-you-braid-proof | 1 | 0 |
| story-page-weather-prose | 2 | 1 |
| story-page-weather-choices | 1 | 1 |
| LabyrinthTalisman* (5 files) | 5 total | 5 total |

**5e.** Sanity check: `du -sh assets/screens assets/art` — screens should drop from
~21MB to well under 10MB; no file in either directory should exceed ~300KB except
`assets/glow/parchment-texture.jpg` (leave that one alone; CSS references it).

---

## Task 6 — Verify in the browser

1. Start the preview server: `preview_start` with name `landing`
   (already configured in `.claude/launch.json`).
2. `preview_network` with filter `failed` — must be empty. A 404 here almost
   certainly means a missed `.png → .jpg` reference; fix it in `index.html`/`app.js`
   (never by renaming files back).
3. `preview_console_logs` level `error` — must be empty.
4. `preview_screenshot` — hero must look unchanged (dark background, cream/gold
   "Real Life, ReEnchanted" headline, phone mockups).
5. In `preview_eval`, run
   `performance.getEntriesByType('resource').reduce((a,r)=>a+(r.transferSize||0),0)/1048576`
   — should now be roughly 2–3 (MB), down from 8.5.
6. Scroll checks beyond the hero: known quirk — the capture tool paints black below
   ~800px scroll on this page. That is a tooling artifact, not a bug; verify deep
   sections with `preview_snapshot` (text) instead of screenshots, or by
   `document.querySelector('main').style.transform = 'translateY(-Npx)'` at scroll 0,
   and reset the transform afterwards.
7. The images renamed in Task 5 are used by JS-driven UI (cast/lore figures, wonder
   chapters, boggle demo). After step 2 shows no failures, additionally
   `preview_eval`: `document.querySelectorAll('img')` → confirm no element has
   `naturalWidth === 0` while having a non-empty `src`.

## Out of scope — do not do these

- No shortening/reordering of page sections, no copy edits beyond the `<title>`.
- No changes to `styles.css`.
- No WebP (no encoder on this machine; `sips` can't write it).
- No changes outside `LandingPage/` and this doc.
- No git commits, staging, or branch changes.
