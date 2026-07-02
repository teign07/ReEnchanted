# Echoes & Ripples — the Book remembers, the cast responds (implementation plan)

Goal: deepen the instant-gratification layer shipped in
`docs/instant-gratification-plan.md` (margin replies, spark fast path, ember,
signature) with five additions, all firing at the keep moment:

1. **The Echo** — a kept page that rhymes with an older page earns a
   recognition note: "You wrote about the harbor like this once — back in March."
2. **Belief ripples** — a kept page that touches a cast member visibly warms
   their Belief, right then, with a one-line ripple under the margin note.
3. **Expanded keep reactions** — six new cast voices join Pilcrow, Mook, and
   Penny (nine total), and **voice selection is weighted by effective Belief**,
   so the cast members the reader believes in most speak up most often.
4. **Festival notes** — on Almanac celebration days, the first keep of the day
   earns the Almanac's own seasonal line (calendar gift, never a performance gift).
5. **Card press from the toast** — when the kept text would gild well, the
   margin-note toast becomes tappable and presses an IlluminatedQuoteCard on
   the spot (instant craft artifact; the renderer already exists).

House laws that must hold:
- **Responsiveness, not reward.** Every mechanic here fires on the *content* of
  the act, by fixed legible rules. No streaks, no counters, no variable-ratio
  anything. Absence stays unpunished.
- Deterministic prose only — no Gemma calls anywhere in this plan.
- All prose below is final — transcribe it verbatim, do not re-author.
- **No new Swift files in `Shared/`** — engine code goes into files already in
  `Package.swift` sources. New test files are fine (auto-discovered).
- Belief ripples move the *real* ledger (`applyEntityBeliefLedgerDelta`), capped
  at +1 per entity per day, derived from data — no new storage.

Precedence at the keep moment (one note per keep, fixed order):
**spark > festival (first keep of a celebration day) > echo > belief-weighted cast note.**
The ripple line attaches to whichever note shows.

---

## Step 1 — Engine: six new voices + belief-weighted selection

File: `Shared/WorldSystems.swift`, inside the existing `KeepMarginalia` enum.

1a. `Note` gains an optional ripple line (used by Step 4). Add to the struct:

```swift
var rippleLine: String? = nil
```

1b. Make the stop-word list reusable by Step 3: change
`private static let stopWords` to `static let stopWords` (no other change).

1c. Append six new `Voice` entries to the `voices` array, **after** Penny
Blackletter. The `slug` values are the narrative *entity IDs* from
`NarrativePackRegistry` (`Shared/NarrativeCore.swift` ~1626–1852) — they must
match exactly or belief weighting silently falls back to the default. Note
Inkrest's entity ID is `dr-inkrest`, not her dossier slug.

```swift
Voice(
    slug: "dr-inkrest",
    name: "Dr. Selene Inkrest",
    asset: "LabyrinthCharacterDrSeleneInkrest",
    plainLines: [
        "The lamp was on for this one. It sat down easily.",
        "A page that reads you back, kept anyway. Well done.",
        "I have set two chairs by this page. It may want company later.",
        "Noted without diagnosis. The chapter stays yours to revise."
    ],
    wordLines: [
        "\u{201C}{word}\u{201D} arrived before the feeling did. That is the good order.",
        "We can leave \u{201C}{word}\u{201D} in the room with the lamp on."
    ]
),
Voice(
    slug: "zara-finch",
    name: "Zara Finch",
    asset: "LabyrinthCharacterZaraFinch",
    plainLines: [
        "Kept. I checked — this page holds your weight.",
        "Good. Small returns, kept word after kept word.",
        "I marked the way back to this one, in case you need it.",
        "Pocket-sized and useful. My favorite kind of true."
    ],
    wordLines: [
        "\u{201C}{word}\u{201D} is a safe place to stand. I scouted it.",
        "If the day goes sideways, \u{201C}{word}\u{201D} is your exit. Remember it."
    ]
),
Voice(
    slug: "lydia-boggle",
    name: "Professor Boggle",
    asset: "LabyrinthCharacterLydiaBoggle",
    plainLines: [
        "A home is a spell with the washing-up still in it. Filed accordingly.",
        "That is kitchen-grade magic. The good kind. Kettle\u{2019}s on.",
        "Your ordinary just confessed something marvelous. I heard it.",
        "Label the chaos by room and it almost behaves. See? Kept."
    ],
    wordLines: [
        "Held \u{201C}{word}\u{201D} up to the glint-lens. Marvelous, as suspected.",
        "\u{201C}{word}\u{201D} could hold an extraordinary day without dropping it."
    ]
),
Voice(
    slug: "gwendolyn-mythwright",
    name: "Gwendolyn Mythwright",
    asset: "LabyrinthCharacterGwendolynMythwright",
    plainLines: [
        "Stamped, cross-referenced, and taken completely seriously.",
        "A wonder with evidence behind it. You need not be lonely about it now.",
        "I have a folder for this. I have a folder for everything.",
        "The improbable appreciates proper paperwork. So do I."
    ],
    wordLines: [
        "\u{201C}{word}\u{201D} has been entered in the register of verified wonders.",
        "I am writing a letter to \u{201C}{word}\u{201D}. I expect a reply."
    ]
),
Voice(
    slug: "wicker-eddies",
    name: "Wicker Eddies",
    asset: "LabyrinthCharacterWickerEddies",
    plainLines: [
        "I tried to puncture this one. It held. Annoying.",
        "Kept, and it survived contact with doubt. That\u{2019}s the real kind.",
        "No theatrics in it. I checked twice. Carry on.",
        "I laughed, I stepped toward it, and it didn\u{2019}t flinch. Fine."
    ],
    wordLines: [
        "\u{201C}{word}\u{201D} — I tested it. It rang true. Don\u{2019}t gloat.",
        "Even I can\u{2019}t collapse \u{201C}{word}\u{201D}. It\u{2019}s load-bearing."
    ]
),
Voice(
    slug: "serenity-brown",
    name: "Serenity Brown",
    asset: "LabyrinthCharacterSerenityBrown",
    plainLines: [
        "See? The detour was the whole adventure.",
        "Kept lightly. That\u{2019}s not the same as kept carelessly.",
        "This one gets to be fun forever now.",
        "You stopped white-knuckling it for a second. It shows."
    ],
    wordLines: [
        "\u{201C}{word}\u{201D} is coming with us. It knows the way out.",
        "A whole kingdom could fit inside \u{201C}{word}\u{201D}, doodled small."
    ]
)
```

All six asset names exist in `InsideCoverApp/Assets.xcassets/` (verified).

1d. Belief-weighted selection. Replace the signature and voice-pick lines of
`note(for:pageType:pageID:)`:

```swift
static func note(
    for input: String,
    pageType: BookPageType,
    pageID: String,
    beliefBySlug: [String: Int] = [:]
) -> Note? {
```

and replace `let voice = voices[Int(seed % UInt64(voices.count))]` with:

```swift
// Weighted pick: a cast member's effective Belief is their share of the
// margins. Unknown slugs fall back to the base glow of 20.
let weights = voices.map { max(1, beliefBySlug[$0.slug] ?? 20) }
let total = weights.reduce(0, +)
var pick = Int(seed % UInt64(total))
var voice = voices[0]
for (index, weight) in weights.enumerated() {
    if pick < weight { voice = voices[index]; break }
    pick -= weight
}
```

Everything downstream (word pool, `{word}` substitution) is unchanged. The
call with no `beliefBySlug` stays deterministic, so the existing tests in
`InstantGratificationTests` still pass — but the seeded voice may differ from
before because the pick arithmetic changed; if
`testMarginNoteVoicesSpreadAcrossPageIDs` or determinism tests fail on exact
voices, re-pin the expectations, do not weaken the assertions.

## Step 2 — Engine: festival notes (the Almanac's calendar gift)

File: `Shared/WorldSystems.swift`, inside `KeepMarginalia`, after `sparkNote`.
The sabbat IDs come from `Almanac`'s wheel in the same file (~6336): imbolc,
ostara, beltane, litha, lughnasadh, mabon, samhain, yule. Non-sabbat
celebrations (moons etc.) get the default line.

```swift
/// The Almanac's own line on a celebration day — a calendar gift, keyed to
/// the real world's clock and never to the reader's performance.
static func festivalNote(celebrationID: String, commonName: String) -> Note {
    let line: String
    switch celebrationID {
    case "imbolc": line = "Something under the snow has decided to live. Your page is part of the evidence."
    case "ostara": line = "The scales tipped toward light today. This page leans with them."
    case "beltane": line = "Greenfire weather. The Book presses your page while the sap is loud."
    case "litha": line = "The longest light, and you spent a little of it here. Rich."
    case "lughnasadh": line = "First harvest. The Book binds early sheaves — this one is in."
    case "mabon": line = "The second rebalancing. This page is weighed and found honest."
    case "samhain": line = "The veil is thin; your page slipped through easily tonight."
    case "yule": line = "The darkest class of the year, and still you brought ink. Noted, warmly."
    default: line = "The Almanac is watching tonight. It saw this page and approved."
    }
    return Note(
        castSlug: "almanac",
        castName: "The Almanac \u{2014} \(commonName)",
        assetName: "LabyrinthFaeBookSprite",
        line: line
    )
}
```

## Step 3 — Engine: the Echo

File: `Shared/StacksSearch.swift` (already in the core target; the Echo is a
Stacks retrieval at heart). Add at the end:

```swift
/// The recognition note: a just-kept page that rhymes with an older page
/// earns a line naming the shared word and when it first appeared. Fixed,
/// legible rule — a rare-enough word, old enough to feel like memory.
enum KeepEcho {
    struct Echo: Equatable {
        var sourcePageID: String
        var sharedWord: String
        var monthLine: String
        var line: String
    }

    /// A word must be at least this old to echo — recognition, not repetition.
    static let minimumAgeDays = 14
    /// A word appearing in more archive pages than this is too common to feel
    /// specific ("coffee" echoes nobody).
    static let maximumWordSpread = 4

    static func find(
        for input: String,
        pageID: String,
        in days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Echo? {
        let inputWords = Set(
            input.lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count >= 5 && !KeepMarginalia.stopWords.contains($0) }
        )
        guard !inputWords.isEmpty else { return nil }

        let cutoff = now.addingTimeInterval(TimeInterval(-minimumAgeDays) * 86_400)
        let candidates = days.flatMap(\.capturedPages).filter { page in
            page.createdAt <= cutoff
                && !EditionCurator.defaultPrivateTypes.contains(page.type)
                && !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !candidates.isEmpty else { return nil }

        // How widely each input word is spread across the archive.
        var spread: [String: Int] = [:]
        var matches: [(page: BookPage, word: String)] = []
        for page in candidates {
            let pageWords = Set(
                page.userInput.lowercased()
                    .split { !$0.isLetter }
                    .map(String.init)
                    .filter { $0.count >= 5 && !KeepMarginalia.stopWords.contains($0) }
            )
            for word in inputWords.intersection(pageWords) {
                spread[word, default: 0] += 1
                matches.append((page, word))
            }
        }

        let rare = matches.filter { spread[$0.word] ?? 0 <= maximumWordSpread }
        guard !rare.isEmpty else { return nil }

        // Longest shared word first (most specific), then oldest page.
        let ranked = rare.sorted {
            if $0.word.count != $1.word.count { return $0.word.count > $1.word.count }
            return $0.page.createdAt < $1.page.createdAt
        }
        let top = Array(ranked.prefix(3))
        let seed = KeepMarginalia.seed(for: pageID)
        let chosen = top[Int(seed % UInt64(top.count))]

        let month = chosen.page.createdAt.formatted(.dateTime.month(.wide))
        let sameYear = calendar.component(.year, from: chosen.page.createdAt)
            == calendar.component(.year, from: now)
        let year = calendar.component(.year, from: chosen.page.createdAt)
        let monthLine = sameYear ? "back in \(month)" : "in \(month) \(year)"

        let lines = [
            "You\u{2019}ve written about \u{201C}\(chosen.word)\u{201D} before — \(monthLine). The Book remembers.",
            "This rhymes with a page from \(monthLine) — the one about \u{201C}\(chosen.word)\u{201D}.",
            "The Stacks stirred: \u{201C}\(chosen.word)\u{201D} again, first pressed \(monthLine)."
        ]
        return Echo(
            sourcePageID: chosen.page.id,
            sharedWord: chosen.word,
            monthLine: monthLine,
            line: lines[Int((seed >> 16) % UInt64(lines.count))]
        )
    }

    static func note(from echo: Echo) -> KeepMarginalia.Note {
        KeepMarginalia.Note(
            castSlug: "the-book",
            castName: "The Book",
            assetName: "LabyrinthFaeBookSprite",
            line: echo.line
        )
    }
}
```

Performance note: this is a linear scan of the in-memory archive at keep time
(a few thousand pages at most) — fine on the main actor; do not pre-optimize.

## Step 4 — Engine: belief ripples

File: `Shared/WorldSystems.swift`, after `KeepMarginalia`:

```swift
/// The visible tick when a kept page warms a cast member's Belief — cause and
/// effect on the relationship layer, at the moment of the cause.
enum BeliefRipple {
    static func line(entityName: String, effectiveBelief: Int) -> String {
        if effectiveBelief >= 60 {
            return "\(entityName) burns a little steadier for it."
        } else if effectiveBelief >= 30 {
            return "\(entityName)\u{2019}s glow brightened."
        }
        return "\(entityName)\u{2019}s glow stirred."
    }
}
```

## Step 5 — App: the keep-moment chain in `savePage`

File: `InsideCoverApp/ContentView.swift`. Replace the block inserted by the
previous plan (search `let keptInput = input.trimmingCharacters`) — the whole
`let keptInput ... presentKeepMarginNote(note) }` region — with:

```swift
let keptInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
let sparked = page.type == .souvenir && StorySpark.score(keptInput) >= 7

// Belief ripple: the first page today that touches a cast member warms their
// glow by one, visibly. Derived from the day's pages — no stored counters.
var rippleLine: String?
if page.origin == .userAuthored, !keptInput.isEmpty {
    let touched = RelationshipFieldEngine.entityIDs(fromTags: page.tags)
    if let entityID = touched.first,
       !day.pages.contains(where: { $0.id != page.id && $0.tags.contains("entity:\(entityID)") }) {
        applyEntityBeliefLedgerDelta(entityID: entityID, delta: 1)
        let name = (NarrativePackRegistry.entities + customCastMembers.map(\.entity))
            .first(where: { $0.id == entityID })?.name
        if let name {
            rippleLine = BeliefRipple.line(entityName: name, effectiveBelief: effectiveCastBelief(for: entityID))
        }
    }
}

let celebration = Almanac.active(on: Date(), hemisphere: Hemisphere.from(latitude: lastAnchorReadingLatitude))
let isFirstKeepToday = !day.pages.contains { $0.id != page.id && $0.origin == .userAuthored }

var keepNote: KeepMarginalia.Note?
if sparked {
    keepNote = KeepMarginalia.sparkNote
    surfaceRefreshDate = Date()
    Task { await prepareStoryPageIfPossible(force: true) }
} else if let celebration, isFirstKeepToday, !keptInput.isEmpty {
    keepNote = KeepMarginalia.festivalNote(celebrationID: celebration.id, commonName: celebration.commonName)
} else if let echo = KeepEcho.find(for: keptInput, pageID: page.id, in: days) {
    keepNote = KeepEcho.note(from: echo)
} else {
    keepNote = KeepMarginalia.note(
        for: keptInput,
        pageType: page.type,
        pageID: page.id,
        beliefBySlug: keepMarginaliaBeliefMap
    )
}
if var note = keepNote {
    note.rippleLine = rippleLine
    keepArtifactQuote = quoteWorthKeeping(keptInput) ? keptInput : nil
    keepArtifactPageType = surface.type
    presentKeepMarginNote(note)
}
```

Add these helpers near `presentKeepMarginNote`:

```swift
private var keepMarginaliaBeliefMap: [String: Int] {
    Dictionary(uniqueKeysWithValues: KeepMarginalia.voices.map {
        ($0.slug, effectiveCastBelief(for: $0.slug))
    })
}

/// A quote earns the card press when it has enough body to gild.
private func quoteWorthKeeping(_ text: String) -> Bool {
    StorySpark.score(text) >= 5 || text.split { !$0.isLetter && !$0.isNumber }.count >= 8
}
```

Anchors that already exist (verified): `RelationshipFieldEngine.entityIDs(fromTags:)`
(NarrativeCore.swift:466), `applyEntityBeliefLedgerDelta(entityID:delta:)` and
`effectiveCastBelief(for:)` (ContentView ~5282), `Almanac.active(on:hemisphere:)`
(WorldSystems.swift:6485), `Hemisphere.from(latitude: lastAnchorReadingLatitude)`
(pattern at ContentView:4251), `customCastMembers` (ContentView property).

## Step 6 — App: ripple caption + card press on the toast

6a. State, next to `keepMarginNote` (ContentView):

```swift
@State private var keepArtifactQuote: String?
@State private var keepArtifactPageType: BookPageType = .diary
@State private var keepArtifactCardURL: URL?
@State private var isShowingKeepArtifactCard = false
```

6b. `KeepMarginNoteToast` (BookStatusCards.swift) gains the ripple caption and
an optional press hint. Replace the inner `VStack` contents:

```swift
VStack(alignment: .leading, spacing: 3) {
    Text(note.castName)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    Text(note.line)
        .font(.system(.subheadline, design: .serif))
        .italic()
        .fixedSize(horizontal: false, vertical: true)
    if let ripple = note.rippleLine {
        Text(ripple)
            .font(.caption2)
            .foregroundStyle(BookPalette.lampGold)
    }
    if showsPressHint {
        Text("Tap to press a souvenir card.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
```

and add `var showsPressHint: Bool = false` to the struct.

6c. In ContentView's toast overlay (search `KeepMarginNoteToast(note: note)`),
make it tappable when a quote is worth pressing — replace the overlay block:

```swift
if let note = keepMarginNote {
    Button {
        pressKeepArtifactCard()
    } label: {
        KeepMarginNoteToast(note: note, showsPressHint: keepArtifactQuote != nil)
    }
    .buttonStyle(.plain)
    .disabled(keepArtifactQuote == nil)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .padding(.horizontal, 28)
    .padding(.bottom, 140)
    .transition(.move(edge: .bottom).combined(with: .opacity))
    .zIndex(17)
}
```

(The previous `.allowsHitTesting(false)` is removed; the `.disabled` keeps
plain notes tap-transparent enough, and the toast still auto-dismisses.)

6d. The press action and sheet, near `presentKeepMarginNote`:

```swift
private func pressKeepArtifactCard() {
    guard let quote = keepArtifactQuote else { return }
    let url = IlluminatedQuoteCardRenderer.render(
        quote: quote,
        sourceTitle: keepArtifactPageType.title,
        weatherLine: nil,
        dateLine: Date().formatted(date: .abbreviated, time: .omitted),
        style: PageVisualStyle.style(for: keepArtifactPageType),
        seed: quote.stableHash
    )
    guard let url else {
        BookFeedback.play(.error)
        return
    }
    keepArtifactCardURL = url
    isShowingKeepArtifactCard = true
    BookFeedback.play(.braidComplete)
}
```

and attach to the same view that hosts the other sheets (search an existing
`.sheet(isPresented:` in ContentView for placement precedent):

```swift
.sheet(isPresented: $isShowingKeepArtifactCard) {
    if let url = keepArtifactCardURL, let image = UIImage(contentsOfFile: url.path) {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
            ShareLink(item: url) {
                Label("Share the card", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
        .presentationDetents([.medium, .large])
    }
}
```

`IlluminatedQuoteCardRenderer.render(...)`, `PageVisualStyle.style(for:)`, and
`String.stableHash` all exist — see the call at
`InsideCoverApp/CapturePageSheet.swift:6859` for the exact prior art.

Known v1 simplifications (acceptable, do not fix):
- The card presses with `weatherLine: nil`; the in-page share path keeps its
  richer context lines.
- Tapping mid-dismiss can present a card for a toast that just faded — harmless.
- Only the first touched entity ripples per keep, and the ripple line reflects
  belief *after* the +1.

## Step 7 — Tests

New file: `Tests/InsideCoverCoreTests/EchoesAndRipplesTests.swift` (auto-
discovered). Mirror the date/fixture helpers from `InstantGratificationTests`
(current-calendar dates — **not** timezone-pinned; `BookDay.capturedPages`
windows on `Calendar.current`). Cover at minimum:

1. **Echo basics** — a page ≥14 days old sharing a rare ≥5-letter word with the
   input produces an echo naming that word; a 3-day-old page does not; `.fuel`
   pages never echo; no overlap → nil.
2. **Echo determinism** — same input + pageID + archive → identical `Echo`.
3. **Belief weighting** — with `beliefBySlug` giving one slug 500 and the rest
   1, at least 30 of 40 seeded pageIDs pick the heavy voice; with an empty map
   the pick is unchanged from the default-weight path.
4. **Festival lines** — each of the eight sabbat IDs returns its own line;
   an unknown ID returns the default line; `castName` contains the common name.
5. **Ripple tiers** — belief 10 → "stirred", 45 → "brightened", 75 → "steadier".
6. **Note ripple field** — `Note` equality includes `rippleLine` (construct two
   notes differing only there and assert inequality).

Also re-run `InstantGratificationTests`: the weighted-pick arithmetic changes
which voice a given seed lands on. If a test pinned an exact voice, re-pin the
expectation; the determinism and threshold assertions must stay as they are.

## Verification

- `swift test` from the repo root — all suites green.
- Build the app scheme (UI changes in ContentView/BookStatusCards are not
  covered by `swift test`).
- Manual pass on device: keep a page tagged with a cast member (a castBond or
  story page) → margin note with a gold ripple caption; keep a meaty sentence →
  toast shows "Tap to press a souvenir card", tapping presents the gilded card
  with a ShareLink; keep a page reusing a distinctive word from an old page →
  the Book's echo line with the month. On a sabbat (or by faking the date),
  first keep of the day gets the Almanac's line.
