# Interactive Page audit

What each Page family lets the reader *do*, and whether the leaf can offer it
yet. Written while pulling Page controls into the Book object.

## How this was derived

Two passes, because the obvious one lies. Counting mentions of a page type near
a `Button` reports `.body` 106 times (SwiftUI's property, not the Page type) and
reports `wonderCompass` as zero despite it being one of the most interactive
families in the app. Matching real dispatch — `case .type`, `== .type` — finds
**60 of 62 types** dispatched on by name across `CapturePageSheet` and
`BookSurfaceViews`.

Dispatch count alone still does not mean *interactive*; plenty of it is
rendering variants. So the families below are keyed to the sheet's ~40 action
callbacks, which are the honest inventory of what a reader can actually do.

## Has a leaf verb already

| Page | The reader does | Leaf invitation |
|---|---|---|
| `enchantment` | picks a photo, casts a spell on it | "Choose a photo and cast" |
| `wonderCompass` | runs a Compass Run in the real world | "Begin the Compass Run" |
| `tarot` | draws and reads a spread | "Turn the cards" |
| `welcome` / colophon | installs the private mind | **printed on the leaf** — the waking button itself, not a door |

## Wants a verb next — one button that starts the steps

Ordered by how much the Page is currently hiding.

| Page | Callback | Likely verb |
|---|---|---|
| `illuminatedPhoto` | `onReplaceIlluminatedSurface` | "Illuminate a photograph" |
| `faeBargain` | `onAcceptFaeBargain`, `onPayFaeBargain` | "Hear the bargain" / "Pay what you promised" |
| `twoReadings` | `onTwoReadingsSided` | "Take a side" |
| `elective` | `onCompleteElective`, `onReleaseElective` | "Sign up" / "Let it go" |
| `letter` | `onGenerateLetter` | "Write the letter" |
| `note` | `onGenerateNote` | "Write the note" |
| `anchor` | `onAnchorPlace` | "Anchor this place" |
| `radio` | `onTuneRadio`, `onStopRadio` | "Tune the radio" |
| `inventory` | `onUseInventoryGift`, `onOpenInventoryMarket` | "Spend a gift" |
| `academyClass` | `onCompleteElective` family | "Sit the class" |
| `gamePage` | in-sheet play | "Play" |
| `narrativeOS` | `onStoryMechanicCompleted` | "Make the choice" |
| `bookNotices` / `bookAside` | `onBookNoticeFeedback`, `onBookOpinionContested` | "Answer" / "Argue with me" |
| `bookOfYou` | braid: `onLoveBraid`, `onRewriteBraid`, `onImproveNextBraid` | "Say what you thought" |
| `taleBound` / bindery | `onBindChapter`, seasonal dispatch setters | "Bind it" |
| `frontMatter` | `onOpenFlyleafDoor` | "Open the door" |
| `rest` | `onRestCelebration` | "Mark the rest" |

## Needs no verb

Reading matter. `diary`, `quotes`, `affirmations`, `lore`, `quip`, `mood`,
`weather`, `todaysSky`, `bookRemembered`, `bookConnections`, `marginsAtlas`,
`packPage`, `plainPage`, and friends. A verb here would be a promise the Page
cannot keep, which is why `leafInvitation` returning nil is a real answer rather
than a gap in the table.

## The rule this audit is applying

A leaf verb is cheap and can land now: it is one sentence and it starts the
existing steps wherever they already live. **Printing the control itself** is the
expensive move and has to be earned per Page — it needs the control to be drawable
as printed matter and worth the leaf's room. The waking button was worth it
because the Page names it in its own prose.

The opened Page stays the honest fallback throughout, so families migrate one at
a time without anything breaking in between.

## Not yet answered

`souvenir` on a full moon should make the leaf **glow**. That is not an action at
all — it is the leaf's material responding to the world, closer to the deckle
edge and the foxing than to a button. It wants the compositor, not
`FolioLeafAction`, and the moon phase is already available to Page packs through
their condition system.
