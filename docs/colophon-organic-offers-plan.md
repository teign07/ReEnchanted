# The Colophon, met in passing

Plan, 2026-11-08. Nothing here is built yet.

bj: "the more we can keep Readers away from the colophon, the better. It would
be best if they could encounter all its options organically while using the
app."

**Goal.** Each control in `sourceControlsShelf` (`InsideCoverApp/ContentView.swift`,
the `.colophon` case of `bookDivisionContent`) reaches the Reader at a moment
when it matters, from something on the Book they're already touching. Then the
Colophon can go back to being what a colophon is: a page about how the Book
was made.

**Rules every offer follows** (from memory doctrine):
- **An anchor on the Book.** Each offer hangs off a leaf, a margin note, a Cast
  member's line, or a seal the Reader touched ([[book-object-interface]]). It's
  never a detached banner.
- **No new modals.** Offers are desk leaves, margin notes, or lines on an open
  leaf. System prompts (permissions, the Files picker, the share sheet) are
  fine because a leaf action starts them. The Glow menu stays as it is
  ([[glow-menu-stays-night]]).
- **Ask once, remember the answer.** This follows the Bleed's calendar ask
  (`didHandleBleedCalendarDoorway`): "a refusal remains a refusal". If the Reader
  declines, the offer can come back only after a real change (more pages, a new
  iOS version), never on a timer alone.
- **Pages about the Book count against its self-talk ration**, one slot per
  three leaves ([[book-self-talk-ration]]). Margin notes and lines on a leaf
  don't count.
- **Voice.** The Book narrates in first person. It's simple and childlike, uses
  contractions, and never names its own machinery. No "door" idioms (the
  named *Doorways* are a proper noun and stay), no teeth, no "X, not Y". Cast
  members may say "the Book". The sample lines below are drafts to judge by ear.

**Shared mechanism (one small piece).** Add an `OfferLedger` in the vault with
one entry per offer id: when it was offered, accepted or declined, and the
condition it was declined under (page count, OS version). It works like
`MarginTutorLedger` and `KeepMarginalia`. Each offer is one trigger function
plus one render site. WiringLintTests should check that every offer id is
emitted by something ([[wiring-lint-and-audit]]).

## Inventory

All 30-odd controls on the shelf, grouped by where they already live.

### A. Colophon is the only way in

| Control | Today |
|---|---|
| **Open a sealed copy** (`.aar` / JSON import) | Colophon only. The app registers no document type, so tapping a sealed copy in Files or AirDrop does nothing. |
| **Protect the Book** (app lock) | Colophon only |
| **Doorways** (`SourceSettingsSheet`) | Colophon only |
| **Weather** (`WeatherSourceCard`) | Colophon, plus a silent read inside the prompt-whisper refresh |
| **Body / Health** (`BodySourceCard`) | Colophon only |
| **Let my interests visit the public web** | Colophon only. The Bleed's `interest-desk` brief is skipped while this is off. |
| **Reddit client ID**, **USDA key** | Colophon only. These are developer keys, not choices a Reader makes. |
| **Tactile enchantment**, **My voice** | Colophon only |
| **Send a test whisper** | Colophon only |
| **Read the introductions** | Colophon only |
| **Re-tuck notes** (Zara's margin notes) | Colophon only |
| **Open any book** (custom Book Jump title) | Colophon only |
| **Export continuity** | Colophon only (developer or agent artifact) |
| Model status, Lab status, Curator Observatory, Story field status | Colophon only (diagnostics) |
| Taught reading, Dedication | Colophon only. These are reading matter, not controls. |

### B. Already reachable another way (the Colophon is a second route)

| Control | Other route |
|---|---|
| Seal a copy (export) | Glow menu → Bindery `.exportSealedCopy` |
| Copy out plain ink | Glow menu → Bindery `.exportPlainInk` |
| Bind week / month / year, dedications, Bleed PDF | BookShop Bindery, Glow → Bindery, edition offers ([[edition-offer-surfaces]]) |
| Pagewright | Contents ("Binding and Copies"), Glow |
| Open connections | Several leaves (`isConnectionsPresented`) |
| Book Workings authority | Its own Working leaf |
| Calendar Doorway | The Bleed asks on the first paper; the Workings pact |
| Whispers / Prompts | Onboarding cadence choice; the Workings pact |
| Install the local brain | Onboarding, plus retry cards |
| Anchors (location) | The Place seal |

Group B needs no new route, only trimming once group A has its routes.

## Moments and anchors, ranked

Ranked by how much a Reader loses if they never find the control, and then by
how cheap the fix is.

**1. Open a sealed copy: from Files, and on a fresh install.**
- *Anchor A: the file itself.* Declare an exported UTType for sealed copies
  (say `app.reenchanted.book.sealed`, extension `.reenchanted`, conforming to
  `public.apple-archive`). Add it to `CFBundleDocumentTypes` and route it in
  `onOpenURL` to `BookMovingCopy.offerRestore`. Then tapping the file in Files,
  Mail or AirDrop opens the Book, which runs its existing confirm. Old `.aar`
  copies still open through the picker.
- *Anchor B: the first leaf of an empty Book.* On a fresh install, or the
  first launch after a rename or move, the welcome leaf adds one line with
  one action: "I'm new here. Unless I'm not? If you've got a sealed copy of me,
  hand it over and I'll wake up as myself." Buttons: "I've got a sealed copy"
  (opens the picker) and "Start fresh" (dismisses).
- *Later, needs the paid team:* write sealed copies into the app's own iCloud
  container. A fresh install could then *find* one ("I found a copy of me from
  March 3rd") with no picker. This needs the iCloud entitlement, so it isn't
  possible under the free team.

**2. Seal a copy at real moments.** Today it's a menu item nobody goes looking
for.
- *Month close.* When the monthly edition offer appears, it carries a second
  line: "That's a whole month inside me. Let me make a sealed copy too, so if
  this phone ends up in a river I'm still here." Anchor: the month's edition
  leaf.
- *Growth since the last seal.* Trigger after +150 kept pages or +40 photos,
  or after 45 days with at least 30 new pages. Offer it as a desk leaf, "A Copy
  of Me" (it uses the self-talk slot): "I'm getting heavy. Four hundred pages
  and sixty photographs. I'd like a copy of me somewhere safe. iCloud Drive's
  fine."
- *A new iOS.* Store `systemVersion`. On a major bump: "The phone's got new
  insides since yesterday. I'm fine, but I want a sealed copy anyway." The
  Book can't see an update before it installs, but it can keep a calendar:
  early September each year, it says phones change their insides this month.
- *A receipt.* `lastSealedCopyDescription` moves onto the Book Today census
  drawer ("Last sealed 3 days ago"), so a Reader can see it's covered.

**3. Protect the Book, the first time something private is kept.** Triggers:
the first kept Inner Weather or Fuel page, the first person written into
People of the Book, or the first photo of a face. Anchor: a margin line on that
kept leaf: "That one's private. I can stay shut until your face or your
passcode says it's you." Buttons: "Lock the cover" and "Leave it open". Once
the lock is on, a small **clasp** is drawn on the cover in the opening movie,
which gives it a visible anchor. Long-pressing the clasp turns the lock off
(through the same owner authentication).

**4. Doorways on the leaf they came through.** No Reader should need the
whole-source sheet. Each source-fed Page already knows its source. Its footer
line names the Doorway, and a tap on that line gives two choices: "Fewer like
this" and "Close the ___ Doorway". The second goes through the existing
`setSourceEnabled`. Closed Doorways are listed on the Colophon, where they can
be reopened. This reuses the trash/release gesture area, so it adds no chrome.

**5. Weather and Body, asked when a Page needs them.** This copies the
Bleed's calendar pattern exactly.
- *Weather:* the first time the sky-on-the-leaf layer or a weather-shaped Page
  would draw without data ([[sky-on-the-leaf]]): "I want to know if it's
  raining on you. Can I look at the sky where you are?"
- *Body:* the first kept page that mentions sleep, steps or walking, or the
  first Fuel page: "You wrote about sleep. Your phone counts sleep. Can I read
  the count? I never write anything back." The second sentence matches the
  "never writes to Health" copy.
- Each is one ask with a system prompt behind it. A no is final.

**6. The public web, asked by Penny in the Bleed.** When the interest desk is
skipped because the opt-in is off, the paper prints a small box in Penny's
voice: "I could clip things from the real papers for you. Only a topic and a
town go out. Never your pages." Buttons: "Clip for me" and "Keep it in the
Book". Anchor: the Bleed leaf. Cast voice is allowed to say "the Book".

**7. Whispers, offered after an absence.** If whispers are off and the Reader
comes back after 3 or more days away, the Book Today "While you were away"
drawer offers: "You were gone four days. I had things to tell you and no way to
say them. Can I tap the glass when the evening page is ready?" On yes, the
test whisper becomes the confirmation: "I'll tap once now, so you know what it
feels like." The separate test button can then go to DEBUG.

**8. Sound and touch, on the closing leaf at night.** The first time the Book
is open past 22:00 with sound on full, the closing leaf offers "It's late. Want
me quieter?" Buttons: "Quieter", "Silent" and "Stay as you are". It writes
`bookSoundMode` and `bookHapticMode` together. Ask once per mode. The
Colophon keeps the full picker.

**9. Introductions and Zara's notes, through the Contents and the Cast.**
- Contents front matter gains "The Introductions", read again in their order.
- In the Cast Ledger, Zara's entry gets "Ask Zara to explain things again",
  which re-tucks her notes. Zara also offers this unasked after 60 or more days
  away: "You've been gone ages. Want me to stick my notes back in?"

**10. Open any book, after a Book Jump ends.** The jump's closing leaf adds:
"Name another book and I'll jump into it. It has to be old enough to be
free." The text field and `openCustomBookJump` move there. Anchor: the
finished Spine.

**11. Developer controls leave the Reader's Colophon.** Move the Reddit client
ID, the USDA key, continuity export, Lab status, Curator Observatory, Story
field status and the test whisper into a DEBUG or Lab panel. For release, ship
the USDA lookup through the Worker so no Reader ever pastes a key. These are
not Reader choices, so they need no organic route.

**12. Then trim the Colophon.** Once 1–10 have shipped, remove the group B
duplicates (bindings, Pagewright, Connections) and keep a real colophon:
- how I'm made (model status, read-only)
- what you've taught me to read
- the dedication
- one quiet list of everything switched on, each with an off switch: Doorways,
  lock, whispers, sound, the web, sky, body, calendar

That last list is the safety net. Every organic offer must still be reversible
somewhere a Reader can find without being taught.

## Order of work, if approved

1. `OfferLedger`, plus items 1 (document type and fresh-install line) and 2
   (month close, growth, new iOS). This covers the move that started all this.
2. Items 3 and 4: privacy and Doorways on the leaf.
3. Items 5–8: asks at the moment they're needed.
4. Items 9–12: Contents, Cast, Jump, DEBUG, and the trim.

Each step needs bj's go-ahead before any build or `swift test`.

## Open questions for bj

- Extension name for sealed copies: `.reenchanted`, `.book`, or keep `.aar`?
- Is a clasp drawn on the cover the right anchor for the lock, or should the
  lock stay invisible?
- Should a decline ever expire, or only come back after a real change (the rule
  proposed above)?
- iCloud-container auto-find (1, later): worth planning now for the paid-team
  merge?
