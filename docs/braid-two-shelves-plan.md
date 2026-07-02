# Book of You braid: Two Shelves + Clash hinge (implementation plan)

Two changes to the nightly braid, in two independent parts:

- **Part A — Two Shelves.** The braid should draw ~50% from lived pages (one-
  sentence souvenirs, fuel logs, inner weather, playful missions, photos,
  imports) and ~50% from fiction pages (letters, Story Page decisions, fae
  bargains/parleys, classes, gossip). Today's PROVENANCE GRAVITY rules demote
  all fiction to "color threads"; upgrade to an even two-shelf diet. **No
  dependency — can ship immediately.**
- **Part B — Clash hinge.** Clash Pages (see `docs/unquiet-folio-plan.md`) are
  high-narrative-weight braid signals: the braid treats a kept clash as the
  day's turn ("Until") unless something more personally true happened, frames
  outcomes by kind (retreat = wisdom, never shame), and leaves story residue.
  **Depends on the Unquiet Folio pack existing.**

All prose below is final — transcribe verbatim. House laws: never shame a
retreat; the braid never recaps like a battle report; deterministic
classification (shelf labels, digest lines) is computed in code so the local
brain only follows labels, never derives them.

---

## Part A — Two Shelves

### A1. Shelf classification helper

File: `Shared/LiteraryContinuity.swift`, inside `BraidPromptBuilder` (near
`threadGravity`). Add:

```swift
/// Which shelf a kept page sits on: the reader's own record, or the Book's
/// fiction. Deterministic so the braid never has to guess provenance.
static func braidShelf(for page: BookPage) -> String {
    switch page.origin {
    case .userAuthored, .imported:
        return "lived"
    case .generated, .simulated:
        return "fiction"
    }
}
```

### A2. Evidence lines carry the shelf

Same file, in the private `evidenceLines(for:characterLimit:)`, the per-page
block currently starts:

```
\(index + 1). \(page.type.title) - kept at \(timeFormatter.string(from: page.createdAt))
Thread gravity: \(threadGravity(for: page))
```

Insert a shelf line between them:

```
\(index + 1). \(page.type.title) - kept at \(timeFormatter.string(from: page.createdAt))
Shelf: \(braidShelf(for: page))
Thread gravity: \(threadGravity(for: page))
```

### A3. Upgrade reader-endorsed fiction in `threadGravity`

Same file, in the private `threadGravity(for:)` (and mirror the identical
change in the duplicate `braidThreadGravity(for:)` in
`Shared/InsideCoverStore.swift` so Ask-the-Book and friends stay consistent).
Replace the `.generated, .simulated` branch body with:

```swift
if hasReaderReply {
    return "reader-endorsed fiction; high gravity - the reader made a real decision here"
}
return "generated fiction color; medium gravity"
```

### A4. Replace PROVENANCE GRAVITY with TWO SHELVES

File: `Shared/LiteraryContinuity.swift`, in `prompt(for:context:)`. Replace the
entire `PROVENANCE GRAVITY:` block (all six lines, from `PROVENANCE GRAVITY:`
through `...half true record, half spell.`) with:

```
TWO SHELVES:
- Each kept page names its shelf. Lived pages are the reader's own record: souvenirs, fuel and body logs, inner weather, playful missions, photos, imported real-world signals. Fiction pages are the Book's side of the day: letters, Story Page scenes and decisions, fae bargains and parleys, classes, gossip.
- Build the braid from both shelves in roughly equal measure: about half the page from what the reader lived, about half from what the story did with it. Never let either shelf drown the other.
- One-Sentence Souvenirs remain the strongest single spine candidates, because they are the reader choosing one true line.
- A fiction page where the reader made a real decision - a chosen Story Page path, a paid bargain, an answered parley - is reader-endorsed: it may carry the spine when the day's truest turn happened there.
- When the shelves disagree about facts, the lived shelf wins. The fiction may color the real; it may never overwrite it.
```

### A5. Tests (Part A)

File: `Tests/InsideCoverCoreTests/` — add to whichever suite already exercises
`BraidPromptBuilder.prompt` (search `BraidPromptBuilder`); if none does, add a
new `func` block to `WorldSystemsTests`:

```swift
func testBraidPromptCarriesTwoShelves() {
    let day = BookDay(id: "shelves-day", date: Date(), pages: [
        BookPage(type: .souvenir, promptText: "One line", userInput: "The kettle sang early.", origin: .userAuthored),
        BookPage(type: .narrativeOS, promptText: "Story Page", userInput: "Wicker leaned on the ladder.", playerReply: "Named the forgery", origin: .generated)
    ])
    let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)
    XCTAssertTrue(prompt.contains("TWO SHELVES:"))
    XCTAssertFalse(prompt.contains("PROVENANCE GRAVITY"))
    XCTAssertTrue(prompt.contains("Shelf: lived"))
    XCTAssertTrue(prompt.contains("Shelf: fiction"))
    XCTAssertTrue(prompt.contains("reader-endorsed fiction; high gravity"))
}

func testBraidShelfClassification() {
    XCTAssertEqual(BraidPromptBuilder.braidShelf(for: BookPage(type: .souvenir, promptText: "p", origin: .userAuthored)), "lived")
    XCTAssertEqual(BraidPromptBuilder.braidShelf(for: BookPage(type: .diary, promptText: "p", origin: .imported)), "lived")
    XCTAssertEqual(BraidPromptBuilder.braidShelf(for: BookPage(type: .narrativeOS, promptText: "p", origin: .generated)), "fiction")
}
```

(If `BookPage`'s init labels differ from the above, match the existing fixture
style used elsewhere in the test file rather than changing the init.)

---

## Part B — Clash hinge (requires the Unquiet Folio pack)

### B1. Keep-time clash tags

File: `InsideCoverApp/CapturePageSheet.swift`, in `preparedTags(for:)` (search
`storyMechanicReturn"] == "true"` — add this new block adjacent to it):

```swift
if preparedSurface.payload.metadata["storyRecipePackID"] == "unquiet-folio" {
    tags.append("clash")
    if let recipeID = preparedSurface.payload.metadata["storyRecipeID"]?.nonEmpty {
        tags.append("clash:\(recipeID)")
    }
}
```

### B2. Outcome tier tag (optional but small — do it)

File: `InsideCoverApp/ContentView.swift`, in
`storyMechanicReturnSurface(from:outcome:)`. The `outcome` parameter is the
kept mechanic result text. After `let outcomeText = ...`, derive a tier and
stash it in metadata so `preparedTags` can pick it up:

```swift
let lowered = outcomeText.lowercased()
let outcomeTier: String
if lowered.contains("critical success") { outcomeTier = "bright-success" }
else if lowered.contains("near miss") || lowered.contains("critical failure") { outcomeTier = "complication" }
else if lowered.contains("failure") { outcomeTier = "complication" }
else if lowered.contains("success") { outcomeTier = "costly-success" }
else { outcomeTier = "unresolved" }
```

Add `"storyMechanicOutcomeTier": outcomeTier` to the returned surface's
metadata (alongside the other `story*` keys it already sets). Then in
`preparedTags(for:)`, inside the existing `storyMechanicReturn == "true"`
block, add:

```swift
if let tier = preparedSurface.payload.metadata["storyMechanicOutcomeTier"] {
    tags.append("clash-outcome:\(tier)")
}
```

Note: "retreat" is not an outcome tier — a retreat is the reader declining or
swiping away, which keeps nothing and costs nothing (house law). The braid's
retreat framing below still matters for days where a clash page was kept
*without* rolling (mandate suppressed) or the result read as standing down.

### B3. Clash digest line in braid evidence

File: `Shared/LiteraryContinuity.swift`, in `evidenceLines`. After the
`Tags: ...` line of the per-page block, append conditionally. Implement by
building the block with a suffix variable:

```swift
let clashDigest: String
if page.tags.contains("clash") {
    let kind = page.tags.first { $0.hasPrefix("clash:") }?.replacingOccurrences(of: "clash:", with: "") ?? "clash"
    let outcome = page.tags.first { $0.hasPrefix("clash-outcome:") }?.replacingOccurrences(of: "clash-outcome:", with: "") ?? "unrolled"
    let choice = page.tags.first { $0.hasPrefix("choice:") }?.replacingOccurrences(of: "choice:", with: "") ?? "none"
    clashDigest = "\nClash digest: Belief was tested (\(kind)); the reader chose the \(choice) path; outcome \(outcome)."
} else {
    clashDigest = ""
}
```

and end the block string with `Tags: \(tags)\(clashDigest)`.

### B4. WHERE BELIEF WAS TESTED section in the braid prompt

File: `Shared/LiteraryContinuity.swift`, in `prompt(for:context:)`. Before the
`return` statement add:

```swift
let clashSection: String
if day.capturedPages.contains(where: { $0.tags.contains("clash") }) {
    clashSection = """


    WHERE BELIEF WAS TESTED:
    - Today holds a clash page: the reader defended something against being made generic. Unless a lived page holds something even more personally true, let the clash be the braid's "Until" - the turn of the day.
    - Name what was protected in concrete words. Never recap it as a battle report; never quote rolls, numbers, or mechanics.
    - Frame the outcome by its digest: a bright success is restored agency; a costly success is saved-but-not-easy; a complication is unfinished business the Book keeps warm; standing down is wisdom - a lamp saved for tomorrow. Never shame a retreat.
    - Leave one clause of residue open (a title still missing, a seal still warm, a word the grey now knows you defend) so tomorrow's pages have something to pick up.
    """
} else {
    clashSection = ""
}
```

and interpolate `\(clashSection)` in the returned string immediately after
`\(evidence... )` alongside the other optional sections (theme/chapter/etc. —
put it directly after the KEPT PAGES interpolation group).

### B5. Tests (Part B)

```swift
func testBraidPromptHingesOnClashPages() {
    let clashPage = BookPage(type: .narrativeOS, promptText: "Clash", userInput: "The grey edited the list.",
                             tags: ["clash", "clash:grey-edit", "choice:progressarc", "clash-outcome:costly-success"], origin: .generated)
    let day = BookDay(id: "clash-day", date: Date(), pages: [clashPage])
    let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)
    XCTAssertTrue(prompt.contains("WHERE BELIEF WAS TESTED:"))
    XCTAssertTrue(prompt.contains("Clash digest: Belief was tested (grey-edit)"))

    let quietDay = BookDay(id: "quiet-day", date: Date(), pages: [
        BookPage(type: .souvenir, promptText: "One line", userInput: "The kettle sang.", origin: .userAuthored)
    ])
    XCTAssertFalse(BraidPromptBuilder.prompt(for: quietDay, context: .empty).contains("WHERE BELIEF WAS TESTED"))
}
```

---

## Verify

1. `swift test` (Parts A and B both have package-level tests; keep-time tag
   code in B1/B2 is app-target and is exercised by building).
2. Build the app target (`xcodebuild -project EnchantifyInsideCover.xcodeproj
   -scheme InsideCoverApp -destination 'generic/platform=iOS Simulator' build`).

## Out of scope (do not attempt)

- Story-consequence bundles for clash residue (`.storyconsequences.json`
  entries boosting follow-up recipes via `storyRecipeBoosts`) — the machinery
  exists and is the phase-2 residue channel; the braid's residue clause is v1.
- A visible "Where Belief Was Tested" *heading in the rendered braid* — the
  section is prompt-internal shaping only.
- Gossip/Letters/Book Notices picking up clash residue.
- Changing braid selection/caps (all kept pages still flow into evidence; the
  50/50 is a composition rule, not a filter).
