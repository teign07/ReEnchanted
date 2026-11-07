# The Knock

*Design, 2026-11-07. bj's decisions are in the next section. All five phases are written (see "Phases 2–5, as built" at the end); not yet built, tested or installed.*

## The idea in one paragraph

People are mentally elsewhere for about half their waking hours (Killingsworth & Gilbert, *A Wandering Mind Is an Unhappy Mind*, 2010: 46.9%). In ReEnchanted that half is the Curse's take. So every notification becomes a **Knock**: the Book reaching out of the pages into the reader's real day. A Knock is always answered with one tap or one sentence, usually right on the lock screen. Each answer is a move in the war the Book and the Reader fight together against the Curse. The war has a score, a map of where the Curse is strongest, pages to rescue, and a twist: one day the Curse gets into the Knocks themselves, and the Reader has to knock back.

## bj's decisions (2026-11-07)

- **Somewhere good counts for the Reader.** Only Grey goes to the Curse.
- **Three bookmarks, and they're ribbons.** The Book has three ribbons sewn into its spine (design in §4).
- **Stakes:** a Page fades from the Book's memory, never from the archive.
- **How many Knocks:** "just enough". The schedule is in §1.
- **The Curse stays faceless** for now.
- **Capture everything we can at each Knock** (place, weather, time, how the phone is held…) so the Book can actually identify the reader's Curse. "This should be a real fight."

## What already exists (and what this joins up)

Most of the parts are built. They aren't yet one game.

| Already in the app | Where | What it does now | What it becomes |
|---|---|---|---|
| Attention probe | `AttentionProbeLedger` (PagePacks), category `book-whisper-attention` | "WHERE'S YOUR MIND?" with HERE / ELSEWHERE, answered headlessly. Runs in cycles of 30–50 answers, then rests; cycles are compared. | **The Where-Were-You Knock**, the heart of the war (below). |
| Morning prompt whisper | `BookWhispers`, category `book-whisper-prompt`, 11:00 | A one-sentence ask with an inline **Keep it** reply ("One sentence..."). | **The Morning Knock**: the day's one-sentence ask. |
| Delayed outcome | category `book-whisper-outcome` | "A real moment / A flicker / Nothing" after a mission. | **The Return Knock**: did the dare land? |
| Evening whisper | 20:45 (18:00 on feasts) | The braid is ready, or a feast. | **The Night Knock**: tonight's chapter. Opens the braid. |
| Weather, Workings, Fae favours, people's pre-meeting charges | seat reservations in `refreshAll` | Assorted reminders. | Knocks in the same voice and shape, answered inline where they can be. |
| Grey Page threat | `GreyPageThreatEngine` (WorldSystems) | A kept Page is marked, fades for 72h, then is rescued or "erased" from the Book's living memory (never the archive). It sends **no** notification today. | **The Grey Knock**: rescue a fading Page with one sentence from the lock screen. |
| Book goes routine | `BookFamiliarityRutEngine` (WorldSystems) | After 6+ weeks, two or more independent signs (flattened language, clockwork sessions, **reflexive knock answers**…) move the Book from *familiar* to *rote*. | **The eucatastrophe**: the Curse gets into the Knocks; the Reader knocks back. |
| Thorned Bargain arc | `docs/lore-bible.md`, Acts 0–V | Duskthorn's opt-in, life-evidence-only grey, irreversible prices, banked mercy. | Untouched. The Knock is the everyday war; the Thorn is the opt-in high-stakes campaign. |

## 1. The Where-Were-You Knock

**When:** two a day: one in the morning (8–12) and one in the afternoon or evening (15–20), at a random minute, so always at least two hours apart. Today the probe knocks once a day between 9 and 7, so one round takes one to two months and almost never sees a morning or an evening. Two a day covers every hour within a round.
- **Their own lane:** the interruption budget gives each day two seats (morning and evening), and today's Knock takes one of them, replacing that window's whisper. Knocks now have a lane of their own, so the day holds at most two Knocks plus the two seats: four interruptions. Three Knocks a day would have made five, which is overdone.
- **Rounds:** the existing cycles become rounds of the fight. A round of 30–50 answers takes about two weeks, then rests for a week, and the round report compares it with the last one.
- **Backing off:** after 36 hours without an answer, the Book knocks once a day (in the afternoon window) until the reader answers again. Silence is never scored.
- **Runway:** iOS holds at most 64 pending notifications, so 20 days × 2 = 40, leaving room for the Book's other Knocks. Opening the app refreshes the runway.

**What it says:** in the Book's voice, short, different each time, never "Where's your mind?" twice in a row:
> *Knock knock. Where were you just now?*
> *I knocked. Were you in the room?*

**How it's answered, from the notification:**
- **Here.** One tap. A point to you.
- **Somewhere good.** One tap. Daydreaming, planning, remembering on purpose. That's travel, not the Curse. Still a point to you.
- **Grey.** One tap. Autopilot, the scroll, the fog. A point to the Curse.
- **Say where.** A text field: *"One sentence: where were you?"* Writing a sentence means you noticed, and noticing is the counter-spell, so it counts for the Reader. The sentence is kept with the Knock, and when the app next opens, the Book can file it as Here, Somewhere good or Grey for the map.

**What's captured with every answer** (on the device only, like a keep's context):
- the time, day-part and weekday;
- how long the answer took after the Knock arrived;
- how the phone was held: posture, moving or still, battery, charging, low-power mode;
- the last known place: its name, plus a coordinate rounded to about a kilometre with its age;
- the sky at that hour, from the stored forecast;
- the sentence, if there was one.

All of it goes in the same `BookPageContextSnapshot` a kept Page uses, so the existing place and noticing tools can read it. A lock-screen answer runs headless, so it gets what the app has stored. Tapping the Knock opens the app, and there the full moment is captured the way a keep is: a fresh fix, the body, the calendar, the nearby Anchor.

Answering is the counter-spell. Noticing you drifted is what brings you back, so even a Grey answer is a small win. The Book should say so now and then.

**Never counts:** an unanswered Knock. Silence isn't evidence (the lore bible already says notification taps are inadmissible as Curse evidence). Hard days don't count either (`distressActive`).

**Needs:** a third button (today's ELSEWHERE splits into *Somewhere good* and *Grey*), and a text-input action. iOS allows several actions on one category, and `UNTextInputNotificationAction` already powers the Morning Knock.

## 2. The score: the Curse's take

- **Today:** a small tally on the Book Today doorstep ("You 5 · Curse 2") and on the lock-screen widget (the widget extension exists).
- **This week:** the Bleed's war column (`bleed-lead-and-data-desks` already has war and odds columns) reports the Curse's share against the 47% everyone starts with. *"The Curse took 31% of you this week. The world average is about half. Penny is insufferable about it."*
- **Over cycles:** `latestCycleComparison` already measures the change in percentage points between cycles. It stays a descriptive receipt, never a diagnosis.
- **No streaks, no guilt.** A bad week is weather: the Curse always comes back, and the canon says attention is never a cure.

## 3. The Curse's hours: learning its habits

Over a few weeks the answers show *when* and *where* (coarse place only) the Curse is strongest:
> *It gets you hardest at three in the afternoon, in the kitchen.*

That gives the counter-attack:
- Wicker's dares and the missions get a seat **at the Curse's hour**: the Book knocks right when it's strongest.
- The Morning Knock can move earlier or later to beat it.
- The braid and the Bleed can name the Curse's favourite hour as the opponent's tactic.

This is learned only from the reader's own answers. It never uses app usage, and never in the Thorn's ledger.

## 4. The Grey Knock: fading ink and bookmarks

**Fading ink (stakes, no loss).** The Grey Page threat already marks one old kept Page at most every 7 days and gives 72 hours to rescue it. Changes:
- **The Knock:** *"Your Tuesday by the river is going grey. One sentence saves it."* The reply field is on the lock screen. Any sentence about that Page rescues it, the sentence is kept beside it, and the ink comes back.
- **On the leaf:** a fading Page shows its ink thinning (the Book's paper is thirsty; ink sinks back in).
- **If it isn't rescued:** the Page is never deleted. It stays in the archive and in print. It fades from the Book's *living memory*: it stops coming back in braids and callbacks. Any later visit or sentence re-inks it. **What the reader risks is the Book's memory of the Page, not the Page.**

**One ribbon, three strands (the choice that gives it weight).** *Built 2026-11-07 (bj: "combine the three ribbons into the one ribbon that is there now… tap the ribbon and you can bookmark, or choose to open one of your bookmarks… tactile and easy").* The Book keeps its single ribbon tail at the head of the Pages, now split into three dyed strands: **Madder** (red), **Woad** (blue) and **Weld** (gold). A strand holding a Page stands up in its colour; a free strand hangs slack and pale, and springs up when it's tucked.
- **Tap the ribbon** for a plain menu:
  - **Tuck a ribbon here**, or **Move a ribbon here** when all three are holding something, choosing which strand moves;
  - **Lift the ribbon from this Page**, when a strand already holds it;
  - **Your ribbons**: each strand's Page (*"Woad · Tuesday by the river"*). Tap one and the Book riffles straight to it.
- **Each Page's own menu** still says *Tuck a ribbon here* / *Lift the ribbon*.
- **The Curse can't drink ink under a ribbon.** Ribboned Pages join `protectedPageIDs`. Laying a strand in a Page that's already fading rescues it: *"Just in time. The grey's going out of it, and the ribbon's got it."*
- **Moving a strand** lets the old Page go: *"I let go of 'Tuesday'. The weather can have it now."*
- **Data:** `PlayerVaultData.ribbons` reads `pageRibbons`, and an older Book's single `savedPageRibbon` becomes the first strand. `BookRibbons` tucks, moves and lifts. `SavedPageRibbon.strand` is 0–2, and `protectedPageID` is the kept Page behind a visiting leaf.
- **In print (still to do):** the season's bound edition opens with the ribboned Pages.

## 5. Every notification is a Knock

One voice, one shape:
- It always comes from inside the Book: the Book knocks.
- It always asks for one tap or one sentence. The answer is taken on the lock screen whenever the action allows it.
- If it can't be answered there, tapping it opens the exact Page (the deep-link stores `PromptWhisperOpenStore` and `ReEnchantedWidgetDeepLinkStore` already exist).

| Knock | Answer in the notification | Tap opens |
|---|---|---|
| Where were you? | Here / Somewhere good / Grey / one sentence | the day's tally |
| Morning | one sentence (Keep it) | the Morning Page |
| Return (did the dare land?) | Real moment / Flicker / Nothing | the mission Page |
| Grey (a Page is fading) | one sentence rescues it | the fading Page |
| Night (the braid is ready) | none | tonight's braid |
| Weather, Working, favour, person | one sentence where it fits | their Page |

**The budget:** all Knocks share one daily allowance, so turning everything into Knocks never means more interruptions. Quiet hours and Focus modes are respected, Where-Were-You Knocks use the passive interruption level, and any kind can be switched off.

## 6. The eucatastrophe: when the Knocks go grey

The Curse doesn't only take the reader's day. It can take the Book.

1. **The Curse gets in.** `BookFamiliarityRutEngine` already counts *reflexive knock answers* (fast, identical taps) as one sign that the Book has gone routine. When it reaches *rote* (two or more independent signs, after six weeks at the earliest), the Book notices that it has become a doorbell.
2. **The Book stops knocking.** No warning, no guilt. For a few days the notifications go quiet, and the desk is a little greyer. The Book says so when you open it: *"I stopped knocking. I wanted to see if you'd notice."*
3. **The Reader knocks back.** The way out is the Reader reaching in unasked: writing to the Book without a prompt, or bringing it something it never asked for. That **reverse knock** wakes it.
4. **The turn.** The Book comes back changed: new Knock voices, new times, a letter in place of a ping. It names what happened plainly: the Reader saved them both.

This is the same shape as the Thorned Bargain's *banked mercy*, but small and everyday. The person who saves the reader is the reader.

## 7. The Inkbones: the dice of the fight

*Added 2026-11-07.* The Inkbones exist today in only a few places: Story choices (`StoryInkbonesBand`: triumph, favour, hesitate, cost or sideways, never blocking the chosen turn), Wicker's onboarding roll, the feast-day throw (`FeastBones`) and the "throw the bones" spell. Every Story throw uses the same odds: `InkbonesThrow.make` passes a fixed Belief of 50 to `BeliefCombatResolver.finalThreshold`, so nothing the reader does changes their luck. In the fight, the Inkbones become its dice.

**7.1 Your fight sets your odds (first).** A throw's threshold reads how the reader has been fighting this round:
- Knocks answered this round, in any way;
- sentences written in reply to Knocks;
- Pages rescued from going grey;
- ribbons held.

It shows as a short modifier stack on the throw, in the Book's voice: *"Knocks answered this round +6 · a rescued Page +2"*. The Unquiet Folio plan already sketches this display ("Throw the Inkbones").
- **Noticing earns the bonus, not being Here.** An honest Grey answer counts exactly like Here. If Grey lowered the odds, readers would learn to lie to the Knock, and the whole record would be worthless.
- Capped, so the bonus can move a throw by about fifteen points at most. Triumph and cost (rolls of 1–5 and 96–100) stay pure luck.
- Silence takes nothing away. An unanswered Knock just doesn't add.

**7.2 The Curse throws too (first).** The Grey Page engine's nightly mark becomes a visible throw. The Curse throws its own Inkbones at one unribboned Page, and the reader's recent rescues and answered Knocks are the number it has to beat. The leaf shows it: *"The Curse threw a 91. Tuesday is going grey."* A low throw is a night the Curse missed: *"The Curse threw a 12 and went home."* Fading reads as a contest, not a rule. The rescue itself is never a throw: one sentence always saves a Page.

**7.3 The bones choose how to look.** The Morning Knock throws one bone to set the day's way of looking, like *The Ninefold Chronicles*: a colour, a sound, something old, something owed, something small, something that changed. The reader chooses what to look at and writes one sentence. The dice decide the angle, never the answer.

**7.4 Sometimes the bones decide real things.** Now and then a Story throw settles an open fictional question rather than its texture: does the Cast member believe you, who gets the misdelivered letter, do you get the object back or only learn where it went. A cost result goes into the consequence ledger so it can come back. This is story work for the monthly packs.

**7.5 The throws are written where they happened.** No new object on the Book: it's crowded already (bj, 2026-11-07). Instead:
- **In the margin:** each throw is inked into the margin of the Page it was thrown on, as a small mark with its number, the way a reader notes a score. The Curse's throws mark the Page it threw at.
- **In the Bleed:** the war column prints the week's throws, both sides: *"The Curse threw 91, 12 and 47. You threw 8 and got a triumph."*
- **On the doorstep:** Book Today's one score line can carry the day's last throw.
- **In print:** the month's edition prints the throws of the month.

**7.6 The Inkbones Page: a game that writes a reading (bj, 2026-11-07).** One Page where the game and the divination are the same thing. How you play decides what the reading says. A first sketch, nothing settled:
- **Bring one thing.** A question, or just the day.
- **Three throws.** The bones fall face up. Each face is a symbol (salt, a thread, a key, a moon, ink, a coin…). After each throw you keep some bones and throw the rest again. Keeping is choosing: it's the Ninefold move again, where the bones offer and you pick.
- **The Curse throws back.** Between your throws it throws its own bones. On a strong throw it greys one of the bones you kept, and that bone is lost for this reading. The round's fight (7.1) gives you a small edge.
- **The reading is what you kept.** Each kept symbol gives the reading a line, in the Book's voice and authored ahead of time. The bone the Curse greyed gives the shadow line: what the Curse is after. A triumph adds a bright line. The text comes from where the bones fell and what you chose, so no two readings match.
- **It ends in one sentence.** The reader answers it: what lands, or what misses.
- **It's kept.** The Book can ask a few days later whether it came true, and the month's edition prints the month's readings.
- **Builds on:** the feast-day `FeastBones` throw and the "throw the bones" spell (`SpellBones`) already turn throws into bands and answers. The Page sits in the Game Page family and reads like the Tarot Page.
- **Questions for bj:** the set of symbols and what each one means, how many bones, and whether a reading should ever be stitched by Gemma or stay authored lines only.

## Rules (from canon)

- The Curse is never the reader's fault. A hard day scores nothing and fades nothing.
- Only the reader's own testimony counts as evidence. App usage never does (lore bible, Act I table). The one exception is the Book-goes-routine arc, which is about the Book, not the reader.
- Attention is not a cure, and every win is temporary. That is what makes it a war and not a chore.
- One sentence is the whole job.
- No streaks, no loss of data, no shaming notifications. Stakes are colour and memory, never content.

## Technical notes

- A notification answer is handled headlessly in `userNotificationCenter(_:didReceive:)` and only *records*. Gemma never runs in the background ([[gemma-gpu-background-abort]] in memory), so the Book's reply to a lock-screen sentence is waiting when the app next opens, or comes as a deterministic line in the next Knock.
- iOS caps pending notification requests at 64. The seat-reservation system in `refreshAll` already plans within a horizon.
- A Notification Content Extension could later show the fading Page's excerpt, or the day's tally, inside the expanded notification.
- The lock-screen widget can show the day's score.

## Phases

1. **The war begins:** the Where-Were-You Knock (Here / Somewhere good / Grey) with a one-sentence answer, the day tally on the doorstep and widget, and the Bleed's war column. All existing notifications get the Knock voice and their inline answers.
2. **The Grey Knock:** lock-screen rescue, thinning ink on the leaf, "faded from living memory, re-inkable", and the Book's three ribbons.
3. **The Curse's hours:** learn when and where, and seat dares and missions there.
4. **The Inkbones:** the fight sets the odds (7.1), and the Curse throws at Pages (7.2). Later: the morning angle (7.3), decisive story throws (7.4) and throws written where they happened (7.5).
5. **The eucatastrophe:** the Knocks go rote, the Book goes quiet, the reverse knock, the turn.

## Phase 1, as built

- `AttentionProbeAnswer` gains `.somewhereGood`. Legacy `.elsewhere` now means Grey.
- `AttentionProbeReceipt` gains an optional `sentence` and an optional `context: BookPageContextSnapshot`.
- The ledger keeps a day tally (Reader vs Curse) and per-round counts that put Somewhere good with the Reader.
- The schedule is two a day in two windows, with a 20-day runway and the quiet back-off. Knocks have their own lane in `BookInterruptionBudget` and their own notification identifiers, so they never take a seat or overwrite a whisper.
- The notification has three tap answers plus a one-sentence reply, and six ways of knocking in the Book's voice. `KnockMoment.snapshot` captures the moment headlessly from what the app stores. The round report speaks Reader vs Curse.
- Tapping a Knock opens `KnockAnswerSheet` (three choices and one sentence), not the ordinary desk.

## Phases 2–5, as built (2026-11-07, uncommitted, not yet compiled)

**The score.** Book Today's doorstep has an "Against the Curse" row (`BookTodayEdition.fight`: today's score plus the Curse's hour). There's a lock-screen widget, `ReEnchantedCurseFightWidget`. The Bleed's data desk prints "The Curse Report" (`BleedDataDesk.curseID`): knocks answered this week, the Curse's share against the usual 47%, its hour, counter-knocks held, rescues and the week's throws.

**The Grey Knock** (`GreyKnock` in AppSupport). When the Curse greys a Page, a notification goes out at 9:30 the next morning. Its one-sentence reply rescues the Page headlessly, and a tap opens it. A fading leaf shows its excerpt with the ink thinning as the 72 hours run out. A ribbon tucked into an erased Page re-inks it (`GreyPageThreatEngine.reink`).

**The ribbons** (§4). There are three strands (Madder, Woad, Weld) in the one ribbon. A `Menu` on the ribbon tucks, moves, lifts or opens them.

**The Inkbones.**
- Your edge: `InkbonesOdds.edge` adds knocks this week (up to 8), sentences (up to 3), rescues ×2 (up to 4) and ribbons (up to 3), capped at 15. It lifts the Story threshold, which the throw overlay shows as a modifier line.
- The Curse's throw: once a night from 18:00, only for a reader in the fight and never on a hard day. It needs `80 + edge`, and a hit greys a Page with a deadline. The Grey Page names the roll.
- Every throw is logged in `PlayerVaultData.inkbonesLog` (`InkbonesThrowRecord`).
- The morning bone (§7.3): one check-in a day is retitled "The bones fell on …".

**The Curse's hours.** Once `CurseFight.strongestHour` holds at least half the Knocks, every other day (by era-day parity) the Knock in that half of the day fires in that hour. Its id ends `-watch`, and it gets the counter-knock voice ("This is when the Curse usually gets you…").

**The eucatastrophe** (`KnockHush`, `KnockHushEngine` in PagePacks, run in `tendGreyPageThreats`).
- When the rut engine says *rote* and it isn't a hard day, the Book goes quiet: no Knocks, and no nightly Curse throw.
- Opening the Book shows "I stopped knocking. I wanted to see if you'd notice." The doorstep reads "No Knocks today. I'm listening for yours."
- A reverse knock wakes it. That's any reader-written Page (non-empty `userInput`) kept while the Book is quiet, because nothing pinged them.
- After the turn line, the week's Knocks end `-turn` and speak in new voices.
- If nobody knocks within 6 days, the Book comes back on its own. There's a 60-day rest before it can go quiet again.

**The Inkbones Page** (§7.6). This is a `.gamePage` with `gameID: inkbones`, surfaced by `GamePageSourceAdapter.inkbonesSurface`: one every 12 hours, leaning in on mornings and for a reader in the fight.
- `InkbonesReading` has five bones, six faces (salt, thread, key, moon, ink, coin), three throws, and keep by tapping.
- Between throws the Curse rolls d100 against `80 + edge` and can grey one kept bone.
- Each face has authored lines for one, two or three-plus bones, plus a shadow line for the greyed face. Three of a kind is a triumph.
- It ends with "One sentence: what lands, or what misses?". The kept Page carries the reading JSON in metadata, so a kept reading replays.
- The view is `InkbonesPageView` (in TarotPageView.swift).
- Choices I made for bj to revise: the six faces and their lines, five bones, and authored lines only (no Gemma).

**In print.** The month's edition has an "Against the Curse" section (`MonthlyEditionBuilder.curseSection`) with the month's score and the bones: both sides' throws, the Pages the Curse took, and the ones taken back.

**Did the bones come true?** (`InkbonesCameTrue`). Three to fourteen days after a reading is kept, the game slot offers *Did the Bones Come True?* (gameID `inkbones-came-true`, `InkbonesCameTrueView`). It shows the old bones and lines, three taps (It came true / Half of it / It missed), each with a line in the Book's voice, and one sentence about what actually happened. Each reading is asked about once (tag `inkbones-came-true:<pageID>`, plus `inkbones-verdict:<v>`).

**Throws in the margin** (`InkbonesMarginMark`). A kept Story Page is tagged `inkbones-mark:reader:<roll>:<band>` for each throw. A Grey Page the Curse threw at is tagged `inkbones-mark:curse:<roll>:took|missed` when it's rescued or let go. A reopened kept Page inks them as small stamps in its margin (`InkbonesMarginMarksView`), for example "37 · favoured" or "the Curse · 91" in grey.

**The season opens with its ribbons.** `MonthlyEditionBuilder.seasonal(… ribbonedPageIDs:)` puts the season's ribboned Pages in `AnnualEdition.ribboned`. They print as "Marked With a Ribbon", straight after the contents (which list them), before Part One.

**Still open.**
- A Notification Content Extension (a new app target).
- Folding the came-true verdicts into the month's edition or the Curse Report.

Tests: `KnockFightTests` (counter-knocks, the hush, the Inkbones Page, came-true, margin marks, the month's leaf, the season's ribbons), alongside the Phase 1 tests in `RutSelfKnowledgeTests`.
