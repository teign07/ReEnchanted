# The Faerie-Tale Spell: implementation plan

Written 2026-11-16 from a design conversation with bj. This is the build plan
for making the Book do what it is for.

## The purpose

bj, 2026-11-15:

> This is a literal grimoire, whose purpose is to turn the user's real life
> into a faerie-tale, one where they can look back on their deathbed and say
> "holy shit, what a magical trip."

The whole loop, in bj's words: every prompt gets the Reader to **notice or do**
something and record it in one sentence, so that over time their experience of
the world becomes a faerie-tale. That is combined with our fiction and
meta-fiction, which also reaches out beyond the Page. Then all of it is printed
as "proof and record of that faerie-tale existence". "Everything reinforces the
spell. We make the spell as potent as possible."

**The test for any feature:** does it leave the Reader with a memory of
something done or seen in the world, keep the record, and make the next one
more likely? A memory of a page read does not count.

**What the audit found (2026-11-15).** The Book is strong at making one moment
strange (217 missions, 49 spells, 40 dares; a working reaches the desk on about
two visits in three) and at recording it (every Page asks one sentence). It is
weak at making moments **add up**. Nothing accumulates into a story about the
Reader. That is what this plan builds.

## Laws (do not break these)

1. **Never invent what the Reader did or felt.** The Book may invent what
   objects, creatures and places think or do. Reader's words are quoted whole or
   left out, never clipped or paraphrased into new facts.
2. **One sentence is the whole job.** Every ask wants one sentence, one subject.
3. **Deterministic first.** Every feature works with no on-device model. Gemma
   only adds judgment and joining lines on top (Phase 7).
4. **Derive from the archive; avoid new ledgers.** State is read from kept
   Pages and their tags (the Bestiary and the deals in Phase 0 work this way).
   A Page the Reader throws away takes its consequences with it. If something
   truly needs vault state, read `PlayerVault` carefully first: it is one
   `@Observable`, mutations are batched, and an undecodable field once blanked a
   Reader's vault. New vault fields must be optional and decode-if-present.
5. **Not gentle.** Faerie tales are not gentle; hard days get magic too. Never
   fix a problem by rationing or softening. The only reader protections that
   stay are the Reader's explicit refusals ("Only when I choose it", "Keep
   wonder indoors", shelf marks, per-person "Tread gently").
6. **The Book's voice.** Read `docs/childlike-honesty.md` and
   `docs/the-book-is-a-character.md` before writing any reader-facing line.
   Simple, direct, childlike, things really are alive. Contractions everywhere.
   Banned: "hinge", "ritual", teeth idioms, door idioms, the "X, not Y" shape,
   therapy and self-improvement phrasing, permission padding ("if you want"),
   semicolons and em dashes in reader copy. The Book has no hands and no pencil.
   Never write "the Book" in the Book's own narration.
7. **Writing sessions think, they do not prewrite.** No session job may
   prewrite the braid or a desk Page. Sessions are secret: no subject or job
   kind is shown while one runs.

## Working conditions

- **Another session has uncommitted work in this tree** (first-week changes in
  `SourceAdapters`, `ContentView`, `BookToday` and others, plus
  `FirstWeekTests.swift`). Do not revert, reformat or "fix" hunks you did not
  write. **Do not commit, push or branch.** bj commits.
- **New Shared files** must be added to `Package.swift` `sources:` **and** the
  Xcode project (`EnchantifyInsideCover.xcodeproj/project.pbxproj`: four edits
  per file: PBXBuildFile, PBXFileReference, group child, Sources phase; ids are
  simple sequential ones). Test files in `Tests/InsideCoverCoreTests` need no
  registration. Prefer extending an existing file when the addition is small.
- **Tests:** `swift test --filter <Suite>` while working; the full
  `swift test` (about nine minutes, 5,572 tests at the time of writing) before
  calling a phase done. Voice rewrites routinely strand tests that assert old
  literals: check with `git log -S` which side is stale before changing either.
- **App target:** `swift test` does not compile `InsideCoverApp/`. Build it with
  `xcodebuild -scheme InsideCoverApp` (scheme, never `-target`). The disk is
  nearly full: check `df -h .` first and stop if under 3 GB free. Never use
  `devicectl --remove-existing-content`.
- The simulator has no on-device model. Anything that needs Gemma is tested
  with a fake teller closure, as `WonderBraid` and `TaleGemmaTelling` are.
- **Keep a log.** At the end of each phase append to "Progress log" at the foot
  of this file: what was built, the files, the test result, and anything left.

## Decisions that are bj's

Do not block on these. Use the stated default and list it in the log.

| Decision | Default until bj says otherwise |
|---|---|
| The price of a broken deal | No price. The Book says one lawful line and records it. |
| The register's name | "The Neighbours" (the fair folk were "the Good Neighbours") |
| December's theme | **Confirmed by bj 2026-11-16: "The Long Watch".** Phase 9 may be drafted; nothing is published without bj. |
| App Store promo text | Leave as is. |

---

## Phase 0: already done (2026-11-15/16, uncommitted)

- 21 of 217 Playful Missions rewritten so each believes something and returns
  one sentence (`Shared/StoryEngine.swift`).
- "Ask gently" removed; the quiet answer to "How sharp should I get?" only caps
  campaign pressure; eleven "lowered the lamps" lines rewritten.
- **Deals the Book comes back for**: `PlayfulMissionRegistry.promiseTerms`,
  `promiseCallIn`, `promiseMissions` in `Shared/StoryEngine.swift`; tests in
  `Tests/InsideCoverCoreTests/StandingPromiseTests.swift`. Nine spells set a
  deal; the Book calls it in at 7, 30 and 90 days and every year, quoting the
  Reader, as the day's mission on alternate two-hour turns for three days.
  Answered call-ins are found by the receipt tag
  `mission:promise-call:<pageID>:<stage>`.

Measured, do not "fix": the desk already guarantees and rotates an errand seat
(`placeLoopFloor(job: .errand)` in `SurfaceAndCurator.swift`). A plain Reader
over 63 desks got missions 22, spells 11, dares 11. The "Maya" journey
simulation shows none for reasons not yet isolated; do not tune the curator
from her numbers.

---

## Phase 1: The Neighbours (the register)

**Goal.** Every thing, creature and spot in the Reader's real life that has
become somebody gets a standing record. This is the keystone: deals, name-days,
the map and the chronicle are all about Neighbours.

**Model.** A `Neighbour` has: stable id (`neighbour:<slug>`), name (or an
epithet like "the heron" until named), kind (`thing`, `creature`, `place`),
the founding Page id and date, the Reader's founding sentence, where it lives
(coordinates of the founding Page when the archive has them), every Page it
appears on, last-seen date, and status (`living`, `resting`, `gone`).

**Where they come from.** The Book proposes; the Reader confirms with one tap
and may correct the name in the same step.

1. *By naming.* A kept Page from a naming working: spell `name-a-tree`; missions
   `faerie-name-earned` (Give It a Name), `tiny-kindness` (Lost Property
   Office), `chair-held`, `faerie-door-courtesy`, `object-drawer-greeting`,
   dare "Rename a Room". Candidate name: a capitalised word that is not
   sentence-initial, using the same rules `PeopleOfTheBook.suggestions` uses
   (lowercase-dominance kills common nouns; exclude Cast names, the Reader's
   name, people threads). If no candidate, propose with the working's subject
   as an epithet ("the tree by the gate" is not derivable; use "the tree").
2. *By coming back.* A `TaleThread` noun (`word:<noun>`, three Pages on three
   days) or a Bestiary creature filed on two or more days.

**Storage.** Archive-derived. Confirming writes one small kept Page (the
Neighbour's founding record) tagged `neighbour:<slug>`, `neighbour-kind:<k>`,
`neighbour-source:<pageID>`, with the name in metadata. Rename, rest and "gone"
are further tagged records. The register is rebuilt from tags; history is found
by whole-word name match over reader-authored text. Memoise it: whole-archive
reads belong off the main thread (`detachedDatabase()`).

**Surfaces.**
- Proposal: through `BookNoticesPageSourceAdapter`, modelled on "A Recurring
  Name" (`spoke:` rest tags, declines are permanent). Copy example:
  "Gerald. Shall I give him a page?"
- The register itself: a leaf listing Neighbours with status, opened from the
  Glow menu's Cast section beside People of the Book. Each row opens a file:
  founding sentence, pages, deals, last seen, and actions Rename / Let it rest /
  It's gone. (App target. Model it on `PeopleOfTheBookSheet`.)

**Tests.** Proposal from a naming Page; no proposal from a common noun, a Cast
name or a person thread; recurrence threshold; confirm creates exactly one
Neighbour and is idempotent; history finds later Pages by name; a thrown-away
founding Page removes the Neighbour; rename keeps history; never proposes on a
Book-authored Page.

## Phase 2: Neighbours over time

- **Addressed workings.** Mission templates that take a Neighbour by name
  ("Go and tell Gerald the news.", "Ask Dribble what it's been keeping from
  you."), chosen by kind, offered through the same due-date tier the deals use.
  The Reader's earlier sentence about the Neighbour rides along, whole.
- **Deals bound to Neighbours.** When a deal's spell Page founded a Neighbour,
  call-ins use the name ("A month ago you told Gerald his name.").
- **Name-days.** Each year on the founding date: a Page for that Neighbour.
- **Gone quiet / came back.** Reuse the shape of `PeopleOfTheBook.quietSignals`
  (35 to 240 days quiet with real history; returned after a 35-day gap).
- **Endings.** "It's gone" writes an ending record. The Neighbour stays in the
  register and on the map as gone, with its dates. An ending is a real ending;
  the Book does not console.
- **The Book's one line** about how each Neighbour is doing, deterministic, from
  facts only (last seen, deal state, season).

**Tests.** Each notice fires on its dates only, once; resting and gone
Neighbours are never addressed; the alternate-turn rule still leaves ordinary
errands.

## Phase 3: Deals, finished

- **The reply.** When a call-in is answered, the Book answers back at keep time
  (see `LivedMissionReturnMarginalia`). It records the answer; it does not
  judge the Reader's sentence. Default: no price (bj's decision).
- **Move the six existing return visits** (`returnInvitations` in
  `StoryEngine.swift`) onto the due-date tier. Today they compete with 217
  missions in the ranked pool and rarely surface.
- **Deals from missions and dares** whose text sets one (audit the lists;
  "Leave It Kinder: don't get caught" is over that day, "May I?" at a doorway
  is not).
- **A count of standing deals** on the Reader's Sheet.

## Phase 4: The deed chronicle and the Reader's titles

- **Deeds.** One derivation that lists what the Reader has done: workings
  returned (`LivedQuestReceipt`), spells cast, deals made / answered, Neighbours
  met, named and lost, feasts kept. Dated, with the Reader's own sentence.
- **The leaf.** In the monthly, seasonal and annual editions: the month or year
  told as deeds, Reader as protagonist, built only from the derivation
  ("In October you told a tree its name. You said hello to it eleven times.").
  Deterministic prose by default (see how `WeeklyBindingPlan` decides before it
  writes). Respect page caps and the print laws in `docs/field-book-plan.md`.
- **Titles.** Epithets earned by deeds ("Namer of Trees", "Who Lost to a Pigeon
  with Honour"), each tied to a specific deed and date, never a claim about
  character. Shown on the Reader's Sheet and available to the edition cover
  beside the existing role (`BoundReaderRole`).
- **Deeds as Tales.** Let `TaleGrammar` open a thread on a Neighbour or a deal
  so a finished one is told "Once upon a time you told a tree its name."

## Phase 5: The map and the print leaves

- **Atlas layer.** `AtlasLayerID("neighbours")` in `Shared/Atlas.swift` (layers
  are built to arrive from outside). One mark per Neighbour at its founding
  coordinates; gone Neighbours get a different glyph. Indoor things cluster at
  home; thin by weight.
- **Gazetteer.** `GazetteerGaps` may say where no Neighbour lives yet.
- **Print.** "Who lives here" leaf (the Reader's dramatis personae) and the
  Neighbours map as an endpaper in the yearly book.

## Phase 6: The other ingredients of a tale

Each is small once Phases 1 to 4 exist. Same laws.

1. **A calendar of their own.** Name-days and deed anniversaries as personal
   feast days, through the existing private-tradition and feast-calendar code
   (`BookPrivateTradition`, `FeastdayComposer`). Never on a grief date the
   feast rules already protect.
2. **Fate.** The Book already seals wagers and asks for forecasts
   (`BookWager`, `SealedMarginEngine`, the "Consultation of the Rodent" feast).
   Add the receipt: "I told you in March." Only when the sealed text exists.
3. **Objects with a history.** Tie Pocket keepsakes and Inventory items to the
   deed that produced them; let one be asked after like a Neighbour.
4. **Their own laws of magic.** Present the grimoire engine's confirmed
   correspondences as the Reader's rules, with when each was tested and which
   broke. No new statistics; presentation only.
5. **The enemy's record.** The Curse has a daily Knock score and no history.
   Derive campaigns: the worst week, a Page rescued from the Grey, rounds won.

## Phase 7: Gemma, through "I want to write"

Two new `WritingWant` kinds in `Shared/WritingDesk.swift`, both thinking jobs:

- **Who is this?** Decide whether two recurring references are one Neighbour
  ("the grey one by the weir" and "Harold"), and pull a name out of a sentence
  ("The blue thermos is Dribble"). Output is a *proposal* the Reader confirms.
  Refuse any answer that names something not in the Reader's text.
- **How are they?** One line about a Neighbour from its real history. Held,
  checked (no reader acts or feelings invented, no copied five-word run), then
  shown on the Neighbour's file. Deterministic line is the fallback.

Also: joining lines for a deed Tale, reusing `TaleGemmaTelling`'s prompt shape
(bare notes, the three openers, "Say <name> in every line").

Everything is tested with a fake teller. Prompts are small (about 400 tokens);
a 2B model renders well and invents badly, so hand it facts and ask for a
verdict or a join.

## Phase 8: The fiction meets the Neighbours

- The wonder braid's object mischief prefers a Neighbour when the day's Pages
  mention one, and may use its name.
- Story Pages may take a Neighbour as `{{thing}}`.
- "Write into the story": one tap makes a Neighbour a `CustomCastMember`,
  exactly as `PeopleOfTheBook.invitedIntoStory` does for a person.
- The Bleed may carry a Neighbours column.

## Phase 9: December, "The Long Watch"

Confirmed by bj on 2026-11-16. The work here is a **draft for bj to read**:
a story document `docs/december-the-long-watch.md` in the shape of
`docs/november-the-guest.md` (thesis, the month's question, the folklore it
stands on, the scene list with dates, the mechanics it rides on, laws for this
story, open questions), and a scenes file in the shape of
`docs/november-the-guest-scenes.md`. Read the November documents, the lore
bible (`docs/lore-bible.md`), `docs/monthly-issue-playbook.md` and the three
December hand-off endings in `ContentPacks/the-guest/content_december.py`
first. Do not build, sign or publish a pack, and do not edit the November pack.
Thorne's knowledge stays ambiguous; the Reader is never punished by an ending;
scenes must stand alone for a Reader who dips in.

November's last scene hands December three tags
(`december-watch-ambrose`, `-light`, `-house`) and the words "Somebody'll have
to sit up with that." October asked who may be invited in; November what you
owe them once inside; December: **who sits up with you through the longest
night?**

Outline: at midwinter the Wild Hunt rides with the Unseelie Court. It passes
over a house where everyone inside is known by name and a light is in the
window. The Academy takes the Roll of the House; something is missing from it,
and which thing depends on November's ending. The Reader takes their own Roll
(the Neighbours), keeps the Watch on the solstice with the lights off, and for
twelve nights after one Neighbour speaks each night. Wassailing is a deal with
a tree. Games become how the long night is passed: riddles, forfeits.

Timing: a content pack can ship by 1 December on what 1.0 already has. The
Neighbours need an app update through App Review; aim for about 12 December so
it is live by the 21st. Model the pack on `ContentPacks/the-guest/` and
`docs/monthly-issue-playbook.md`.

## Phase 10: Loose ends from the audit

- **Dares** are bold but not fae. A light pass so each has a believed premise,
  keeping Wicker's rules (`WickerDareTests`).
- **Elective fallbacks** (`ElectiveOfferFallback` in `WorldSystems.swift`) read
  as field notes. Give each a believed premise.
- **The braid**: only October's saved outputs exist, mostly flagged too short.
  Re-run the lab (`BraidMonthLabTests`) and record current quality.
- **The "Maya" simulation** shows no spells or dares in a month. Find out why
  before trusting either number.
- **Brain-less Readers** get no Story Pages. Consider a deterministic vignette.

---

## Order and what can run unattended

Phases 1 to 4 and the core halves of 6 and 7 are `Shared/` plus tests and can
be built and verified with `swift test`. The Neighbours leaf (1), the atlas
layer's view and the print leaves (5) and "write into the story" (8) touch the
app target and need a build; they cannot be seen working without a device.
Phase 9 is a written draft for bj and can run unattended; do it straight
after Phase 2, because 1 December is close.

## Progress log

- 2026-11-16: plan written. Phase 0 done as listed above; full suite green
  (5,572 tests) before this plan was written.
- 2026-11-16, Phases 1 and 2 (core and app), by an agent. Full `swift test`:
  **5,619 tests, 8 skipped, 0 failures** (baseline 5,572 + 47 new). App target
  `xcodebuild -scheme InsideCoverApp -destination 'generic/platform=iOS'
  CODE_SIGNING_ALLOWED=NO build`: **BUILD SUCCEEDED**. Not run on a device or
  simulator; nothing seen working on screen.
  - **New:** `Shared/Neighbours.swift` (model, archive-derived register with
    memo, proposals, records, addressed visits, the one line),
    `Shared/NeighbourSurfacing.swift` (`NeighboursPageSourceAdapter`: proposals,
    name-days, gone quiet, came back), `Tests/.../NeighboursTests.swift` (28),
    `Tests/.../NeighboursOverTimeTests.swift` (19). Both Shared files registered
    in `Package.swift` and the pbxproj (ids `…08A0`–`…08A3`).
  - **Edited (small hunks):** `SourceAdapters.swift` (adapter registered after
    the Bestiary's); `StoryEngine.swift` (`PromiseTerms.namedDeed/namedAsk`,
    `name-a-tree` uses the Neighbour's name, resting/gone Neighbours' deals not
    called in, visits added to the due tier); app: `CapturePageSheet.swift`
    (three adaptive actions), `ContentView.swift` (handlers,
    `applyNeighbourRecord`, `isNeighboursPresented`, sheet, Glow action,
    Contents entry), `ContentViewFeatures.swift` (one line, sheet counted as
    presented), `BookStatusCards.swift` (`GlowMenuAction.openNeighbours`, menu
    button beside People of the Book, `NeighboursSheet` appended at the end).
  - **Deviation:** proposals come from their own adapter (shares the Book
    Notices type, like the Bestiary) instead of a new branch inside
    `BookNoticesPageSourceAdapter`, to stay out of a busy file.
  - **Records** are `.bookNotices` Pages, origin `.generated`, tags
    `neighbour-record`, `neighbour:<slug>`, `neighbour-event:<founded|renamed|
    resting|awake|gone>`, plus `neighbour-kind/key/source` on the founding one.
    Declines reuse the existing reading boundary (`observationKey`
    `neighbour-propose:<key>`) through "It's nobody"; no new vault field.
  - **Defaults chosen (bj to review):** kinds: tree and room are `place`,
    chair/drawer/lost thing/kettle `thing`, Bestiary animals `creature`.
    Recurring nouns need 3 Pages on 3 days *and* "the/my/our X" at least twice,
    and skip a `notSomebody` list (weather, meals, rooms, family words). A
    creature needs photographs on 2 days. Visits: first at 10 days, then every
    28, open 3 days. Quiet/return thresholds copied from People of the Book.
    Name-day on 29 Feb falls on 28 Feb in other years. The confirm button uses
    the Book's guess; correcting the name "in the same step" is supported in
    core (`foundingRecord(for:name:)`) but the app has no text field on the
    proposal, so the reader renames from the Neighbours leaf instead.
  - **Not done:** whole-archive reads in the app are not moved off the main
    thread (`Neighbours.register` is memoised; the sheet builds it on open).
- 2026-11-16, Phase 9 (December draft), by an agent. **Written, for bj to
  read:** `docs/december-the-long-watch.md` (thesis, question, the Hunt, the
  Roll of the House and what's missing by November ending, three endings,
  Thorne kept ambiguous, folklore with attributions, 13 scenes + residue with
  2026 dates, the real-world asks, what ships on 1.0 vs needs the app update,
  laws, seven open questions) and `docs/december-the-long-watch-scenes.md`
  (scenes 1, 3, 4, 8, 9, 10, 13 in full prose with choices, braid lines,
  memories, recalls and fallbacks; 2, 5, 6, 7, 11, 12 and the residue as
  shorter working drafts). Nothing built, staged, signed or published; the
  November pack untouched. Not run through ProseAuditTests or
  BookCharacterLint (they read packs, and there is no pack). Defaults chosen
  for bj: the Twelve Nights run Dec 22 to Jan 2 (the last two as residue);
  wassail on New Year's Eve; the Huntsman unnamed and Herla-shaped.
- 2026-11-16, Phase 3 (deals, finished), by an agent.
  - **The reply:** `DealReplyMarginalia` (in `Shared/Neighbours.swift`), called
    first inside `LivedMissionReturnMarginalia.note` (one 4-line hunk in
    `WorldSystems.swift`). A call-in, a Neighbour visit or a name-day kept gets
    the Book's own margin line that records the answer and never judges it.
    Default: no price for a broken deal (bj's decision stands).
  - **Return visits** moved from the ranked pool onto the due tier in
    `PlayfulMissionRegistry.mission(for:)` (alternate turns, like the deals).
    A return visit to a Page that founded a Neighbour steps aside for that
    Neighbour's own named visits (`Neighbours.supersedingVisits`).
  - **Deals from missions and dares: audit result, nothing added.** No mission
    or dare text in `StoryEngine.swift` sets a standing deal (scanned for "from
    now on", "every time", "promise", "deal", "never tell", etc.; the hits are
    all over that day). The six return visits already cover the deeds that
    invite a second look. December's wassail would be the first pack deal and
    needs a pack-page hook (noted in the December doc).
  - **Reader's Sheet:** `standingDealCount` ("You've got N deals standing. I
    come back for every one.") and `neighbourNames` ("Your Neighbours: …").
    `PlayfulMissionRegistry.standingDeals(days:)` drops a deal whose Neighbour
    is resting or gone.
  - Tests: `DealsFinishedTests` (10).
- 2026-11-16, Phase 4 (deeds and titles), by an agent. New
  `Shared/Deeds.swift` (registered, ids `…08A4`/`…08A5`): `DeedChronicle.deeds`
  (workings returned, spells cast, deals answered, Neighbours met / named /
  gone, visits, name-days, feasts kept; a spell that named a Neighbour is told
  once, as the naming), `told(...)` (deterministic month-as-deeds prose, number
  words, the reader's sentences quoted whole), `titles(...)` (ten titles, each
  tied to the deed and date that earned it). Wired: a "What You Did" section in
  `MonthlyEditionBuilder.edition` (new `deedsSection`, placed before the
  souvenirs; multi-month spans say "the months from … to …"); titles on the
  Reader's Sheet. **Not done:** the annual builder (`AnnualEdition`), the
  edition cover beside `BoundReaderRole`, and "Deeds as Tales" in
  `TaleGrammar`. Page caps not re-checked against `docs/field-book-plan.md`:
  the section is one or two items. Tests: `DeedChronicleTests` (7).
  Default titles (bj to review): Namer of Trees, Who Renamed a Room, Keeper of
  Lost Things, Friend of Things (third thing), Known to a Creature, Who Answers
  for Deals (third answer), Who Goes Out When Asked (tenth errand), Caster of
  Seven Spells, Keeper of Feasts (third), Who Kept a Name-Day.
- 2026-11-16, Phase 7 core half, by an agent. `NeighbourThinking` (in
  `Shared/Neighbours.swift`): "How are they?" prompt (facts only, under 400
  words), a checker (one sentence, says the name, no reader act or feeling,
  no five-word run copied from the reader, no name the facts don't hold, no
  semicolons or dashes, never "the Book") with the deterministic line as
  fallback; "Who is this?" prompt and a parser that only takes a name written
  exactly in the reader's sentence; a same-one verdict prompt and parser.
  Tested with a fake teller (`NeighbourThinkingTests`, 6). **Not wired:** no
  new `WritingWant.Kind`, nothing runs it in a writing session, and the
  Neighbours leaf still shows only the deterministic line.
- 2026-11-16, Phase 10 passes, by an agent. **Dares:** 39 of the 40 immediate
  dares now open with a one-sentence believed premise in Wicker's register
  ("Pigeons keep score.", "That place has noticed you walking past it. It's
  offended."); "Give the Plant the Breaking News" already had one. The local
  (place) dares were left alone. **Elective fallbacks:** the eight offline
  `localStudy` acts in `ElectiveOfferFallback` each open with a premise
  ("Buildings remember every hand that pushed them."). The generic "A Field
  Note for …" title and ask were left as they are because the other session
  has an uncommitted hunk on those lines. Braid lab, the Maya simulation and
  brain-less vignettes: not started.
- Phase 5 (map and print leaves), Phase 6, Phase 8: not started.
- 2026-11-16, final check after all of the above (Phases 1–4, 7 core, 9, 10
  passes): full `swift test` **5,642 tests, 8 skipped, 0 failures**; app
  `xcodebuild -scheme InsideCoverApp -destination 'generic/platform=iOS'
  CODE_SIGNING_ALLOWED=NO build` **BUILD SUCCEEDED** (4.5 GB free after).
  Nothing committed. Nothing run on a device or simulator.
- 2026-11-18, simulator check of Phase 1 (iPhone 17 Pro Max simulator, a
  seeded "Tell a tree its name" spell Page; the simulator's own data was backed
  up and restored afterwards). **Seen working on screen:** the Neighbours entry
  in Contents under The Cast; the empty state; a proposal ("Shall I give Gerald
  a page?" with the Reader's sentence); Give it a page; the file ("Where it
  started"); Let it rest; Wake it; Rename (keeps "Called Gerald before."); It's
  gone (with its confirm); It's nobody (saved, survives a restart).
  - **Found:** the proposal never reached the desk. It scored 104 and was not
    rejected, but proposals use the Book Notices page type and the desk seats
    one Page per type, so "I've been reading you." (or any other notice) holds
    the seat. **Fixed here:** the Neighbours sheet now lists waiting proposals
    ("Waiting to Be Asked") with a name box the Reader can correct, Give it a
    page and It's nobody (`neighbourProposals`, `acceptNeighbourProposal`,
    `declineNeighbourProposal` in ContentView; `proposalCard` in
    BookStatusCards). **Still open:** the desk seat itself. Options: give
    proposals their own page type, or let a proposal outrank an ordinary
    notice. bj's call.
  - **Fixed:** both name boxes rendered white-on-cream / black in the sheet;
    they now use ink on paper.
  - Not exercised on screen: name-days, gone quiet / came back, addressed
    visits, deal call-ins by name (all date-driven; covered by tests only).
- **2026-11-19 — Neighbours get their own page type (bj's call).** New
  `BookPageType.neighbours` ("The Neighbours", house-and-flag), registered as
  the `the-neighbours` source. Proposals, name-days, gone quiet, came back and
  the archive records all use it. It sits in the **outward** lane (real things
  in the Reader's world) and is deliberately **not** `speaksOfItself`, so the
  Book's self-talk ration doesn't hold it back. It reads, answers and opens like
  a notice (`BookPageType.isNoticeLeaf` covers both in the leaf UI), binds with
  the notices in monthly editions, and counts as reprise / reflects-the-reader.
  **Seen in the simulator:** with the Gerald spell Page seeded, the proposal
  opened the desk ("Is This Somebody?", NEIGHBOURS header), Answer it showed
  Give it a page / It's nobody, and Give it a page saved a `neighbours`
  founding record. Also fixed "These 1 kept Page led me here." Simulator data
  restored afterwards.
- **2026-11-25 — Phase 5 (map and print) built.** `NeighboursAtlasLayer` puts
  every Neighbour whose founding Page knew where it was on the Atlas, at that
  spot (signpost / pawprint / sparkle by kind; a dotted mark when gone, moon
  when resting), on by default, with the Book's line and the Reader's own
  sentence on its card. `Neighbours.roll` + `whoLivesHereSection` print
  "Who Lives Here" in each monthly edition, and once at the back of seasonal and
  yearly volumes (`AnnualEdition.neighbourRoll`), told as each period was
  (a Neighbour gone later is still living in an earlier book). **Seen in the
  simulator:** Gerald made from the Neighbours sheet appears on the chart and
  the unfolded map with his card. **Fixed on the way:** the Atlas only
  recomputed when the day count changed (a Neighbour made today never showed);
  its caption now counts Neighbours; mark cards were see-through over the dark
  map; elective titles doubled the sender's name ("A Field Note for Lysander
  Mosswood: Lysander Mosswood"); the Book's own Cast tide said "The Book caught
  a point"; Inkrest's descriptor dropped "Gentle narrative therapist" for her
  canon line. The register memo now keys on coordinates too. Not built from
  Phase 5: the printed Neighbours *map* endpaper (needs the print plate's
  privacy loosening) and Gazetteer gaps. `WeeklyTaleReadingTests
  .testModelWritesBookJoins…` fails on the committed code as well (fixed dates;
  likely the system NaturalLanguage tagger); not touched.
