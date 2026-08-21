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

## Has a verb now

Every one of these is a single sentence that starts steps which already exist,
wherever they live. Nothing was migrated to add them.

| Page | The reader does | Leaf invitation |
|---|---|---|
| `illuminatedPhoto` | lights a photograph | "Illuminate a photograph" — *only while unlit* |
| `faeBargain` | hears an offer | "Hear the bargain" |
| `twoReadings` | picks a reading | "Take a side" |
| `elective` | enrols | "Take the elective" |
| `academyClass` | attends | "Sit the class" |
| `anchor` | fixes a place | "Anchor this place" |
| `radio` | tunes a station | "Tune the radio" |
| `inventory` | spends a gift | "Open the satchel" |
| `gamePage` | plays | "Play" |
| `narrativeOS` | chooses | "Make the choice" |
| `bookNotices` | tells the Book whether it is right | "Tell me if I have it right" |
| `bookOfYou` | answers the braid | "Say what you thought" |
| `taleBound` | binds a chapter | "Bind it" |
| `frontMatter` | opens a door | "Open the door" |
| `rest` | marks a rest | "Mark the rest" |

Three of these carry an honesty rule rather than a plain label:

- An **illuminated plate** that already has a rendered preview stops asking. A
  verb there would be requesting work already done.
- A **fae bargain** on the desk is only ever *offered*. Naming the debt would
  front a cost the reader has not agreed to, and letting one go is meant to cost
  nothing. Tested for: the invitation must not contain pay, owe, or debt.
- **letter** and **note** deliberately have no verb. They already reach the reader
  through the generation path, which offers "Let me write" when there is writing
  to do; for one already written, asking again would be a lie.

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
