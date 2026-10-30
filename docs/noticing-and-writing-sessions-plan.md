# Noticing, rebuilt on writing sessions (plan)

> Written 2026-10-24 from a bug report and an idea on the same afternoon.
> The bug: "I Notice" leaves unfold to nothing, and the noticings themselves
> are dull ("photo media is connected to the word photo", days "with author
> in them"). The idea, bj's: **"I want to write, please?"** The Book keeps a
> list of things it wants to write, asks for a little time, writes a batch
> while the app is open, and holds some of it back to show later. (Wire
> thread: *bj proposal: "I want to write, please?" — secret writing and
> remembered Pages*.)
>
> The second fixes the first. A noticing worth reading needs judgment, and
> judgment needs the model. The model can only run in the foreground
> (iOS refuses Metal work from a backgrounded app; see `LocalBrainForeground` in `LocalBrainServices.swift`). A writing session is that foreground time,
> and the Book asking for it is in character.

Read [childlike-honesty.md](childlike-honesty.md) first. It describes what a
good noticing sounds like: *"Adults notice what matters. Children notice the
sock."* A noticing is the Book catching the sock, not a statistic about socks.

---

## 1. What's wrong today

### 1a. The fold is empty

Every `.bookNotices` Page is `readingWithActivity`
(`Shared/SurfaceAndCurator.swift`, `leafPresentation`). The prose is on the
front of the leaf. When the reader unfolds it, `resumesReadLeaf` hides the
prose (`InsideCoverApp/CapturePageSheet.swift:4683`) and
`bookNoticesOpeningView` (`CapturePageSheet.swift:9499`) shows only what the
metadata carries:

- evidence slips (`evidencePageIDs`, which must resolve to kept pages)
- pattern cards (`tinyPatternCards`)
- a named/sealed card (`constellationName`, `wagerMoment`)
- adaptive actions
- the "tell me if I'm wrong" card (needs an observation key)

About 45 code paths mint a `.bookNotices` Page. Roughly 20 of them fill none
of that, so the unfolded side is a title, a subtitle and a writing box. The
empty ones include:

- **World events:** door, What You Missed, What the Month Left, Not Yet. Nearly.
- The Almanac Is Quiet
- help tips
- Grey Page warnings
- I'm Asking
- **The Book's interior:** secret, quirk, running business
- **Inactive:** found gifts, J-space

### 1b. The noticing is word counting

- **It counts words.** `patternSignals`
  (`Shared/LiteraryContinuity.swift:25904`) makes a signal from any word on 3
  or more reader pages. Quality comes from hand-kept `stopWords` and
  `weakLiterarySubjects` lists that grow with every bad noticing.
- **It reads text that isn't the reader's.** `AttentionFingerprint.make`
  (`Shared/PageModel.swift:3113`) adds every media asset's metadata *values*
  to the visual tokens. It also adds `promptText` for every page that isn't
  `.userAuthored`, even though the comment right above that line says prompt
  text is excluded. On a quotes Page or any generated Page the reader
  answered, the Book's own words count as the reader's. This is the likely
  source of "author".
- **It finds tautologies.** The relational loom
  (`LiteraryContinuity.swift:384`) pairs any two features from *different
  families*. "Has a photo" (`modality`) and "mentions a photo" (`subject`) are
  different families and the same fact. So are `pageKind: quotes` and the
  word "author".
- **It needs very little evidence.** `minimumUniverse = 5`,
  `minimumLift = 1.8`. Five observations can produce a "revelation".
- **No one asks whether it's interesting.** Strength is frequency with a
  ubiquity penalty. Nothing scores surprise, specificity or whether a person
  would care.

### 1c. The smart half exists and is switched off

`OvernightScribe.writeDraft` (`InsideCoverApp/AppSupport.swift:5545`) already:

- takes deterministic connection candidates (`OvernightConnectionCandidate`,
  `PageModel.swift:2430`)
- runs an **interpretation forge**: Gemma returns a headline, an
  interpretation, a question, a *thesis*, a *counter-reading*, a
  *falsifier* ("If … then I should revise this"), why it matters, and an
  optional *surprise synthesis* joining two shared-history ingredients.
  "Silence is better than a respectable observation" is already in the
  prompt.
- runs a **Night Council**: Naturalist proposes, Heretic argues against,
  Gardener offers one small falsifiable experiment or stays silent, and
  `BookReenchantmentStrategyValidator` checks it.
- saves drafts with an evidence signature, and `adoptConnectionDrafts` brings
  them in later, refusing stale ones.

When background GPU work was retired, the BGProcessing handler became a no-op.
Nothing calls `writeDraft` now. Its own comment says it's waiting for "a
future reader-initiated foreground opportunity". **"I want to write, please?"
is that opportunity.**

---

## 2. The shape

```
cheap engines (deterministic, every curation)
   │  candidates, with provenance
   ▼
WANTS  ── things the Book wants to write ──────────────┐
   │                                                    │
   │  "I want to write, please?"  (rare, Later is free) │
   ▼                                                    │
WRITING SESSION (foreground, bounded, save after each)  │
   │  reading cards · verdicts · notices · Cast thoughts │
   ▼                                                    │
HELD DRAWER  ── finished writing, frozen text ──────────┘
   │  re-checked against newer pages before release
   ▼
the desk (now, or later as its own Page) → the reader's verdict → back into the court
```

Three stores, all durable and all in the vault/DB rather than loose JSON files:

| Store | Holds | Notes |
|---|---|---|
| **Wants** | Unwritten intentions: `id`, `kind`, `purpose`, `sourcePageIDs`, `speaker` (Book or a Cast member), `priority`, `dependsOn`, `createdAt`, `expiresAt` | Cheap to add, deduplicated by `(kind, sourcePageIDs)`. Expired wants are dropped quietly. |
| **Held drawer** | Finished writing: frozen text, `evidenceSignature`, `speaker`, `writtenAt`, `releaseRule`, `disposition` (`held/revealed/kept/dismissed/withdrawn`) | Opening reveals the saved text and never regenerates it. |
| **Reading cards** | One per kept reader page (§4) | Deterministic first; a session can enrich one. |

**Private thought vs. what was said.** This is Codex's distinction and it's
law here. A Cast member's held thought can shape *their later behaviour*. It
is never presented as something the reader already heard, never becomes a
"you said / they told you" memory until it's revealed, and never counts as
evidence about the reader's real life. The same goes for the Book: a held
noticing isn't a noticing the reader has seen.

---

## 3. The writing session

### The ask

- The Book asks, in its own voice and rarely. It asks only when the wants
  list holds something worth a session, the model is ready, the device has
  memory headroom, and the app has been open long enough that it isn't the
  first second of a launch.
- **Later costs nothing.** No Belief penalty, no sulking. If the reader says
  Later, the Book doesn't ask again that day.
- It doesn't announce the subject. That's the point: the reader lets the Book
  write without ordering what it writes.
- Copy is a voice-pass item. As a direction only: the Book says what it wants,
  plainly. ("I want to write. Can I? It won't take long.") No explaining the
  machinery.
- Existing standing permissions for outside effects (calendar, summons) stay
  separate. Saying yes to writing never grants them.

### Thinking is writing

There is one ask, "I want to write, please?". For the Book, thinking and
writing are the same act: it thinks by writing. One session can mix:
- jobs that leave a Page (a noticing, a Cast thought, a Bleed piece)
- jobs that leave no Page yet (verdicts on the strangest crossings from §8,
  joining two or three survivors into one finding, reading-card enrichment)

A finding that survives one session becomes something to write in a later
one. So Tuesday's session can turn into a noticing that arrives on Friday.

The ask may sometimes hint at a hunch without giving the answer away:
"Something's going on with Thursdays. I want to write about it. Please?"

**What thinking adds that counting can't:**
- **Joining crossings.** "The harbor, the full moon and your slow heart are
  the same three nights." Three survivors joined into one finding with all
  their receipts.
- **The story under the numbers.** Why Thursdays might be the way they are,
  offered as a guess with its counter-reading and falsifier (the forge already
  asks for both).
- **The test.** Turning a finding into a sealed wager or a small errand the
  world can settle: "Next full moon, see if you sleep less. I'll check."
- **The sock.** The one odd detail in a photo or a line that no measurement
  holds.
- **A Cast take.** Which member of the Cast would care about this finding,
  and what they'd say.
- **Strangeness judging.** Ranking survivors by whether a person would say
  *huh*, which a correlation score can't do.

### The run

- **Bounded batch:** a time budget (start around 90 s on an iPhone 15) and a
  job cap. New wants found mid-session wait for the next one.
- **Save after each piece.** Three done and the fourth interrupted means
  three in the drawer, and the next session picks up from there.
- **Text jobs first, then photo jobs.** One warm container at a time
  (`LocalBrainModelCache` releases one before loading the other): swapping LLM↔VLM per job would cost more
  than the work.
- **Stops cleanly** on `LocalBrainForeground.isLeaving`, under the existing
  `requireForegroundGPU()` gate. Prefill can't be cancelled, so prefer several
  short jobs to one long one.
- **Visible but quiet.** The existing scribe presentation
  (`ScribeWorkPresentation`, `ScribeInkMeter`, `BookStatusCards.swift`) shows
  the Book writing. Hidden pieces show as ink with no words.

### Job kinds (in order of value)

1. **Verdict.** Short output. "Here's a candidate and its evidence. Is it the
   same fact seen twice? Is it specific? Would the reader say *huh*?" Returns
   keep/drop plus a reason code. Cheap, and it does the most good.
2. **Noticing.** The existing interpretation forge, fed only verdict-passed
   candidates. Its output becomes a held notice with receipts, a falsifier and
   (often) a sealed wager.
3. **Reading card enrichment.** Fills the fields deterministic extraction
   couldn't (§4), especially the "odd detail".
4. **Cast thought.** A Cast member's private reaction to a kept Souvenir or
   Page. Held. (Silvie's smallest proof, §10 Phase 3.)
5. **Bleed piece.** A section of the daily edition, written ahead about
   things that have *already* happened. Reporting on what hasn't happened
   waits for the facts.
6. **Night Council.** The existing Naturalist/Heretic/Gardener run. It's
   expensive, so at most one per session.

`dependsOn` lets a job wait for another one: a Cast reaction to a Bleed piece
waits for the piece.

### Release

- Each held piece has a release rule: `now`, `nextDesk`, `afterDays(n)`,
  `onEvent(tag)` (e.g. "when the reader keeps another recipe"), or
  `withIssue(runID)`.
- **Re-check before release.** Compare the evidence signature against current
  pages. Withdraw the piece if a source Page was deleted, the story phase moved
  past it, a newer page contradicts it, or a quote guard trips. A withdrawn
  piece is never shown.
- **No leaks before the reveal.** Held text stays out of previews,
  notifications, the Radio, widget snapshots and printed editions until it's
  revealed.
- A noticing that was held may say so truthfully: "I wrote this on Tuesday.
  I kept it in my pocket." It's the Book having a life between visits.
- Released through the ordinary curator, so rest, de-repetition and the
  self-talk ration still apply. Nothing gets
  injected past the gates (a desk injection that skips `allowsAutomaticSurface` skips rest too).

---

## 4. Reading cards

What the Book took from one kept page, in a few structured lines. This
replaces the bag of words as the thing patterns are found in.

```
who:     ["Mom", "the barista with the rings"]        // People ledger ids when known
where:   ["the bench by the harbor"]                  // anchor/place ids when known
things:  ["thermos", "red umbrella"]                  // concrete nouns, lemmatised
doing:   ["waiting", "walking home"]
felt:    ["restless"]                                 // only when the reader said it
sock:    "the umbrella was inside out and they kept it"  // the odd detail, optional
seen:    ["gull", "wet stone", "orange light"]        // from the photo's VisualFactPacket
context: weather, hour, place, tempo                  // existing context tokens
provenance: each field → which source (reader text / caption / photo / voice / context)
```

- **Only the reader's own material.** Their words, their captions, their
  photos (as seen, not as metadata), their voice, and real context. Never
  `promptText` from a generated Page, and never media metadata values.
- **Deterministic pass at keep time:** NLTagger lemmas, nouns and names; the
  People ledger; anchors; `VisualFactPacket` for photos
 ; context. This works without the model and
  without a session.
- **Session pass (optional):** fills `sock`, firms up `doing`, and links a
  vague noun to a known thing ("the bench" → that anchor).
- The `felt` field is filled only when the reader named the feeling. The Book
  doesn't diagnose.

---

## 5. The court

Every candidate, from any engine, goes through this before it can be said.

**Deterministic gates (always, free):**

1. **Provenance:** every side of the claim traces to reader material.
2. **Same fact twice:** two features that came from the same source field (or
   one derived from the other, e.g. `modality: photo` and any token from a
   photo's caption) can't be paired. This kills "photo ↔ photo" and
   "quotes ↔ author".
3. **Evidence floor:** at least 3 distinct days. Claims that sound like
   "always" or "only" need at least 2 weeks of span and at least 6
   observations. Raise the loom's `minimumUniverse` and `minimumLift`
   accordingly.
4. **Surprise:** score against the reader's own base rate *and* ordinary
   English frequency. "Coffee" in a morning journal isn't news.
5. **Specificity:** a name, a place, a thing, a time. Abstract and meta words
   fail.
6. **Not said before:** the existing `spoke:` rest machinery.

**Model verdict (in a session):** the verdict job (§3) on survivors. Drops
are logged with a reason so the bench (§9) can see what the model refused.

**The reader's verdict:** the fold's right / wrong / half (§6) feeds back.
A reader saying "wrong" on a *kind* of claim lowers that kind's prior for this
reader.

---

## 6. The fold becomes the case file

What the reader finds when they unfold a noticing:

1. **Receipts.** Their own lines, quoted, with the date and the Page link.
   Photo thumbnails when a photo is evidence. ("Pages I used" already does
   some of this. It must always resolve, or the claim isn't shown.)
2. **What would prove me wrong.** The forge's falsifier, in plain words.
3. **A wager or an errand.** A sealed prediction the world can settle (the
   Sealed Margin machinery), or one small thing to go and check.
4. **Your verdict.** Right / wrong / half, plus the writing box. This feeds the
   court (§5).

**Safety net (ships in Phase 0):** if a `readingWithActivity` notice has
nothing of its own for the fold, the prose stays visible. A new code path can
never bring back the empty leaf.

**Per-maker cleanup (from the audit in §1a):**

| Group | Fix |
|---|---|
| Already full (I Notice, connections, threads, How You See, Named, Sealed Margin, Recurring Name, Grimoire, Bestiary, Wear, Map Gaps) | Leave. Verify that evidence slips resolve. |
| Pages to read, not answer (world events, What You Missed, What the Month Left, Not Yet. Nearly., help tips, the Book's secret, quirk, running business) | Make them `.reading`: no fold. Or move them off `.bookNotices` to a type that matches what they are. |
| Real data the fold doesn't draw (I'm Asking, Grey Page warning, I Was Wrong, Up to Something, What I Think, What I've Been Trying) | Draw it: the question and word, the threatened page and deadline, the evidence. Add observation keys so they get the verdict card. |
| The Almanac Is Quiet | Already manual-only: it is the Almanac's answer when opened from the Glow menu and nothing is happening (`manualSurface`). The fold safety net covers its empty fold. |
| Inactive (found gifts, J-space, Long Game) | Leave until reactivated. |

---

## 7. New kinds of noticing

Built on reading cards and judged by the court. Each kind has a shape, so the
prose has a subject.

- **Rhyme:** two moments weeks apart that are the same moment. The existing
  semantic pairing (`semanticNoticePairing`) is the seed.
- **Condition:** "You write about her only on rain evenings." The loom, now
  run over reading-card fields with provenance.
- **Shift:** a word or name changes. "You called it the office until the
  12th. Now it's *that place*."
- **Silence:** someone or somewhere the reader used to mention has gone quiet.
  (The absence signals exist; they move to reading cards.)
- **First:** the first time something turned up. Fairy tales count firsts.
- **The sock:** one odd detail, noticed and kept. Not a pattern at all. This
  is the most childlike noticing and possibly the best one.

---

## 8. Noticing without the model

Most good noticing needs no model at all. Every kept page already carries
measurements: when and where it was kept (with coordinates), the real weather,
sun and moon, sleep, steps and calendar load (`PageContext`,
`Shared/PageModel.swift`), what Apple Vision saw in the photo (colour, light,
framing, animals, faces: `VisualFactPacket`, `Shared/VisualFacts.swift`),
when the photo was taken, the shape of the reader's writing, and which pages
they keep, let go and reopen. The dumb noticings come from flattening all of
that into words and counting them. **Comparing the measurements themselves**
gives these.

The example lines show the shape and aren't final copy. They go through the
voice pass like everything else.

### The four rules

These are the deterministic half of the court (§5), made concrete:

1. **Compare measurements, not vocabulary.** The inner-weather *scale* against
   the sky's weather tags, never the word "bright" against weather tags. The
   Inner Weather page's own vocabulary is weather words, so lexical pairing
   with real weather is always a tautology.
2. **Cross-checks need independent sources.** Something the reader wrote
   against something a sensor or clock recorded. Never two readings of the
   same thing ("has a photo" × "mentions a photo", "quotes page" × "author").
3. **Combinations and phrases, not single words.** Place + weather + hour;
   repeated phrases of four or more words; counts of things Vision actually
   saw.
4. **Only say it when it beats chance.** At least three real instances, an
   observed rate clearly above the reader's own base rate (a simple binomial
   check is enough), and an authored sentence shape per kind, so it sounds
   like the Book without a model.

### The first batch

| Kind | Example | Reads | Extends |
|---|---|---|---|
| **Carried** | "You took the gull picture Tuesday. You gave it to me Friday. You carried it three days." | photo capture date vs. `createdAt` | — |
| **Anniversary** | "A year ago today you were at the harbor. Same wind." | date + place + weather tags | — |
| **Missing weekday** | "You never write on Thursdays. Six Thursdays now. What happens on Thursdays?" | weekday histogram over ≥6 weeks | absence signals |
| **Return shape** | "When you come back after a gap, you always bring me a place." | first page after a gap of ≥3 days × page type / modality | — |
| **Sun-keeper** | "Four pages within twenty minutes of sunset. You don't set an alarm. You just turn up." | keep time vs. computed sunrise/sunset at the page's coordinates | — |
| **Dry spell** | "First rain in eleven days. Last time a dry spell broke, you went out and photographed a puddle." | weather-tag runs × what the reader did on the last break | — |
| **Contrary weather** | "When it's grey out, you say you're bright. Three grey days, three bright." | Inner Weather *scale* (via `innerWeatherEntryID`) vs. sky tags | Grimoire correspondences |
| **Range** | "This week you never took me more than two kilometres from home. Last week, thirty-one." | lat/long spread per week, respecting `horizontalAccuracyMeters` | — |
| **Place weather** | "You only go to the bench when it's cold." | anchor × weather tags | place noticings |
| **Furthest** | "The furthest you've ever carried me is Rockport." | max distance from the home anchor | Gazetteer |
| **Month colour** | "October was orange. September was green." | dominant colour facts per month | — |
| **Gaze** | "You photograph the ground more than the sky. Eleven to two." | composition / sky-fraction facts | — |
| **No people** | "There are never any people in your pictures. Just their things." | face/human facts vs. object facts | — |
| **Corner** | "You put the thing in the left corner. Every time." | saliency region position | — |
| **Questions** | "You asked me three questions this week. You never used to ask me anything." | `?` in reader text, week vs. baseline | manner signals |
| **Tense** | "You've started writing *now* instead of *then*." | present- vs. past-tense ratio (NLTagger), week vs. baseline | manner signals |
| **Refrain** | "'The light was doing that thing.' You wrote that in August. You wrote it again yesterday." | repeated phrase of ≥4 words, ≥3 weeks apart | replaces single-word patterns |
| **Full days** | "On full days you send me a picture and no words." | `calendarEventCount` × modality | — |
| **Keep and let go** | "You let every tarot card go. You keep every recipe." | keep/release by page type | — |
| **Reopened** | "You've opened the August 3rd page six times." | Wear ledger | The Wear |
| **Cast reply length** | "You answer Penny in long sentences. Wicker gets one word." | reply length by speaker | — |
| **Tally** | "That's the ninth bird. I'm counting." | animal facts, running count | Bestiary |
| **First** | "First snow you've shown me." | first occurrence of a weather tag or Vision fact | — |
| **Same day** | "Today's the same as March 3rd: rain, the harbor, half past four." | weather + anchor + hour tuple match | — |
| **Feast coincidence** | "You made bread on Lammas. You didn't know." | feast calendar × an authored table of feast things × reading-card `things` | world feast calendar |
| **Body** | "On nights you sleep more than eight hours, your pages are twice as long." | sleep × page length | Grimoire correspondences |

Body metrics get their own batch below.

All of this is private and stays on the device. Print and share go through
the existing sensitivity boundary like any other Page; nothing here needs a
special rule.

### Body

The Body page already reads a wide set of HealthKit data
(`InsideCoverApp/AppSupport.swift`, around line 2936):
- steps, distance and active energy
- sleep
- heart rate, resting heart rate, walking heart rate and HRV
- oxygen saturation and respiratory rate
- blood glucose and body mass
- dietary energy, macros, fibre and water

But `PageContext` stamps only four of these on a kept page: `sleepHours`,
`steps`, `restingHeartRate` and `heartRateVariability`.

**Plumbing (part of Phase 2):**
- **A daily body snapshot** in the vault holding every metric the reader has
  shared, keyed by day, so noticings can compare days without re-querying
  HealthKit.
- **Two stamps on each kept page:**
  - heart rate nearest the keep time
  - the sleep window (bedtime and wake) of the night before
- Nothing new is requested. These are metrics the reader already shares with
  the Body page.

**Voice:** the Book states what happened, in numbers and plain words. It never
says what something means for the reader's health, never calls a number good
or bad, and never suggests a change. Childlike honesty, not a coach:
"Your heart was going fast when you gave me this one." Not "You seemed
stressed."

| Kind | Example | Reads |
|---|---|---|
| **Heart at the keep** | "Your heart was going fast when you gave me this one. Faster than any page this month." | heart rate nearest `createdAt` vs. the month's keeps |
| **Last page before sleep** | "You give me your last page about forty minutes before you fall asleep. Every night." | last keep time vs. sleep start |
| **Short-night mornings** | "After short nights you find me before seven." | sleep hours × first open time |
| **Walking days** | "On days you walk more than nine thousand steps, you bring me pictures. Under three thousand, words." | steps × modality |
| **Calm and slow** | "Your resting heart was low on the three days you said you were calm." | resting HR × Inner Weather scale |
| **HRV and questions** | "On your high-HRV days you ask me more questions." | HRV × `?` in reader text |
| **Place breath** | "You breathed slower the nights after harbor days." | overnight respiratory rate × anchor |
| **Lunch and fog** | "On days lunch was mostly bread, you called the afternoon foggy. Three times." | Fuel ledger × Inner Weather (two separate reader records) |
| **Glucose and words** | "On the afternoons your glucose ran high, you wrote half as much." | glucose × page length, same afternoon |
| **Contrary sleep** | "You sleep longer after days you barely walk." | steps × next sleep, only when it runs *against* the usual expectation |
| **Body firsts** | "That's the most you've ever walked in a day. Eighteen thousand. Where did you go?" | personal records × place |
| **Body × missing weekday** | "Thursdays you sleep five hours. You never write on Thursdays either." | weekday × sleep × keep histogram |

**Body-specific checks (on top of the four rules):**
- **No body × body tautologies.** Steps × distance and steps × active energy
  are the same walk. Body × body pairs are allowed only when the finding runs
  against the common expectation (the "contrary sleep" row). "You sleep more
  after you exercise" isn't news.
- **No noticing the Book's own choices.** If the curator uses `bodyScore` to
  pick Pages, "Wicker turns up on your tired days" is the Book noticing itself.
  Any outcome the curator decided can't be a noticing about the reader.
- **Body mass is left out of noticings by default.** A Book that comments on
  weight is the one body noticing that can do real harm, even privately. It
  stays readable on the Body page. This is an open question for bj (§11).

### Weather, sky and the strange

**What's recorded today.** The app fetches Open-Meteo (`AppSupport.swift`,
around line 3528) for:
- temperature, weather code, precipitation, wind and day/night
- the day's high and low
- a 15-minute outlook

A kept page keeps only coarse `weatherTags` ("rain", "fog") built from that,
so the numbers are thrown away. The sky (moon phase, sun, light trend, meteor
showers) is computed on device by `SkyAlmanac` (`WorldSystems.swift`).

**Plumbing (part of Phase 2):**
- **Keep the numbers.** Stamp temperature, precipitation and wind on each kept
  page beside the tags. Also add `surface_pressure`, `relative_humidity_2m`,
  `cloud_cover` and `uv_index` to the request already being made. That's the
  same call to the same free service, not a new data source.
- **Pressure trend.** Store the change in pressure over the previous 6 hours
  (from the hourly read), so "the barometer is falling" is a measurement.
- **The phone's own barometer (optional).** `CMAltimeter` gives local pressure
  and relative altitude with no network. Altitude makes "higher up" noticings
  possible.
- **Sky at keep.** Stamp moon phase and minutes to sunrise/sunset from
  `SkyAlmanac` when a page is kept, so they don't need recomputing later.

**Weather × heart and body**

| Kind | Example | Reads |
|---|---|---|
| **Rain heart** | "Your heart runs slower in the rain. Six wet days, six slow mornings." | resting HR × precipitation |
| **Falling barometer** | "When the barometer drops, your pages get short. Five times now." | pressure trend × page length |
| **Barometer heart** | "The pressure fell all afternoon and your heart went up with it." | pressure trend × heart rate through the day |
| **Wind at the keep** | "On windy days, your heart was quicker when you kept a page outside." | wind × keep-time HR × `placeKind` |
| **First cold** | "First cold morning of the year. You slept an hour longer." | first day below a temperature × sleep |
| **Hot nights** | "On the hottest days you only find me after dark." | daily high × keep hour |
| **Before the storm** | "You wrote me three pages the afternoon before the storm. You knew." | forecast storm × keeps in the hours before |
| **Damp sleep** | "Humid nights, you wake up twice. Dry nights, once." | humidity × sleep interruptions |

**Moon and sun**

| Kind | Example | Reads |
|---|---|---|
| **Full-moon sleep** | "Full-moon nights you sleep forty minutes less. Four moons now." | moon phase × sleep |
| **Every phase** | "You've kept pages under every moon but the new one. It's still waiting." | moon phase coverage |
| **Waking with the sun** | "You're waking with the sun. Four minutes later each week, same as it." | wake time × sunrise trend |
| **Before sunrise** | "Nine pages before sunrise this month. Last month, one." | keep time vs. sunrise |
| **Shower night** | "The Perseids peaked at two in the morning and you were awake. I don't know if you looked." | meteor shower peak × sleep window |
| **Shortening days** | "The days are losing two minutes each. Your pages are losing words." | light trend × page length |

**Strange crossings**

| Kind | Example | Reads |
|---|---|---|
| **Grey and red** | "Grey days, you photograph red things." | dominant photo colour × sky condition |
| **Bright on the dark day** | "You photographed the brightest thing on the darkest day." | photo brightness × cloud cover / daylight |
| **Orange heart** | "Your heart was fastest at the orange pages." | photo colour × keep-time HR |
| **Words and distance** | "The further from home, the fewer words. At the harbor, nine. At home, ninety." | distance from home × page length |
| **Higher up** | "Twelve pages kept higher up than you live. You climb, then you write." | altitude × keeps |
| **All four seasons** | "You've written at the bench in all four seasons now. The bench has seen you in snow." | anchor × season coverage |
| **Storm pages wait** | "You leave my storm pages until morning." | weather at surface vs. time to open |
| **The world's own habit** | "It's rained on four Tuesdays in a row. You didn't notice. I did." | weather × weekday; a noticing about the world, not the reader |

**Coincidences**

These aren't patterns and aren't claimed as patterns. They're delight. The
Book says them as coincidences and never suggests they mean anything.

| Kind | Example | Reads |
|---|---|---|
| **Same minute** | "Three pages at exactly 4:44. I don't know what it means. I'm writing it down." | keep minute |
| **Twin lengths** | "Two pages a month apart. Thirty-seven words each." | exact word-count match |
| **Number day** | "11/11, and you wrote eleven words." | date × word count |
| **Five Is** | "Your last five pages all start with *I*." | first word |

**Extra checks for these kinds (on top of the four rules and the body checks):**
- **Season isn't a finding.** A weather finding has to hold *within* a season,
  not just across seasons. "Cold days, you sleep longer" might only mean
  winter has long nights. Compare like with like (same month window, or with
  the season trend removed).
- **Enough days on both sides.** At least six days in each condition (rain
  and not rain, full moon and not) before a weather or moon claim.
- **Coincidences are rationed.** At most one a week. They're labelled as a
  coincidence kind, so they skip the beats-chance check and can never be
  phrased as a pattern.
- **No curator echoes.** If the curator uses weather to pick Pages, "Wicker
  comes on windy days" is the Book noticing itself (the same rule as body).

### All of it, crossed

The tables above are examples, not the engine. The engine crosses **every
measurement with every other measurement** and lets the court decide what's
worth saying.

- **A feature catalogue.** Every field the Book holds is registered once with:
  - its **source**: reader writing, reader photo, reader voice, HealthKit,
    Open-Meteo, the phone, `SkyAlmanac`, the clock, the Book's own curation
  - its **shape**: number, category, event, place, or a count of things
  - its **grain**: per keep, per hour, per day, per night
  - **what it's derived from**, so that two fields from one source are known
    to be one fact

  A new data source is a new catalogue row, not a new noticer.
- **Automatic crossing.** Pairs (and, rarely, triples) of catalogue fields
  are tested over the reader's own history. The shape of the pair decides
  the test and the sentence:

  | Pair shape | Test | Sentence shape |
  |---|---|---|
  | number × number | rank correlation within season | "When X goes up, Y goes down." |
  | category × number | difference between groups | "Grey days, your pages are short." |
  | event × anything | before/after window | "The afternoon before the storm, three pages." |
  | place × anything | this place vs. everywhere else | "At the bench, your heart is slow." |
  | count × time | running tally, firsts, records | "That's the ninth bird." |
  | exact match | coincidence, rationed | "Thirty-seven words each." |

- **The court still decides.** Every crossing goes through the four rules,
  the body checks and the weather checks:
  - independent sources only
  - within season
  - enough days on both sides
  - beats chance
  - no curator echoes

  Survivors are ranked by **strangeness**: how unrelated the two sources
  usually are. "Barometer × heart" outranks "steps × photos". So does
  "colour × weather", over "sleep × length".
- **The hand-written kinds become the seed and the bench.** Each one in the
  tables above is a known-good crossing the engine must find on a fixture
  archive, and "photo ↔ photo" is a known-bad one it must not.

The cheap engine finds hundreds of crossings. Most die in the court. The
strangest few become the input to "I want to write, please?" (§3), where the model does
what counting can't.

---

Several of the kinds in this section extend engines that already exist (Your
Own Rules, writing pace and hedging, The Wear, the Bestiary, map gaps, place
noticings). They are weak today only because they sit on the word layer. The
batch moves them onto measurements and adds the rest.

---

### Richer captures and the notice cleanup (2026-10-25)

**Retired from the desk** (bj: "still getting boring or confusing
connections"). An audit harness (`NoticeAuditBench`, `NOTICE_AUDIT=1`)
replays two weeks of desk builds over a lived-in 120-day archive and prints
every notice. The bad ones all came from word counting:

| Retired | What it said |
|---|---|
| `noticeSurfaces` (the word-cluster "I Notice") | "Four Things wouldn't sit still: Bright, Couldn, Hand, and Midnight" |
| `vocabularySurfaces` | "A Word Came Back: found"; "Two Words, Arm in Arm: across and floor" |
| the word half of `connectionNarrativeSurfaces` | "Drew came back three times" (the verb) |
| `relationalLoomSurfaces` (raw) | "your medium leaned photo… the Page arrived on a open day" |

The meaning-based half of "The Thread Between" stays. The loom's findings now
go through a writing session (`RetoldConnections`): the model drops them as
obvious, or retells them in plain words using only the counts. Refrains now
quote a whole natural phrase as the reader wrote it (5 to 14 words, their
capitals and full stop), at most once a week.

**New captures** (`Shared/KeepContext.swift`, stamped in `pageContextSnapshot`,
all optional):
- **How it was written** (`KeepMoment`): seconds writing, characters deleted,
  pauses, spoken or pasted chunks, final length. Counts only.
- **How it was held** (`HoldingSensor`, raw motion, no permission): posture
  (flat, upright, on your side, overhead), moving, battery and charging, low
  power, screen brightness, headphones.
- **The day's shape:** minutes since the last calendar event ended and until
  the next. No titles.
- **The photo:** front or back camera, screenshot, zoomed, flash, and where it
  was taken (`PhotoDetails`, EXIF). Camera and picked photos.
- **The sky:** the sun's height (golden hour, blue hour, dark); the tide
  coming in or going out and the waves (Open-Meteo marine); US AQI and, in
  Europe, pollen (Open-Meteo air quality); the planetary K-index (NOAA).
  These are fetched with the weather, never at the keep.
- **More body** (same HealthKit sheet, new types): daylight minutes, the last
  workout and how long ago it ended, mindful minutes, the mood logged in
  Health, surrounding sound level, stairs.

**New noticings:**
- crossings on posture, the dark, low battery, headphones, moving, just after
  an event, golden hour and the tide, against writing time, crossing-out,
  daylight, stairs and logged mood
- sea, air and noise as conditions only
- "you crossed out more than you kept"
- "the first time you've shown me your own face"
- aurora weather
- "You carried it three days. And 49 kilometres."

Golden hour, the dark and the part of the day are never crossed with the hour
(`entangledNumbers`), and ordinary states (battery fine, no headphones) are
the background, never the finding.

**Sessions get senses:** each piece of dream or wondering material carries how
it was kept ("lying on your side, in the dark, as the tide came in"), and a
wondering may ask about the moment.

## 9. The noticing bench

The harness that keeps this honest, modelled on the braid bench.

- Run every engine over a fixture archive (and, on a Mac, a real exported
  archive) and dump **every candidate**: its kind, its evidence, which gate
  passed or killed it, and its score.
- bj marks a sample good / bad / boring once. Those marks become a golden
  file.
- Tests: no candidate on the golden "bad" list may reach the court's output.
  Precision on the marked set must not drop. "photo ↔ photo" and
  "author days" are the first two entries.
- The model verdict gets a Mac mirror like the braid lab, so prompt
  changes can be benched without the phone.

---

## 10. Phases

### Status (2026-10-24)

- **Phase 0 landed.**
  - `AttentionFingerprint` v2 counts only what a photo shows (the
    `attention…` content fields) and what a voice said (its transcript). It
    never counts a prompt. Older stored fingerprints are rebuilt.
  - The loom refuses entangled pairs (`RelationalLoom.areEntangled`), and a
    glimmer now needs three hits on three days.
  - Hot and cold read the thermometer, not its digits.
  - The fold keeps the prose when a notice has no receipts.
  - Tests: `NoticingProvenanceTests`.
- **Phase 2's first batch landed** in `Shared/NoticingCrossings.swift`,
  surfaced through `BookNoticesPageSourceAdapter.crossingSurfaces`. It has:
  - category × number crossings (weather, moon, weekday, part of day, place,
    photo colour against words, questions, hour, people in pictures, sleep,
    steps, resting heart, HRV, calendar)
  - number × number trends
  - same-minute and twin-length coincidences
  - a steps record
  - weather firsts
  - the missing weekday
  - sunset pages
  - refrains
  - same-day rhymes
  - month colours
  - nobody in the pictures
  - the question shift

  Tests: `NoticingCrossingsTests`.
- **Phase 2 plumbing landed (2026-10-25).** Each kept page now stamps:
  - `WeatherMeasurements`: temperature, rain, wind, surface pressure and its
    six-hour change, humidity, cloud, UV. These come from the existing
    Open-Meteo call, with `surface_pressure` added for the past seven hours.
  - heart rate at the keep (only within 20 minutes), breathing, glucose
    (within 3 hours), active energy
  - last night's sleep window, on `BodySourceSignal`, kept off `metrics` so it
    never reaches prompts as text
  - EXIF capture date on picked photos (`PhotoTakenAt`)

  Old saved pages still decode.
- **New kinds:**
  - weather numbers as conditions only. They explain the reader and are never
    the finding.
  - a falling or rising barometer
  - the last page before sleep and the first after waking
  - "you carried it three days"
  - "your heart was quickest at this one"
- **The court got statistics.** A random-archive test (20 archives, nothing
  planted) found 17 chance "revelations" ("On Fridays, your heart is slower
  when you write to me"). Every crossing now has to:
  - hold separately in the older and newer halves of its evidence
  - clear a Bonferroni bar set by how many pairs were tested, using the exact
    shuffled-difference spread
  - when it's near that bar, pass a seeded permutation test

  Trends need ρ ≥ 0.55 over 21+ days, holding in both halves. The random
  archives are now quiet: at most 2 findings across all 20.
- **Cost:** 646 ms cold in debug on 2,920 pages (crossings 288 ms), off-main,
  once per archive change per hour. 2.4 ms memoised.
- **Phase 3 landed (2026-10-25)**, as Silvie's smallest proof: one Cast
  thought on one kept Souvenir.
  - `Shared/WritingDesk.swift` holds the wants, the held drawer
    (`WritingDesk` in the vault) and `WritingDeskPageSourceAdapter`.
  - Wants come from Souvenirs kept in the last 3 days with six or more words of
    the reader's own. Each gets a Cast speaker with a written voice, picked
    from the page so the choice is stable.
  - The ask is an "I Want to Write" page whose fold has two buttons: "Yes.
    Write." and "Later". It shows at most once a day, only when the model is
    ready, and never under distress. Either answer means no more asks today.
  - The session (`InsideCoverApp/WritingSessions.swift`) writes up to 2 pieces
    in at most 150 seconds while the screen is held awake. It saves each piece
    the moment it's done and stops if the reader leaves.
  - Each piece goes through the existing `StudentNoteWriter`: character canon,
    the Souvenir as the required subject, a fidelity audit and a repair pass.
    It uses `writeHeld`, which returns nothing instead of the canned fallback,
    so the drawer only holds real writing that is really about the Souvenir.
  - Held for at least 14 hours, then revealed one a day as that member's own
    note ("Penny Blackletter left you something."), using the exact frozen
    text. A changed or deleted Souvenir, or 10 days unshown, withdraws it.
    Keeping it marks it revealed, so that Souvenir is never written about
    again.
  - Tests: `WritingDeskTests`.
- **Still owed:**
  - try the session on Rabbit (the simulator has no model, so it never asks)
  - include `writingDesk` in `ReEnchantedSaveFile` so held writing travels in
    a moved copy
  - capture dates for camera and illuminated photos (only picked photos so far)
  - the feature catalogue as data rather than code
  - bj's marked bench


| Phase | What | Ships with |
|---|---|---|
| **0. Stop the bleeding** | Remove `promptText` and media metadata values from `AttentionFingerprint`. Add a same-provenance rejection to the loom. Raise evidence floors. Fold safety net. Delete the automatic Almanac Is Quiet. | Tests reproducing "photo ↔ photo" and "author". |
| **1. Bench** | §9 harness and golden file. | First marked sample from bj. |
| **2. Model-free noticing** | **First batch: §8's kinds, under its four rules** (the court's deterministic gates), found by the feature catalogue and automatic crossing ("All of it, crossed"), with the hand-written kinds as its seed. Underneath them, deterministic reading cards (§4) at keep time, backfilled off-main via `detachedDatabase()`, so patterns and the loom read cards instead of words. | Bench entries per kind, each with a beats-chance test. The daily body snapshot plus the keep-time heart rate and sleep-window stamps. Weather numbers, pressure trend and sky stamped at keep (the extra Open-Meteo fields ride the existing request). A within-season test for weather kinds. A lint that body noticings carry no health judgments ("good", "bad", "healthy", "should"). Bench precision before/after. |
| **3. Wants + drawer + one session** | The stores, the ask, the runner on `writeDraft`'s skeleton. **One job kind: a Cast thought on a kept Souvenir**, held and revealed once. This is Silvie's smallest proof. | On-device run on Rabbit. Interrupt mid-session and confirm nothing duplicates. |
| **4. Court + forge** | The Phase 2 gates applied to every notice maker. Verdict and noticing jobs in sessions. The forge's output becomes held notices. | Bench, plus a week of real notices. |
| **5. Case-file fold** | §6: receipts, falsifier, wager/errand, verdict feedback. Per-maker cleanup. | Every notice maker has a non-empty fold (test). |
| **6. New kinds** | §7, one at a time, starting with the sock and shift. | Bench entries per kind. |
| **7. More customers** | Bleed pieces, Night Council, Cast business across sessions. | — |
| **8. Thinking jobs** | §12. Every kind of job that needs judgment rather than counting goes through the same ask. First batch: verdicts on noticings, rereading held writing before it's revealed, and writing edition leaves ahead (never the braid). | Tests per job kind. A device session on Rabbit. |

Phases 0 and 1 are independent of everything else and can start today.
Phase 2 needs no model and no writing session either, so the Book can get
much better at noticing before "I want to write, please?" exists.

---

## 11. Open questions for bj

1. **How rare is "rare"?** A starting guess: at most once a day, and only when
   the wants list has at least two jobs worth doing.
2. **Should the reader ever see the wants list?** ("Things I want to write" as
   a leaf.) It would make the Book's appetite visible. It would also spoil the
   surprise.
3. **Belief.** Opening a model-written Page already "borrows some Belief"
   (`BeliefEconomyPolicy.generationKind`). Does a session cost Belief, earn it,
   or neither? Proposal: neither. Writing is the Book's appetite, not a
   purchase.
4. **Held-then-revealed and print.** Once revealed and kept, a held piece
   prints like any Page. Should it carry its written-on date in print ("written
   Tuesday, shown Friday")?
5. ~~**The Almanac Is Quiet**~~ Settled: it was already Glow-menu only.
6. **What does the first session prove?** Silvie's proof (one Cast thought,
   held and revealed) tests the drawer and the reveal: the part the reader
   feels. Claude's preference is verdicts first: short keep/drop outputs that
   test the runner cheaply and improve noticing the most, with prose after.
   Phase 3 is written as Silvie's version. Swapping in verdicts moves the court
   ahead of the drawer.
7. **Body mass in noticings?** Left out by default (§8, Body). Include it,
   include it only as a count ("you weighed in every Monday"), or leave it
   out?
8. ~~**Should a braid ever be written early?**~~ **Settled, bj
   2026-10-25: no.** The braid is never prewritten.
9. ~~**Reading the desk ahead and Belief.**~~ **Settled, bj 2026-10-25: no
   reading ahead.** Desk Pages are written when opened, from current data.

---

## 12. Thinking jobs (Phase 8)

"I want to write, please?" is the Book's one way of asking for time. For the
Book, thinking and writing are the same act. Anything that needs judgment
rather than counting queues as a want and waits for the next yes. The desk
grows from one job kind to many; the ask, the runner, the save-after-each-piece
rule and the drawer stay the same.

### What thinking is for

1. **Judging** (short outputs, cheap on E2B)
   - The court's verdict on a noticing: one fact seen twice? Obvious? Would a
     person say *huh*?
   - Which kept page deserves to come back this week.
   - Which Cast member would care about a finding.
2. **Reading**
   - Reading cards (§4): who, where, what thing, the sock.
   - A second look at photographs with the VLM, batched after text jobs.
   - Spotting people for People of the Book. Never guessing at real details.
3. **Joining**
   - Two or three surviving crossings made into one finding with all their
     receipts.
   - Rhymes across months.
   - A reader's real Souvenir carried into the monthly story ("the rescued
     recipe ends up in Ambrose's kitchen"). This stays inside canon rules: it
     doesn't rewrite the authored spine.
4. **Writing ahead**
   - Bleed pieces about things that have already happened.
   - Edition prose, so printing is instant.
   - Cast talking to each other about the reader, held.
5. **Planning**
   - The Night Council (Naturalist/Heretic/Gardener, already built in
     `OvernightScribe.writeDraft`).
   - Sealing a wager.
   - Choosing tomorrow's dare or errand to fit the week.
6. **Remembering**
   - The Book's own private journal, a few lines a session, findable later.
   - What each Cast member now thinks of the reader.
   - A monthly précis for Let's Chat.
7. **Rereading its own work**
   - Before a held piece is revealed, the Book rereads it against newer pages
     and keeps it, revises it, or crosses it out.

### Rules

- **The deterministic layer decides; the model judges or renders** (the
  braid's lesson). Nothing the model guessed is presented as known, and every
  held thing carries its receipts.
- **Short outputs, many small jobs.** Prefill can't be cancelled, so a session
  is a queue of brief jobs, saved one by one.
- **Text jobs first, then VLM jobs:** one warm container.
- **One ask, never nagging.** As wants pile up the ask may say how hungry it is
  ("I've got four things I want to write"), never what they are.
- **Priority:** short judgments first (verdicts, then rereads), then what the
  Book wants to make (Cast thoughts), then long jobs (edition leaves). A long
  job starts only when the session has the time left for it.

### First batch

1. **Verdicts on noticings.** The strongest unspoken crossings get a model
   verdict: keep or drop, with a reason code (`same-fact`, `obvious`,
   `boring`, `ok`). Drops never reach the desk. Verdicts are stored on the desk
   by noticing id and expire with the archive window. Reading cards follow,
   built on the deterministic cards from §4.
2. **Rereading before revealing.** A held piece due within a day is reread
   with its Souvenir as it stands now. The verdict is keep or cross out; a
   crossed-out piece is withdrawn, honestly. Revision is a later step.
3. **Writing ahead: edition leaves.** Binding a month always waits on the
   model (the "fast" bind's flag is ignored and `gemmaMonthlyBinding` always
   runs). A session writes the most recent finished, unbound month's foreword,
   binding story, closing and Cast conversation into the same checkpoint the
   Bind button reads, so binding becomes instant. A stage is marked done only
   when the model really wrote it.

   **Braids are never written ahead** (bj, 2026-10-25). Tonight's braid
   gathers the pages since the last braid, and it belongs to the night.

### Second batch (2026-10-25)

1. **Crossing wagers, inside the existing sealed margins.** The Book already
   bet with itself (`BookWager`, `SealedMarginEngine`: "X will return within
   14 days", graded by a word search). A crossing judged worth saying now seals
   a sharper bet in the same ledger: "The next three rain days: your heart goes
   slower, under 61 beats a minute."
   - It carries a `test`, and the engine grades it on the next three days that
     test it instead of by searching. Two of three is right.
   - Its `opensAt` is only a 60-day deadline: untested by then, it opens as
     lost ("A bet the world never tests is one I lose").
   - It uses the same two-sealed limit, the same subject cooldown, and the same
     "A Sealed Margin" and "The Seal Opens" pages. The opening carries the
     actual readings.
   - One system, not two (bj, 2026-10-25).
2. **Joined findings.** Two or more kept crossings about the same condition
   (rain days: a slower heart *and* shorter pages) become one want. The model
   writes them into one "I've been thinking" page. Every number in its output
   must already be in the evidence it was given, or the draft is thrown away.
   The joined page carries every receipt and retires its parts.
3. **The Book's journal.** After a session that did anything, the model writes
   two or three first-person lines from a plain list of what the session did.
   The list never names what a held piece is about, so the journal can't spoil
   it. Every week or so, once three or more entries are unread, a "From My
   Journal" page turns up with the latest few, dated.
4. **Secret while it works** (bj, 2026-10-25). Unlike every other
   generation, a writing session never shows what is being thought or written.
   While a session runs, every writing card is one sealed card ("I'm writing.
   You can't see it."), whatever the job: no subject, no kind of job, no live
   ink, no progress line, no making-of scene (`WritingSessionSecrecy`). What it
   made is only seen when it's revealed.

5. **Dreams.** Every couple of days, with three or more fresh pages of the
   reader's own, the Book dreams. The model recombines real things from those
   pages into three to five sentences that never happened, and the dream is
   told the next morning as "I Had a Dream". It must share at least two real
   words with the pages, contain no numbers, and never explain what it means.
   The fold shows "What it was made of".
6. **Wondering.** Every few days the Book picks one small, specific thing in
   the reader's recent pages and asks one real question about it, later, as
   "I've Been Wondering". It must be a question, about something actually
   there, and never a therapist's question ("how did that make you feel"). The
   reader answers in the margin.

**Decided: no reading the desk ahead** (bj, 2026-10-25). Notes, Two Readings,
letters and the like are written when opened, from up-to-the-minute data,
and stay that way. Writing sessions are for the Book to *think* in ways it
can't without a model, not for prewriting Pages that should be fresh.

## Risks

- **Small model, big judgments.** E2B makes confident nonsense. The court's
  deterministic gates come *first*, so the model only judges candidates that
  are already plausible, and every claim needs receipts that resolve.
- **Asking too often turns into nagging.** The cap and the free Later are
  hard rules, not tuning.
- **Held text going stale.** The re-check before release is mandatory. A
  withdrawn piece costs nothing, and a stale one costs trust.
- **Prefill can't be cancelled.** Keep jobs short and prompts lean. The
  forge prompt is the largest and gets trimmed first.
