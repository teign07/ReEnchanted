# The Day — plan for the ReEnchanted site

**One continuous scroll through a single day, from before dawn to after midnight.**
The visitor doesn't read about the app. They live one day of it, keep what catches
them, and are handed their own page at the end.

Decided: continuous shaft + an hours rail; the site performs the keep loop for real;
the existing dark lamplight world stays, but the light genuinely travels across the scroll.

---

## 1. The spine

The axis is **time of day**, not depth. Depth is what makes neal.fun/deep-sea work —
the scrollbar means something, so you always know where you are and you want to keep
going. Ours means something better: it ends somewhere emotionally, at the moment the
Book braids the day into a story.

Every feature attaches to the hour where it naturally belongs. Anything that can't
earn an hour gets cut. That edit is the point — the current page is 13,461px of list.

| Hour | Stretch | What the visitor does | Feature it carries |
|------|---------|------------------------|--------------------|
| 05:00 | **Before the light** | Scrolls, and the scroll wakes something | The address. Letters drift; the pixie is asleep |
| 06:30 | **Waking** | Watches the first page arrive | Story pages built from real signals (weather, place) |
| 08:00 | **The first door** | **Keeps a page, or lets it go** | Consent and taste. No streaks, no blank page |
| 10:00 | **The margin answers** | Reads a reply in the Book's hand | The Cast; margin replies at keep |
| 12:00 | **Noon, brightest** | **Writes one true sentence** | Sentence Builder — peak light, peak participation |
| 14:00 | **The wireless** | Turns the dial | Radio: Fae‑Fi, Mothlight, Thornwave, real DJ banter |
| 16:00 | **Without you** | Watches something that isn't about them | World‑led vignettes; the Academy argues; Thorne |
| 18:00 | **The wager** | Is told something true about themselves | FirstWagers, honest claims, Belief |
| 20:00 | **Lamplight** | Watches the braid begin | The nightly braid |
| 22:00 | **Your page** | **Reads the page they made** | Book of You, monthly editions, print |
| 00:00 | **The Book closes** | Leaves, or installs | Colophon, privacy, open source, download |

Roughly 20 viewports — *shorter* than the page we have now, and every screen has a job.

**The visitor's real clock sets where the page opens.** Arrive at 9pm and the site
opens in lamplight. Local signals only, nothing sent. This is the app's own move,
performed before anyone has installed anything.

## 2. The pixie is promoted

Today the spell-field pixie is background decoration. It becomes **the guide** — the
one continuous character, descending the shaft with the visitor.

- Vertical position tracks scroll; it always shares your screen.
- It gathers drifting letters and deposits them in the margin as notes.
- Each hour it does one specific thing (wakes at 05:00, first gather at 06:30,
  carries the kept page to the margin at 08:00, settles into the Book at 00:00).
- At night the letters it touched stay lit.

One continuous character is what makes twenty screens feel like one journey, and it
is the thing nobody can copy — because it is what the product actually *is*:
something that notices you and writes in your margin.

## 3. The keep loop, for real

Not a demo of the loop. The loop.

1. Pages surface as the day runs. Each is built from real, local signals.
2. The visitor keeps or lets go. Letting go costs nothing and is never punished.
3. Kept pages live in `localStorage`. Nothing is sent anywhere — the privacy claim
   is demonstrated rather than asserted.
4. At 20:00 the braid starts. At 22:00 the site hands back **a real page made of
   their own choices**, readable and shareable.
5. The CTA writes itself: *this is one day; the app does this every day.*

Prose assembly is deterministic (same approach as the app's default path) so it is
instant and works offline. No model call, no key, no cost.

## 4. Light

One custom property, `--hour`, driven by `animation-timeline: scroll()`. Every colour
in the document derives from it. Dawn is cold and thin, noon is warm and open,
dusk goes amber, lamplight is a deep pool, midnight is ink with lit letters.

Zero JavaScript for the entire day-cycle — it runs GPU-side and cannot jank.

## 5. The hours rail

A slim vertical clock on the right edge. Shows the hour you're in, lets you jump,
and doubles as the depth gauge that makes a long scroll legible. This is what buys
back the deep links, section anchors, and skimmer tolerance that a pure single
shaft would cost us. Sections stay real HTML, so SEO survives.

## 6. Tech

| Choice | Why |
|--------|-----|
| **CSS scroll-driven animations** (`animation-timeline: scroll()` / `view()`) | Native, ~83% support (Chrome 115+, Safari 18+). The whole day-cycle, free and jank-proof. `@supports` fallback for Firefox: static hour tints, no scrub. |
| **GSAP** (free, all plugins) | The pixie's path and per-hour orchestration, where CSS can't reach. |
| **Lenis** | Weighted scroll. The single biggest "expensive" tell, and it's ~3kb. |
| **localStorage** | Kept pages. Demonstrates the privacy claim. |
| **No three.js** | The material is paper, ink, lamplight. A particle field is the opposite substance and the fastest way to look generically award-y. |
| **No build step** | Matches the current static-file deploy to `teign07/landingpage`. |

Cost: **$0**, except one optional licensed display typeface (~$50–300), which is the
highest-leverage spend available — a face nobody else has is what stops a site
reading as templated.

## 7. Quality floor

- Responsive to 375px; the rail collapses to a thin progress ribbon.
- `prefers-reduced-motion`: the day is already lit, the pixie is at rest, no scrub.
  Content is never gated behind motion.
- Keyboard: every keep/let-go is a real button; the rail is a real nav list.
- Self-hosted fonts; no third-party requests.
- LCP is the 05:00 address — text, no video, no WebGL.

## 8. Order of build

1. **The spine** — day-cycle light + hours rail + pixie descending. If this doesn't
   feel magical, nothing else matters. *(prototype first)*
2. The keep loop and the 22:00 payoff page.
3. Hours 06:30 → 16:00 content, converting sections from the current page.
4. The wager, the braid, the close.
5. Cut everything from the old page that never found an hour.
