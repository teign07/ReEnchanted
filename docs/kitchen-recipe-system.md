# The Kitchen: the recipe system (November 2026)

Agreed with the project owner 2026-10-19. The long plan and the house laws are in
[kitchen-november-pack.md](kitchen-november-pack.md); the story it serves is
[november-the-guest.md](november-the-guest.md). This file is what gets built for November.

## Decisions

- **Ships for November,** in the app build that goes on Rabbit before Nov 1. The revised November pack requires
  runtime 12 for The Guest's Cast role. Install the matching app before publishing that pack.
- **The recipes live in the app,** not the monthly pack, so they never retire with a month. A later
  pack can add more (`PageArchetypePack.recipes`, read the same way).
- **Gayle O'Brien's recipes ship for everybody,** credited as **"Gayle O'Brien, Mom"**. They're
  transcribed from her typed binder (the project owner sends photos; no photos ship in the app). They're never
  story machinery and never the magic dish.
- **The tally never gates an ending.** Made recipes restore *The Middlemost Cookery*'s letters; the
  paper and Book Today print the count. All three endings stay the reader's choice.
- **The Hob is Aiken Drum,** named only in the Stay ending. He joins the Cast at introduction as
  **The Guest**, keeping the stable `visitor-the-guest` ID when the name is revealed. The Book
  distinguishes the folklore brownie of Blednoch from what it knows about its own Guest.
- **No generated recipes, ever** (house law 5). Gemma may talk about a recipe; it never writes one.

## The pieces

### 1. `KitchenRecipe` and the corpus (`Shared/Kitchen.swift`, `Shared/KitchenRecipes.json`)

```swift
struct KitchenRecipe: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var shelf: KitchenShelf          // .inherited / .cookery / .custom / .rescued
    var credit: String?              // "Gayle O'Brien, Mom"; "The Middlemost Cookery"; "All Souls, England"
    var line: String                 // one line: Ambrose's, or the Book's
    var makes: String?               // "about 20", "4 bowls"
    var minutes: Int?
    var ingredients: [String]        // as written; allergens named in the line
    var allergens: [String]          // "milk", "egg", "wheat", ... for the row and the Page
    var steps: [String]
    var cookNote: String?            // the source's own note, word for word (Gayle's margin)
    var window: KitchenWindow?       // pinned days, e.g. Oct 31 to Nov 2 for soul cakes
    var months: [Int]?               // in season; nil is any time
    var weatherTags: [String]?       // "cold", "rain"... (RadioPageContext tags)
    var smellAsk: String?            // the margin ask, when it should be its own
    var tags: [String]
}
```

### 2. The Recipe Page (`BookPageType.recipe`, "The Kitchen")

- One recipe at a time, set out as a page from somebody's kitchen: title, credit, the line, *You'll
  need*, *What you do*, the cook's own note. The reader's earlier margin notes for this recipe print
  above the steps ("Last time: *too much pepper*. 3 November, raining.").
- Three chips: **Made it · Made it badly · Not yet.** The margin asks what it smelled like.
- Kept with a tag: `kitchen-made:<id>`, `kitchen-badly:<id>` or `kitchen-owed:<id>`, plus
  `kitchen:<id>`. The archive is the ledger; nothing else stores it.
- "Made it badly" is a full keep with its own answer. Ambrose would rather hear that than nothing.

### 3. When recipes arrive (`KitchenOffering`)

At most one Recipe Page a day, deterministic for the day:

1. **Pinned windows first, with a desk floor:** soul cakes Oct 31 to Nov 2, parkin and toffee Nov 4
   to 5, Martinmas Nov 10 to 11, Stir-up pudding Nov 21 to 22, the bowl Nov 29 to 30.
2. **A re-offer:** a recipe offered more than four days ago and never made. Ambrose puts it down again
   ("I gave you this on the 3rd.") rather than nagging.
3. **The weather:** cold or rain brings soup.
4. **Otherwise Gayle's** on ordinary days, then the rest of the shelf.

A recipe made in the last five days rests. "Not yet" counts as offered, not made.

### 4. The Kitchen (`BookObjectDivision.kitchen`)

A room in the contents, after the Bestiary. Three shelves: **Gayle O'Brien, Mom**, ***The Middlemost
Cookery*** (story and custom recipes) and **Rescued** (the reader's own). Each row: the title, how
many times it's been made, the last time ("Made 3 times. Last on 12 November, in the rain."), and the
reader's notes. A row opens the recipe as a Page, to make it again. **Rescue a recipe** sits at the
top of the room.

### 5. Rescue a Recipe

A Recipe Page with nothing printed on it: *Whose is it? What's it called? Write it down the way they
said it.* "Enough" is a measurement. Kept with `kitchen-rescued` and the name in metadata, it goes on
the Rescued shelf for good, and its own Page can be opened and made like any other.

### 6. The tally (`KitchenTally`)

- **Made recipes** (made or made badly) and **rescued recipes** kept during the event.
- **The Cookery's count:** letters gone rises with the live day (Penny's figures: 1, 3, 11, 40, 214 by
  day 12, 231 by day 20); letters back is the Academy's share plus nine for each recipe the reader
  made and twelve for each one they rescued.
- **Printed** in the Bleed while the event runs and as one line on Book Today.

### 7. Aiken Drum (pack text plus an app entity)

- **Pack:** the Stay branch of *The Bowl* names him, and the December scene uses the name.
- **App:** the Cast entity `visitor-the-guest` appears after the Reader meets or learns of the
  Guest. Runtime 12 includes his illustration, dossier, voice, eight relationships, authored
  memories and Kitchen routine. Stay reveals Aiken Drum; Home and Court preserve the Cast page
  while removing him from new Academy business. See [guest-cast-implementation.md](guest-cast-implementation.md).

## Status (2026-10-19)

Kitchen implementation includes tests (`KitchenTests`, 14) and a proof step (`kitchen`). The
current checkout, including runtime 12 and the Guest Cast work, built in Release and was
installed/launched on Rabbit on October 19. Guest-related native suites passed after correcting
three failures found by the full run; see the Cast handoff for the exact verification gates.

- ✅ The model, the ten hand-set recipes, the archive ledger, the offering, the Cookery count.
- ✅ `BookPageType.recipe`, its adapter and source, its paper; a recipe's own day is a desk milestone.
- ✅ The chips and keep tags, Ambrose's answer at keep, Rescue a Recipe with whose it is.
- ✅ The Kitchen in the contents.
- ✅ The paper's Academy box (Ambrose's chalkboard, the Cookery count) and Book Today (the count
  while the event runs; drawers for recipes made and rescued).
- ✅ Packs can post recipes (`PageArchetypePack.recipes`), installed at launch with the undertakings.
- ✅ Aiken Drum named in the Stay ending and the December scene; Trencher and Boggle written in.
- ⬜ **Gayle O'Brien's recipes:** waiting for the binder photos. They go in
  `KitchenRecipeRegistry.inherited`, word for word, with her notes as `cookNote`.
- ✅ **The Guest as Cast:** implementation, portrait and native regression checks complete for
  runtime 12. Release installed/launched on Rabbit; hands-on story and illustration QA remains.
  He no longer waits for December.
- ✅ **A Release build on Rabbit:** installed and launched October 19. November content still
  requires its separate publication step.
- Later: a kept Recipe Page could carry the whole recipe, so a pack recipe outlives its month;
  the jars; the starter; the printed Kitchen.

## Build order

1. `Shared/Kitchen.swift`: the model, corpus loading, offering, ledger, tally. Tests.
2. `BookPageType.recipe` and its adapter; the curator floor for pinned windows.
3. The capture sheet's chips and the keep tags; the Rescue fields.
4. The Kitchen room in the contents.
5. The Cookery count in the Bleed and on Book Today.
6. The corpus: the story's recipes (soul cakes, parkin, bonfire toffee, Martinmas bread, stone soup,
   soda bread, leek and potato soup, Christmas pudding, the Hob's bowl), then Gayle's from the binder.
7. Aiken Drum: pack text, then the entity.
8. A build on Rabbit by about Oct 30.
