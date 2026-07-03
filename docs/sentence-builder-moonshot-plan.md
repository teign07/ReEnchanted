# Sentence Builder — Moonshot Completion Plan

The builder's core (grammar-safe scaffold, context themes, ReaderLexicon merge, starter
templates, LivingTextEditor UI) is finished and tested. What's missing is everything the
word "upgradeable" promised: the expansion-pack pipe is capped at both ends, the Shadow
Wonder pack never reaches the editor, the registry cache is dead code, and a legacy
"nudge/steps" layer rides along unrendered. Five phases below, ordered so each stands
alone. No new Shared files are added, so **no pbxproj / Package.swift changes needed**.

Run `swift test` after each phase. Baseline: 44 tests pass in
`SentenceBuilderTests`, `BraidTextPolisherTests`, `ReaderLexiconLanguageLawTests`.

---

## Phase 1 — Compose `shadowWonder` into the editor when Shadow Wonder is active

**Why:** The doc comment on `SentenceBuilderPack.shadowWonder`
([Shared/SentenceBuilder.swift:759](../Shared/SentenceBuilder.swift)) claims it "is
composed in-world only while ShadowWonder is active" — but no call site ever merges it.
It only seeds `ShadowWonder.gameWords`.

**Canon gate (already implemented, do not re-implement):** `ShadowWonder.state(inputs:now:)`
in [Shared/WorldSystems.swift:3691](../Shared/WorldSystems.swift) sets
`isUnlocked = (inputs.entityBeliefOffsets["dusk-thorn"] ?? 0) > 0` — i.e. Shadow Wonder
does not exist until the player has invested belief in the Duskthorn at least once.
`State.isActive` additionally requires night / Duskthorn ascendant / hard day / somber
weather. **Use `.isActive` as the flag; it already encodes the belief gate.**

**Changes:**

1. `Shared/SentenceBuilder.swift` — extend the two lexicon-composing registry entry
   points with a flag (default `false` so existing tests/call sites compile unchanged):

   ```swift
   static func composedCore(
       readerLexicon: ReaderLexicon,
       shadowWonderActive: Bool = false
   ) -> SentenceBuilderPack {
       var pack = composed(onto: .core, readerLexicon: readerLexicon)
       if shadowWonderActive { pack = pack.merged(with: .shadowWonder) }
       return pack
   }
   ```

   Same for `composedSouvenir(readerLexicon:shadowWonderActive:)`. Merge `.shadowWonder`
   **last** so its ritual voice ("Wake the worn edge", "The Thornlight Index") wins while
   active — that is intended; the pack is `bundledFree` and only reachable through this
   flag, so a normal run never turns goblin-core.

2. `InsideCoverApp/CapturePageSheet.swift` — add a stored property near `readerLexicon`
   (line ~724):

   ```swift
   var isShadowWonderActive: Bool = false
   ```

   Pass it at all three `LivingTextEditor` call sites (lines ~2570, ~5324, ~5986), e.g.:

   ```swift
   builderPack: SentenceBuilderPackRegistry.composedCore(
       readerLexicon: readerLexicon,
       shadowWonderActive: isShadowWonderActive
   )
   ```

3. `InsideCoverApp/ContentView.swift` — at the `CapturePageSheet(` construction
   (line ~3810, where `readerLexicon: activeReaderLexicon` is passed at ~3896), add:

   ```swift
   isShadowWonderActive: ShadowWonder.state(inputs: sourceInputs, now: Date()).isActive
   ```

   (`sourceInputs` is a computed var on ContentView, line ~368.)
   If there is a second CapturePageSheet-like construction near line 6279, wire it the
   same way; if that context has no `sourceInputs`, leave the default `false`.

4. Update the `shadowWonder` doc comment so it describes the now-real wiring instead of
   promising it.

**Tests (add to `Tests/InsideCoverCoreTests/SentenceBuilderTests.swift`):**
- `composedCore(readerLexicon: .init(), shadowWonderActive: true)` contains the
  `thornlight` and `decay` themes and `ritualTitle == "Wake the worn edge"`.
- With `shadowWonderActive: false`, no `thornlight` theme and core ritual title intact.

---

## Phase 2 — Make `nightAndGarden` purchasable (shop listing + entitlement)

**Why:** `pack.night-and-garden` ships `availability: "locked"` and should only compose
after its pack id is present in `PackEntitlements.ownedPackIDs`.

**Decision taken:** list it in the shop as a paid word pack. StoreKit or the dev counter
writes the id into `ownedPackIDs`; the sentence builder composes it only after that
entitlement exists.

**Changes (all in `Shared/PagePacks.swift`):**

1. Add a new `BookShopListing.Family` case:

   ```swift
   case wordPack   // shelfLabel: "Word Hoards"
   ```

   (`Family` is `Codable`/`CaseIterable`; adding a case is additive and safe — check for
   any `switch` over `Family` elsewhere, e.g. shelf ordering in
   `InsideCoverApp/BookShopSheet.swift`, and add the case there too.)

2. Add a listing to `BookShopCatalog.listings`:

   ```swift
   BookShopListing(
       id: "listing-night-and-garden",
       packID: "pack.night-and-garden",
       family: .wordPack,
       title: "Night & Garden Word Hoard",
       goblinPitch: "Moths, moss, and moonlit verbs. The Index Empire counted every word twice and taxed neither.",
       contents: "More senses, livelier verbs, and two new context themes (Garden, Night) for the sentence builder.",
       productID: "com.openclaw.enchantify.insidecover.pack.night-and-garden",
       saleState: .standard
   )
   ```

3. `InsideCoverApp/ContentViewFeatures.swift`, `unlockPack(_:)` (line ~1835): add
   `SentenceBuilderPackRegistry.reload()` after the entitlement is written, so a
   purchase invalidates the composed-pack cache (matters once Phase 4 makes the cache
   live).

**Tests:**
- `BookShopCatalog.listing(forPackID: "pack.night-and-garden")` is non-nil.
- With no entitlement, `SentenceBuilderPackRegistry.enabledExpansionPacks()` omits
  `pack.night-and-garden`; after ownership it contains the pack.
- `composedCore(readerLexicon: .init())` contains the `garden` theme and the word
  `"moth"` in `concreteWords`.

---

## Phase 3 — In-app import for `.sentencepack.json`

**Why:** `SentenceBuilderPackRegistry.userPacks()` reads `*.sentencepack.json` from
Documents, but the app's only `fileImporter` imports save files. There is no in-app way
to install a word pack.

**Changes (UI in `InsideCoverApp/BookShopSheet.swift` — existing file, no pbxproj work):**

1. Add a small "Bring your own hoard" row/section (natural home: near the Word Hoards
   shelf from Phase 2, or at the shop's foot). Button label along the lines of
   "Import a word pack (.sentencepack.json)".

2. Wire a `.fileImporter(isPresented:allowedContentTypes:[.json])` on the sheet.
   On success:
   - Read the file's `Data` (wrap in `url.startAccessingSecurityScopedResource()` /
     `defer { stopAccessing... }` — files come from outside the sandbox).
   - Validate: `JSONDecoder().decode(SentenceBuilderPack.self, from: data)` **and**
     require the decoded pack to be non-empty (at least one of `concreteWords`,
     `sensoryWords`, `animateVerbs`, `crossingWords`, `themes` non-empty) — the decoder
     is lenient-by-default, so an arbitrary JSON file would otherwise "decode" as an
     empty pack.
   - Copy into Documents named `<sanitized-pack-id>.sentencepack.json` (overwrite OK —
     re-import is an update).
   - Call `SentenceBuilderPackRegistry.reload()`.
   - Show a status line (the shop already has status messaging patterns) — success:
     pack displayName/id + word count; failure: "That file isn't a word pack."

3. Note: `userPacks()` already forces non-locked imports to `availability:
   "userImported"`; no registry change needed.

**Tests (registry-level, no UI):**
- Write a valid pack JSON into a temp dir, point `userPacks(fileManager:)` at it —
  already possible? `userPacks` uses `.documentDirectory` from the passed FileManager;
  if not easily testable, extract the validation ("decodes + non-empty") into a small
  `SentenceBuilderPackRegistry.validateImport(data:) -> SentenceBuilderPack?` helper and
  test that: valid pack → non-nil; `{}` → nil; malformed JSON → nil. Use the helper from
  the UI.

---

## Phase 4 — Make the registry cache real (and used)

**Why:** The cached `composedCore()` / `composedSouvenir()` (no-lexicon) variants are
never called from UI. The lexicon variants used at all three call sites bypass the cache,
so every SwiftUI render of the capture sheet rescans Documents and re-decodes every user
pack. `reload()` is never called.

**Changes (`Shared/SentenceBuilder.swift`, `SentenceBuilderPackRegistry`):**

1. Restructure so the **expensive part** (Documents scan + JSON decode + expansion merge)
   is cached, and the **cheap, save-state-dependent parts** (lexicon, shadow flag) are
   merged on top per call:

   ```swift
   static func composedCore(
       readerLexicon: ReaderLexicon,
       shadowWonderActive: Bool = false
   ) -> SentenceBuilderPack {
       var pack = composedCore()   // cached base: core + expansions
           .merged(with: readerLexicon.asSentenceBuilderPack())
       if shadowWonderActive { pack = pack.merged(with: .shadowWonder) }
       return pack
   }
   ```

   Same shape for `composedSouvenir`. (This folds Phase 1's change into the cached path —
   if implementing in order, Phase 1's version gets rewritten here; that's fine.)

2. `reload()` call sites (now meaningful):
   - after pack unlock — `unlockPack(_:)` (added in Phase 2),
   - after user-pack import (added in Phase 3).

3. Keep the existing `nonisolated(unsafe) static var cache` pattern; it matches the
   file's other registries.

**Tests:**
- `composedCore(readerLexicon:)` equals the old uncached composition for the same inputs
  (compare against a hand-built `composed(onto: .core, readerLexicon: lexicon)`).
- After `reload()`, `composedCore()` still returns a pack containing an expansion word
  (cache rebuild works).

---

## Phase 5 — Delete the legacy nudge/steps layer

**Why:** The append-chips design was replaced by the scaffold/token-strip UI. The
nudge machinery is computed but never rendered; several private views are dead.

**Delete — UI (`InsideCoverApp/LivingTextInput.swift`):**
- `private var nudge` (line ~24) — never referenced in `body`.
- `@State private var completedKinds` and its reset block inside `.onChange(of: text)`
  (lines ~11, ~123–126) — only fed the nudge.
- Dead private views: `replayCard` (~630), `craftMarks` (~650), `alchemyLadder` (~672),
  `diagnosticRow` (~701). (`starterOrReplayCard`, `builderProgressPill`, and `coachLine`
  are the live equivalents — keep those.)
- `private var alchemyLevels` (~45) — only fed `alchemyLadder`.

**Delete — engine (`Shared/SentenceBuilder.swift`):**
- `SentenceBuilderEngine.nudge(for:completedKinds:)`, `mistStep(for:)`, `glowStep(for:)`.
- `chips(for:text:)` and `phrase(for:chip:step:)` (the latter is a six-case identity
  switch) and `append(_:to:)`.
- `struct SentenceBuilderNudge`.
- `struct SentenceBuilderStep`, the `steps` field on `SentenceBuilderPack` (+ its
  `CodingKeys` entry, decoder line, `mergedSteps(with:)`, and the `steps:` arrays in
  `.core` / `.souvenir`). Lenient decoding ignores unknown keys, so existing
  `.sentencepack.json` files with a `steps` array still decode.
- `alchemyLevels(for:)` and `struct SentenceBuilderAlchemyLevel` (UI consumer deleted
  above).

**Keep (used by the live scaffold path — do not delete):**
- `enum SentenceBuilderStepKind` — it is the ID type of `SentenceBuilderCraftMark` and
  drives `symbol(for:)` in the UI.
- `analyze(_:)`, diagnostics, `hasAvoidWord(_:)`, `firstMatchedWord`, `alternatives(for:)`
  (feeds `moves(for:)` for misty/smoke tokens), `souvenirShareText`, everything scaffold/
  starter/theme/moves related.

**Tests:** delete the nudge-flow tests in `SentenceBuilderTests` (names like
`testVagueWordsBecomeCutMistNudges`, and any test calling `nudge`, `chips(for:)`,
`append`, or asserting on `steps`). The compiler is the guide: delete engine code first,
then fix what fails to build. Everything scaffold/analysis/starter/lexicon-related must
still pass untouched.

---

## Verification (after all phases)

1. `swift test` — full package green.
2. Build the app target:
   `xcodebuild -project EnchantifyInsideCover.xcodeproj -scheme <app scheme> build` (or
   build in Xcode).
3. Manual sanity if running the app: open a capture sheet → "Wake the sentence" →
   token strip works; with a Duskthorn belief invested and night/somber conditions the
   ritual header reads "Wake the worn edge" and thorn/rust chips appear.
