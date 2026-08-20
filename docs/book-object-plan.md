# The Book Object

Turning the interface from an app into a book. This is the anchor map: what
hangs off the Book, where, and what it opens.

Status: Phase 0 shipped. The phone implementation of Phases 1 and 3, plus the
first Phase 2 status slip, is now in the worktree and awaiting build/device
verification. Later items remain a plan, not a description.

---

## The law

**Every trigger must live on the Book. Nothing lives on the homescreen outside
it.**

Two clauses, and the second one is the permissive half — do not over-read the
first:

1. **The trigger is on the Book.** A control the reader can touch must be a
   physical part of the object: painted into a leaf, protruding from an edge,
   hanging off it on a cord. If you cannot point at the thing on the Book it
   came from, it is wrong.

2. **What it opens can be an ordinary floating surface.** A popover, a sheet, a
   menu — normal, Apple-standard, quick to use. It does *not* have to unfold
   with a bespoke animation. The fore-edge seals already work exactly this way:
   press INPUT, a normal choice popover appears. That is the model, and it is
   correct.

So the question for any surface is never "does it animate out of the paper?" It
is **"what on the Book did the reader touch to get here?"** If the answer is
"nothing — it was just up there in a bar", it has to move.

### What this replaces

An earlier draft of this rule said "no foldouts, everything becomes a leaf".
That was wrong, and it would have cost a great deal of work for a worse product:
paginating a settings screen into leaves is bad design and slow to use. Foldouts
and floating menus are welcome. Detachment is the defect, not the mechanism.

### The backdrop is exempt

The celestial background, the drifting letters, and the pixie that gathers them
(`AmbientLetterField` / `AmbientLetterFieldRenderer` in `BookSurfaceViews.swift`)
stay exactly as they are. They are atmosphere, not furniture — the room the Book
sits in. The law governs things the reader can touch.

---

## The anchor map

Every surface, and the part of the Book it hangs from.

### Painted into the leaf

| Anchor | Opens | State |
|---|---|---|
| **Folio number**, tail-outer corner | nothing — it is furniture | Shipped |

The Glow illumination used to be painted here, in the head-outer corner of every
leaf, and it opened the Glow menu. It is **gone**. An interface with two doors to
one room has to explain itself twice, and the bookmark is the better door: it is
a physical part of the binding rather than a mark printed on a page that happens
to be tappable. Its Belief reading moved to the bookmark with it.

### The fore-edge

Reading down the outer edge. The seals are what the reader *hands* the Book; the
contents tab is how the reader asks what the Book already holds.

| Anchor | Opens | State |
|---|---|---|
| **Glow bookmark** (head of the fore-edge) | the Glow command menu, swinging out on a hinge at the fore-edge | Shipped. The only way in, and lit from behind by the reader's actual Belief. |
| **Contents tab** | riffles to the contents leaf | Shipped |
| **Input seal** | photo / text / audio popover | Shipped (pre-existing) |
| **Body seal** | body reading | Shipped |
| **Place seal** | location / weather popover | Shipped |
| **Radio seal** | radio, on-air state | Shipped |

### The tail — charms and ribbon

The phone worktree now hangs the two durable journeys here. This is where the
dissolved nav bar went.

| Anchor | Opens |
|---|---|
| **Magnifier charm** | Search the Stacks — implemented, awaiting device verification |
| **Almanac charm** | the calendar — implemented, awaiting device verification |
| **Ribbon** | where you left off; threads left open — deferred until the thread model earns it |
| **Quill charm** | the Chosen Quill — deferred; available through existing Book routes |
| **Pocket charm** | the Book's Pocket — deferred; available through existing Book routes |

Charms hang on a cord from the tail edge and swing slightly. Tapping one opens
its ordinary floating surface. The set is deliberately small — a charm the
reader never uses is clutter on the object itself.

### Inside the boards

What a real book pastes inside its covers. Reached by closing the Book, or from
the contents leaf.

| Anchor | Opens |
|---|---|
| **Bookseller's ticket** | the Bookshop |
| **Binder's ticket** | the Bindery |
| **Colophon** (back paste-down) | how the Book is made; Doorways; model status |

### Laid on the open leaf

Not anchors — arrivals. A slip of paper set on the page, slightly rotated, with
a shadow. Replaces anything that currently appears as a banner or toast under
the Book.

- status messages (`StatusBanner`)
- margin replies at keep
- unlock notes and achievement toasts

---

## The nav bar dissolves

This is the concrete Phase 1 work. Everything currently in the navigation bar
moves onto the Book:

| Now | Becomes |
|---|---|
| `sparkle.magnifyingglass` (top-left) | magnifier charm at the tail |
| `calendar.badge.clock` (top-left) | almanac charm at the tail |
| `navigationTitle("ReEnchanted")` | removed on phone; the Book needs no app title or labeled spine |
| Small Glow pill (top-right) | the Glow bookmark on the fore-edge; deleted from phone chrome |

Then `.toolbar(.hidden)` for the phone. The iPad `NavigationSplitView` is a
separate question and is **not** in scope here: a book on a lectern with its
divisions showing is a legitimate reading of the same idea.

---

## The desk

Six shelves currently scroll below the Book: The Book Today, The Cast, Today's
Margins, Returned From The Stacks, The Book of You, Colophon. They are content
sitting outside the object.

The contents leaf already routes to all six, so the reader can *reach* them from
the Book today — but arriving still means scrolling a desk that exists
independently of it.

Target: the Book is the only furniture on the screen, on the celestial backdrop.
The shelves become divisions reached from the contents leaf. Convert
highest-traffic first; keep the scroll working throughout so the app is never
half-migrated in a shipping build.

First implementation: all six open as ordinary reading sheets from the printed
contents, while reusing their existing source-backed content and actions. The
detached phone shelves are gone, and the Book remains present even when no loose
Page is tapping. **The Book Today**, **Returned**, and eventually **The Book of
You** may become bound divisions later; the attached trigger rule does not
require that more expensive layout work before the object is coherent.

---

## Phases

**Phase 0 — the leaf. Shipped.**
A worn Glow bookmark leads the fore-edge and opens the full Glow menu; it is the
only entrance, and a lamp behind it burns at the reader's Belief. Folio number to
the tail. Leaves are cut with a deckle edge rather than stamped from a rounded
rectangle. Short Pages are set at display size, with the landing word of the
opening sentence taking the accent ink. Pagination memoised (measured ~22ms per
body evaluation against a 16.7ms frame budget).

**Phase 1 — the nav bar dissolves. Shipped on phone.**
Search and Almanac objects hang unlabeled from distinct chains at the tail;
toolbar and screen title are hidden; the Glow bookmark is the phone's only Glow
trigger. A labeled spine was tried and deliberately removed.

**Phase 2 — arrivals become paper. Begun.** Phone status messages now use a
parchment slip laid against the Book. Margin replies and unlock notes remain.

**Phase 3 — the desk folds in. Implemented on phone; awaiting device QA.** The
six shelves are reached from Contents as attached reading sheets. iPad remains
the separate lectern question described above.

**Phase 4 — inside the boards.** Bookshop and Bindery tickets, Colophon as the
back paste-down.

**Phase 5 — aliveness.** Block thickness driven by archive size. Cumulative wear
where the reader kept things. Fore-edge painting. Found-closed-with-something-inside.

---

## Still open, and deliberately not started

**Bleed geometry.** The Book is still a card on a dark field rather than paper
running off the screen edges. Two things hold the margin: `.padding(.horizontal,
8)` on the desk stack and the folio's 48pt fore-edge reserve. It is not a small
change — `leafWidth` feeds `FolioLayoutMetrics`, so widening it reflows every
leaf in the Book, and it wants its own pass with the simulator open.

**Relational placement.** In the reference art a moth's dotted trail *leads to* a
marginal note. Marks currently know only their own free rectangle; this needs the
placement pass to see pairs of resolved frames and draw a leader between them.

**Decoration richness.** 92 marks were cut from two painted sheets and every one
declares its role, anchors, and whether prose may run over it. `supportedDialects`
is left `nil` on all of them on purpose: `nil` means "any" to the filter, and
narrowing 79 marks on guesswork would have starved leaves long before it improved
one. That field is worth filling by hand once marks are seen landing.

---

## Already shipped, for reference

Verified on `generic/platform=iOS` with 3060 tests green, and driven by hand in
the simulator.

- **Contents leaf** — printed matter, not a menu. Nine divisions, leader dots,
  detail lines in the Book's voice. Details are voice rather than counts on
  purpose: a contents line quoting a number must be right on every desk render.
- **Riffle-to-travel** — tapping the contents tab riffles the Book to it.
  `FolioRiffle` stays permanently mounted (mounting and animating in one
  transaction leaves `Animatable` no prior value, and nothing flies); leaves are
  z-ordered by how far through their turn they are, not by index.
- **Closing leaf** — the block ends on "That's all I set out tonight", with
  *Explore deeper* and *Back to the first leaf*. Carried as a real leaf so both
  pagers reach it with ordinary index arithmetic, appended after numbering so
  "leaf 2 of 2" stays truthful.

## Known, not caused by this work

The launch greeting overlay (`BookGreetingOverlay`, zIndex 19) covers the desk
and swallows the first tap after launch.
