# Instant Gratification — the Book replies at once (implementation plan)

Goal: shorten the felt distance between "I kept a page" and "the world responded,"
without touching the ritual calendar. Four features, smallest first:

1. **Margin replies** — a cast member leaves a one-line margin note the moment a
   substantive page is kept.
2. **Story Spark fast path** — a vivid souvenir sentence starts drawing its door
   *now*, not at the next cadence slot.
3. **Evening ember** — from 5pm, a shelf card teases which threads tonight's
   braid has already caught.
4. **Weekly signature** — on weekends, a shelf card reports which pages the
   Bindery has sewn into this month's edition so far.

House laws that must hold:
- **Responsiveness, not reward.** Fixed, legible cause-and-effect. No variable-ratio
  surprise, no streaks, no counters. The big payoffs (nightly braid, Monthly
  Binding) keep their schedule — these features only make the wait visible and warm.
- Deterministic prose is the floor; nothing here calls Gemma except the existing
  `prepareStoryPageIfPossible` path, which already has its own deterministic floor.
- All prose below is final — transcribe it verbatim, do not re-author.
- **No new Swift files in `Shared/`** — all engine code goes into files already
  listed in `Package.swift` sources, so **no pbxproj or Package.swift changes are
  needed**. New *test* files are fine (the test target auto-discovers by path).

---

## Step 1 — Engine: `KeepMarginalia` (deterministic margin replies)

File: `Shared/WorldSystems.swift` (already in the core target). Add at the end:

```swift
/// The instant margin reply a cast member leaves when the reader keeps a page.
/// Deterministic: the page ID seeds voice and line, so the same keep always
/// earns the same note (and tests can pin it).
enum KeepMarginalia {
    struct Note: Equatable {
        var castSlug: String
        var castName: String
        var assetName: String
        var line: String
    }

    struct Voice {
        let slug: String
        let name: String
        let asset: String
        /// Lines usable as-is.
        let plainLines: [String]
        /// Lines containing "{word}", filled with a word lifted from the input.
        let wordLines: [String]
    }

    static let voices: [Voice] = [
        Voice(
            slug: "pippa-pilcrow",
            name: "Pippa Pilcrow",
            asset: "LabyrinthCharacterPilcrow",
            plainLines: [
                "I let a comma loose in that one. It needed the air.",
                "That sentence stretched its legs the moment you looked away.",
                "Kept! And the full stop is already plotting its escape.",
                "The margins clapped. Quietly. But they clapped."
            ],
            wordLines: [
                "Oh, \u{201C}{word}\u{201D} wants to be two things at once. I say let it.",
                "\u{201C}{word}\u{201D} — now THAT is a word with somewhere to be."
            ]
        ),
        Voice(
            slug: "professor-thaddeus-mook",
            name: "Professor Mook",
            asset: "LabyrinthCharacterMook",
            plainLines: [
                "Adequate. I have filed it before it could misbehave.",
                "One true sentence, properly shelved. The Registry thanks you.",
                "I corrected nothing. Do not let it go to your head.",
                "Filed under: better than expected. A provisional category."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} is used correctly. I am noting my surprise in red.",
                "\u{201C}{word}\u{201D} — 1743 would have approved. As, grudgingly, do I."
            ]
        ),
        Voice(
            slug: "penny-blackletter",
            name: "Penny Blackletter",
            asset: "LabyrinthCharacterPennyBlackletter",
            plainLines: [
                "Catalogued. The small detail is the load-bearing one, as usual.",
                "I nearly lost this one to the margins. Went back for it.",
                "Evidence accepted. One honest detail can save a whole day.",
                "The archive is one true thing heavier tonight."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} goes on its own card. It earned it.",
                "Filed edge to edge. \u{201C}{word}\u{201D} gets a cross-reference."
            ]
        )
    ]

    /// The special note when a kept souvenir clears the Story Spark bar —
    /// the Book itself answers, promising the door that Step 3 of `savePage`
    /// is already preparing.
    static let sparkNote = Note(
        castSlug: "book-sprite",
        castName: "The Book",
        assetName: "LabyrinthFaeBookSprite",
        line: "That sentence is glowing at the edges. Somewhere in the Stacks, a door is being drawn."
    )

    private static let stopWords: Set<String> = [
        "about", "after", "again", "because", "before", "being", "could",
        "every", "first", "other", "really", "their", "there", "these",
        "thing", "think", "today", "under", "where", "which", "while", "would"
    ]

    /// Longest interesting word in the input (>= 5 letters, not a stop word).
    static func featuredWord(in input: String) -> String? {
        input.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 5 && !stopWords.contains($0) }
            .max { $0.count < $1.count }
    }

    /// FNV-1a — stable across launches, unlike `hashValue`.
    static func seed(for pageID: String) -> UInt64 {
        pageID.unicodeScalars.reduce(into: UInt64(1_469_598_103_934_665_603)) {
            $0 = ($0 ^ UInt64($1.value)) &* 1_099_511_628_211
        }
    }

    /// Nil when the keep is too thin to deserve ink (fewer than 3 words) or the
    /// page is one of the intimate log types that the cast never comments on.
    static func note(for input: String, pageType: BookPageType, pageID: String) -> Note? {
        guard !EditionCurator.defaultPrivateTypes.contains(pageType) else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split { !$0.isLetter && !$0.isNumber }.count
        guard wordCount >= 3 else { return nil }

        let seed = seed(for: pageID)
        let voice = voices[Int(seed % UInt64(voices.count))]
        let word = featuredWord(in: trimmed)
        let pool = word == nil ? voice.plainLines : voice.plainLines + voice.wordLines
        var line = pool[Int((seed >> 8) % UInt64(pool.count))]
        if let word {
            line = line.replacingOccurrences(of: "{word}", with: word)
        }
        return Note(castSlug: voice.slug, castName: voice.name, assetName: voice.asset, line: line)
    }
}
```

Notes for the implementer:
- `EditionCurator.defaultPrivateTypes` already exists (`Shared/EditionCurator.swift`,
  search `defaultPrivateTypes`) and covers `.body` and `.fuel` — the cast stays
  out of the reader's body and fuel logs.
- The `LabyrinthCharacterMook` and `LabyrinthCharacterPilcrow` imagesets were
  just added to `InsideCoverApp/Assets.xcassets/`; `LabyrinthCharacterPennyBlackletter`
  and `LabyrinthFaeBookSprite` already exist (see `ScribeWorkDescriptor` in
  `InsideCoverApp/BookStatusCards.swift` for prior art using them).

## Step 2 — App: margin-note toast at the keep moment

File: `InsideCoverApp/ContentView.swift`.

2a. State (next to `keepInkBurstTrigger`, search `@State private var keepInkBurstTrigger`):

```swift
@State private var keepMarginNote: KeepMarginalia.Note?
@State private var keepMarginNoteTicket = 0
```

⚠️ Do **not** name the local counter `generation` anywhere — `ContentView`
already has a `generation` property (the local-brain generation store) and the
shadowing will not compile cleanly.

2b. Presenter (place near `savePage`):

```swift
private func presentKeepMarginNote(_ note: KeepMarginalia.Note) {
    keepMarginNoteTicket += 1
    let ticket = keepMarginNoteTicket
    Task { @MainActor in
        // Let the ink burst land first; the margin note is the echo.
        try? await Task.sleep(nanoseconds: 900_000_000)
        guard ticket == keepMarginNoteTicket else { return }
        withAnimation(.spring(duration: 0.5)) { keepMarginNote = note }
        try? await Task.sleep(nanoseconds: 5_200_000_000)
        guard ticket == keepMarginNoteTicket else { return }
        withAnimation(.easeOut(duration: 0.4)) { keepMarginNote = nil }
    }
}
```

2c. Overlay. In the same layered stack as `LivingInkBurst` (search
`LivingInkBurst(` in `rootStack`), immediately after its `.zIndex(16)`:

```swift
if let note = keepMarginNote {
    KeepMarginNoteToast(note: note)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 28)
        .padding(.bottom, 140)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(17)
        .allowsHitTesting(false)
}
```

2d. The toast view. Add to `InsideCoverApp/BookStatusCards.swift`:

```swift
/// The instant margin reply shown right after a page is kept — a cast member's
/// one-line note, echoing the keep before the surface retires.
struct KeepMarginNoteToast: View {
    let note: KeepMarginalia.Note

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(note.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(BookPalette.gold.opacity(0.35), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(note.castName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(note.line)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}
```

2e. Hook into `savePage(surface:input:tags:)` (ContentView.swift, search
`recordNarrativeEvent(for: page)`). Insert immediately after that line:

```swift
let keptInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
let sparked = page.type == .souvenir && StorySpark.score(keptInput) >= 7
if sparked {
    presentKeepMarginNote(KeepMarginalia.sparkNote)
} else if let note = KeepMarginalia.note(for: keptInput, pageType: page.type, pageID: page.id) {
    presentKeepMarginNote(note)
}
```

Scope: only the `savePage` path. The onboarding photo keep and other
`BookFeedback.play(.keepPage)` call sites stay as they are.

## Step 3 — Story Spark fast path

File: `InsideCoverApp/ContentView.swift`, same insertion point as 2e — extend
the `if sparked` branch:

```swift
if sparked {
    presentKeepMarginNote(KeepMarginalia.sparkNote)
    surfaceRefreshDate = Date()
    Task { await prepareStoryPageIfPossible(force: true) }
}
```

Why this works with no engine change:
- `StorySpark.candidate(for:inputs:now:)` (`Shared/StoryEngine.swift:1460`)
  already prefers the highest-scoring recent souvenir, and the page we just
  appended is in `today.capturedPages`, so the grounding for the prepared story
  page pins to it (`grounding(...)`, StoryEngine.swift:1703).
- `prepareStoryPageIfPossible(force: true)` (ContentView.swift, search
  `func prepareStoryPageIfPossible`) already bypasses the 4-hour
  `SurfaceCadence` slot gate when forced, and already refuses to run while the
  local brain is busy or a preparation is in flight — no extra guarding needed.
- Bumping `surfaceRefreshDate` re-runs `buildCuratorSurfaces` (the
  `.onChange(of: surfaceRefreshDate)` at ContentView.swift:845), so the desk
  reflects the spark without waiting for the next slot tick.

Known v1 simplification (acceptable, do not fix): if the local brain is mid-task
the forced preparation is skipped and the spark simply lands at the next regular
opportunity — the margin note still promised only that a door "is being drawn."

## Step 4 — Engine + shelf: the evening ember

4a. Engine. File: `Shared/SurfaceAndCurator.swift`. Add near `SurfaceCadence`:

```swift
/// From 5pm, a one-line teaser naming the threads tonight's braid has already
/// caught — anticipation for the Book of You without moving its reveal.
enum BraidEmber {
    static func teaser(for day: BookDay, now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard calendar.component(.hour, from: now) >= 17 else { return nil }
        let threads = threadLabels(for: day)
        guard threads.count >= 2 else { return nil }
        let countWord = threads.count == 2 ? "two" : "three"
        let joined = threads.count == 2
            ? "\(threads[0]) and \(threads[1])"
            : "\(threads[0]), \(threads[1]), and \(threads[2])"
        return "Tonight\u{2019}s braid has caught \(countWord) threads: \(joined)."
    }

    /// Up to three short labels for today's captured pages, strongest first.
    /// A page with prose is named by its most vivid word; a wordless log is
    /// named by its page type.
    static func threadLabels(for day: BookDay) -> [String] {
        let ranked = day.capturedPages.sorted {
            let left = StorySpark.score($0.userInput.nonEmpty ?? $0.promptText)
            let right = StorySpark.score($1.userInput.nonEmpty ?? $1.promptText)
            if left == right { return $0.createdAt > $1.createdAt }
            return left > right
        }
        var labels: [String] = []
        for page in ranked {
            let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let label: String
            if let word = KeepMarginalia.featuredWord(in: text) {
                label = "the \(word)"
            } else if !text.isEmpty {
                label = "the \(page.type.shortTitle.lowercased())"
            } else {
                label = "a \(page.type.shortTitle.lowercased())"
            }
            if !labels.contains(label) { labels.append(label) }
            if labels.count == 3 { break }
        }
        return labels
    }
}
```

4b. Card. File: `InsideCoverApp/BookStatusCards.swift`, next to
`BraidingStatusCard` (line ~1498):

```swift
struct BraidEmberStatusCard: View {
    let teaser: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundStyle(BookPalette.lampGold)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(teaser)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                Text("The Book of You braids tonight.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        )
    }
}
```

4c. Shelf hook. File: `InsideCoverApp/ContentView.swift`, in
`localBrainWorkShelf` (search `var localBrainWorkShelf`). Extend the else-if
chain after the `generation.isBraiding` branch:

```swift
} else if let teaser = BraidEmber.teaser(for: today) {
    BraidEmberStatusCard(teaser: teaser)
        .transition(.opacity.combined(with: .move(edge: .top)))
}
```

## Step 5 — Engine + shelf: the weekly signature

5a. Engine. File: `Shared/EditionCurator.swift`.

First, hoist the phrase helper so it can serve both the set-aside line and the
signature: move `private func countPhrase(type:count:)` out of `CuratedMonth`
and make it `static func countPhrase(type: BookPageType, count: Int) -> String`
on `EditionCurator` (body unchanged); update the one call site in
`setAsideLine` to `EditionCurator.countPhrase(type: type, count: count)`.

Then add:

```swift
/// A weekend accounting of what the Bindery sewed into this month's edition
/// over the past seven days. Nil until at least two pages made the cut —
/// a signature is a gathering of sheets, not a single leaf.
static func weeklySignatureLine(monthPages: [BookPage], now: Date = Date()) -> String? {
    guard !monthPages.isEmpty else { return nil }
    let curated = curate(monthPages, now: now)
    let weekStart = now.addingTimeInterval(-7 * 86_400)
    let sewn = curated.pages.filter { $0.createdAt >= weekStart && $0.createdAt <= now }
    guard sewn.count >= 2 else { return nil }
    let parts = Dictionary(grouping: sewn, by: \.type)
        .mapValues(\.count)
        .sorted { left, right in
            if left.value == right.value { return left.key.title < right.key.title }
            return left.value > right.value
        }
        .prefix(3)
        .map { countPhrase(type: $0.key, count: $0.value) }
    let joined: String
    switch parts.count {
    case 1: joined = parts[0]
    case 2: joined = "\(parts[0]) and \(parts[1])"
    default: joined = "\(parts[0]), \(parts[1]), and \(parts[2])"
    }
    let month = now.formatted(.dateTime.month(.wide))
    return "This week the Bindery sewed \(sewn.count) pages into \(month)\u{2019}s edition: \(joined)."
}
```

5b. Card. File: `InsideCoverApp/BookStatusCards.swift`, next to
`BraidEmberStatusCard`:

```swift
struct WeeklySignatureCard: View {
    let line: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 16))
                .foregroundStyle(BookPalette.teal)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(line)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                Text("The Monthly Binding gathers its signatures.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
        )
    }
}
```

5c. Shelf hook. In `localBrainWorkShelf`, after the Step 4c branch:

```swift
} else if Calendar.current.isDateInWeekend(Date()),
          let line = EditionCurator.weeklySignatureLine(monthPages: currentMonthPages) {
    WeeklySignatureCard(line: line)
        .transition(.opacity.combined(with: .move(edge: .top)))
}
```

And add the helper nearby in `ContentView`:

```swift
private var currentMonthPages: [BookPage] {
    let calendar = Calendar.current
    let now = Date()
    return days
        .flatMap(\.pages)
        .filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
}
```

Known v1 simplifications (acceptable, do not fix):
- On weekend *evenings* the ember outranks the signature — the chain shows one
  card at a time and the braid is the nearer event.
- `weeklySignatureLine` recomputes `curate` on shelf redraws. `curate` is a
  linear pass over one month of pages; if profiling ever flags it, memoize by
  day ID — do not pre-optimize now.

## Step 6 — Tests

New file: `Tests/InsideCoverCoreTests/InstantGratificationTests.swift` (the test
target auto-discovers files under its path; no registration needed). Mirror the
`BookPage`/`BookDay` construction helpers already used in
`Tests/InsideCoverCoreTests/StorySparkTests.swift`.

Cover at minimum:

1. **Marginalia determinism** — `KeepMarginalia.note(for:pageType:pageID:)`
   returns the same `Note` for the same `pageID` twice; two different IDs that
   land on different `seed % 3` buckets produce different voices.
2. **Marginalia thresholds** — input `"ok"` returns nil (under 3 words);
   `pageType: .fuel` returns nil even with rich input
   (`defaultPrivateTypes` respected).
3. **Word substitution** — an input whose longest eligible word is known (e.g.
   `"the parking lot looked like a cathedral"` → `cathedral`) produces a line
   with no remaining `{word}` placeholder, and `featuredWord(in:)` returns
   `"cathedral"`.
4. **Ember gating** — `BraidEmber.teaser` is nil at 10:00 for a full day, nil at
   18:00 with one captured page, and non-nil listing two labels at 18:00 with
   two prose pages. Build `now` with the same `Self.date(...)` helper pattern
   as StorySparkTests.
5. **Ember labels** — a page containing a vivid word yields `"the <word>"`; a
   wordless mood log yields its type label; duplicates dedupe.
6. **Weekly signature** — pages created 2 days ago that survive `curate`
   produce a line containing the count and month; pages older than 7 days are
   excluded; a single qualifying page returns nil. Use `.souvenir` pages with
   `origin: .userAuthored` and real body text so `bindingScore` clears the
   centerpiece bar.

## Verification

- `swift test` from the repo root (runs `InsideCoverCoreTests`, including the
  existing `StorySparkTests`, which must stay green — Steps 1/4/5 add code but
  change no existing behavior except the `countPhrase` hoist).
- Build the app scheme in Xcode (the UI additions in ContentView and
  BookStatusCards are not covered by `swift test`).
- Manual pass: keep a diary page with a real sentence → ink burst, then a
  margin note ~1s later, auto-dismissing ~5s after. Keep a vivid souvenir
  ("The rain made the parking lot look like a page under glass.") → the Book's
  spark note appears and the story-page scribe card starts working. Set the
  clock past 5pm with 2+ kept pages → ember card on the shelf. On a weekend
  with 2+ strong pages this month → signature card.
