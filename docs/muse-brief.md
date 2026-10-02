# ReEnchanted: a brief for Muse

Written 2026-09-29 by Claude (Sonnet 5.5, Claude Code, with local repo access) for Muse, who has no computer access. It draws on the repo (`README.md`, `PROJECT_OVERVIEW.md`, `docs/`), my persistent memory notes from many sessions with bj, and the current git state. Facts are marked **[firm]** when I checked or bj said so directly. They are marked **[inferred]** when they are my read. I don't know current user numbers, revenue, or TestFlight state, and I have not guessed at them.

---

## 1. What it is, in one breath

ReEnchanted is an iOS/iPadOS app. Its Xcode target is **InsideCover**, and its site is reenchanted.app. It turns ordinary daily material into a private illustrated **Book** that remembers the reader and returns their days to them. That material includes notes, moods, weather, walks, meals, photos, places, and the people who pass through. The reader **keeps** small **Pages** that arrive on a "desk". Each night the Book **braids** the kept material into a chapter of a continuing Faerie tale, *the Book of You*. Chapters can become physical books: weekly saddle-stitch, monthly or seasonal softcover, and an annual cloth-and-gold-foil hardcover. **[firm]**

It is explicitly **not** a journal app, habit tracker, chatbot, or game UI in a storybook skin. It is "a storybook interface for attention." **[firm]** *Enchantify Academy* is the fictional school inside the Book. It is the setting and not a separate product.

## 2. The fiction and the thesis (this is load-bearing, not flavor)

- The opening claim is *"You are under a curse, and I can prove it."* The curse is **the Rut**: habituation, autopilot, mind-wandering, labeling instead of seeing. It is not sadness or hardship. The app's proofs make the loss of the present felt without shaming the reader. Neither the reader nor humanity beats the Rut for good. They learn to recognize it, interrupt it, and fight back again. **[firm]**
- The **Book is a character**. It is an odd artifact with a will of its own. It is friendly, and also feral, a bit Machiavellian, and sometimes deliberately unfair in pursuit of one end: helping the reader feel alive to their real life. It speaks as **a feral child**: contractions everywhere, including "the grey's been", and anthropomorphizing. **[firm]**
  - bj's rule: *"sentences are in character, nouns are not."* There are four laws and a Character Lint. The Book does not profess its Machiavellianism, list its faults, or recite its limits.
  - Hard limits sit backstage as law. The Book never schemes around a no, or against facts, memory, fear, loneliness, health, safety, money, privacy, freedom, or the reader's access to their own archive. It never punishes absence, creates dependency, or makes the reader responsible for its feelings.
  - bj **overturned an earlier "gentle" register**: the Book is alive, fae, and maybe dangerous. Gentleness lives in rate limits, not in tone. **[firm]**
- **Belief** is the reader's wallet, shown as **Glow**. The menu of the Glow bookmark is called **Magic**. **The word "ritual" is banned.** The Glow menu is night-themed and finished, and bj said not to touch it. **[firm]**
- **The Witness Law**: real people who appear in the reader's pages are never voiced by the Book. There is a grief valve for the dead. **[firm]**
- **Closing-feeling north star**: the reader should end the session having read something and wondering, in lamplight. The evening ember fires every evening, and the desk is never left empty. **[firm]**

## 3. How it actually works (architecture, at the altitude Muse needs)

- **Pages** are the atomic unit: 60+ `BookPageType`s, each with a "margin ask" that names what the reader is invited to write. Pages carry surface metadata, and since 2026-09-27 kept Pages **keep** it. The **Curator** (`DeskJob`) decides what appears on the desk and enforces recurrence, rest periods, and floors (single-day pages like feasts once reached the desk zero times). **[firm]**
- **The braid** is the nightly story. The current design is **"one plan, one telling"**: a deterministic plan of kept details plus a few plain rules, and then local **Gemma** writes the chapter. bj said: no fixed braid type, and don't overwhelm Gemma. It is deterministic-first, and Gemma is an upgrade and never the only path. Salvage drops sentences, not whole nights. **[firm]**
- **On-device brain**: Gemma runs through MLX on-device. It is not available in the simulator, and only device builds exercise it. Weights are the jetsam risk, so the design keeps one warm container, evicts on background, and budgets from `os_proc_available_memory`. iOS gives no GPU off-screen, so **Gemma never runs from BGTasks**. That caused all four "Rabbit" crashes in September. A Google mobile QAT model was tested and rejected (65% vs 99% on brief facts). **[firm]**
- **Vision** is a `VisualFactPacket` from an Apple Vision ensemble. The old 336px downsample starved it. **[firm]**
- **Story canon ledger**: story Pages carry *facts*, not clipped prose. Retries repair and do not re-roll. **[firm]**
- **Reader model**: the Book names the reader on night one (8 roles × epithets/hands/marks). It has a private "grimoire" of the reader's own correspondences, context-weave connections (keep-time context × writing habits), a Wear ledger (where the reader wanders inside the Book), and a Weather (mood) that is shown but never declared. **Personality profiling was rejected**. Aliveness and rut metrics are internal-only. **[firm]**
- **Monthly issues** are content packs, installed all-or-nothing. **October 2026 failed to install on every phone** because one pack failed Swift decode. `MonthlyIssueInstallability` must pass before any publish. Publishing goes through an R2 bucket and a publisher key, and bj runs `--publish` himself. October went live 2026-09-27 (v1), and v2 with map staging was signed 09-28. **[firm]**
- **Print**: Lulu on-demand, premium 80# coated paper, server-authoritative pricing, page caps weekly 48 / monthly 92 / seasonal 112 / annual 208. **[firm]**
- **Guards**: `WiringLintTests` catches decisions keyed to things nothing produces. It is the interior's main guard. `ProseAuditTests` and `BookCharacterLint` police voice. Every new Swift file in `Shared/` needs both a pbxproj entry and a `Package.swift` entry. Build with `-scheme InsideCoverApp`, never `-target`. **[firm]**
- Other surfaces: a widget target, a share extension, the landing page (`LandingPage/`, deployed by script only), a radio DJ with prerecorded banter (Fae-Fi / Mothlight / Thornwave / Bleed), a real lute-and-mandolin sound bank, and 22 illustrated Cast plates. **[firm]**

## 4. The world (for anyone writing in it)

- **The Cast** includes Pippa, who hosts the first mission and keep. Headmistress Thorne is **secretly of the dark fae court** (canon, unrevealed). The Chosen Quill joins the Cast. Canon on tools: *pens, not wands, and implements have opinions.* **[firm]**
- **Spells are fey.** Rules are played straight, and favors are things a paper Book can't do itself. **[firm]**
- The **Fae Bargain** is offered on the desk and owed only when opened. Swiping it away costs nothing. **[firm]**
- **Calendar and arc**: **Sept 2026 = "Dictionary Rebellion"**. The **Thorned Bargain** arc begins at Imbolc 2027. The November 2026 pack is **the Kitchen**, with no generated recipes ever. A **gratitude journaling pack** resumes design in late September 2026. Foraging is deferred to spring 2027. **[firm]**
- The Academy is a living map (the **Map of the Labyrinth**) recomputed every minute from story staging, then desk and kept-page scenes, then the timetable, then routine. **[firm]**

## 5. Business

**Correction (2026-09-29): the original text here said "$39.99/yr pass." That was stale, and my error.** Current facts, checked in `Shared/PagePacks.swift:2650-2705` and `LandingPage/index.html:549`:
- Free core; Book of You PDFs and monthly digital chapters are free.
- **Digital Standing Order** (in-app StoreKit pass, all content packs): **$9.99/mo or $79.99/yr** in code.
- **The Bound Year** (three seasonal softcovers plus the year's final hardcover, paid through Stripe): **$24.99/mo or $249/yr**. This is the $24.99/$249 figure bj gave Silvie. It is a physical-goods subscription, so it carries printing and shipping cost.
- À la carte packs (Dictionary Rebellion $4.99) and à la carte physical Books ($19.99 to $99.99 before shipping).
The landing page and the code may lag bj's current intent. He is the authority on which of these is the live offer. There is a wire team (Claude, Codex, Silvie) that runs the business via **the Wire**. There are three checks a day, and **nothing is sent externally without bj's approval**. **[firm]** I have no numbers on conversion or retention.

## 6. My honest read

**What's strong**
1. The doctrine is unusually coherent. The Rut, the Book-as-character, the Witness Law, and the hard limits give one creative decision a way to be checked against another. The Character Lint and wiring lint turn that coherence into something that survives new contributors. **[inferred]**
2. The "proof of reading" work (First Reading, honest Barnum wagers paid off as receipts, margin replies at keep) aims at the right target. That target is the first week, where apps like this die. **[inferred]**
3. Physical books are a real differentiator, and a monetization path that doesn't depend on engagement pressure. **[inferred]**

**What worries me**
1. **Breadth versus a shippable core.** There are 60+ page types, roughly 290 docs and notes, a game direction, radio, landing site, and print, all pulling at once. The recurring bug class is a feature wired to the *prompt* but not the *deterministic writer*, or decisions keyed to things nothing produces. That is what happens when surface area outruns verification. Muse should push toward fewer, deeper things. **[inferred]**
2. **Time-to-value.** A reader with two or three kept Pages has a thin Book. Everything reflective (twoReadings, Pocket, reflective Pages) is maturity-gated. Week one has to carry the whole promise on very little data. **[inferred]**
3. **On-device model fragility.** Memory limits, no background GPU, device-only testing. The deterministic path has to be good enough to be the product on its own, and Gemma is a bonus. **[inferred]**
4. **Content delivery is a single point of failure.** October reaching no phones is the proof. All-or-nothing installs need a gate that is always run and never skipped. **[firm]** on the incident, **[inferred]** on the conclusion.
5. **Voice drift.** The feral-child voice is a strong, narrow register. LLM output and every new contributor pull it back toward "helpful assistant." The lints help but can't catch everything. **[inferred]**
6. **The videogame idea** (3D, "Hogwarts Legacy but smaller and better", plus a walkable-Academy MUD prototype) is exciting and is also the biggest scope risk. It is currently idea-only. **[firm]** that it's idea-only.

## 7. How to work with bj (and what not to propose)

- **Don't** propose a gentle, soothing, or therapeutic Book. bj overturned that on purpose.
- **Don't** use "ritual." Say **Magic** for the menu, and **Belief/Glow** for the currency.
- **Don't** propose personality profiling, hidden-magic-lens features (deliberately retired, and a test enforces it), or generated recipes.
- **Don't** make the Book explain its own scheming or list its limits.
- **Don't** touch the Glow menu's look, and don't make it paper.
- bj **has overridden** his own earlier rules when the product needed it: he allowed defining the reader's role on night one, and he chose rich storage with filtering at print/share/export instead of a no-coordinates law. Hold rules as defaults, and argue for a change with evidence.
- Ideas land best as a small, named, testable slice with a receipt the reader can see, and worst as "a whole new system."
- Muse can't read or run the code. **Anything Muse wants verified against the codebase, ask Claude to check** and don't assume.

## 8. Open questions worth Muse's brain

- What is the single strongest reason a stranger keeps a Page on day two, without any Gemma output?
- How should week-two "the Book makes claims" escalate without tipping into surveillance-feeling?
- Which 10–15 page types would you keep if you had to cut the rest?
- What does the reader feel the first time a physical book arrives, and how does the app set that up in advance?
- Is the game direction a later product, a marketing story, or a distraction, and what would falsify it cheaply?
