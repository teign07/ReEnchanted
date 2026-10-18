# How We Met: moonshot audit

Played end to end on 2026-10-17 in the iOS Simulator (iPhone 17 Pro Max, fresh
install, Debug build of the working tree). Screenshots are in
`docs/onboarding-moonshot/before/`, one contact sheet at
`docs/onboarding-moonshot/before-contact-sheet.jpg`, and the PDF it bound at
`docs/onboarding-moonshot/before/how-we-met.pdf` (19 pages).

## What a first run costs today

| | Today |
|---|---|
| Screens | **25** (9 on the loose Page, 13 inside the Book, 3 for the little book) |
| Answers asked for | **~30 taps and choices**, including **5 typed answers** (one good moment, one true thing, snack, name, belief) |
| Words on screen | **~5,000 unique words**: about **22 minutes of reading** at 230 wpm before any typing |
| Wall clock | 18 min driving it by tool (my latency inflates this; the word count is the honest number) |
| New names and systems | **~30** |
| System permission prompts | 2 (photo library, mid-Pagewright; notifications, at the end) |

The Book admits it twice. The Pagewright card stamps "NO. Too many
questions." And the first desk page says "You got through all my questions and
you didn't run."

## Screen by screen

`Q` = an answer asked for. `New` = a name or system the reader hasn't met yet.

| # | Screen | Q | New |
|---|---|---|---|
| 00 | The Page Finds You (STOP. You're under a curse) | – | Page, Book, Curse, Book of You |
| 01 | The Ink Cheats (word vanishes, "did you see it go?") + 642 minutes | 1 | – |
| 02 | One Ordinary Hour (cook / walk / drive, then 3 remember taps) | 4 | – |
| 03 | A Good Moment, Lately (8 chips + one typed detail) | 2 | – |
| 04 | That's the Curse (verdict + science card) | – | Rut of Routine, 3 studies |
| 05 | What We Do About It (offer + "what makes your days blur?") | 1 | Rut, Grey |
| 06 | Your First Move (Pact + one true thing + keep/wait + preview) | 3 | the Pact, Keep, Pippa |
| 07 | Two Honest Answers (what happens to small things / did it get stranger) | 2 | – |
| 08 | Choose a Story Style (3 styles, card re-forms, share, Open the Book) | 1 | – |
| 09 | Through the Page (fall in, Zara, take her hand) | 1 | The Unwritten, Academy, Zara |
| 10 | Snacks | 1 | – |
| 11 | Word Got Around (three Cast members argue about your snack) | – | Mook, Pippa, Penny |
| 12 | Your Name | 1 | – |
| 13 | What You Believe (+ the Belief economy card) | 2 | Grey (again), Wicker (name-dropped), Belief-the-currency |
| 14 | The Inkbones (practice throw, "nothing happens") | 1 | Inkbones |
| 15 | Your Kind of Magic (9 chips) + what your hands do (5) | 2 | – |
| 16 | The Pagewright (full studio + Keep Page) | 1 | Pagewright, worktable, "The Inscription" |
| 17 | The Book Names You | 1 | role, epithet, Hands, Mark ("Backer"), patron (Lysander Mosswood) |
| 18 | What Should the Book Bring You First? | 1 | – |
| 19 | How Hard May the Book Push? | 1 | – |
| 20 | Choose Your First Chapter | 1 | Chapters, Emberheart, Mossbloom, Tidecrest, Riddlewind, Duskthorn, the Wind Cipher |
| 21 | Wicker Takes the Page (reply + Inkbones throw) | 1 | Wicker (in person), Cast |
| 22 | What the Book Made of Your Answers (recap) | – | Edition |
| 23 | Cover + photo + bind the little book | 2 | Bindery, cover plates |
| 24 | When should I knock? (+ habit research) | 1 | knock, "30" |

## Where a first-time reader gets lost

1. **Screen 06, the heaviest screen in the flow (429 words).** The button on 05
   says "Catch one now". What arrives is the Pact: three promises and a vow to
   tap. The ask to catch something comes after that, then keep-or-wait, then a
   margin note from Pippa, whom nobody has met, then the Rut's arrival, then the
   story preview. Pippa's note also says "a real page now, not a rehearsal": an
   X-not-Y.
2. **"First question, and it's important"** (Zara, screen 10). By then the reader
   has answered about 14.
3. **Belief means two things on one screen** (13). "Tell me one thing you
   believe" becomes "Belief's what you give… you earn it, you spend it". The
   same screen re-introduces the Grey and drops Wicker's name, eight screens
   before he turns up.
4. **Three strangers at once** (11). Mook, Pippa and Penny all arrive to argue
   about a snack. The snack is also pasted in mid-sentence with its capital
   ("what Salted almonds does to a page").
5. **Part 3 is called "The Story Bites Back", and it opens with two settings
   questions** (18, 19). The story doesn't bite until screen 21.
6. **Six new names on the Chapter screen** (20): five Chapters plus "The Wind
   Cipher warms", which nothing ever explains.
7. **The role reveal stacks five new things on one card** (17): role, epithet,
   "Making Hands", a "BACKER" Mark and a patron ("Lysander Mosswood has been
   told… You'll meet them soon"). The role is the payoff. The patron and the
   bare Mark label only dilute it.
8. **Pagewright** (16). Opening the worktable fires a full Photo Library
   permission prompt with no warning. The text toolbar sits over the title.
   Fact labels leak onto the scraps ("Most alive: Moving my body", "Robin
   brought Salted almonds and said: A walk usually helps"). And there's another
   name to learn: "The Inscription, in Pieces".
9. **Wicker quotes an answer out of context.** "'A little,' he reads off your
   Page. 'A little. How brave.'" It's the reader's tap on screen 07, without the
   question. The Inkbones result also says "The arrow points at **moving my
   body**": the reader's chip label lands in the Book's voice, and the Book
   has no body.
10. **The same facts are recapped three times.** The role's "How I knew", the
    list on Wicker's screen ("You said… You're most awake…") and screen 22's
    "What you gave me". The PDF is a fourth.
11. **The ending stacks decisions.** Photo, cover and bind sit on one screen
    (23). Then 24 opens with an unexplained "30" badge, a second research block,
    and "Missing a day doesn't undo anything", which manages the reader's
    feelings, against the voice rules.

**Mechanical bugs found on the way** (fix whatever the structure ends up being):

- **The living-ink chip gives the answer away.** "I caught it: It was
  'afternoon's'. Wasn't it?" is visible before the reader answers.
- **The time-of-day phrase follows the clock, not the frozen arrival.** I
  arrived at 10:42 and the card said "morning's". After a pause the vanished
  word was "afternoon's", the title changed to "The Afternoon You Arrived", and
  it still said 10:42 AM.
- **The "HOW WE MET" banner lingers half-transparent over the top of the card**
  on most screens. When it collapses the content jumps ~90pt, and twice my tap
  landed on the wrong choice because of it (05→06, 07).
- **Revealed content and the Continue button land below the fold with no
  auto-scroll.** Every answer needs a manual scroll to find what happened.
- **A blank cream panel covers half the screen** behind both margin-note echoes
  (06, 14).
- **"Two little bone dice"**, but the animation throws five sticks. The "8" on
  the practice throw has no scale to read it against.

## Answers that never visibly pay off

| Answer | Where it goes on screen | Verdict |
|---|---|---|
| What happens to small things (07) | A "Noted" card, never seen again | **unpaid** |
| Did it get stranger (07) | "Filed: …keep the maybes that misbehave", then Wicker's out-of-context "A little" | **unpaid** |
| The Pact vow (06) | One line back. Never revisited in onboarding | **unpaid** |
| Practice Inkbones (14) | "Nothing happens" (by design) | **no payoff by design** |
| Belief (13) | Advances at once. First visible use is Wicker, 8 screens later | **late** |
| Rut (05) | "Noted" line; then the epithet, 12 screens later | ok locally |
| Magic + hands (15) | Role reveal, two screens later (Pagewright in between) | **late** |
| Snack (10) | The Cast argument, next screen | paid, but costs 3 nouns |
| Recall + good moment (02–03) | The verdict, next screen | **best beat in the flow** |
| Story style (08) | The card re-forms at once | paid |
| Taste (18), comfort (19), knock (24) | Paid on the same screen | paid; settings, not story |
| Chapter (20) | It reads your Page at once; Wicker uses it | paid |

## Proposal: 13 screens, one new thing each, every answer used at once

bj's fixed points are all kept: the Curse proof on the opening Page, the Book
naming the reader (role as an identity claim), the Potter joke verbatim, Wicker
plus the Inkbones, and the little PDF book at the end.

| # | Screen | Asks | The one new thing | How the answer pays off right away |
|---|---|---|---|---|
| 1 | **The Page Finds You.** STOP stamp, then a word vanishes while you read | Did you see it go? | the Curse | "It was 'X'." The chip no longer gives it away. Then "642 minutes of today are already gone" |
| 2 | **One Ordinary Hour** | cook / walk / drive, then 3 remember taps | – | The count, on the same screen |
| 3 | **A Good Moment** | 8 chips + one typed detail | – | Quoted back on 4 |
| 4 | **That's the Curse.** Verdict + science card (unchanged) | Where does it get you worst? (6 chips) | the Rut of Routine (the Grey alias is dropped) | "Then I'll point at whatever's next to your phone", on the same screen |
| 5 | **Catch One Now.** No hands, so you catch, I keep | One true thing (typed), then Keep / let it wait | Keep | The story card presses your sentence in front of you. No Pact, no Pippa |
| 6 | **Through the Page.** You fall in; Zara | What should we call you? | Zara | She says it; the Book darkens the letters. Every line after uses it. No "Academy" yet |
| 7 | **One Thing You Believe** | belief (typed), then put it in the story | Belief (one meaning, one line) | The fading word on your Page comes back dark with your belief in it |
| 8 | **What Makes a Day Feel Magic** | magic (9 chips) + what your hands do (5) | – | Next screen names you from it |
| 9 | **The Book Names You** | That's me / That's not me | your role | "How I knew" receipts, one per answer. No patron card; the Mark is shown as a receipt line, not a label |
| 10 | **Choose Your First Chapter.** Potter joke verbatim | pick one, or "you pick" | the Chapters | The Chapter reads your Page at once. "Wind Cipher" line dropped |
| 11 | **Wicker Takes the Page** | – (Answer him) | Wicker | He reads your belief, your role and your Chapter off the Page to taunt you |
| 12 | **The Inkbones.** Zara presses them into your hand | Pick your reply, then throw | the Inkbones | The throw settles it on the same screen. The practice throw is gone |
| 13 | **Your First Little Book.** Wicker flips the Page back | Cover (photo optional), Make my little book, then When should I knock? | the little book | The PDF opens. The knock choice triggers the notification prompt it promised |

**What goes, and where it lives instead**

- **Cut outright:** the Pact (one promise survives as a line on 5: "Every month
  I hand you back what you kept, in writing"), both Two Honest Answers, the
  story-style choice, the practice throw, the recap screen (22), the patron
  card, the "Wind Cipher" line, the habit-research block, "Missing a day…",
  and the "30" badge.
- **Snack + the Cast argument:** cut. Mook, Pippa and Penny meet the reader on
  the desk; the first-run sequence already has a Cast on-ramp.
- **Taste and comfort:** cut from onboarding. Comfort already defaults to
  "nudge" (`BookChallengePermission.read`). Taste is an optional cold-start
  prior. Both stay editable where they already live in the Book Shop.
- **The Pagewright: your call** (see below).

**Size of the cut:** 25 → 13 screens, ~30 → ~17 answers, 5 → 4 typed answers
(good moment, one true thing, name, belief), ~30 → ~10 new names, and an estimated ~5,000 → ~2,300
words, about 10 minutes of reading.

**Code impact.** All of this lives in `OnboardingFlowView`. The `Result`
struct keeps every field so nothing downstream breaks; cut answers simply
arrive empty, which every reader in `ContentViewFeatures.completeOnboarding`,
`InscriptionReaderProfile` and the curator already tolerates. `stepCount`,
`openingMiniStepCount` and `currentOnboardingFlowVersion` change, and the bump
in flow version resets anyone mid-onboarding to the start. Tests that pin old
wording get rewritten to assert intent.

## Decisions for bj

1. **The Pagewright.** You switched onboarding to the full studio yesterday.
   Played cold it's the heaviest detour: a photo-permission prompt, a toolbar,
   and a new name in the middle of the questions. Options:
   - **(a) Move it to the desk (recommended).** The little book still gets an
     auto-arranged leaf; the Pagewright gets its own first-run card on day one,
     when the reader has a real kept Page to arrange.
   - **(b) Keep it, optional, after the role reveal.** It becomes screen 10, the
     flow is 14 screens, and the studio no longer asks for photo access until
     the reader taps Add photo.
2. **The snack.** It's the one relatable, funny question inside the Book, and
   the proposal cuts it. Keeping it, without the Cast argument, makes 14
   screens, and Zara's "first question" line goes.

## After (implemented 2026-10-17)

Played end to end again on a fresh install (iPhone 17 Pro Max simulator):
**14 screens** (5 on the loose Page, 8 inside the Book, 1 for the little book),
4 typed answers (good moment, one true thing, name, snack, belief: the snack
stayed, without the Cast argument), the Pagewright moved to a day-one desk card
("The Pagewright Wants Your Scraps"), and the knock choice raises the
notification prompt it promised. Screenshots in `docs/onboarding-moonshot/after/`,
contact sheet at `docs/onboarding-moonshot/after-contact-sheet.jpg`.

Fixed after the replay: progress rail and ribbon button had no side gutter on
phones; story-card title read "The Radiator at the Afternoon"; nested quotes on
the card; the default cover art still said "YOUR FIRST PAGES"; the PDF role line
ended ", Backer"; the dice said "I roll" while the reader throws; "2 of three";
"The arrow points at you, with people you love"; the planted-belief card kept
saying "Put it in the story"; the desk welcome repeated its own headline.

Known and left: the "The Hedge Door" cover plate (a literal door in the art,
shared by every edition); "The Unwritten" on the cover-opening animation.
