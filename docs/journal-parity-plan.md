# Journal Parity Plan

Close the gaps between ReEnchanted and the standard journaling-app feature set,
without breaking the local-first privacy stance or the fiction. Six phases,
ordered by importance. Each phase is independently shippable — finish one,
build, test, commit, then start the next.

## Ground rules (read before every phase)

- **New files in `Shared/` must be registered twice**: add to
  `EnchantifyInsideCover.xcodeproj/project.pbxproj` AND `Package.swift`
  (InsideCoverCore target), or tests won't see them. Files in
  `InsideCoverApp/` only need the pbxproj.
- **Never rename or remove existing Codable fields.** All new fields must be
  optional or have defaults, decoded with `decodeIfPresent(...) ?? default` —
  copy the pattern at `Shared/PageModel.swift:1375`.
- **Tests are XCTest**, live in `Tests/InsideCoverCoreTests/`, target
  `@testable import InsideCoverCore`. Only `Shared/` code is testable there —
  put logic in `Shared/`, keep views thin. Verify with `swift test`.
- **Everything user-facing is in-world.** No "Backup", "Export", "Calendar"
  labels. Use the names given per phase. Match the prose voice of nearby UI.
- **iOS deployment target is 17.0.** Anything newer needs
  `if #available(...)` guards.
- Don't touch `docs/physical-book-backend/` or the landing page.
- Ignore `.claude/worktrees/` in all searches.

## Key existing code (anchors)

- Full-archive save file: `ReEnchantedSaveFile` in `Shared/PagePacks.swift:1246`
  (version 1, JSON, extension `reenchanted-save.json`).
- Export flow: `buildSaveFile()` / `exportSaveFile()` at
  `InsideCoverApp/ContentViewFeatures.swift:655` and `:705`; share button at
  `InsideCoverApp/ContentView.swift:3501` (ShareLink on `preparedSaveFileURL`);
  import at `ContentViewFeatures.swift:1180` via `.fileImporter`
  (`ContentView.swift:952`).
- Page model: `BookPage` at `Shared/PageModel.swift:1300`; media attachments
  already exist as `BookPageMediaAsset` (`Shared/PageModel.swift:1269`) with
  kinds `.bundledImage`, `.renderedImageFile`, `.photoLibraryAsset`.
- Media rendering: `BookOfYouMediaStrip` and asset→image resolution at
  `InsideCoverApp/BookSurfaceViews.swift:2511`. NOTE: for `.renderedImageFile`
  the `reference` is a **full absolute file path**, loaded with
  `UIImage(contentsOfFile:)`.
- File storage: app-group container via `InsideCoverStore.containerURL`
  (`Shared/InsideCoverStore.swift:14`).
- Search sheet (UI pattern to copy for new sheets):
  `InsideCoverApp/SearchTheStacksSheet.swift`.
- Days/pages data source for read-only views: see how
  `Shared/MonthlyEdition.swift:177` consumes `BookArchiveExport(days:calendar:)`.

---

## Phase 1 — The Sealed Copy (backup that actually preserves everything)

**Problem.** `exportSaveFile()` writes JSON only. Pages with
`.renderedImageFile` assets reference image files in the app-group container
by absolute path; those bytes are not in the save file, so photos die on
export/import or a new phone. Also, absolute paths are wrong after reinstall
(container UUID changes).

**Changes.**

1. In `Shared/PagePacks.swift`, extend `ReEnchantedSaveFile`:
   - `static let currentVersion = 2`
   - new field `var mediaFiles: [String: Data]?` — keyed by **filename only**
     (last path component), value = file bytes. `Codable` handles `Data` as
     base64 automatically. Decode with `decodeIfPresent` so v1 files still load.
2. In `buildSaveFile()` (`ContentViewFeatures.swift:655`): walk every
   `BookPage.mediaAssets` in `days` (pages live under each day); for each
   asset with `kind == .renderedImageFile`, read
   `Data(contentsOf: URL(fileURLWithPath: asset.reference))` and store under
   `URL(fileURLWithPath: asset.reference).lastPathComponent`. Skip unreadable
   files silently. Cap total at 400 MB; if exceeded, stop adding and set a
   flag the UI can mention ("some photographs were too heavy to seal").
3. In `importSaveFile(from:)` (`ContentViewFeatures.swift:1180`): after
   decoding, for each entry in `mediaFiles`, write bytes to
   `InsideCoverStore.containerURL!.appendingPathComponent(filename)`
   (atomic write, skip if identical file exists). Then **rewrite every
   imported `.renderedImageFile` asset's `reference`** to the new absolute
   path in this container. Put the rewrite logic in `Shared/` (e.g. a
   `ReEnchantedSaveFile.rehomedMediaAssets(days:containerURL:)` static helper)
   so it's testable.
4. UI (minimal): where the current export ShareLink lives
   (`ContentView.swift:3501`), rename the action to **"Seal a copy"** with a
   one-line caption: "A complete copy of the Book — pages, photographs, and
   all. Keep it somewhere safe (iCloud Drive counts)." Below it show
   "Last sealed <relative date>" from a new `@AppStorage`-style timestamp in
   the store defaults (`InsideCoverStore.defaults`), set on successful export.

**Do not** attempt zip archives, background scheduling, or CloudKit.

**Tests** (`Tests/InsideCoverCoreTests/SealedCopyTests.swift`):
- v2 round-trip: save file with one fake page whose asset references a temp
  file → encode → decode → `mediaFiles` contains the bytes.
- v1 compatibility: hand-written minimal v1 JSON decodes, `mediaFiles == nil`.
- `rehomedMediaAssets`: asset with path `/old/container/img.jpg` +
  container `/new/container` → reference becomes `/new/container/img.jpg`.

### Phase 1b (optional, only if Phase 1 lands cleanly) — passphrase seal

- CryptoKit `AES.GCM`; key = `HKDF<SHA256>` from the passphrase bytes with
  salt `"reenchanted-sealed-copy-v1"`. File = magic prefix
  `RESEALED1` + combined sealed box. Extension `.reenchanted-sealed`.
- Optional toggle in the seal UI ("Seal with a word only you know"); import
  path detects the magic prefix and prompts for the word.
- Note in code: HKDF is not a password-stretching KDF; acceptable because the
  file lives in the user's own storage. One round-trip test + wrong-passphrase
  test (expect throw).

---

## Phase 2 — The Almanac (jump to any date)

A month-grid calendar over the archive. New file
`InsideCoverApp/AlmanacSheet.swift` (pbxproj only) + logic file
`Shared/AlmanacModel.swift` (pbxproj + Package.swift).

1. `Shared/AlmanacModel.swift`: pure functions that, given `[BookDay]` and a
   `Calendar`, produce a month structure: 7-column weeks, each day cell =
   date, kept-page count, whether it has any page. Follow how
   `MonthlyEdition.swift:177` filters `BookArchiveExport(days:calendar:)`.
   Also `earliestMonth` / `latestMonth` bounds so paging can't run past the
   archive.
2. `AlmanacSheet.swift`: copy the sheet scaffolding/styling of
   `SearchTheStacksSheet.swift`. Month title + chevrons to page months,
   `LazyVGrid` 7 columns. Days with kept pages get an ink-dot; today gets a
   ring. Tapping a day expands an in-sheet list of that day's kept pages
   (title/type/first line) — reuse whatever row view SearchTheStacks uses for
   kept-page results, including its tap-through behavior if it has one.
   Do **not** build a new page-reading view.
3. Entry point: add an "Almanac" button directly beside the existing
   Search the Stacks entry point (find where `SearchTheStacksSheet` is
   presented in `ContentView.swift` and mirror it), SF Symbol
   `calendar.badge.clock` or similar.

**Tests** (`AlmanacModelTests.swift`): month grid for a fixed calendar/date
has correct leading blanks and day count; kept-page counts land on the right
cells; bounds clamp correctly.

---

## Phase 3 — The Pressed Photograph (a photo on any kept page)

The model already supports this (`mediaAssets` on every `BookPage`; rendering
exists at `BookSurfaceViews.swift:2416`). The gap is capture UI for ordinary
pages.

1. In `InsideCoverApp/CapturePageSheet.swift`, add a small
   `PhotosPicker` affordance to the ordinary capture flow (label:
   "Press a photograph between these pages", one photo max). There is already
   asset-creation code at `CapturePageSheet.swift:1951` — study it and the
   Illuminated Photos flow before writing anything; reuse, don't duplicate.
2. On selection: load data, downscale so the longest side ≤ 2048 px, encode
   JPEG quality 0.8, write to
   `InsideCoverStore.containerURL!.appendingPathComponent("pressed-<pageID>.jpg")`,
   append `BookPageMediaAsset(kind: .renderedImageFile, reference: <full path>,
   caption: "", sourceID: <match the flow's sourceID>)` to the draft page.
   Put the downscale+encode helper in `Shared/` for testability
   (`Shared/PressedPhotograph.swift`, register in both manifests).
3. Verify the kept page shows the image via the existing media strip. If the
   ordinary kept-page view doesn't render `mediaAssets`, add the existing
   `BookOfYouMediaStrip` there rather than inventing a new component.
4. Confirm Phase 1's seal picks these up automatically (they're
   `.renderedImageFile` — it should).

**Tests**: downscale helper — oversized dimensions come back ≤ 2048 on the
long side; small images pass through unscaled.

---

## Phase 4 — The Book Notices (Apple JournalingSuggestions)

Feed real-life moments (photos, workouts, places, music) into capture as
prompt material. **iOS 17.2+, iPhone-only** — the picker does not exist on
iPad; everything here is additive and gated.

1. Add the **Journaling Suggestions capability** to the app target in the
   Xcode project (entitlement `com.apple.developer.journal.allow`), i.e. edit
   `InsideCoverApp/InsideCoverApp.entitlements` and the pbxproj capability.
   No Info.plist usage string is needed — the picker runs out of process.
2. New file `InsideCoverApp/BookNoticesPicker.swift`: wrap
   `JournalingSuggestionsPicker` (`import JournalingSuggestions`) behind
   `#if canImport(JournalingSuggestions)` + `if #available(iOS 17.2, *)` +
   `UIDevice.current.userInterfaceIdiom == .phone`.
3. Entry point: a "What the Book noticed today…" affordance at the top of the
   capture flow (near where prompts surface in `CapturePageSheet.swift`),
   only when available.
4. Mapping (keep it dumb): suggestion **photo** → run it through Phase 3's
   pressed-photograph path; anything else (workout, location, song, contact)
   → compose one plain sentence from its title/date and prefill it as the
   page's prompt seed text the way an ordinary prompt would be. If a
   suggestion type is awkward, skip it — partial coverage is fine.
5. Add a paragraph to `docs/AppStoreReviewPacket.md`: what the entitlement is
   for, that suggestion data stays on device and is only what the user
   explicitly picks.

**Tests**: none required (framework is UI-only and device-gated); just make
sure the project still builds for iPad/simulator without the framework.

---

## Phase 5 — Pages in Plain Ink (full-archive Markdown export)

1. New file `Shared/PlainInkExport.swift` (both manifests): a pure function
   `PlainInkExport.markdown(days: [BookDay], calendar: Calendar) -> String`.
   Format: `# <Book title / "ReEnchanted — the Book">`, then per day
   `## <full date>`, then per kept page `### <page type display title>`,
   prompt text as a `>` blockquote (if any), the user's words as body,
   tags as a trailing `_#tag #tag_` line. Chronological. Skip empty days.
2. Wire a second action next to Phase 1's seal button: **"Copy out in plain
   ink"** — builds the string, writes
   `ReEnchanted-plain-<date>.md` to the temp dir exactly like
   `exportSaveFile()` does, hands it to the same ShareLink mechanism
   (mirror `preparedSaveFileURL`, `ContentView.swift:3501`).
   Caption: "Every kept page as ordinary text, readable anywhere, forever."

**Tests** (`PlainInkExportTests.swift`): two days / three pages → output
contains both date headings, page bodies in order, tag line present, no
empty-day heading.

---

## Phase 6 — The Kept Voice (audio pages) — LAST, biggest surface

Dictation exists (`InsideCoverApp/DictationInput.swift`) but discards audio.
Keep the recording alongside the transcript.

1. Add `case audioFile` to `BookPageMediaAsset.Kind`
   (`PageModel.swift:1270`). Safe: old data never contains it. Check every
   `switch asset.kind` (at minimum `BookSurfaceViews.swift:2511` and `:7607`,
   plus any others `grep -rn "asset.kind" InsideCoverApp Shared` finds) and
   add an explicit `.audioFile` branch — return nil/skip for image contexts.
2. Recording: extend the dictation flow so that while dictation runs, audio
   is also captured to `.m4a` in the app-group container
   (`kept-voice-<pageID>.m4a`, AAC 64 kbps mono). If the existing dictation
   uses `SFSpeechRecognizer` with an audio engine tap, write the same buffers
   out via `AVAudioFile` rather than adding a second recorder. Keep the
   transcript as `userInput` exactly as today; append an `.audioFile` asset.
   Add a small "keep my voice too" toggle (default on) in the dictation UI.
   Requires no new permission beyond the mic permission dictation already has.
3. Playback: in the kept-page media strip, render `.audioFile` as a small
   play/pause chip ("the phonograph") using `AVAudioPlayer`. New view in
   `BookSurfaceViews.swift` next to the media strip.
4. Extend Phase 1's seal to include `.audioFile` assets in `mediaFiles` and
   the import rehoming — generalize the `kind == .renderedImageFile` check to
   a `kind.isFileBacked` helper on the enum.

**Tests**: `Kind` decodes `"audioFile"`; `isFileBacked` is true for
`.renderedImageFile` and `.audioFile`, false for the others; seal round-trip
picks up an audio asset (reuse Phase 1 test scaffolding).

---

## Explicitly out of scope

- Video attachments, mood check-ins/graphs (deliberately absent — the
  belief-weather systems cover this in-world), CloudKit sync, multi-device,
  background/scheduled backups, zip archives, third-party dependencies.

## Definition of done, per phase

Builds for iOS simulator; `swift test` passes including the phase's new
tests; new user-facing strings are in-world; no existing Codable field
renamed; commit per phase referencing this plan.
